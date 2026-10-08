import 'package:flame/extensions.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flame_test/test_paths.dart';

/// The SVG files of the [TestPaths], each one as a single [Path] made of all
/// of the paths in the file, which are loaded once with [load].
///
/// The round rect, at index 0 in [TestPaths.names], has no SVG file, so it
/// comes from [TestPaths].
abstract final class SvgTestPaths {
  static Future<void>? _loading;

  /// The path of each SVG file, by its index in [TestPaths.names].
  static final _paths = <int, Path>{};

  /// Loads the SVG files, unless they are loaded already.
  static Future<void> load() {
    return _loading ??= _load().catchError((Object error, StackTrace stack) {
      // A later call tries again.
      _loading = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  static Future<void> _load() async {
    final indices = List.generate(TestPaths.count - 1, (i) => i + 1);
    final files = await Future.wait([
      for (final index in indices)
        SvgPaths.fromFile('assets/svgs/${TestPaths.names[index]}.svg'),
    ]);
    for (final (i, svg) in files.indexed) {
      _paths[indices[i]] = pathOf(svg);
    }
  }

  /// The SVG file of the test path with the given [index] in
  /// [TestPaths.names], fitted within [size] while keeping its aspect ratio.
  ///
  /// The SVG files have to be loaded with [load] first.
  static Path byIndex(int index, Size size) {
    if (index == 0) {
      return TestPaths.byIndex(index, size);
    }
    final path = _paths[index];
    if (path == null) {
      throw StateError('The SVG files of the test paths are not loaded');
    }
    return path.resizeTo(size, keepRatio: true);
  }

  /// A single [Path] made of all the paths of the [svg], like the hitbox of
  /// an [SvgPathsComponent]: the open contours of the filled paths are
  /// closed, as filling closes them.
  static Path pathOf(SvgPaths svg) {
    final result = Path();
    for (var i = 0; i < svg.length; i++) {
      final vectorPath = svg.pathAt(i)!;
      final path = vectorPath.path;
      result.addPath(
        vectorPath.paint.isFilled ? _closeContours(path) : path,
        Offset.zero,
      );
    }
    return result;
  }

  /// The [path] with all of its contours closed.
  static Path _closeContours(Path path) {
    final closed = Path()..fillType = path.fillType;
    for (final metric in path.computeMetrics()) {
      closed.addPath(
        metric.extractPath(0, metric.length)..close(),
        Offset.zero,
      );
    }
    return closed;
  }
}
