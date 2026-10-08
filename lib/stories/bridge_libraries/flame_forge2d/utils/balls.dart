import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/boundaries.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/utils/style.dart';
import 'package:flame/palette.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart';

class Ball(
  final Vector2 _position, {
  final double radius = 2,
  final BodyType bodyType = BodyType.dynamic,
  Color? color,
}) extends BodyComponent with ContactCallbacks, ContactPlayer, GlowingBody {
  this {
    originalPaint = Paint()..color = color ?? randomColor();
    paint = originalPaint;
  }

  static int _colorIndex = 0;

  /// Cycles through the palette so that neighboring balls stay readable.
  Color randomColor() =>
      ExampleColors.dynamicColor(_colorIndex++ % ExampleColors.dynamics.length);

  Paint randomPaint() => Paint()..color = randomColor();

  @override
  Body createBody() {
    final shapeDef = ShapeDef(
      material: SurfaceMaterial(restitution: 0.7),
      enableContactEvents: true,
    );

    final bodyDef = BodyDef(
      userData: this,
      angularDamping: 0.8,
      position: _position,
      type: bodyType,
    );

    return world.createBody(bodyDef)
      ..createShape(Circle(radius: radius), shapeDef);
  }
}

class WhiteBall(super.position) extends Ball {
  this {
    originalPaint = BasicPalette.white.paint();
    paint = originalPaint;
  }

  @override
  void touch(Object other) {
    if (other is ContactPlayer) {
      other.giveNudge = true;
    }
  }
}

/// A body that takes part in the game of the contact callbacks example: the
/// [WhiteBall]s nudge it, and it passes its color on to the walls and to the
/// other players that it touches.
mixin ContactPlayer on BodyComponent, ContactCallbacks {
  late Paint originalPaint;
  bool giveNudge = false;
  double _timeSinceNudge = 0.0;
  static const double _minNudgeRest = 2.0;

  final _impulseForce = Vector2(0, 1000);

  /// How many contacts there are with each body that touches this one.
  ///
  /// Box2D reports a contact for each pair of shapes that touch, so a body
  /// made of several shapes can begin several contacts at once, which should
  /// count as a single touch.
  final _contacts = <Object, int>{};

  @override
  @mustCallSuper
  void update(double dt) {
    super.update(dt);
    _timeSinceNudge += dt;
    if (giveNudge) {
      giveNudge = false;
      if (_timeSinceNudge > _minNudgeRest) {
        body.applyLinearImpulse(_impulseForce);
        _timeSinceNudge = 0.0;
      }
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    final count = _contacts[other] ?? 0;
    _contacts[other] = count + 1;
    if (count == 0) {
      touch(other);
    }
  }

  @override
  void endContact(Object other, Contact contact) {
    final count = (_contacts[other] ?? 0) - 1;
    if (count > 0) {
      _contacts[other] = count;
    } else {
      _contacts.remove(other);
    }
  }

  /// Reacts to the [other] body, once it starts touching this one.
  void touch(Object other) {
    if (other is Wall) {
      other.paint = paint;
    }

    if (other is WhiteBall) {
      return;
    }

    if (other is ContactPlayer) {
      if (paint != originalPaint) {
        paint = other.paint;
      } else {
        other.paint = paint;
      }
    }
  }
}
