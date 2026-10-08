import 'dart:math';
import 'dart:ui';

import 'package:flame_path_svgs/commons/convex_pieces.dart';
import 'package:flame_path_svgs/commons/svg_test_paths.dart';
import 'package:flame_path_svgs/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

/// The [contour] of a [path] with that index, or the whole [path] if it is
/// null, fitted within [size] meters and centered on [offset], in the
/// coordinates of a body.
typedef PathPlacement = ({
  Path path,
  int? contour,
  Vector2 size,
  Vector2 offset,
});

/// A body made of some [Path]s, or of one contour of each, each one drawn by a
/// [PathComponent] with the look of [GlowingBody] in the color of the [paint],
/// and colliding as the convex pieces of the polygons of that component.
///
/// The body has to add the pieces as its shapes with [createPathShapes]. They
/// are drawn on top of the paths when [renderBody] is true, so it is usually
/// false.
mixin PathShapes on BodyComponent {
  /// The paths that the body is made of, which must not change.
  List<PathPlacement> get pathPlacements;

  /// The width of the outline of the paths, in meters.
  double get pathOutlineWidth => 0.04;

  /// The convex pieces of all the [pathPlacements], in the coordinates of the
  /// body.
  late final List<List<Vector2>> _pathPieces;
  final _pathComponents = <PathComponent>[];
  late final double _pixels;

  /// The color that the paints of the [_pathComponents] were made for.
  Color? _pathColor;

  @override
  Future<void> onLoad() async {
    _pixels = gameRef.metersToPixels;
    // The pieces of a path are worked out once, even when it is placed more
    // than once with the same contour and size, and shifted to each placement.
    final known = <(PathPlacement, List<List<Vector2>>)>[];
    final pieces = <List<Vector2>>[];
    for (final placement in pathPlacements) {
      final component = PathShape.placementComponent(
        placement.path,
        placement.size,
        _pixels,
        contour: placement.contour,
      );
      var placementPieces = known
          .where(
            (entry) =>
                identical(entry.$1.path, placement.path) &&
                entry.$1.contour == placement.contour &&
                entry.$1.size == placement.size,
          )
          .firstOrNull
          ?.$2;
      if (placementPieces == null) {
        // The component is still centered on the origin.
        placementPieces = PathShape.piecesOf(component);
        known.add((placement, placementPieces));
      }
      pieces.addAll([
        for (final piece in placementPieces)
          [for (final vertex in piece) vertex + placement.offset],
      ]);
      _pathComponents.add(component..position = placement.offset);
    }
    _pathPieces = pieces;
    _syncPathPaints();
    // The body is created from the pieces by super.onLoad, and again whenever
    // it is mounted after being removed, so they are worked out only once.
    await super.onLoad();
    addAll(_pathComponents);
  }

  /// Adds the convex pieces of the [pathPlacements] to the [body], as shapes
  /// made with the [shapeDef].
  void createPathShapes(Body body, ShapeDef shapeDef) {
    for (final piece in _pathPieces) {
      body.createShape(Polygon(piece), shapeDef);
    }
  }

  /// Gives the [_pathComponents] the look of [GlowingBody] in the color of the
  /// [paint], which may change at any time.
  void _syncPathPaints() {
    final color = paint.color;
    if (_pathColor == color) {
      return;
    }
    _pathColor = color;
    final paintLayers = [
      Paint()..color = color.withValues(alpha: 0.28),
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pathOutlineWidth * _pixels,
    ];
    for (final component in _pathComponents) {
      component.paintLayers = paintLayers;
    }
  }

  @override
  void render(Canvas canvas) {
    _syncPathPaints();
    super.render(canvas);
  }
}

