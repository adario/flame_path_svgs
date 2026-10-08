import 'dart:math';
import 'dart:ui';

import 'package:flame_path_shapes/commons/convex_pieces.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/test_paths.dart';

/// A body with the shape of the first contour of a [Path], fitted within
/// [size] meters, which is drawn by a [PathComponent] and collides as the
/// convex pieces of the polygon of that component.
///
/// The pieces are drawn on top of it when [renderBody] is true.
class PathShape(final Vector2 initialPosition, final Path path, {Vector2? size})
    extends BodyComponent
    with GlowingBody {
  this : super(renderBody: false);

  final Vector2 size = size ?? Vector2(2, 3);

  /// The linear slop of Box2D in meters, as `Tolerances.linearSlop` with the
  /// default length units, which is not used here as it needs the native
  /// library: the points of a polygon closer than 4 times it are welded, and
  /// the ones closer than twice it to an edge are dropped, see
  /// `b2ComputeHull`.
  static const linearSlop = 0.005;

  late final List<List<Vector2>> _pieces;
  late final PathComponent _component;
  late final double _pixels;

  /// The color that the paints of the [_component] were made for.
  Color? _componentColor;

  @override
  double get outlineWidth => 0.04;

  /// The component that draws the first contour of the [path], fitted within
  /// [size] meters, with [pixels] per meter.
  ///
  /// The contour is laid out in pixels rather than in meters, so that the
  /// default sampling of the component follows it closely, and then the
  /// component is scaled down to meters.
  static PathComponent contourComponent(
    Path path,
    Vector2 size,
    double pixels,
  ) {
    final metric = path.computeMetrics().first;
    final contour = metric.extractPath(0, metric.length)..close();
    return PathComponent(
      path: contour.resizeTo((size * pixels).toSize(), keepRatio: true),
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
  Future<void> onLoad() async {
    _pixels = gameRef.metersToPixels;
    _component = contourComponent(path, size, _pixels);
    _syncComponentPaints();
    // The body is created from the pieces by super.onLoad, and again whenever
    // it is mounted after being removed, so they are worked out only once.
    _pieces = piecesOf(_component);
    await super.onLoad();
    add(_component);
  }

  /// Gives the [_component] the look of [GlowingBody] in the color of the
  /// [paint], which may change at any time.
  void _syncComponentPaints() {
    final color = paint.color;
    if (_componentColor == color) {
      return;
    }
    _componentColor = color;
    _component.paintLayers = [
      Paint()..color = color.withValues(alpha: 0.28),
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth * _pixels,
    ];
  }

  @override
  void render(Canvas canvas) {
    _syncComponentPaints();
    super.render(canvas);
  }

  @override
  Body createBody() {
    final shapeDef = ShapeDef(
      userData: this, // To be able to determine object in collision
      material: SurfaceMaterial(restitution: 0.4, friction: 0.5),
      // Like the default BodyComponent.createBody, a body that reacts to
      // contacts asks for their events.
      enableContactEvents: this is ContactCallbacks,
    );

    final bodyDef = BodyDef(
      position: initialPosition,
      rotation: Rot.fromAngle((initialPosition.x + initialPosition.y) / 2 * pi),
      type: BodyType.dynamic,
    );
    final body = world.createBody(bodyDef);
    for (final piece in _pieces) {
      body.createShape(Polygon(piece), shapeDef);
    }
    return body;
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

/// A world with [ShowPieces] and nothing else.
class ShowPiecesWorld() extends Forge2DWorld with ShowPieces;
