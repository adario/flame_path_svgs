import 'dart:math';
import 'dart:ui';

import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/joints/wheel_joint.dart'
    show TrackEnd, WheelJointExample;
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/joint_renderer.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_svg/flame_svg.dart';

class PathWheelJointExample() extends Forge2DExampleGame {
  static const description = '''
    This example shows how to use a `WheelJoint`, which is the suspension of
    a vehicle: the wheel can spin and travel along a spring-loaded axis.

    The chassis and the wheels of the car are the paths of an SVG file, laid
    out as they are in the file, and the hills are a path of cubic curves.

    Tap the screen to change the direction that the car drives in.
  ''';

  this
    : super(
        gravity: Vector2(0, 10.0),
        world: PathWheelJointWorld(),
        metersToPixels: 14,
      );
}

class PathWheelJointWorld()
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame> {
  final joints = <WheelJoint>[];

  /// Faster than in the [WheelJointExample], as the wheels are smaller, so
  /// that the car bounces over the hills as much.
  static const _motorSpeed = 24.0;
  bool drivingRight = true;

  /// The paths of the left wheel, the right wheel and the chassis of the car
  /// in `car.svg`, all scaled alike, so that the chassis is as wide as
  /// the one of the [WheelJointExample]: 4.4 meters.
  static Future<List<Path>> loadCar() async {
    // Without merging, the wheels are paths of their own, even though they
    // have the same paint.
    final svg = await SvgPaths.fromFile('assets/svgs/car.svg', merge: false);
    final paths = [for (var i = 0; i < 3; i++) svg.pathAt(i)!.path];
    final scale = 4.4 / paths[2].getBounds().width;
    final matrix = Matrix4.diagonal3Values(scale, scale, 1).storage;
    return [for (final path in paths) path.transform32(matrix)];
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(Terrain());
    // Keeps the car on the track instead of driving off into the void.
    add(TrackEnd(Terrain.startX));
    add(TrackEnd(Terrain.endX));

    final [leftWheel, rightWheel, chassisPath] = await loadCar();
    final chassis = Chassis(Vector2(-14, 1), chassisPath);
    add(chassis);
    await chassis.loaded;
    // Follow the car so that it stays visible while it drives.
    gameRef.camera.follow(chassis);

    for (final wheelPath in [leftWheel, rightWheel]) {
      // The wheel is placed on the chassis as it is in the SVG file.
      final offset =
          (wheelPath.getBounds().center - chassisPath.getBounds().center)
              .toVector2();
      final wheel = Wheel(chassis.body.position + offset, wheelPath);
      add(wheel);
      await wheel.loaded;

      // The wheel hangs under the chassis on a spring and is driven by the
      // joint's motor.
      final joint = physicsWorld.createWheelJoint(
        WheelJointDef(
          bodyA: chassis.body,
          bodyB: wheel.body,
          localAnchorA: offset,
          localAxisA: Vector2(0, 1),
          hertz: 4,
          dampingRatio: 0.6,
          enableLimit: true,
          lowerTranslation: -0.3,
          upperTranslation: 0.3,
          enableMotor: true,
          maxMotorTorque: 60,
          motorSpeed: _motorSpeed,
        ),
      );
      joints.add(joint);
      add(JointRenderer(joint: joint, color: ExampleColors.amber));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    drivingRight = !drivingRight;
    for (final joint in joints) {
      joint.motorSpeed = drivingRight ? _motorSpeed : -_motorSpeed;
    }
  }
}

/// A body with the shape of the [_path], in meters, centered on its
/// position.
class Chassis(final Vector2 _position, final Path _path)
    extends BodyComponent
    with GlowingBody, PathShapes {
  this : super(renderBody: false) {
    paint = Paint()..color = ExampleColors.indigo;
  }

  @override
  late final List<PathPlacement> pathPlacements = [
    (
      path: _path,
      contour: null,
      size: _path.getBounds().size.toVector2(),
      offset: Vector2.zero(),
    ),
  ];

  @override
  Body createBody() {
    final bodyDef = BodyDef(type: BodyType.dynamic, position: _position);
    final body = world.createBody(bodyDef);
    createPathShapes(body, ShapeDef(material: SurfaceMaterial(friction: 0.3)));
    return body;
  }
}

/// A body with the shape of the [_path], in meters, centered on its
/// position, with a radius line that makes its rotation visible.
class Wheel(final Vector2 _position, final Path _path)
    extends BodyComponent
    with GlowingBody, PathShapes {
  this : super(renderBody: false) {
    paint = Paint()..color = ExampleColors.emerald;
  }

  @override
  late final List<PathPlacement> pathPlacements = [
    (
      path: _path,
      contour: null,
      size: _path.getBounds().size.toVector2(),
      offset: Vector2.zero(),
    ),
  ];

  late final _radiusEnd = Offset(_path.getBounds().width / 2, 0);
  late final _radiusPaint = Paint()
    ..color = paint.color.withValues(alpha: 0.95)
    ..style = PaintingStyle.stroke
    ..strokeWidth = pathOutlineWidth;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawLine(Offset.zero, _radiusEnd, _radiusPaint);
  }

  @override
  Body createBody() {
    final bodyDef = BodyDef(type: BodyType.dynamic, position: _position);
    final body = world.createBody(bodyDef);
    createPathShapes(
      body,
      ShapeDef(density: 2, material: SurfaceMaterial(friction: 1.5)),
    );
    return body;
  }
}

/// The rolling hills of the [WheelJointExample] for the car to drive over,
/// drawn as a [path] of cubic curves, and colliding as a one-sided chain
/// through the points of that path.
class Terrain() extends BodyComponent {
  this : super(renderBody: false) {
    paint = Paint()
      ..color = ExampleColors.slate.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;
  }

  static const startX = -20.0;
  static const endX = 100.0;

  /// The height of the ground at [x], as in the [WheelJointExample].
  static double heightAt(double x) => 6 - sin((x - startX) / 3) * 1.2;

  /// The ground, with a cubic curve for each half period of the sinusoid of
  /// [heightAt], from the top of a hill to the bottom of a valley or the
  /// other way around, which follows it within a millimeter. It runs from the
  /// last of these points before [startX] to the first one after [endX].
  static final Path path = () {
    const halfPeriod = 3 * pi;
    // The handles are horizontal, as the ends of each curve are, and this
    // long, which keeps the curve closest to the sinusoid.
    const handle = 0.3645 * halfPeriod;
    var x = startX - halfPeriod / 2;
    final path = Path()..moveTo(x, heightAt(x));
    while (x < endX) {
      final next = x + halfPeriod;
      path.cubicTo(
        x + handle,
        heightAt(x),
        next - handle,
        heightAt(next),
        next,
        heightAt(next),
      );
      x = next;
    }
    return path;
  }();

  /// The points of the chain, from left to right, sampled about every meter
  /// along the [path] and kept only where they are needed to stay within a
  /// centimeter of it.
  static final List<Vector2> chainPoints = [
    for (final point in path.walkContourAt(0, 1, 0.01)) point.toVector2(),
  ];

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawPath(path, paint);
  }

  @override
  Body createBody() {
    // Chains are one-sided: the solid surface is to the right of the winding
    // direction. Flame's y-axis points down, so listing the ground from left
    // to right is what puts the drivable surface on top.
    return world.createBody(BodyDef())..createChain(
      ChainDef(
        points: chainPoints,
        materials: [SurfaceMaterial(friction: 0.8)],
      ),
    );
  }
}
