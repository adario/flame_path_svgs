import 'dart:math';

import 'package:flame_path_shapes/commons/paths.dart';
import 'package:flame_path_shapes/commons/test_path_knob.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/palette.dart';
import 'package:flame_noise/flame_noise.dart';
import 'package:flame_test/test_paths.dart';
import 'package:flutter/material.dart';

class RaycastMaxDistanceExample extends FlameGame
    with HasCollisionDetection, TestPathSelectable {
  static const description = '''
This examples showcases how raycast APIs can be used to detect hits within certain range.
The moving shape is chosen randomly, and can be changed with the Shape knob and
rotated with the Rotate knob.
''';

  /// Shows the shape with the given index in [TestPaths.names], or a random
  /// one if there is none, which is passed to [onShapeLoaded].
  RaycastMaxDistanceExample({int? shape})
    : _shape = shape ?? Random().nextInt(TestPaths.count);

  static const _maxDistance = 50.0;
  static const _rotateAmplitude = pi * 2;
  static const _rotateDuration = 2.0;

  int _shape;
  var _isReady = false;

  /// Moves the shape back and forth, while the shape rotates within it.
  final _carrier = PositionComponent();
  PositionComponent? _movingShape;
  var _isRotating = false;
  Effect? _rotate;

  /// Counts the requests for a moving shape, as loading one is asynchronous,
  /// so that only the latest one is added.
  var _shapeRequests = 0;

  late Ray2 _ray;
  late _Character _character;
  final _result = RaycastResult<ShapeHitbox>();

  final _text = TextComponent(
    text: "Hey! Who's there?",
    anchor: Anchor.center,
    textRenderer: TextPaint(
      style: const TextStyle(
        fontSize: 8,
        color: Colors.amber,
      ),
    ),
  );

  @override
  Future<void> onLoad() async {
    camera = CameraComponent.withFixedResolution(
      world: world,
      width: 320,
      height: 180,
    );

    // The carrier moves back and forth at all times, whatever the shape and
    // its rotation.
    _carrier.add(
      MoveByEffect(
        Vector2(50, 0),
        EffectController(
          duration: 2,
          alternate: true,
          infinite: true,
        ),
      ),
    );
    world.add(_carrier);
    await _addMovingShape();

    world.add(
      _character = _Character(
        maxDistance: _maxDistance,
        position: Vector2(-50, 0),
        anchor: Anchor.center,
      ),
    );

    _text.position = _character.position - Vector2(0, 50);

    _ray = Ray2(
      origin: _character.absolutePosition,
      direction: Vector2(1, 0),
    );
    _isReady = true;
    onShapeLoaded?.call(_shape);
  }

  /// Replaces the moving shape, which keeps moving and keeps its angle.
  @override
  void setShape(int shape) {
    if (shape == _shape) {
      return;
    }
    _shape = shape;
    if (_isReady) {
      _addMovingShape();
    }
  }

  /// Rotates the moving shape or stops it, keeping its current angle.
  @override
  void setRotate(bool rotate) {
    if (rotate == _isRotating) {
      return;
    }
    _isRotating = rotate;
    _updateRotate();
  }

  void _updateRotate() {
    _rotate?.removeFromParent();
    _rotate = null;
    if (_isRotating) {
      _movingShape?.add(
        _rotate = RotateEffect.by(
          _rotateAmplitude,
          EffectController(duration: _rotateDuration, infinite: true),
        ),
      );
    }
  }

  Future<void> _addMovingShape() async {
    final request = ++_shapeRequests;
    final size = Vector2(20, 40) * 1.5;
    final component = await svgComponent(
      _shape,
      size.toSize(),
      paint: BasicPalette.red.paint()..style = .stroke,
    );
    if (request != _shapeRequests) {
      // A newer shape has been requested while this one was loading.
      return;
    }
    // The pivot of the shape, the centroid of its area, is at the origin of
    // the carrier, so that the shape rotates around it in its own coordinate
    // system while the carrier moves it.
    anchorAtCentroid(component);
    component
      ..position.setZero()
      ..angle = _movingShape?.angle ?? 0;
    _movingShape?.removeFromParent();
    _movingShape = component;
    _updateRotate();
    _carrier.add(component);
  }

  @override
  void update(double dt) {
    collisionDetection.raycast(_ray, maxDistance: _maxDistance, out: _result);
    if (_result.isActive) {
      if (camera.viewfinder.children.query<Effect>().isEmpty) {
        camera.viewfinder.add(
          MoveEffect.by(
            Vector2(5, 5),
            NoiseEffectController(
              duration: 0.2,
              noise: PerlinNoise(frequency: 400),
            ),
          ),
        );
      }
      if (!_text.isMounted) {
        world.add(_text);
      }
    } else {
      _text.removeFromParent();
    }
    super.update(dt);
  }
}

class _Character extends PositionComponent {
  _Character({required this.maxDistance, super.position, super.anchor});

  final double maxDistance;

  final _rayOriginPoint = Offset.zero;
  late final _rayEndPoint = Offset(maxDistance, 0);
  final _rayPaint = BasicPalette.gray.paint();

  @override
  Future<void>? onLoad() async {
    addAll([
      CircleComponent(
        radius: 20,
        anchor: Anchor.center,
        paint: BasicPalette.green.paint(),
      )..scale = Vector2(0.55, 1),
      CircleComponent(
        radius: 10,
        anchor: Anchor.center,
        paint: _rayPaint,
      ),
      RectangleComponent(
        size: Vector2(10, 3),
        position: Vector2(12, 5),
      ),
    ]);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawLine(_rayOriginPoint, _rayEndPoint, _rayPaint);
  }
}
