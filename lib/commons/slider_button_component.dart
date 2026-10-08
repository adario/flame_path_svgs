import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_path_shapes/commons/position_paint_component.dart';
import 'package:flame_path_shapes/commons/rounded_rect_component.dart';
import 'package:flutter/foundation.dart';

class SliderButtonComponent extends PositionComponent
    with TapCallbacks, DragCallbacks, HoverCallbacks {
  SliderButtonComponent({
    required this.min,
    required this.max,
    double initialValue = 0,
    this.step,
    this.trackHeight = 10,
    this.thumbSize = 24,
    this.trackColor = const Color(0xFF5E5E5E),
    this.thumbColor = const Color(0xFFFFFFFF),
    this.activeTrackColor = const Color(0xFFB3C7FF),
    this.activeThumbColor = const Color(0xFF6FA8FF),
    this.labelSpacing = 12,
    this.minLabel,
    this.currentLabel,
    this.maxLabel,
    this.titleLabel,
    this.track,
    this.thumb,
    super.position,
    super.size,
    super.priority,
    super.anchor,
    this.valueListener,
  }) : assert(min < max),
       assert(initialValue >= min && initialValue <= max),
       valueNotifier = ValueNotifier<double>(initialValue);

  final double min;
  final double max;
  final double? step;

  final double trackHeight;
  final double thumbSize;

  final Color trackColor;
  final Color thumbColor;
  final Color activeTrackColor;
  final Color activeThumbColor;
  final double labelSpacing;

  final PositionPaintComponent? track;
  final PositionPaintComponent? thumb;
  final TextComponent? minLabel;
  final TextComponent? currentLabel;
  final TextComponent? maxLabel;
  final TextComponent? titleLabel;

  final ValueNotifier<double> valueNotifier;
  final VoidCallback? valueListener;

  double get value => valueNotifier.value;
  set value(double newValue) {
    final normalized = _normalizeValue(newValue);
    if (normalized == valueNotifier.value) {
      return;
    }
    valueNotifier.value = normalized;
  }

  double get amplitude => max - min;

  bool _isDragging = false;
  bool _isHovering = false;

  late final PositionPaintComponent _track;
  late final PositionPaintComponent _thumb;

  @override
  set position(Vector2 position) {
    super.position = position;
    _adjustItems();
  }

  @override
  set size(Vector2 size) {
    super.size = size;
    _adjustItems();
  }

  void _adjustItems() {
    _track
      ..position = Vector2(0, 0)
      ..size = Vector2(size.x, trackHeight);
    minLabel?.position = Vector2(0, trackHeight + labelSpacing);
    currentLabel?.position = Vector2(size.x / 2, trackHeight + labelSpacing);
    titleLabel?.position = Vector2(size.x / 2, -(trackHeight + labelSpacing));
    maxLabel?.position = Vector2(size.x, trackHeight + labelSpacing);
    _syncThumbPosition();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _track = track ?? RoundedRectComponent()
      ..position = Vector2(0, 0)
      ..size = Vector2(size.x, trackHeight)
      ..anchor = .topLeft
      ..setColor(trackColor);
    add(_track);

    _thumb = thumb ?? RoundedRectComponent()
      ..position = Vector2(0, trackHeight / 2)
      ..size = Vector2(thumbSize, thumbSize)
      ..anchor = .center
      ..setColor(thumbColor);
    add(_thumb);

    if (minLabel != null) {
      final label = minLabel!;
      label.anchor = .topLeft;
      label.position = Vector2(0, trackHeight + labelSpacing);
      add(label);
    }

    if (currentLabel != null) {
      final label = currentLabel!;
      label.anchor = .topCenter;
      label.position = Vector2(size.x / 2, trackHeight + labelSpacing);
      add(label);
    }

    if (titleLabel != null) {
      final label = titleLabel!;
      label.anchor = .center;
      label.position = Vector2(size.x / 2, -(trackHeight + labelSpacing));
      add(label);
    }

    if (maxLabel != null) {
      final label = maxLabel!;
      label.anchor = .topRight;
      label.position = Vector2(size.x, trackHeight + labelSpacing);
      add(label);
    }

    _applyVisualFeedback();
    _syncLabels();
  }

  @override
  void onMount() {
    super.onMount();
    valueNotifier.addListener(_handleValueChanged);
    if (valueListener != null) {
      valueNotifier.addListener(valueListener!);
    }
  }

  @override
  void onRemove() {
    if (valueListener != null) {
      valueNotifier.removeListener(valueListener!);
    }
    valueNotifier.removeListener(_handleValueChanged);
    super.onRemove();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 &&
        point.x <= size.x &&
        point.y >= 0 &&
        point.y <= trackHeight + thumbSize;
  }

  @override
  void onTapDown(TapDownEvent event) {
    _isDragging = true;
    _applyVisualFeedback();

    // Guard against invalid local event positions.
    var local = event.localPosition;
    if (local.x.isNaN) {
      local = absoluteToLocal(event.canvasPosition);
    }
    _updateFromDrag(local.x);
  }

  @override
  void onTapUp(TapUpEvent event) {
    _isDragging = false;
    _applyVisualFeedback();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _isDragging = false;
    _applyVisualFeedback();
  }

  @override
  void onHoverEnter() {
    // Only apply hover feedback when not dragging.
    if (!_isDragging) {
      _isHovering = true;
      _applyVisualFeedback();
    }
  }

  @override
  void onHoverExit() {
    if (!_isDragging) {
      _isHovering = false;
      _applyVisualFeedback();
    }
  }

  @override
  void onHoverCancel() {
    if (!_isDragging) {
      _isHovering = false;
      _applyVisualFeedback();
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _isDragging = true;
    _applyVisualFeedback();
    _updateFromDrag(event.localPosition.x);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // Guard against invalid local event positions.
    var local = event.localEndPosition;
    if (local.x.isNaN) {
      local = absoluteToLocal(event.canvasEndPosition);
    }
    _updateFromDrag(local.x);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isDragging = false;
    _applyVisualFeedback();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isDragging = false;
    _applyVisualFeedback();
  }

  void _updateFromDrag(double dragX) {
    if (dragX.isNaN) {
      return;
    }

    final constrainedX = dragX.clamp(0.0, size.x);
    final normalized = constrainedX / size.x;
    final rawValue = min + (normalized * amplitude);
    value = rawValue;
  }

  void _handleValueChanged() {
    _syncThumbPosition();
    _syncLabels();
  }

  void _syncThumbPosition() {
    final visualThumbSize = _isDragging ? thumbSize + 2.0 : thumbSize;
    final ratio = (value - min) / amplitude;
    final clampedRatio = ratio.clamp(0.0, 1.0);
    final x =
        (visualThumbSize / 2) + (clampedRatio * (size.x - visualThumbSize));
    _thumb.position = Vector2(x, trackHeight / 2);
  }

  void _applyVisualFeedback() {
    final active = _isDragging || _isHovering;
    final trackColorToUse = active ? activeTrackColor : trackColor;
    final thumbColorToUse = active ? activeThumbColor : thumbColor;
    final visualGrow = active ? 2.0 : 0.0;

    _track.setColor(trackColorToUse);
    _thumb.setColor(thumbColorToUse);
    _thumb.size = Vector2(thumbSize + visualGrow, thumbSize + visualGrow);
    _syncThumbPosition();
  }

  void _syncLabels() {
    if (minLabel != null) {
      minLabel!.text = min.toStringAsFixed(0);
    }

    if (currentLabel != null) {
      currentLabel!.text = value.toStringAsFixed(0);
    }

    if (maxLabel != null) {
      maxLabel!.text = max.toStringAsFixed(0);
    }
  }

  double _normalizeValue(double candidate) {
    final bounded = candidate.clamp(min, max);

    if (step == null || step! <= 0) {
      return bounded;
    }

    final snappedSteps = ((bounded - min) / step!).round();
    final snapped = min + (snappedSteps * step!);
    return snapped.clamp(min, max);
  }
}
