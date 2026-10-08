import 'dart:math';
import 'dart:ui';

import 'package:flame_path_shapes/commons/paths.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_test/test_paths.dart';

mixin PathsCreationMixin on FlameGame {
  final random = Random();

  /// How many random positions are tried for each test path before giving up
  /// on it.
  static const _maxAttempts = 50;

  /// The areas taken by what was added so far, which the test paths avoid.
  ///
  /// The components are not mounted yet while the game loads, so the
  /// collision detection cannot tell where they are.
  final _occupied = <_Area>[];

  /// A random position for the center of something with the given
  /// [dimension], such that it is fully within the game.
  Vector2 randomPosition(Size dimension) {
    final half = dimension.toVector2() / 2;
    return Vector2(
          random.nextDouble() * (size.x - dimension.width),
          random.nextDouble() * (size.y - dimension.height),
        ) +
        half;
  }

  /// Marks the circle with the given [center] and [radius] as taken, so that
  /// the test paths added later avoid it.
  void addOccupiedCircle(Vector2 center, double radius) {
    _occupied.add(_Area.circle(center, radius));
  }

  void _addFixed(ShapeComponent component) {
    add(component);
    _occupied.add(
      component is CircleComponent
          ? _Area.circle(
              component.positionOfAnchor(Anchor.center).clone(),
              component.radius,
            )
          : _Area.rectangle(
              component.positionOfAnchor(Anchor.topLeft).clone(),
              component.size,
            ),
    );
  }

  void addFixedPaths(Paint paint) {
    _addFixed(
      CircleComponent(
        position: Vector2(100, 100),
        radius: 50,
        paint: paint,
        children: [CircleHitbox()],
      ),
    );
    _addFixed(
      CircleComponent(
        position: Vector2(150, 500),
        radius: 50,
        paint: paint,
        children: [CircleHitbox()],
      ),
    );
    _addFixed(
      RectangleComponent(
        position: Vector2.all(300),
        size: Vector2.all(100),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );
    _addFixed(
      RectangleComponent(
        position: Vector2.all(500),
        size: Vector2(100, 200),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );
    _addFixed(
      RectangleComponent(
        position: Vector2(550, 200),
        size: Vector2(200, 150),
        paint: paint,
        children: [RectangleHitbox()],
      ),
    );
  }

  /// Adds [numPaths] different random test paths at random positions, at
  /// least [margin] away from each other and from what was added before.
  ///
  /// There are at most [TestPaths.count] test paths. A test path that does not
  /// fit anywhere after [_maxAttempts] positions is left out, so fewer than
  /// [numPaths] paths may be added.
  Future<void> addTestPaths(
    Paint paint, {
    int numPaths = 5,
    bool renderHitboxes = false,
    double margin = 10,
  }) async {
    const pathSize = Size.square(100);
    final paths = List.generate(TestPaths.count, (index) => index)
      ..shuffle(random);
    for (final path in paths.take(numPaths)) {
      final component = await svgComponent(
        path,
        pathSize,
        paint: paint,
        renderHitboxes: renderHitboxes,
      );
      // The component is still at the origin, so its area only has to be
      // moved to each position that is tried.
      final outline = _Area(_hitboxPolygons(component));
      for (var attempt = 0; attempt < _maxAttempts; ++attempt) {
        final position = randomPosition(pathSize);
        final area = outline.translated(position);
        if (_occupied.every((other) => !area.isCloserThan(other, margin))) {
          add(component..position.setFrom(position));
          _occupied.add(area);
          break;
        }
      }
    }
  }
}

/// The polygons of all the [PathHitbox]es within the [component], in the
/// coordinate system of its parent.
List<List<Vector2>> _hitboxPolygons(PositionComponent component) {
  final polygons = <List<Vector2>>[];
  void collect(Component parent, Vector2 Function(Vector2) toOuter) {
    for (final child in parent.children) {
      final childToOuter = child is PositionComponent
          ? (Vector2 point) => toOuter(child.positionOf(point))
          : toOuter;
      if (child is PathHitbox) {
        polygons.addAll(
          child.polygons.map((polygon) => polygon.map(childToOuter).toList()),
        );
      }
      collect(child, childToOuter);
    }
  }

  collect(component, component.positionOf);
  return polygons;
}

/// An area made of polygons, used to keep the test paths apart.
class _Area {
  _Area(this.polygons)
    : bounds = [
        for (final polygon in polygons) RectExtension.getBounds(polygon),
      ];

  factory _Area.circle(Vector2 center, double radius) {
    const sides = 64;
    return _Area([
      [
        for (var i = 0; i < sides; ++i)
          Vector2(cos(i * 2 * pi / sides), sin(i * 2 * pi / sides))
            ..scale(radius)
            ..add(center),
      ],
    ]);
  }

  factory _Area.rectangle(Vector2 topLeft, Vector2 size) {
    return _Area([
      [
        topLeft,
        topLeft + Vector2(size.x, 0),
        topLeft + size,
        topLeft + Vector2(0, size.y),
      ],
    ]);
  }

  final List<List<Vector2>> polygons;

  /// The bounds of each of the [polygons].
  final List<Rect> bounds;

  _Area translated(Vector2 offset) => _Area([
    for (final polygon in polygons)
      [for (final vertex in polygon) vertex + offset],
  ]);

  /// Whether any polygon of this area is closer than [margin] to any polygon
  /// of the [other] area, including when they overlap.
  bool isCloserThan(_Area other, double margin) {
    for (var i = 0; i < polygons.length; ++i) {
      final inflated = bounds[i].inflate(margin);
      for (var j = 0; j < other.polygons.length; ++j) {
        if (inflated.overlaps(other.bounds[j]) &&
            _polygonsCloserThan(polygons[i], other.polygons[j], margin)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _polygonsCloserThan(
    List<Vector2> a,
    List<Vector2> b,
    double margin,
  ) {
    // When no edges are close, the polygons are either apart or one of them
    // is inside of the other.
    if (_contains(b, a.first) || _contains(a, b.first)) {
      return true;
    }
    final margin2 = margin * margin;
    for (var i = 0; i < a.length; ++i) {
      final a1 = a[i];
      final a2 = a[(i + 1) % a.length];
      for (var j = 0; j < b.length; ++j) {
        final b1 = b[j];
        final b2 = b[(j + 1) % b.length];
        if (min(a1.x, a2.x) - margin > max(b1.x, b2.x) ||
            min(b1.x, b2.x) - margin > max(a1.x, a2.x) ||
            min(a1.y, a2.y) - margin > max(b1.y, b2.y) ||
            min(b1.y, b2.y) - margin > max(a1.y, a2.y)) {
          continue;
        }
        if (_segmentsCross(a1, a2, b1, b2) ||
            _distance2(a1, b1, b2) < margin2 ||
            _distance2(a2, b1, b2) < margin2 ||
            _distance2(b1, a1, a2) < margin2 ||
            _distance2(b2, a1, a2) < margin2) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the [point] is inside of the [polygon], by counting how many of
  /// its edges a horizontal ray from the [point] crosses.
  static bool _contains(List<Vector2> polygon, Vector2 point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.y > point.y) != (b.y > point.y) &&
          point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _segmentsCross(Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2) {
    final b = b2 - b1;
    final a = a2 - a1;
    return (b.cross(a1 - b1) > 0) != (b.cross(a2 - b1) > 0) &&
        (a.cross(b1 - a1) > 0) != (a.cross(b2 - a1) > 0);
  }

  /// The squared distance of the [point] from the segment from [a] to [b].
  static double _distance2(Vector2 point, Vector2 a, Vector2 b) {
    final abx = b.x - a.x;
    final aby = b.y - a.y;
    final length2 = abx * abx + aby * aby;
    final t = length2 == 0
        ? 0.0
        : (((point.x - a.x) * abx + (point.y - a.y) * aby) / length2).clamp(
            0.0,
            1.0,
          );
    final dx = a.x + abx * t - point.x;
    final dy = a.y + aby * t - point.y;
    return dx * dx + dy * dy;
  }
}
