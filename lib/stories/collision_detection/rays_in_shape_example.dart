import 'dart:async';
import 'dart:math';

import 'package:flame_path_shapes/commons/paths.dart';
import 'package:flame_path_shapes/commons/rounded_rect_component.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:flame_test/test_paths.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

const side = 200.0;
const playArea = Rect.fromLTRB(-side, -side, side, side);
const fontSize = 9.0;

/// The width below which Widgetbook switches to its mobile layout, where the
/// knobs are only reachable through a modal sheet (see its `ResponsiveLayout`).
const widgetbookMobileWidth = 840.0;

typedef ButtonColors = (Color, Color);

/// Hosts a single [RaysInShapeExample] and applies the knob values to it, so
/// that changing a knob doesn't restart the game.
///
/// When there isn't enough room for the knobs panel, the game shows its own
/// buttons as well, whose changes are written back to the knobs.
class RaysInShapeStory extends StatefulWidget {
  const RaysInShapeStory({
    required this.rotate,
    required this.shape,
    required this.rays,
    required this.changes,
    super.key,
  });

  final bool rotate;
  final int shape;
  final int rays;

  /// The number of times that a new set of rays has been requested.
  final int changes;

  @override
  State<RaysInShapeStory> createState() => _RaysInShapeStoryState();
}

