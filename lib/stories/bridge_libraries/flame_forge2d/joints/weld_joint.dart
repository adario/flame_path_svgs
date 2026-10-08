import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/boxes.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/joint_renderer.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart';

class WeldJointExample() extends Forge2DExampleGame {
  static const description = '''
    This example shows how to use a `WeldJoint`. Tap the screen to add a
    ball or the SVG file of a test path, in turns, to test the bridge built
    using a `WeldJoint`.
  ''';

  this : super(world: WeldJointWorld());
}

class WeldJointWorld()
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame>, HasSvgTestPaths {
  final pillarHeight = 20.0;
  final pillarWidth = 5.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final leftPillar = Box(
      startPosition: gameRef.screenToWorld(Vector2(50, gameRef.size.y))
        ..y -= pillarHeight / 2,
      width: pillarWidth,
      height: pillarHeight,
      bodyType: BodyType.static,
      color: Colors.white,
    );
    final rightPillar = Box(
      startPosition: gameRef.screenToWorld(
        Vector2(gameRef.size.x - 50, gameRef.size.y),
      )..y -= pillarHeight / 2,
      width: pillarWidth,
      height: pillarHeight,
      bodyType: BodyType.static,
      color: Colors.white,
    );

    final pillars = [leftPillar, rightPillar];
    addAll(pillars);
    await pillars.loaded;

    createBridge(leftPillar, rightPillar);
  }

  Future<void> createBridge(Box leftPillar, Box rightPillar) async {
    const sectionsCount = 10;
    // Vector2.zero is used here since 0,0 is in the middle and 0,0 in the
    // screen space then gives us the coordinates of the upper left corner in
    // world space.
    final halfSize = gameRef.screenToWorld(Vector2.zero())..absolute();
    final sectionWidth =
        ((leftPillar.center.x.abs() +
                    rightPillar.center.x.abs() +
                    pillarWidth) /
                sectionsCount)
            .ceilToDouble();
    Body? prevSection;

    for (var i = 0; i < sectionsCount; i++) {
      final section = Box(
        startPosition: Vector2(
          sectionWidth * i - halfSize.x + sectionWidth / 2,
          halfSize.y - pillarHeight,
        ),
        width: sectionWidth,
        height: 1,
      );
      add(section);
      await section.loaded;

      if (prevSection != null) {
        createWeldJoint(
          prevSection,
          section.body,
          Vector2(
            sectionWidth * i - halfSize.x + sectionWidth,
            halfSize.y - pillarHeight,
          ),
        );
      }

      prevSection = section.body;
    }
  }

  void createWeldJoint(Body first, Body second, Vector2 anchor) {
    final joint = physicsWorld.createWeldJoint(
      WeldJointDef(
        bodyA: first,
        bodyB: second,
        localAnchorA: first.localPoint(anchor),
        localAnchorB: second.localPoint(anchor),
      ),
    );
    add(JointRenderer(joint: joint));
  }

  /// The bodies that the taps add, which cycle on each tap.
  final _shapes = BallOrTestPath();

  /// The index of the color of the next test path.
  var _tint = 0;

  @override
  Future<void> onTapDown(TapDownEvent info) async {
    super.onTapDown(info);
    const radius = 5.0;
    // A test path is slightly larger than the ball, and moves like it.
    final size = Vector2.all(radius * 2 + 1);
    final shape = _shapes.next();
    add(
      shape == null
            ? Ball(info.localPosition, radius: radius)
            : PathShape(
                info.localPosition,
                pathOf(shape, size.toSize()),
                contour: null,
                size: size,
                initialAngle: 0,
                material: SurfaceMaterial(restitution: 0.7),
                angularDamping: 0.8,
              )
        ..paint = (Paint()..color = ExampleColors.dynamicColor(_tint++)),
    );
  }
}
