import 'dart:ui';

import 'package:flame_path_shapes/commons/test_path_knob.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/swappable_body.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/palette.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

class TapCallbacksExample({final int? shape})
    extends Forge2DExampleGame
    with TestPathSelectable, SwappableBody {
  static const String description = '''
    In this example we show how to use Flame's TapCallbacks mixin to react to
    taps on `BodyComponent`s.
    Tap the ball to give it a random impulse. The Shape knob replaces the ball
    with a test path, or the other way around, which collides as the convex
    pieces of its outline that the Show pieces knob draws.
  ''';

  this
    : super(
        metersToPixels: 20,
        gravity: Vector2(0, 10.0),
        world: ShowPiecesWorld(),
      );

  /// The size of the test paths in meters, which is the size of the ball.
  static final shapeSize = Vector2.all(4);

  @override
  int get initialShape => shape ?? ballShape;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final boundaries = createBoundaries(this);
    world.addAll(boundaries);
  }

  @override
  BodyComponent createSwappable(int shape, Vector2 position) {
    if (shape == ballShape) {
      return TappableBall(position);
    }
    return TappablePathShape(
      position,
      TestPaths.byIndex(shape, shapeSize.toSize()),
      size: shapeSize,
    );
  }
}

class TappableBall(super.position) extends Ball with TapCallbacks {
  this {
    originalPaint = BasicPalette.white.paint();
    paint = originalPaint;
  }

  @override
  void onTapDown(_) {
    body.applyLinearImpulse(Vector2.random() * 1000);
    paint = randomPaint();
  }
}

/// A [PathShape] that reacts to the taps like the [TappableBall].
class TappablePathShape(super.initialPosition, super.path, {super.size})
    extends PathShape
    with TapCallbacks {
  this {
    paint = BasicPalette.white.paint();
  }

  static int _tint = 0;

  @override
  void onTapDown(_) {
    body.applyLinearImpulse(Vector2.random() * 1000);
    paint = Paint()..color = ExampleColors.dynamicColor(_tint++);
  }
}
