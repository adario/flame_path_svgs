import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart' as forge2d;
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/path_shape.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/spawn_layout.dart';
import 'package:flame_test/test_paths.dart';
import 'package:flutter_test/flutter_test.dart';

/// The test paths that the revolute joint with motor example adds.
const _paths = ['abstract', 'alien1', 'flame', 'invader1', 'invader2'];

/// The pixels per meter of the revolute joint with motor example.
const _pixels = 10.0;

void main() {
  group('spreadAround', () {
    test('keeps the bodies apart from each other and within the bounds', () {
      final world = forge2d.World();
      addTearDown(world.destroy);
      const bounds = Rect.fromLTRB(-20, -20, 20, 20);
      final radii = [for (var i = 0; i < 15; i++) 0.5 + (i % 5) * 0.5];
      final positions = spreadAround(
        Vector2.zero(),
        radii,
        bounds: bounds,
        world: world,
        random: Random(0),
      );
      for (var i = 0; i < positions.length; i++) {
        final p = positions[i];
        final r = radii[i];
        expect(bounds.deflate(r).contains(p.toOffset()), isTrue);
        for (var j = i + 1; j < positions.length; j++) {
          expect(
            p.distanceTo(positions[j]),
            greaterThanOrEqualTo(r + radii[j]),
          );
        }
      }
    });

    test('keeps the bodies apart from the shapes in the world', () {
      final world = forge2d.World();
      addTearDown(world.destroy);
      // A static box right where the bodies are added.
      world.createBody().createShape(forge2d.Polygon.box(3, 3));
      final radii = List.filled(10, 1.0);
      final positions = spreadAround(
        Vector2.zero(),
        radii,
        bounds: const Rect.fromLTRB(-30, -30, 30, 30),
        world: world,
        random: Random(0),
      );
      for (final p in positions) {
        // The box reaches 3 meters from the origin, the bodies 1 meter from
        // their positions.
        expect(max(p.x.abs(), p.y.abs()), greaterThanOrEqualTo(4));
      }
    });
  });

  // Regression test: balls and test path shapes added all at once within a
  // meter of a tap used to end up stuck inside each other, as the convex
  // pieces of a concave shape push the ones of another one in opposite
  // directions at once.
  test('bodies spread around a tap do not stay stuck inside each other', () {
    for (var seed = 0; seed < 10; seed++) {
      final random = Random(seed);
      final world = forge2d.World(gravity: Vector2(0, 10));
      final bodies = [
        for (var i = 0; i < 15; i++)
          i.isEven ? _Spec.ball(random) : _Spec.shape(random),
      ];
      final positions = spreadAround(
        Vector2.zero(),
        [for (final body in bodies) body.boundingRadius],
        bounds: const Rect.fromLTRB(-60, -40, 60, 40),
        world: world,
        random: random,
      );
      final created = [
        for (final (index, spec) in bodies.indexed)
          spec.create(world, positions[index]),
      ];
      for (var step = 0; step < 90; step++) {
        world.step(1 / 60);
      }
      for (var i = 0; i < created.length; i++) {
        for (var j = i + 1; j < created.length; j++) {
          expect(
            _penetration(
              bodies[i].worldPolygons(created[i]),
              bodies[j].worldPolygons(created[j]),
            ),
            lessThan(0.05),
            reason: 'seed $seed, bodies $i and $j',
          );
        }
      }
      world.destroy();
    }
  });
}

/// A ball or a test path shape, like the ones of the revolute joint with
/// motor example.
class _Spec {
  _Spec.ball(Random random)
    : radius = 0.4 + random.nextDouble() * 0.6,
      pieces = null;

  _Spec.shape(Random random) : radius = null, pieces = _randomPieces(random);

  final double? radius;
  final List<List<Vector2>>? pieces;

  double get boundingRadius =>
      radius ??
      pieces!.expand((piece) => piece).map((v) => v.length).reduce(max);

  static List<List<Vector2>> _randomPieces(Random random) {
    final size = Vector2.all(3 + random.nextDouble() * 0.5);
    final index = TestPaths.names.indexOf(
      _paths[random.nextInt(_paths.length)],
    );
    return PathShape.piecesOf(
      PathShape.contourComponent(
        TestPaths.byIndex(index, size.toSize()),
        size,
        _pixels,
      ),
    );
  }

  forge2d.Body create(forge2d.World world, Vector2 position) {
    final body = world.createBody(
      forge2d.BodyDef(type: forge2d.BodyType.dynamic, position: position),
    );
    final shapeDef = forge2d.ShapeDef(
      material: forge2d.SurfaceMaterial(restitution: 0.4, friction: 0.5),
    );
    if (radius != null) {
      body.createShape(forge2d.Circle(radius: radius!), shapeDef);
    } else {
      for (final piece in pieces!) {
        body.createShape(forge2d.Polygon(piece), shapeDef);
      }
    }
    return body;
  }

  /// The convex polygons of the [body] in world coordinates, with a ball as a
  /// 16-sided polygon.
  List<List<Vector2>> worldPolygons(forge2d.Body body) {
    if (radius != null) {
      return [
        [
          for (var k = 0; k < 16; k++)
            Vector2(cos(k * pi / 8), sin(k * pi / 8)) * radius! + body.position,
        ],
      ];
    }
    return [
      for (final piece in pieces!) [for (final v in piece) body.worldPoint(v)],
    ];
  }
}

/// How deep the two sets of convex polygons [a] and [b] are inside each
/// other, as the largest overlap of two of their polygons along their
/// separating axes.
double _penetration(List<List<Vector2>> a, List<List<Vector2>> b) {
  var deepest = 0.0;
  for (final pa in a) {
    for (final pb in b) {
      deepest = max(deepest, _convexPenetration(pa, pb));
    }
  }
  return deepest;
}

double _convexPenetration(List<Vector2> a, List<Vector2> b) {
  var smallest = double.infinity;
  for (final polygon in [a, b]) {
    for (var i = 0; i < polygon.length; i++) {
      final edge = polygon[(i + 1) % polygon.length] - polygon[i];
      final axis = Vector2(-edge.y, edge.x)..normalize();
      double low(List<Vector2> p) => p.map((v) => v.dot(axis)).reduce(min);
      double high(List<Vector2> p) => p.map((v) => v.dot(axis)).reduce(max);
      final overlap = min(high(a), high(b)) - max(low(a), low(b));
      if (overlap <= 0) {
        return 0;
      }
      smallest = min(smallest, overlap);
    }
  }
  return smallest;
}
