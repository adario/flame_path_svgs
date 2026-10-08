import 'package:flame_path_shapes/commons/test_path_knob.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

/// A game with a single body of the shape picked with the [testPathKnob],
/// either a ball or a test path, which is replaced by a body of another shape
/// whenever the knob changes; the new body takes on the motion of the old one.
///
/// The world of the game must have [ShowPieces].
mixin SwappableBody on Forge2DGame, TestPathSelectable {
  /// The index in [TestPaths.names] of the first shape, or [ballShape].
  int get initialShape;

  /// Creates a body of the given [shape] at the given [position], where
  /// [shape] is an index in [TestPaths.names] or [ballShape].
  BodyComponent createSwappable(int shape, Vector2 position);

  late int _shape = initialShape;
  var _isReady = false;

  /// The current body.
  BodyComponent? _swappable;

  /// The motion that the [_swappable] takes on from the body that it
  /// replaced, once it is loaded, if it is not loaded yet.
  _Motion? _pendingMotion;

  ShowPieces get _world => world as ShowPieces;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _addSwappable();
    _isReady = true;
  }

  /// Replaces the body with one of the given [shape].
  @override
  void setShape(int shape) {
    if (shape == _shape) {
      return;
    }
    _shape = shape;
    if (_isReady) {
      _addSwappable();
    }
  }

  @override
  void setShowPieces(bool showPieces) => _world.showPieces = showPieces;

  /// Adds a body of the [_shape], which replaces the current one and takes on
  /// its motion: position, angle and velocities.
  void _addSwappable() {
    final current = _swappable;
    // A body that is not loaded yet has no motion of its own, but the one that
    // it was going to take on.
    final motion = current != null && current.isLoaded
        ? _Motion.of(current.body)
        : _pendingMotion;
    current?.removeFromParent();
    final position = motion?.position.clone() ?? Vector2.zero();
    final swappable = createSwappable(_shape, position);
    if (swappable is PathShape) {
      swappable.renderBody = _world.showPieces;
    }
    world.add(_swappable = swappable);
    _pendingMotion = motion;
    if (motion != null) {
      // The body is created when the component is loaded.
      swappable.loaded.then((_) {
        if (_swappable == swappable) {
          motion.applyTo(swappable.body);
          _pendingMotion = null;
        }
      });
    }
  }
}

/// The position, angle and velocities of a body.
class _Motion.of(Body body) {
  final Vector2 position = body.position.clone();
  final double angle = body.angle;
  final Vector2 linearVelocity = body.linearVelocity.clone();
  final double angularVelocity = body.angularVelocity;

  void applyTo(Body body) {
    body
      ..setTransform(position, Rot.fromAngle(angle))
      ..linearVelocity = linearVelocity
      ..angularVelocity = angularVelocity;
  }
}
