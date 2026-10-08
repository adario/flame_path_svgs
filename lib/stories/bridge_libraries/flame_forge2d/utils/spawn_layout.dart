import 'dart:math';

import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart' as forge2d;

/// Positions around [center] for new bodies, whose bounding circles have the
/// given [radii], such that the bodies don't overlap each other, nor the
/// shapes already in the [world], and lie within [bounds].
///
/// Box2D separates overlapping circles easily, but bodies made of several
/// convex pieces, like the ones of concave shapes, can push each other in
/// opposite directions at once and stay stuck together, so new bodies should
/// not start overlapping.
///
/// Each position is tried at random within a disc around [center], which
/// grows by [step] after each failed attempt. After [maxAttempts] attempts,
/// the last one is used anyway.
List<Vector2> spreadAround(
  Vector2 center,
  List<double> radii, {
  required Rect bounds,
  required forge2d.World world,
  required Random random,
  double startRadius = 1,
  double step = 0.1,
  int maxAttempts = 500,
}) {
  final placed = <(Vector2, double)>[];
  for (final radius in radii) {
    // The bodies stay within the bounds, or at their center if they don't
    // fit.
    final inner = bounds.deflate(radius);
    final minX = inner.width > 0 ? inner.left : bounds.center.dx;
    final maxX = inner.width > 0 ? inner.right : bounds.center.dx;
    final minY = inner.height > 0 ? inner.top : bounds.center.dy;
    final maxY = inner.height > 0 ? inner.bottom : bounds.center.dy;
    var discRadius = startRadius;
    late Vector2 position;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // A point uniformly distributed within the disc.
      final distance = discRadius * sqrt(random.nextDouble());
      final angle = random.nextDouble() * 2 * pi;
      position = Vector2(
        (center.x + distance * cos(angle)).clamp(minX, maxX),
        (center.y + distance * sin(angle)).clamp(minY, maxY),
      );
      final isFree =
          placed.every(
            (other) => other.$1.distanceTo(position) >= other.$2 + radius,
          ) &&
          !_overlapsWorld(world, position, radius);
      if (isFree) {
        break;
      }
      discRadius += step;
    }
    placed.add((position, radius));
  }
  return [for (final (position, _) in placed) position];
}

/// Whether the circle with the given [center] and [radius] overlaps any of
/// the shapes in the [world].
bool _overlapsWorld(forge2d.World world, Vector2 center, double radius) {
  final extent = Vector2.all(radius);
  final candidates = world.overlapAabb(
    forge2d.Aabb(center - extent, center + extent),
  );
  return candidates.any((shape) => _overlapsShape(shape, center, radius));
}

/// Whether the circle with the given [center] and [radius] overlaps the
/// [shape], whose bounding box overlaps the one of the circle.
bool _overlapsShape(forge2d.Shape shape, Vector2 center, double radius) {
  final body = shape.body;
  // The center of the circle in the coordinates of the body.
  final local = body.localPoint(center);
  switch (shape.geometry) {
    case forge2d.Circle(center: final c, radius: final r):
      return local.distanceTo(c) < radius + r;
    case forge2d.Capsule(:final center1, :final center2, radius: final r):
      return _distanceToSegment(local, center1, center2) < radius + r;
    case forge2d.Segment(:final point1, :final point2):
      return _distanceToSegment(local, point1, point2) < radius;
    case forge2d.Polygon(:final points, radius: final r):
      if (points == null || points.length < 3) {
        // Without its points, the bounding box has to do.
        return true;
      }
      if (_containsPoint(points, local)) {
        return true;
      }
      for (var i = 0; i < points.length; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        if (_distanceToSegment(local, a, b) < radius + r) {
          return true;
        }
      }
      return false;
  }
}

/// Whether the convex [polygon] contains the [point], whatever its direction.
bool _containsPoint(List<Vector2> polygon, Vector2 point) {
  var sign = 0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    final cross = (b - a).cross(point - a);
    final side = cross.sign.toInt();
    if (side == 0) {
      continue;
    }
    if (sign == 0) {
      sign = side;
    } else if (side != sign) {
      return false;
    }
  }
  return true;
}

double _distanceToSegment(Vector2 point, Vector2 a, Vector2 b) {
  final ab = b - a;
  final lengthSquared = ab.length2;
  if (lengthSquared == 0) {
    return point.distanceTo(a);
  }
  final t = ((point - a).dot(ab) / lengthSquared).clamp(0.0, 1.0);
  return point.distanceTo(a + ab * t);
}
