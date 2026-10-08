import 'package:flame/game.dart';
import 'package:flame_test/test_paths.dart';
import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

const _testPathKnob = 'Shape';

/// The value of the [testPathKnob] for a ball instead of a test path.
const ballShape = -1;

/// A knob to pick one of the [TestPaths], which returns its index.
///
/// With [ball], the knob starts with a ball, whose value is [ballShape].
int testPathKnob(BuildContext context, {bool ball = false}) {
  return context.knobs.object.dropdown(
    label: _testPathKnob,
    initialOption: ball ? ballShape : 0,
    options: [
      if (ball) ballShape,
      ...List.generate(TestPaths.count, (index) => index),
    ],
    labelBuilder: testPathLabel,
  );
}

/// The label of the value [shape] of the [testPathKnob].
String testPathLabel(int shape) {
  return shape == ballShape ? 'ball' : TestPaths.names[shape];
}

/// A knob to rotate the shape, which is off by default.
bool rotateKnob(BuildContext context) {
  return context.knobs.boolean(label: 'Rotate');
}

/// A game that shows one of the [TestPaths], which can be changed later.
/// It applies to any [Game], so that games with a specific world, like the
/// Forge2D ones, can use it too.
mixin TestPathSelectable on Game {
  /// Shows the shape with the given index in [TestPaths.names].
  void setShape(int shape);

  /// Rotates the shape or stops it, for the games that support the
  /// [rotateKnob]; the others ignore it.
  void setRotate(bool rotate) {}

  /// Draws the convex pieces of the physics shapes or stops drawing them, for
  /// the games that support a Show pieces knob; the others ignore it.
  void setShowPieces(bool showPieces) {}

  /// Called with the index of the shape once the game has loaded, as it can
  /// be chosen by the game itself.
  void Function(int shape)? onShapeLoaded;
}

/// Hosts a single [TestPathSelectable] game and applies the [testPathKnob] to
/// it, so that changing the knob doesn't restart the game.
///
/// The game is created with the knob value only if the knob has one already,
/// so that it can choose its shape otherwise, which is then written back to
/// the knob once the game has loaded.
class TestPathStory extends StatefulWidget {
  const TestPathStory({
    required this.shape,
    required this.create,
    this.rotate = false,
    this.showPieces = false,
    super.key,
  });

  /// The value of the [testPathKnob].
  final int shape;

  /// The value of the [rotateKnob], if the game supports it.
  final bool rotate;

  /// The value of the Show pieces knob, if the game supports it.
  final bool showPieces;

  /// Creates the game with the given shape, or one of its own choice.
  final TestPathSelectable Function(int? shape) create;

  @override
  State<TestPathStory> createState() => _TestPathStoryState();
}

class _TestPathStoryState extends State<TestPathStory> {
  late final _game = widget.create(_hasKnobValue ? widget.shape : null)
    ..onShapeLoaded = _updateKnob
    ..setRotate(widget.rotate)
    ..setShowPieces(widget.showPieces);

  bool get _hasKnobValue {
    final state = WidgetbookState.of(context);
    final knobs = FieldCodec.decodeQueryGroup(state.queryParams['knobs']);
    return knobs.containsKey(_testPathKnob);
  }

  @override
  void didUpdateWidget(TestPathStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shape != oldWidget.shape) {
      _game.setShape(widget.shape);
    }
    if (widget.rotate != oldWidget.rotate) {
      _game.setRotate(widget.rotate);
    }
    if (widget.showPieces != oldWidget.showPieces) {
      _game.setShowPieces(widget.showPieces);
    }
  }

  void _updateKnob(int shape) {
    if (!mounted) {
      return;
    }
    WidgetbookState.of(context).updateQueryField(
      group: 'knobs',
      field: _testPathKnob,
      value: testPathLabel(shape),
    );
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
