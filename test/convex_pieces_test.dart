import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_path_shapes/commons/convex_pieces.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_test/test_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convexPieces', () {
    test('keeps a convex polygon whole', () {
      final square = [
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(1, 1),
        Vector2(0, 1),
      ];
      final pieces = convexPieces(square);
      expect(pieces, hasLength(1));
      expect(pieces.first, hasLength(4));
    });

    test('splits a concave polygon into convex pieces of the same area', () {
      final l = [
        Vector2(0, 0),
        Vector2(2, 0),
        Vector2(2, 1),
        Vector2(1, 1),
        Vector2(1, 2),
        Vector2(0, 2),
      ];
      final pieces = convexPieces(l);
      expect(pieces.length, greaterThan(1));
      expect(pieces.every(_isConvex), isTrue);
      expect(_totalArea(pieces), closeTo(3, 1e-9));
    });

    test('keeps the direction of the polygon', () {
      final clockwise = [
        Vector2(0, 0),
        Vector2(0, 2),
        Vector2(1, 2),
        Vector2(1, 1),
        Vector2(2, 1),
        Vector2(2, 0),
      ];
      final pieces = convexPieces(clockwise);
      expect(pieces.every((piece) => _signedArea(piece) < 0), isTrue);
    });

    test('limits the number of vertices of the pieces', () {
      final circle = [
        for (var i = 0; i < 64; i++)
          Vector2(math.cos(i * math.pi / 32), math.sin(i * math.pi / 32)),
      ];
      final pieces = convexPieces(circle, maxVertices: 5);
      expect(pieces.every((piece) => piece.length <= 5), isTrue);
      expect(_totalArea(pieces), closeTo(_signedArea(circle), 1e-9));
    });

    test('welds the vertices closer than minDistance', () {
      // A triangle with a corner split in two vertices 0.01 apart, which
      // Box2D would weld into a degenerate piece.
      final polygon = [
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(1, 0.01),
        Vector2(0.5, 1),
      ];
      final pieces = convexPieces(polygon, minDistance: 0.02);
      expect(pieces, hasLength(1));
      expect(pieces.first, hasLength(3));
    });

    test('leaves out the pieces narrower than minWidth', () {
      final sliver = [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.005)];
      expect(convexPieces(sliver, minWidth: 0.01), isEmpty);
      expect(convexPieces(sliver), hasLength(1));
    });
  });

  // Regression test: some pieces of the 'abstract' test path, at 2 x 3 meters
  // and 24 pixels per meter, used to be rejected by Box2D.
  group('PathShape pieces are valid Box2D polygons', () {
    for (final pixels in [10.0, 24.0]) {
      for (final size in [
        Vector2(1, 1.5),
        Vector2(2, 3),
        Vector2(3, 4.5),
        Vector2(4, 6),
        // The size of the shapes in the contact and tap callbacks examples.
        Vector2.all(4),
        // The size of the shapes in the drag callbacks example.
        Vector2.all(10),
      ]) {
        for (var i = 0; i < TestPaths.count; i++) {
          final name = TestPaths.names[i];
          test('$name at ${size.x} x ${size.y} m, $pixels px/m', () {
            final component = PathShape.contourComponent(
              TestPaths.byIndex(i, size.toSize()),
              size,
              pixels,
            );
            final pieces = PathShape.piecesOf(component);
            expect(pieces, isNotEmpty);
            final hulls = [
              for (final piece in pieces)
                _box2dHull(piece, PathShape.linearSlop),
            ];
            for (final (index, hull) in hulls.indexed) {
              expect(
                hull.length,
                greaterThanOrEqualTo(3),
                reason: 'piece $index: ${pieces[index]}',
              );
            }
            // The pieces still cover the shape, as Box2D sees them, except for
            // the details thinner than its tolerances, which matter most for
            // the smallest shapes.
            final polygon = [
              for (final vertex in component.polygons.first)
                component.positionOf(vertex),
            ];
            final area = _signedArea(polygon).abs();
            expect(_totalArea(hulls), closeTo(area, area * 0.02));
          });
        }
      }
    }
  });

  // flame_forge2d warns about the shapes of moving bodies that are less than
  // 0.1 meters across (5 speculative distances), and each piece is a shape.
  group('PathShape pieces of the examples are large enough for Forge2D', () {
    const minSide = 5 * 4 * PathShape.linearSlop;
    final allPaths = TestPaths.names;
    // The size of the pieces doesn't grow steadily with the size of the
    // shape, so the whole range of random sizes is checked in small steps.
    final revoluteSizes = [
      for (var i = 0; i <= 10; i++) Vector2.all(3 + i * 0.05),
    ];
    const revolutePaths = [
      'abstract',
      'alien1',
      'flame',
      'invader1',
      'invader2',
    ];
    for (final (example, size, pixels, paths) in [
      ('domino', Vector2(2, 3), 24.0, allPaths),
      ('contact callbacks', Vector2.all(4), 10.0, allPaths),
      ('tap callbacks', Vector2.all(4), 20.0, allPaths),
      ('drag callbacks', Vector2.all(10), 10.0, allPaths),
      for (final size in revoluteSizes)
        ('revolute joint with motor', size, 10.0, revolutePaths),
    ]) {
      for (final name in paths) {
        final i = TestPaths.names.indexOf(name);
        test('$name in the $example example, at ${size.x} m', () {
          final component = PathShape.contourComponent(
            TestPaths.byIndex(i, size.toSize()),
            size,
            pixels,
          );
          for (final piece in PathShape.piecesOf(component)) {
            expect(_largestSide(piece), greaterThanOrEqualTo(minSide));
          }
        });
      }
    }
  });
}

