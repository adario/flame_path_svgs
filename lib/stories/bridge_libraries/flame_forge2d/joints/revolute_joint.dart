import 'dart:math';
import 'dart:ui';

import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/joint_renderer.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class RevoluteJointExample() extends Forge2DExampleGame {
  static const description = '''
    In this example we use a joint to keep a body with several fixtures stuck
    to another body.

    Tap the screen to add more of these combined bodies, whose pieces are
    circles or the SVG files of test paths, in turns.
  ''';

  this : super(gravity: Vector2(0, 10.0), world: RevoluteJointWorld());
}

class RevoluteJointWorld()
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame>, HasSvgTestPaths {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    addAll(createBoundaries(gameRef));
  }

  /// The shapes of the pieces, which cycle on each tap.
  final _shapes = BallOrTestPath();

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final ball = Ball(event.localPosition);
    add(ball);
    const size = CircleShuffler.pathSize;
    final shape = _shapes.next();
    final path = shape == null ? null : pathOf(shape, const Size(size, size));
    add(CircleShuffler(ball, path: path));
  }
}

/// A ring of pieces around the [ball], which are circles, or the whole [path]
/// fitted within [pathSize], if any, as [PathShapes].
class CircleShuffler(final Ball ball, {final Path? path})
    extends BodyComponent
    with PathShapes {
  // The convex pieces of a path are not drawn, only the path.
  this : super(renderBody: path == null);

  static const pieceRadius = 1.2;

  /// The size of the square that the [path] is fitted within, in meters,
  /// slightly larger than the circles.
  static const pathSize = pieceRadius * 2 + 1;

  static const _numPieces = 5;
  static const _radius = 6.0;

  /// The centers of the pieces, in the coordinates of the body.
  static final _centers = [
    for (var i = 0; i < _numPieces; i++)
      Vector2(
        _radius * cos(2 * pi * (i / _numPieces)),
        _radius * sin(2 * pi * (i / _numPieces)),
      ),
  ];

  @override
  late final List<PathPlacement> pathPlacements = [
    if (path != null)
      for (final center in _centers)
        (
          path: path!,
          contour: null,
          size: Vector2.all(pathSize),
          offset: center,
        ),
  ];

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: ball.body.position.clone(),
    );
    final body = world.createBody(bodyDef);
    final shapeDef = ShapeDef(
      density: 50.0,
      material: SurfaceMaterial(friction: 0.5, restitution: 0.4),
    );

    if (path == null) {
      for (final center in _centers) {
        body.createShape(Circle(radius: pieceRadius, center: center), shapeDef);
      }
    } else {
      createPathShapes(body, shapeDef);
    }

    final joint = world.physicsWorld.createRevoluteJoint(
      RevoluteJointDef(bodyA: body, bodyB: ball.body),
    );
    world.add(JointRenderer(joint: joint));

    return body;
  }
}
