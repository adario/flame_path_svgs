import 'dart:math';
import 'dart:ui';

import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/hud.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/spawn_layout.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

class RevoluteJointWithMotorExample() extends Forge2DExampleGame {
  static const String description = '''
    This example showcases a revolute joint, which is the spinning balls in the
    center.
    
    If you tap the screen some colorful balls and test path shapes are added
    and will interact with the bodies tied to the revolute joint once they
    have fallen down the funnel.

    The frame rate is shown at the top left, and the number of bodies at the
    top right.
  ''';

  this : super(world: RevoluteJointWithMotorWorld());
}

class RevoluteJointWithMotorWorld()
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame>, BodiesHud {
  final random = Random();

  /// The indices in [TestPaths.names] of the test paths that are added.
  static final _shapes = [
    for (final name in ['abstract', 'alien1', 'flame', 'invader1', 'invader2'])
      TestPaths.names.indexOf(name),
  ];

  /// The bodies are kept between 0.1 and 10 meters, which Forge2D is tuned
  /// for: the radius of the balls is between these ones, in meters.
  static const _minBallRadius = 0.4;
  static const _maxBallRadius = 1.0;

  /// The size of the test path shapes is between these ones, in meters, so
  /// that each of their convex pieces is at least 0.1 meters across too.
  static const _minShapeSize = 3.0;
  static const _maxShapeSize = 3.5;

  int _tint = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final boundaries = createBoundaries(gameRef);
    addAll(boundaries);
    final center = Vector2.zero();
    add(CircleShuffler(center));
    add(CornerRamp(center, isMirrored: true));
    add(CornerRamp(center));
  }

  @override
  void onTapDown(TapDownEvent info) {
    super.onTapDown(info);
    final tapPosition = info.localPosition;
    // Half of the bodies are balls and half are shapes, in turns. Each one is
    // given by its bounding radius and a function that creates it at a
    // position.
    final ballsFirst = random.nextBool();
    final bodies = <(double, BodyComponent Function(Vector2))>[
      for (var i = 0; i < 15; i++)
        if (i.isEven == ballsFirst) _randomBall() else _randomShape(),
    ];
    final positions = spreadAround(
      tapPosition,
      [for (final (radius, _) in bodies) radius],
      // Inside of the walls.
      bounds: gameRef.camera.visibleWorldRect.deflate(_wallWidth),
      world: physicsWorld,
      random: random,
    );
    for (final (index, (_, create)) in bodies.indexed) {
      final position = positions[index];
      final body = create(position);
      add(body);
      // The bodies move away from the tap, as they used to do when they
      // started overlapping each other.
      final direction = position - tapPosition;
      final velocity = direction.isZero()
          ? (Vector2.random(random) - Vector2.all(0.5))
          : direction;
      velocity.scaleTo(_spreadSpeed);
      body.loaded.then((_) => body.body.linearVelocity = velocity);
    }
  }

  /// The width of the walls, which [createBoundaries] lays out along the
  /// edges of the visible world.
  static const _wallWidth = 0.15;

  /// The speed in meters per second at which the new bodies move away from
  /// the tap.
  static const _spreadSpeed = 2.0;

  (double, BodyComponent Function(Vector2)) _randomBall() {
    final radius = _randomBetween(_minBallRadius, _maxBallRadius);
    return (radius, (position) => Ball(position, radius: radius));
  }

  (double, BodyComponent Function(Vector2)) _randomShape() {
    final size = Vector2.all(_randomBetween(_minShapeSize, _maxShapeSize));
    final shape = _shapes[random.nextInt(_shapes.length)];
    final color = ExampleColors.dynamicColor(_tint++);
    // The shape fits within its size, centered on the body.
    return (
      size.length / 2,
      (position) => PathShape(
        position,
        TestPaths.byIndex(shape, size.toSize()),
        size: size,
      )..paint = (Paint()..color = color),
    );
  }

  double _randomBetween(double min, double max) {
    return min + random.nextDouble() * (max - min);
  }
}

class CircleShuffler(final Vector2 _center) extends BodyComponent {
  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: _center + Vector2(0.0, 25.0),
    );
    const numPieces = 5;
    const radius = 6.0;
    final body = world.createBody(bodyDef);

    for (var i = 0; i < numPieces; i++) {
      final xPos = radius * cos(2 * pi * (i / numPieces));
      final yPos = radius * sin(2 * pi * (i / numPieces));

      body.createShape(
        Circle(radius: 1.2, center: Vector2(xPos, yPos)),
        ShapeDef(
          density: 50.0,
          material: SurfaceMaterial(friction: 0.5, restitution: 0.4),
        ),
      );
    }
    // Create an empty ground body.
    final groundBody = world.createBody(BodyDef());

    world.physicsWorld.createRevoluteJoint(
      RevoluteJointDef(
        bodyA: body,
        bodyB: groundBody,
        localAnchorB: body.position.clone(),
        motorSpeed: pi,
        maxMotorTorque: 1000000.0,
        enableMotor: true,
      ),
    );
    return body;
  }
}

class CornerRamp(final Vector2 _center, {final bool isMirrored = false})
    extends BodyComponent
    with GlowingBody {
  this {
    paint = Paint()..color = ExampleColors.slate;
  }

  @override
  Body createBody() {
    final mirrorFactor = isMirrored ? -1 : 1;
    // The tips of the ramps are 8 meters apart, more than twice the size of
    // the test path shapes, which would pile up at a narrower opening.
    final diff = 4.0 * mirrorFactor;
    // A solid polygon rather than a chain loop: chains are one-sided in
    // Box2D v3, so a chain ramp lets balls through from the other side and
    // they end up trapped inside it.
    final vertices = [
      Vector2(diff, 0),
      Vector2(diff + 20.0 * mirrorFactor, -20.0),
      Vector2(diff + 35.0 * mirrorFactor, -30.0),
    ];

    final bodyDef = BodyDef(position: _center);

    return world.createBody(bodyDef)..createShape(
      Polygon(vertices),
      ShapeDef(material: SurfaceMaterial(friction: 0.5)),
    );
  }
}
