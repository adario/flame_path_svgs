import 'dart:math';
import 'dart:ui';

import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/hud.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

class DominoExample({bool showPieces = false}) extends Forge2DExampleGame {
  static const description = '''
    The classic domino tower: vertical dominoes carry horizontal ones as
    planks, level by level, with braces at the edges.

    The tower stands on its own until you tap the screen, which drops a random
    shape, different from the last one, that topples it. The shape collides as
    the convex pieces of its outline, which the Show pieces knob draws.

    The frame rate is shown at the top left, and the number of bodies at the
    top right.
  ''';

  this
    : super(
        gravity: Vector2(0, 10.0),
        world: DominoExampleWorld(showPieces: showPieces),
        metersToPixels: 24,
      );
}

class DominoExampleWorld({bool showPieces = false})
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame>, ShowPieces, BodiesHud {
  this {
    this.showPieces = showPieces;
  }

  static const dominoWidth = 0.2;
  static const dominoHeight = 1.0;
  static const baseCount = 12;

  /// The size of the dropped shapes, in meters.
  static final shapeSize = Vector2(2, 3);

  int _tint = 0;

  final _shapes = ShuffledTestPaths();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(Ground());
    _buildTower();

    // Frame the tower, which is built upwards from the ground at y = 0.
    gameRef.camera.viewfinder.position = Vector2(0, -towerHeight / 2);
  }

  /// How tall the finished tower is, in world units.
  static double get towerHeight =>
      dominoHeight * 0.5 + (dominoHeight + 2 * dominoWidth) * (baseCount - 1);

  /// Adds a domino [height] above the ground, standing up or lying down.
  void _addDomino(
    double x,
    double height, {
    required bool horizontal,
    required double density,
  }) {
    add(
      Domino(
        // The tower is built upwards, which is the negative y direction.
        initialPosition: Vector2(x, -height),
        horizontal: horizontal,
        density: density,
        color: ExampleColors.dynamicColor(_tint++),
      ),
    );
  }

  void _buildTower() {
    var density = 10.0;

    for (var i = 0; i < baseCount; i++) {
      final x = i * 1.5 * dominoHeight - 1.5 * dominoHeight * baseCount / 2;
      _addDomino(x, dominoHeight / 2, horizontal: false, density: density);
      _addDomino(
        x,
        dominoHeight + dominoWidth / 2,
        horizontal: true,
        density: density,
      );
    }

    for (var level = 1; level < baseCount; level++) {
      if (level > 3) {
        density *= 0.8;
      }
      final height =
          dominoHeight * 0.5 + (dominoHeight + 2 * dominoWidth) * 0.99 * level;
      final count = baseCount - level;
      for (var i = 0; i < count; i++) {
        final x = i * 1.5 * dominoHeight - 1.5 * dominoHeight * count / 2;
        // The braces at both ends of a level are heavier, which is what
        // keeps the tower standing.
        density *= 2.5;
        if (i == 0) {
          _addDomino(
            x - 1.25 * dominoHeight + 0.5 * dominoWidth,
            height - dominoWidth,
            horizontal: false,
            density: density,
          );
        }
        if (i == count - 1) {
          _addDomino(
            x + 1.25 * dominoHeight - 0.5 * dominoWidth,
            height - dominoWidth,
            horizontal: false,
            density: density,
          );
        }
        density /= 2.5;

        _addDomino(x, height, horizontal: false, density: density);
        _addDomino(
          x,
          height + 0.5 * (dominoWidth + dominoHeight),
          horizontal: true,
          density: density,
        );
        _addDomino(
          x,
          height - 0.5 * (dominoWidth + dominoHeight),
          horizontal: true,
          density: density,
        );
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final position = event.localPosition;
    add(
      PathShape(position, TestPaths.byIndex(_shapes.next(), shapeSize.toSize()))
        ..paint = (Paint()..color = ExampleColors.dynamicColor(_tint++))
        ..renderBody = showPieces,
    );
  }
}

class Domino({
  /// Where the domino starts out; [position] tracks the live body position.
  required final Vector2 initialPosition,
  required final bool horizontal,
  required final double density,
  required Color color,
}) extends BodyComponent with GlowingBody {
  this {
    paint = Paint()..color = color;
  }

  @override
  double get outlineWidth => 0.04;

  @override
  Body createBody() {
    final bodyDef = BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
      rotation: horizontal ? Rot.fromAngle(pi / 2) : const Rot.identity(),
    );
    return world.createBody(bodyDef)..createShape(
      Polygon.box(
        DominoExampleWorld.dominoWidth / 2,
        DominoExampleWorld.dominoHeight / 2,
      ),
      // The default material is what a domino wants: plenty of grip and no
      // bounce. With less friction the tower shakes itself apart as soon as
      // the frame rate dips.
      ShapeDef(density: density),
    );
  }
}

class Ground() extends BodyComponent with GlowingBody {
  this {
    paint = Paint()..color = ExampleColors.slate;
  }

  @override
  Body createBody() {
    // The top of the ground is at y = 0, which the tower is built up from.
    final bodyDef = BodyDef(position: Vector2(0, 1));
    return world.createBody(bodyDef)..createShape(Polygon.box(24, 1));
  }
}
