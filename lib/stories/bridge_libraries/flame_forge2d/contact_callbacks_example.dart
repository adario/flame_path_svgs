import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class ContactCallbacksExample({bool showPieces = false})
    extends Forge2DExampleGame {
  static const description = '''
    This example shows how `BodyComponent`s can react to collisions with other
    bodies.
    Tap the screen to add balls or random shapes, different from the last one;
    the white balls will give an impulse to the bodies that they collide with,
    and the other bodies pass their color on to the ones that they touch.
    The shapes come from the SVG files of the test paths, and each one
    collides as the convex pieces of all of its contours, but the ones inside
    of the largest one, which the Show pieces knob draws.
  ''';

  this
    : super(
        gravity: Vector2(0, 10.0),
        world: ContactCallbackWorld(showPieces: showPieces),
      );
}

class ContactCallbackWorld({bool showPieces = false})
    extends Forge2DWorld
    with TapCallbacks, HasGameRef<Forge2DGame>, ShowPieces, HasSvgTestPaths {
  this {
    this.showPieces = showPieces;
  }

  /// The size of the added shapes in meters, which is the size of a ball.
  static final shapeSize = Vector2.all(4);

  final _random = math.Random();
  final _shapes = ShuffledTestPaths();
  int _tint = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final boundaries = createBoundaries(gameRef);
    addAll(boundaries);
  }

  @override
  void onTapDown(TapDownEvent info) {
    super.onTapDown(info);
    final position = info.localPosition;
    // White balls 20% of the times, balls 30% and shapes 50%.
    final choice = _random.nextInt(10);
    if (choice < 2) {
      add(WhiteBall(position));
    } else if (choice < 5) {
      add(Ball(position));
    } else {
      add(
        ContactPathShape(
          position,
          pathOf(_shapes.next(), shapeSize.toSize()),
          size: shapeSize,
          contour: null,
          color: ExampleColors.dynamicColor(_tint++),
        )..renderBody = showPieces,
      );
    }
  }
}

/// A [PathShape] that takes part in the game of this example like the balls.
class ContactPathShape(
  super.initialPosition,
  super.path, {
  super.size,
  super.contour,
  required Color color,
}) extends PathShape with ContactCallbacks, ContactPlayer {
  this {
    originalPaint = Paint()..color = color;
    paint = originalPaint;
  }
}
