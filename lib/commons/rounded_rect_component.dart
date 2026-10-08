import 'package:flame/extensions.dart';
import 'package:flame_path_shapes/commons/position_paint_component.dart';
import 'package:flutter/material.dart';

/// A rectangle whose corners are rounded with half of its height, so that
/// its short sides are semicircles.
class RoundedRectComponent extends PositionPaintComponent {
  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), Radius.circular(height / 2)),
      paint,
    );
  }
}
