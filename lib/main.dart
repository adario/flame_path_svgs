import 'package:flame_path_shapes/commons/example_app.dart';
import 'package:flame_path_shapes/stories/bridge_libraries/flame_forge2d/flame_forge2d.dart';
import 'package:flame_path_shapes/stories/collision_detection/collision_detection.dart';
import 'package:flame_path_shapes/stories/experimental/experimental.dart';
import 'package:flame_path_shapes/stories/input/input.dart';
import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runAsWidgetbook();
}

void runAsWidgetbook() {
  runApp(
    Widgetbook(
      appBuilder: (_, child) => ExampleApp(child: child),
      addons: [ViewportAddon(Viewports.all)],
      header: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Image.asset('assets/images/flame.png', height: 28),
            const SizedBox(width: 12),
            const Text(
              'Flame Examples',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      home: const ExampleApp(
        child: Center(
          child: Text('Select an example in the navigation to try it out.'),
        ),
      ),
      enableLeafComponents: false,
      directories: [
        // Some small sample games
        // gameStories(),

        // Show some different ways of structuring games
        // structureStories(),

        // Feature examples
        // audioStories(),
        // animationStories(),
        // cameraAndViewportStories(),
        collisionDetectionStories(),
        // componentsStories(),
        // decoratorStories(),
        // effectsStories(),
        experimentalStories(),
        inputStories(),
        // layoutStories(),
        // parallaxStories(),
        // renderingStories(),
        // routerStories(),
        // tiledStories(),
        // spritesStories(),
        // svgStories(),
        // systemStories(),
        // utilsStories(),
        // widgetsStories(),
        // imageStories(),

        // Bridge package examples
        forge2DStories(),
        // jointsStories(),
        // flameIsolateStories(),
        // flameJennyStories(),
        // flameLottieStories(),
        // flameSpineStories(),
      ],
    ),
  );
}