/// The largest side of the bounding box of the [polygon], which is how
/// flame_forge2d measures shapes.
double _largestSide(List<Vector2> polygon) {
  final xs = polygon.map((vertex) => vertex.x);
  final ys = polygon.map((vertex) => vertex.y);
  return math.max(
    xs.reduce(math.max) - xs.reduce(math.min),
    ys.reduce(math.max) - ys.reduce(math.min),
  );
}

double _signedArea(List<Vector2> polygon) {
  var area = 0.0;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area / 2;
}

double _totalArea(List<List<Vector2>> pieces) {
  return pieces.fold(0, (sum, piece) => sum + _signedArea(piece).abs());
}

bool _isConvex(List<Vector2> piece) {
  final sign = _signedArea(piece).sign;
  for (var i = 0; i < piece.length; i++) {
    final a = piece[i];
    final b = piece[(i + 1) % piece.length];
    final c = piece[(i + 2) % piece.length];
    if ((b - a).cross(c - b) * sign < -1e-12) {
      return false;
    }
  }
  return true;
}

/// A port of `b2ComputeHull` from Box2D v3 (`src/hull.c`), which Forge2D runs
/// on the points of a polygon, and throws if it returns fewer than three.
List<Vector2> _box2dHull(List<Vector2> points, double linearSlop) {
  if (points.length < 3 || points.length > 8) {
    return const [];
  }
  // Points closer than 4 times the linear slop are welded.
  final ps = <Vector2>[];
  for (final p in points) {
    if (ps.every(
      (q) => p.distanceToSquared(q) >= 16 * linearSlop * linearSlop,
    )) {
      ps.add(p);
    }
  }
  if (ps.length < 3) {
    return const [];
  }
  final min = Vector2(
    points.map((p) => p.x).reduce(math.min),
    points.map((p) => p.y).reduce(math.min),
  );
  final max = Vector2(
    points.map((p) => p.x).reduce(math.max),
    points.map((p) => p.y).reduce(math.max),
  );
  final center = (min + max) / 2;
  var f1 = 0;
  for (var i = 1; i < ps.length; i++) {
    if (center.distanceToSquared(ps[i]) > center.distanceToSquared(ps[f1])) {
      f1 = i;
    }
  }
  final p1 = ps[f1];
  ps[f1] = ps.last;
  ps.removeLast();
  var f2 = 0;
  for (var i = 1; i < ps.length; i++) {
    if (p1.distanceToSquared(ps[i]) > p1.distanceToSquared(ps[f2])) {
      f2 = i;
    }
  }
  final p2 = ps[f2];
  ps[f2] = ps.last;
  ps.removeLast();
  final e = (p2 - p1)..normalize();
  final right = <Vector2>[];
  final left = <Vector2>[];
  for (final p in ps) {
    final d = (p - p1).cross(e);
    if (d >= 2 * linearSlop) {
      right.add(p);
    } else if (d <= -2 * linearSlop) {
      left.add(p);
    }
  }
  final hull1 = _recurseHull(p1, p2, right, linearSlop);
  final hull2 = _recurseHull(p2, p1, left, linearSlop);
  if (hull1.isEmpty && hull2.isEmpty) {
    return const [];
  }
  final hull = [p1, ...hull1, p2, ...hull2];
  // Points closer than twice the linear slop to their neighbors' edge are
  // removed.
  var searching = true;
  while (searching && hull.length > 2) {
    searching = false;
    for (var i = 0; i < hull.length; i++) {
      final s1 = hull[i];
      final s2 = hull[(i + 1) % hull.length];
      final s3 = hull[(i + 2) % hull.length];
      final r = (s3 - s1)..normalize();
      if ((s2 - s1).cross(r) <= 2 * linearSlop) {
        hull.removeAt((i + 1) % hull.length);
        searching = true;
        break;
      }
    }
  }
  return hull.length < 3 ? const [] : hull;
}

List<Vector2> _recurseHull(
  Vector2 p1,
  Vector2 p2,
  List<Vector2> ps,
  double linearSlop,
) {
  if (ps.isEmpty) {
    return const [];
  }
  final e = (p2 - p1)..normalize();
  final right = <Vector2>[];
  var best = ps.first;
  var bestDistance = (best - p1).cross(e);
  for (final p in ps) {
    final distance = (p - p1).cross(e);
    if (distance > bestDistance) {
      best = p;
      bestDistance = distance;
    }
    if (distance > 0) {
      right.add(p);
    }
  }
  if (bestDistance < 2 * linearSlop) {
    return const [];
  }
  return [
    ..._recurseHull(p1, best, right, linearSlop),
    best,
    ..._recurseHull(best, p2, right, linearSlop),
  ];
}