class _RaysInShapeStoryState extends State<RaysInShapeStory>
    with WidgetsBindingObserver {
  late final _game = RaysInShapeExample(
    rotate: widget.rotate,
    shape: widget.shape,
    rays: widget.rays,
    onButtonChange: _updateKnobs,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The window is measured through [View], which doesn't rebuild this widget
  /// when it's resized (or the device is rotated), so that's done here.
  @override
  void didChangeMetrics() {
    setState(() {});
  }

  @override
  void didUpdateWidget(RaysInShapeStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    final world = _game.world;
    if (widget.rotate != oldWidget.rotate) {
      world.setRotate(widget.rotate);
    }
    if (widget.shape != oldWidget.shape) {
      world.setShape(widget.shape);
    }
    if (widget.rays != oldWidget.rays) {
      world.setRayCount(widget.rays);
    }
    if (widget.changes != oldWidget.changes) {
      world.changeRays();
    }
  }

  /// Writes the values changed by the buttons back to the knobs, which in turn
  /// rebuild this widget with the values that the game already has.
  void _updateKnobs() {
    if (!mounted) {
      return;
    }
    final world = _game.world;
    WidgetbookState.of(context)
      ..updateQueryField(
        group: 'knobs',
        field: 'Rotate',
        value: world.isRotating.toString(),
      )
      ..updateQueryField(
        group: 'knobs',
        field: 'Shape',
        value: RaysInShapeWorld.shapeNames[world.shapeIndex],
      );
  }

  @override
  Widget build(BuildContext context) {
    // The MediaQuery of a use case has the size of the workbench, between the
    // side panels, whereas Widgetbook picks its layout by the window width.
    final view = View.of(context);
    final width = view.physicalSize.width / view.devicePixelRatio;
    _game.showButtons =
        WidgetbookState.of(context).panels == null &&
        width < widgetbookMobileWidth;
    return GameWidget(game: _game);
  }
}

class RaysInShapeExample extends FlameGame<RaysInShapeWorld> {
  static const description = '''
In this example we showcase the raytrace functionality where you can see whether
the rays are inside the shapes or not. The rays originate from small circles,
and if the circle is inside the shape it will be green, otherwise red. And if
the ray doesn't hit any shape it will be gray. Drag a circle to move its ray and
drag its line to aim it. In the knobs panel, Shape changes the shape that the
rays are casted against, which includes concave shapes made from paths, Rotate
rotates the shape (except the circle), Quantity sets the number of rays and
Change casts a new set of rays. On narrow screens, the Rotate, Shape and Rays
buttons in the game do the same as the Rotate, Shape and Change knobs.
''';

  RaysInShapeExample({
    bool rotate = false,
    int shape = 0,
    int rays = RaysInShapeWorld.defaultRays,
    this.onButtonChange,
  }) : super(
         world: RaysInShapeWorld(rotate: rotate, shape: shape, rays: rays),
         camera: CameraComponent.withFixedResolution(
           width: playArea.width,
           height: playArea.height,
         ),
       );

  /// Called after the Rotate or Shape button has changed the world.
  final VoidCallback? onButtonChange;

  final TextRenderer textRenderer = TextPaint(
    style: const TextStyle(fontSize: fontSize - 1, color: Colors.white),
  );

  final TextRenderer textOffRenderer = TextPaint(
    style: const TextStyle(fontSize: fontSize - 1, color: Colors.white54),
  );

  final buttonSize = Vector2(40, 16);

  late AdvancedButtonComponent _rotateButton;
  late AdvancedButtonComponent _shapeButton;
  late AdvancedButtonComponent _raysButton;
  var _hasButtons = false;

  /// Whether the buttons are shown, which can be set before loading.
  bool get showButtons => _showButtons;
  bool _showButtons = false;
  set showButtons(bool value) {
    if (value == _showButtons) {
      return;
    }
    _showButtons = value;
    _updateButtons();
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    _rotateButton = _createRotateButton();
    _shapeButton = _createShapeButton();
    _raysButton = _createRaysButton();
    _hasButtons = true;
    _updateButtons();
  }

  void _updateButtons() {
    if (!_hasButtons) {
      return;
    }
    final buttons = [_rotateButton, _raysButton, _shapeButton];
    if (_showButtons) {
      camera.viewport.addAll(buttons);
    } else {
      for (final button in buttons) {
        button.removeFromParent();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // The shape can also be changed by the knobs.
    if (_hasButtons && _rotateButton.isDisabled != isCircle) {
      _rotateButton.isDisabled = isCircle;
    }
  }

  Vector2 get halfSize => size * 0.5;
  bool get isCircle => world.isCircle;

  ButtonColors _getColorsFor(Color color) {
    final disabledColor = color.withValues(alpha: 0.5);
    final colors = <Color, Color>{
      BasicPalette.orange.color: BasicPalette.lightOrange.color,
      BasicPalette.blue.color: BasicPalette.lightBlue.color,
      BasicPalette.pink.color: BasicPalette.lightPink.color,
      BasicPalette.purple.color: BasicPalette.magenta.color,
    };
    final downColor = colors[color] ?? color;
    return (downColor, disabledColor);
  }

  AdvancedButtonComponent _createButton(
    String title,
    double x,
    Anchor anchor,
    Color color,
    void Function()? action, {
    double y = 2,
  }) {
    final colors = _getColorsFor(color);
    final disabledColor = colors.$2;
    final downColor = colors.$1;
    return AdvancedButtonComponent(
      position: Vector2(x, y),
      size: buttonSize,
      anchor: anchor,
      priority: RaysInShapeWorld.hudPriority,
      defaultLabel: TextComponent(text: title, textRenderer: textRenderer),
      disabledLabel: TextComponent(text: title, textRenderer: textOffRenderer),
      defaultSkin: RoundedRectComponent()..setColor(color),
      disabledSkin: RoundedRectComponent()..setColor(disabledColor),
      downSkin: RoundedRectComponent()..setColor(downColor),
      onReleased: action,
    );
  }

  AdvancedButtonComponent _createRotateButton() {
    return _createButton(
      'Rotate',
      2,
      .topLeft,
      BasicPalette.orange.color,
      _toggleRotate,
    );
  }

  AdvancedButtonComponent _createShapeButton() {
    return _createButton(
      'Shape',
      size.x * 0.5,
      .topCenter,
      BasicPalette.blue.color,
      _changeShape,
    );
  }

  AdvancedButtonComponent _createRaysButton() {
    return _createButton(
      'Rays',
      size.x - 2,
      .topRight,
      BasicPalette.purple.color,
      () => world.changeRays(),
    );
  }

  void _toggleRotate() {
    world.setRotate(!world.isRotating);
    onButtonChange?.call();
  }

  void _changeShape() {
    final shapes = RaysInShapeWorld.shapeNames.length;
    world.setShape((world.shapeIndex + 1) % shapes);
    onButtonChange?.call();
  }
}

class RayCircleComponent extends CircleComponent
    with
        DragCallbacks,
        HoverCallbacks,
        TapCallbacks,
        HasWorldRef<RaysInShapeWorld> {
  RayCircleComponent(
    this.ray, {
    super.radius,
    super.position,
    super.scale,
    super.angle,
    super.anchor,
    super.children,
    super.priority,
    super.paint,
    super.paintLayers,
    super.key,
  });

  RaycastResult<ShapeHitbox>? _raycastResult;
  bool get _hitScreen {
    final hitbox = _raycastResult?.hitbox;
    if (hitbox != null) {
      return hitbox is ScreenHitbox ||
          (hitbox is RectangleHitbox && hitbox.parent is ScreenHitbox);
    }
    return false;
  }

  late final _rayLength = playArea.width * 0.1;
  late Offset _lineTarget;

  Offset get _lineOffset => Offset(radius, radius);

  @override
  void update(double dt) {
    super.update(dt);
    _raycastResult = worldRef.intersections(ray);
    if (_raycastResult == null) {
      paint = _lightPaint;
      _lineTarget = ray.direction.scaled(_rayLength).toOffset();
    } else {
      if (_hitScreen) {
        paint = _lightPaint;
      } else {
        paint = _raycastResult!.isInsideHitbox ? _greenPaint : _redPaint;
      }
      final origin = ray.origin.toOffset();
      _lineTarget = _raycastResult!.intersectionPoint!.toOffset() - origin;
    }
    _lineSegment = _segment();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final offset = _lineOffset;
    canvas.drawLine(offset, _lineTarget + offset, paint);
  }

  @override
  void onMouseMove(MouseMoveEvent event) {
    if (worldRef.hasHovering == false || worldRef.isHovering(this)) {
      super.onMouseMove(event);
    }
  }

  @override
  void onHoverEnter() {
    if (!isDragging) {
      _isHovering = true;
    }
    worldRef.addHovering(this);
  }

  @override
  void onHoverExit() {
    if (!isDragging) {
      _isHovering = false;
    }
    worldRef.removeHovering(this);
  }

  @override
  void onHoverCancel() {
    onHoverExit();
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isDragging = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isDragging = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isDragging = false;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
    _updateFromDrag(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Guard against invalid local event positions.
    var local = event.localEndPosition;
    if (local.x.isNaN || local.y.isNaN) {
      local = absoluteToLocal(event.canvasEndPosition);
    }
    _updateFromDrag(local);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isDragging = false;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    _lineDrag = false;
    final length = radius * 2;
    final taxiDistance = point.x.abs() + point.y.abs();
    var result = taxiDistance <= length || super.containsLocalPoint(point);
    // A segment without a length contains every point.
    if (!result && _lineSegment.from != _lineSegment.to) {
      // The epsilon is compared with a cross product, which is the distance
      // to the line times the length of the segment.
      result = _lineSegment.containsPoint(
        point,
        epsilon: length * _lineSegment.length,
      );
      _lineDrag = result;
    }
    return result;
  }

  late var _lineSegment = LineSegment.zero();
  var _lineDrag = false;

  LineSegment _segment([Vector2? offset]) {
    offset ??= _lineOffset.toVector2();
    return LineSegment(offset, offset + _lineTarget.toVector2());
  }

  void _updateFromDrag(Vector2 drag) {
    final delta = drag - Vector2(radius, radius);
    if (_lineDrag) {
      // Aim the ray at the pointer, which has to be away from the origin to
      // give a direction.
      if (!delta.isZero()) {
        ray.direction = delta.normalized();
      }
    } else {
      position += delta;
      ray.origin += delta;
    }
  }

  final Ray2 ray;

  bool get isDragging => _isDragging || isDragged;
  bool get isHovering => _isHovering || isHovered;

  bool _isDragging = false;
  bool _isHovering = false;

  Paint get _lightPaint => _paintFrom(lightStrokes);
  Paint get _redPaint => _paintFrom(redStrokes);
  Paint get _greenPaint => _paintFrom(greenStrokes);

  Paint _paintFrom(InteractiveStatePaints paints) {
    return paints.forState(isDragging: isDragging, isHovering: isHovering);
  }
}

class RaysInShapeWorld extends World
    with HasGameRef<RaysInShapeExample>, HasCollisionDetection {
  RaysInShapeWorld({bool rotate = false, int shape = 0, int rays = defaultRays})
    : isRotating = rotate,
      _componentIndex = shape,
      _count = rays;

  static const defaultRays = 200;
  static const minRays = 10;
  static const maxRays = 500;
  static const raysStep = 10;

  /// The names of the shapes, in the order of their indices.
  static final shapeNames = List<String>.unmodifiable([
    'Circle',
    'Rectangle',
    'Polygon',
    ...TestPaths.names,
  ]);

  final _rng = Random();

  /// Every ray of the current set, of which only the first [_count] are cast.
  ///
  /// Lowering the number of rays leaves the cache as it is, so that raising it
  /// again brings back the same rays (moved and aimed as they were left).
  final List<Ray2> _cache = [];
  final Map<Ray2, RayCircleComponent> _circles = {};
  int _count;

  Iterable<Ray2> get _rays => _cache.take(_count);
  Iterable<RayCircleComponent> get circleComponents =>
      _rays.map((ray) => _circles[ray]!);

  List<Ray2> randomRays(int count) => List<Ray2>.generate(
    count,
    (index) => Ray2(
      origin:
          (Vector2.random(_rng)) * playArea.size.width -
          playArea.size.toVector2() / 2,
      direction: (Vector2.random(_rng) - Vector2(0.5, 0.5)).normalized(),
    ),
  );

  /// Adds new random rays to the cache until it has at least [_count] rays.
  void _fillCache() {
    final missing = _count - _cache.length;
    if (missing <= 0) {
      return;
    }
    for (final ray in randomRays(missing)) {
      _cache.add(ray);
      _circles[ray] = RayCircleComponent(
        ray,
        position: ray.origin.clone(),
        radius: 3,
        anchor: .center,
        paint: lightStrokes.normal,
        priority: shapePriority * 2,
      );
    }
  }

  void _removeCircles(Iterable<RayCircleComponent> circles) {
    for (final circle in circles) {
      _hovering.remove(circle);
      circle.removeFromParent();
    }
  }

  int _componentIndex;

  /// The index of the current shape in [shapeNames].
  int get shapeIndex => _componentIndex;

  static final _componentSize = Vector2(
    playArea.width * 0.5,
    playArea.height * 0.5,
  );

  static Effect createRotate() {
    return RotateEffect.by(
      rotateAmplitude,
      EffectController(duration: rotateDuration, infinite: true),
    );
  }

  static double get rotateAmplitude => pi * 2.0;
  static double get rotateDuration => 20.0;

  static int get hudPriority => 1000;

  static final _pathSize = Size(playArea.width * 0.5, playArea.height * 0.5);
  final _components = [
    CircleComponent(
      priority: shapePriority,
      radius: _componentSize.x * 0.6,
      anchor: Anchor.center,
      position: Vector2.zero(),
      paint: whiteStroke,
      children: [CircleHitbox()],
    ),
    RectangleComponent(
      priority: shapePriority,
      size: _componentSize,
      anchor: Anchor.center,
      position: Vector2.zero(),
      paint: whiteStroke,
      children: [RectangleHitbox()],
    ),
    PositionComponent(
      priority: shapePriority,
      position: Vector2.zero(),
      children: [
        PolygonHitbox.relative(
            [
              Vector2(-0.7, -1),
              Vector2(1, -0.4),
              Vector2(0.3, 1),
              Vector2(-1, 0.6),
            ],
            parentSize: _componentSize,
            anchor: Anchor.center,
            position: Vector2.zero(),
          )
          ..paint = whiteStroke
          ..renderShape = true,
      ],
    ),
  ];

  late TextComponent _textComponent;
  final _textRenderer = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: fontSize),
  );

  PositionComponent get current => _components[_componentIndex];

  bool addHovering(RayCircleComponent circle) {
    return _hovering.add(circle);
  }

  bool removeHovering(RayCircleComponent circle) {
    return _hovering.remove(circle);
  }

  bool isHovering(RayCircleComponent circle) {
    return _hovering.contains(circle);
  }

  bool get hasHovering => _hovering.isNotEmpty;

  final _hovering = <RayCircleComponent>{};
  Effect? rotate;

  /// Whether the shapes rotate, which doesn't apply to the circle.
  bool isRotating;

  /// Whether [onLoad] has added the shapes and rays, before which the setters
  /// only record the values that it will use.
  var _isReady = false;

  bool get isCircle => current is CircleComponent;

  var _doUpdate = false;
  void _forceUpdate() {
    _intersections.clear();
    _doUpdate = true;
    _resetTimer();
    _resetTotalTimer();
  }

  void setRotate(bool value) {
    if (value == isRotating) {
      return;
    }
    isRotating = value;
    if (!_isReady) {
      return;
    }
    if (isRotating) {
      _addRotate(current);
    } else {
      _removeRotate();
    }
    _forceUpdate();
  }

  void setShape(int index) {
    if (index == _componentIndex) {
      return;
    }
    if (!_isReady) {
      _componentIndex = index;
      return;
    }
    final angle = isRotating && !isCircle ? current.angle : null;
    remove(current);
    _componentIndex = index;
    _addCurrent(current);
    if (isRotating && angle != null) {
      current.angle = angle;
    }
    _forceUpdate();
  }

  void setRayCount(int count) {
    if (count == _count) {
      return;
    }
    final previous = _count;
    _count = count;
    if (!_isReady) {
      return;
    }
    if (count > previous) {
      _fillCache();
      addAll(_cache.sublist(previous, count).map((ray) => _circles[ray]!));
    } else {
      _removeCircles(
        _cache.sublist(count, previous).map((ray) => _circles[ray]!),
      );
    }
    _forceUpdate();
  }

  /// Replaces the cache with a new set of rays.
  void changeRays() {
    _removeCircles(circleComponents);
    _cache.clear();
    _circles.clear();
    _fillCache();
    addAll(circleComponents);
    _forceUpdate();
  }

  void _addRotate(Component component) {
    _removeRotate();
    final effect = current.firstChild<Effect>();
    if (_componentIndex != 0 && effect == null) {
      rotate = createRotate();
      component.add(rotate!);
    }
  }

  void _removeRotate() {
    rotate?.removeFromParent();
    rotate = null;
  }

  void _addCurrent(PositionComponent component) {
    _removeRotate();
    if (isRotating && !isCircle) {
      _addRotate(component);
    }
    add(component);
  }

  Future<void> _addComponents() async {
    final svgs = [
      for (var index = 0; index < TestPaths.count; ++index)
        await svgComponent(
          index,
          _pathSize,
          paint: pathStroke,
          renderHitboxes: true,
        ),
    ];
    // Rotate the paths around the center of their area.
    svgs.forEach(anchorAtCentroid);
    _components.addAll(svgs);
  }

  @override
  FutureOr<void> onLoad() async {
    super.onLoad();
    await _addComponents();

    _addCurrent(current);
    add(ScreenHitbox());
    _textComponent = TextComponent(
      text: '',
      priority: hudPriority,
      position: Vector2(
        (playArea.width * 0.5) - 2,
        (playArea.height * 0.5) - 6,
      ),
      anchor: .centerRight,
      textRenderer: _textRenderer,
    );
    addAll([
      FpsTextComponent(
        decimalPlaces: 1,
        windowSize: _updatesInterval,
        priority: hudPriority,
        position: Vector2(
          (-playArea.width * 0.5) + 2,
          (playArea.height * 0.5) - 6,
        ),
        anchor: .centerLeft,
        textRenderer: _textRenderer,
      ),
      _textComponent,
    ]);
    _fillCache();
    addAll(circleComponents);
    _isReady = true;
  }

  final Map<Ray2, RaycastResult<ShapeHitbox>?> _intersections = {};
  final int _updatesInterval = 30;
  var _totalUpdates = 0;
  final _timings = <double>[];
  late Stopwatch _timer;

  RaycastResult<ShapeHitbox>? intersections(Ray2 ray) => _intersections[ray];

  double _totalElapsed = 0;

  void _startTimer() {
    _timer = Stopwatch()..start();
  }

  double? _advanceTimer() {
    _timer.stop();
    _timings.add(_timer.elapsedMicroseconds.toDouble());
    if (_doUpdate || _timings.length >= _updatesInterval) {
      if (_doUpdate) {
        _doUpdate = false;
        return 0;
      } else {
        _timings.sort();
        return _timings[_timings.length ~/ 2];
      }
    }
    return null;
  }

  void _updateTotalTimer(double elapsed) {
    _totalElapsed += elapsed;
    _totalUpdates++;
  }

  void _resetTimer() {
    _timings.clear();
  }

  void _resetTotalTimer() {
    _totalUpdates = 0;
    _totalElapsed = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _startTimer();
    for (final ray in _rays) {
      _intersections[ray] = collisionDetection.raycast(ray);
    }
    final elapsed = _advanceTimer();
    if (elapsed != null) {
      _updateTimer(elapsed);
      _resetTimer();
    }
  }

  void _updateTimer(double elapsed) {
    _updateTotalTimer(elapsed);
    final total = _totalElapsed / _totalUpdates;
    _updateTimerText(elapsed, total);
  }

  void _updateTimerText(double elapsed, double total) {
    _textComponent.text =
        '${elapsedString(elapsed).padLeft(7)}'
        '/${elapsedString(total).padLeft(7)}';
  }

  String elapsedString(double elapsed) {
    if (elapsed >= 1000) {
      return '${(elapsed / 1000).toStringAsFixed(1)}ms';
    } else {
      return '${elapsed.toStringAsFixed(1)}us';
    }
  }
}
