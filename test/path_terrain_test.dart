import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/joints/path_wheel_joint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the terrain of the path wheel joint example', () {
    test('is a single open contour across the whole track', () {
      final metrics = Terrain.path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.first.isClosed, isFalse);
      final bounds = Terrain.path.getBounds();
      expect(bounds.left, lessThanOrEqualTo(Terrain.startX));
      expect(bounds.right, greaterThanOrEqualTo(Terrain.endX));
    });

    test('follows the sinusoid within a millimeter', () {
      final metric = Terrain.path.computeMetrics().first;
      for (var distance = 0.0; distance <= metric.length; distance += 0.05) {
        final point = metric.getTangentForOffset(distance)!.position;
        expect(
          point.dy,
          closeTo(Terrain.heightAt(point.dx), 0.001),
          reason: 'at x = ${point.dx}',
        );
      }
    });

    test('has chain points along the path, from left to right', () {
      final points = Terrain.chainPoints;
      expect(points.first.x, lessThanOrEqualTo(Terrain.startX));
      expect(points.last.x, greaterThanOrEqualTo(Terrain.endX));
      for (var i = 1; i < points.length; i++) {
        expect(points[i].x, greaterThan(points[i - 1].x));
      }
      for (final point in points) {
        expect(point.y, closeTo(Terrain.heightAt(point.x), 0.002));
      }
    });

    test('has chain segments within a centimeter of the sinusoid', () {
      final points = Terrain.chainPoints;
      for (var i = 1; i < points.length; i++) {
        final from = points[i - 1];
        final to = points[i];
        for (var t = 0.0; t <= 1; t += 0.1) {
          final point = from + (to - from) * t;
          expect(
            point.y,
            closeTo(Terrain.heightAt(point.x), 0.012),
            reason: 'segment $i at $t',
          );
        }
      }
    });
  });
}