/// A body with the shape of the [contour] of a [Path] with that index, the
/// first one by default, or of the whole [path] if it is null, fitted within
/// [size] meters, which is drawn by a [PathComponent] and collides as the
/// convex pieces of the polygons of that component.
///
/// The body starts at the [initialAngle], or at one worked out from the
/// [initialPosition] if there is none, and its shapes have the [material],
/// with a restitution of 0.4 and a friction of 0.5 if there is none.
///
/// The pieces are drawn on top of it when [renderBody] is true.
class PathShape(
  final Vector2 initialPosition,
  final Path path, {
  final int? contour = 0,
  Vector2? size,
  final double? initialAngle,
  final SurfaceMaterial? material,
  final double angularDamping = 0,
}) extends BodyComponent with GlowingBody, PathShapes {
  this : super(renderBody: false);

  final Vector2 size = size ?? Vector2(2, 3);

  /// The linear slop of Box2D in meters, as `Tolerances.linearSlop` with the
  /// default length units, which is not used here as it needs the native
  /// library: the points of a polygon closer than 4 times it are welded, and
  /// the ones closer than twice it to an edge are dropped, see
  /// `b2ComputeHull`.
  static const linearSlop = 0.005;

  @override
  late final List<PathPlacement> pathPlacements = [
    (path: path, contour: contour, size: size, offset: Vector2.zero()),
  ];

  @override
  double get outlineWidth => 0.04;

  @override
  double get pathOutlineWidth => outlineWidth;

  /// The component that draws the [contour] of the [path] with that index, or
  /// the whole [path] if it is null, fitted within [size] meters, with
  /// [pixels] per meter.
  ///
  /// A single contour is fitted on its own, and closed. The path is laid out
  /// in pixels rather than in meters, so that the default sampling of the
  /// component follows it closely, and then the component is scaled down to
  /// meters.
  static PathComponent placementComponent(
    Path path,
    Vector2 size,
    double pixels, {
    int? contour = 0,
  }) {
    var shape = path;
    if (contour != null) {
      final metrics = path.computeMetrics().toList();
      RangeError.checkValidIndex(contour, metrics, 'contour');
      final metric = metrics[contour];
      shape = metric.extractPath(0, metric.length)..close();
    }
    return PathComponent(
      path: shape.resizeTo((size * pixels).toSize(), keepRatio: true),
      anchor: Anchor.center,
      scale: Vector2.all(1 / pixels),
    );
  }

  /// The convex pieces of the polygons of the [component], in the coordinates
  /// of its parent, which Box2D accepts as polygons.
  static List<List<Vector2>> piecesOf(PathComponent component) {
    return [
      for (final polygon in component.polygons)
        ...convexPieces(
          [for (final vertex in polygon) component.positionOf(vertex)],
          maxVertices: Polygon.maxVertices,
          minDistance: 4 * linearSlop,
          minWidth: 2 * linearSlop,
        ),
    ];
  }

  @override
  Body createBody() {
    final shapeDef = ShapeDef(
      userData: this, // To be able to determine object in collision
      material: material ?? SurfaceMaterial(restitution: 0.4, friction: 0.5),
      // Like the default BodyComponent.createBody, a body that reacts to
      // contacts asks for their events.
      enableContactEvents: this is ContactCallbacks,
    );

    final bodyDef = BodyDef(
      position: initialPosition,
      rotation: Rot.fromAngle(
        initialAngle ?? (initialPosition.x + initialPosition.y) / 2 * pi,
      ),
      angularDamping: angularDamping,
      type: BodyType.dynamic,
    );
    final body = world.createBody(bodyDef);
    createPathShapes(body, shapeDef);
    return body;
  }
}

/// Cycles through a ball and some test paths, for the examples that add one
/// of them on each tap.
class BallOrTestPath() {
  /// The names in [TestPaths.names] of the test paths that follow the ball.
  static const names = [
    'flame',
    'alien1',
    'clover',
    'abstract',
    'invader3',
    'invader1',
    'invader2',
    'alien2',
    'recycle',
    'setup',
  ];

  /// The number of choices so far.
  var _count = 0;

  /// The index in [TestPaths.names] of the next test path, or null for a
  /// ball.
  int? next() {
    final index = _count++ % (names.length + 1);
    return index == 0 ? null : TestPaths.names.indexOf(names[index - 1]);
  }
}

/// Hands out the indices in [TestPaths.names] in rounds, in which each test
/// path comes once, in random order, and never the same one twice in a row.
class ShuffledTestPaths() {
  final _random = Random();

  /// The indices still to come in this round, taken from the end.
  final _indices = <int>[];

  /// The index handed out last.
  int? _last;

  /// The index of the next test path.
  int next() {
    if (_indices.isEmpty) {
      _indices.addAll(
        List.generate(TestPaths.count, (i) => i)..shuffle(_random),
      );
      // The first one of a round must not repeat the last one of the previous
      // round.
      if (_indices.last == _last) {
        _indices
          ..[_indices.length - 1] = _indices.first
          ..[0] = _last!;
      }
    }
    return _last = _indices.removeLast();
  }
}

/// A world whose [PathShape]s can show their convex pieces.
mixin ShowPieces on Forge2DWorld {
  bool _showPieces = false;

  /// Whether the convex pieces of the [PathShape]s are drawn, which applies to
  /// the shapes already added too; the new ones should follow it.
  bool get showPieces => _showPieces;
  set showPieces(bool value) {
    _showPieces = value;
    for (final shape in children.whereType<PathShape>()) {
      shape.renderBody = value;
    }
  }
}

/// A world whose [PathShape]s come from the SVG files of the test paths,
/// which it loads with [SvgTestPaths.load].
mixin HasSvgTestPaths on Forge2DWorld {
  @override
  Future<void> onLoad() async {
    await SvgTestPaths.load();
    await super.onLoad();
  }

  /// The SVG file of the test path with the given [index] in
  /// [TestPaths.names], fitted within [size], see [SvgTestPaths.byIndex].
  Path pathOf(int index, Size size) => SvgTestPaths.byIndex(index, size);
}

/// A world with [ShowPieces] and nothing else.
class ShowPiecesWorld() extends Forge2DWorld with ShowPieces;
