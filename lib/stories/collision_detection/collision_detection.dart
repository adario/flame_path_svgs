import 'package:flame_path_shapes/commons/button_knob.dart';
import 'package:flame_path_shapes/commons/commons.dart';
import 'package:flame_path_shapes/commons/example_use_case.dart';
import 'package:flame_path_shapes/commons/test_path_knob.dart';
// import 'package:flame_path_shapes/stories/collision_detection/bouncing_ball_example.dart';
// import 'package:flame_path_shapes/stories/collision_detection/circles_example.dart';
// import 'package:flame_path_shapes/stories/collision_detection/collidable_animation_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/multiple_shapes_example.dart';
// import 'package:flame_path_shapes/stories/collision_detection/multiple_worlds_example.dart';
// import 'package:flame_path_shapes/stories/collision_detection/quadtree_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/raycast_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/raycast_light_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/raycast_max_distance_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/rays_in_shape_example.dart';
import 'package:flame_path_shapes/stories/collision_detection/raytrace_example.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent collisionDetectionStories() {
  return WidgetbookComponent(
    name: 'Collision Detection',
    useCases: [
      // ExampleUseCase(
      //   name: 'Collidable AnimationComponent',
      //   builder: (_) => GameWidget(game: CollidableAnimationExample()),
      //   codeLink: baseLink(
      //     'collision_detection/collidable_animation_example.dart',
      //   ),
      //   info: CollidableAnimationExample.description,
      // ),
      // ExampleUseCase(
      //   name: 'Circles',
      //   builder: (_) => GameWidget(game: CirclesExample()),
      //   codeLink: baseLink('collision_detection/circles_example.dart'),
      //   info: CirclesExample.description,
      // ),
      // ExampleUseCase(
      //   name: 'Bouncing Ball',
      //   builder: (_) => GameWidget(game: BouncingBallExample()),
      //   codeLink: baseLink('collision_detection/bouncing_ball_example.dart'),
      //   info: BouncingBallExample.description,
      // ),
      ExampleUseCase(
        name: 'Multiple shapes',
        builder: (_) =>
            ClipRect(child: GameWidget(game: MultipleShapesExample())),
        codeLink: baseLink('collision_detection/multiple_shapes_example.dart'),
        info: MultipleShapesExample.description,
      ),
      // ExampleUseCase(
      //   name: 'Multiple worlds',
      //   builder: (_) => GameWidget(game: MultipleWorldsExample()),
      //   codeLink: baseLink('collision_detection/multiple_worlds_example.dart'),
      //   info: MultipleWorldsExample.description,
      // ),
      // ExampleUseCase(
      //   name: 'QuadTree collision',
      //   builder: (_) => GameWidget(game: QuadTreeExample()),
      //   codeLink: baseLink('collision_detection/quadtree_example.dart'),
      //   info: QuadTreeExample.description,
      // ),
      ExampleUseCase(
        name: 'Raycasting (light)',
        builder: (_) => GameWidget(game: RaycastLightExample()),
        codeLink: baseLink('collision_detection/raycast_light_example.dart'),
        info: RaycastLightExample.description,
      ),
      ExampleUseCase(
        name: 'Raycasting',
        builder: (_) => GameWidget(game: RaycastExample()),
        codeLink: baseLink('collision_detection/raycast_example.dart'),
        info: RaycastExample.description,
      ),
      ExampleUseCase(
        name: 'Raytracing',
        builder: (_) => GameWidget(game: RaytraceExample()),
        codeLink: baseLink('collision_detection/raytrace_example.dart'),
        info: RaytraceExample.description,
      ),
      ExampleUseCase(
        name: 'Raycasting Max Distance',
        builder: (context) {
          return TestPathStory(
            shape: testPathKnob(context),
            rotate: rotateKnob(context),
            create: (shape) => RaycastMaxDistanceExample(shape: shape),
          );
        },
        codeLink: baseLink(
          'collision_detection/raycast_max_distance_example.dart',
        ),
        info: RaycastMaxDistanceExample.description,
      ),
      ExampleUseCase(
        name: 'Ray inside/outside shapes',
        builder: (context) {
          final shapes = RaysInShapeWorld.shapeNames;
          return RaysInShapeStory(
            rotate: context.knobs.boolean(label: 'Rotate'),
            shape: context.knobs.object.dropdown(
              label: 'Shape',
              initialOption: 0,
              options: List.generate(shapes.length, (index) => index),
              labelBuilder: (index) => shapes[index],
            ),
            rays: context.knobs.int.slider(
              label: 'Quantity',
              initialValue: RaysInShapeWorld.defaultRays,
              min: RaysInShapeWorld.minRays,
              max: RaysInShapeWorld.maxRays,
              divisions:
                  (RaysInShapeWorld.maxRays - RaysInShapeWorld.minRays) ~/
                  RaysInShapeWorld.raysStep,
            ),
            changes: context.knobs.button(label: 'Rays', text: 'Change'),
          );
        },
        codeLink: baseLink('collision_detection/rays_in_shape_example.dart'),
        info: RaysInShapeExample.description,
      ),
    ],
  );
}
