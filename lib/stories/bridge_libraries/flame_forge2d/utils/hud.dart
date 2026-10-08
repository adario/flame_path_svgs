import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart' show TextStyle;

/// A world that shows the frame rate at the top left of the screen, and the
/// number of its bodies at the top right.
mixin BodiesHud on Forge2DWorld, HasGameRef<Forge2DGame> {
  static final _textRenderer = TextPaint(
    style: const TextStyle(color: ExampleColors.text, fontSize: 14),
  );

  var _bodyCount = 0;
  final _bodyCountText = _TopRightText(textRenderer: _textRenderer);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    gameRef.camera.viewport.addAll([
      FpsTextComponent(
        position: Vector2.all(_TopRightText.margin),
        textRenderer: _textRenderer,
      ),
      _bodyCountText,
    ]);
    _updateBodyCount();
  }

  @override
  void onChildrenChanged(Component child, ChildrenChangeType type) {
    super.onChildrenChanged(child, type);
    if (child is BodyComponent) {
      _bodyCount += type == ChildrenChangeType.added ? 1 : -1;
      _updateBodyCount();
    }
  }

  void _updateBodyCount() {
    _bodyCountText.text = 'Bodies: $_bodyCount';
  }
}

/// A text at the top right corner of its parent, which stays there when the
/// parent is resized.
class _TopRightText({super.textRenderer}) extends TextComponent {
  this : super(anchor: Anchor.topRight);

  /// The distance from the edges of the parent.
  static const margin = 8.0;

  @override
  void onParentResize(Vector2 maxSize) {
    super.onParentResize(maxSize);
    position.setValues(maxSize.x - margin, margin);
  }
}
