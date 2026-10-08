import 'dart:math';

import 'package:flame_path_shapes/commons/test_path_knob.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/balls.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/swappable_body.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';
import 'package:material_ui/material_ui.dart' hide Draggable;

class DragCallbacksExample({final int? shape})
    extends Forge2DExampleGame
    with TestPathSelectable, SwappableBody {
  static const description = '''
    In this example we use Flame's normal `DragCallbacks` mixin to give impulses
    to a ball when we are dragging it around. If you are interested in dragging
    bodies around, also have a look at the MouseJointExample.
    The Shape knob replaces the ball with a test path, or the other way around,
    which collides as the convex pieces of its outline that the Show pieces
    knob draws.
  ''';

  this : super(gravity: Vector2.all(0.0), world: ShowPiecesWorld());

  /// The radius of the ball in meters.
  static const ballRadius = 5.0;

  /// The size of the test paths in meters, which is the size of the ball.
  static final shapeSize = Vector2.all(2 * ballRadius);

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
      return DraggableBall(position);
    }
    return DraggablePathShape(
      position,
      TestPaths.byIndex(shape, shapeSize.toSize()),
      size: shapeSize,
    );
  }
}

/// The mass of the ball in kilograms, as a disc with the default density of 1.
const _ballMass =
    pi * DragCallbacksExample.ballRadius * DragCallbacksExample.ballRadius;

/// The impulse per meter dragged and per kilogram of the body, which is the
/// one that the ball has always had: 1000 for its mass.
const _dragImpulse = 1000 / _ballMass;

/// Pushes the [body] along a drag, as much for any mass.
void _applyDragImpulse(Body body, DragUpdateEvent event) {
  // The delta is in the coordinates of the body, which turn with it, while
  // the impulse is in the coordinates of the world.
  final delta = body.rotation.rotate(event.localDelta);
  body.applyLinearImpulse(delta..scale(_dragImpulse * body.mass));
}

class DraggableBall(super.position) extends Ball with DragCallbacks {
  this : super(radius: DragCallbacksExample.ballRadius) {
    originalPaint = Paint()..color = Colors.amber;
    paint = originalPaint;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    paint = randomPaint();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _applyDragImpulse(body, event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    paint = originalPaint;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    paint = originalPaint;
  }
}

/// A [PathShape] that reacts to the drags like the [DraggableBall].
class DraggablePathShape(super.initialPosition, super.path, {super.size})
    extends PathShape
    with DragCallbacks {
  this {
    paint = _originalPaint;
  }

  final _originalPaint = Paint()..color = Colors.amber;

  static int _tint = 0;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    paint = Paint()..color = ExampleColors.dynamicColor(_tint++);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _applyDragImpulse(body, event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    paint = _originalPaint;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    paint = _originalPaint;
  }
}
