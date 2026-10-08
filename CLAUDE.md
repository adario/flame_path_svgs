# CLAUDE.md

## What this is

`flame_path_svgs`: Flutter/Flame testbed app for a proposed Flame feature — using `Path` objects as shapes (render + hitbox) and importing SVG files as `Path`s. Not published (`publish_to: none`). Visual demo: `README.md` / `screenshots/flame_path_svgs.gif` (modified `RaysInShapeExample`).

It is a trimmed copy of the Flame `examples` app (Widgetbook-based, migrated from Dashbook like upstream commit `2176fb6d`), with the examples that deal with shapes/hitboxes/gestures rewritten to use the new path APIs.

## Environment / tooling

- Dart SDK `^3.13.2` (uses dot-shorthand syntax like `.round`, `.bevel`), Flutter.
- `pubspec.yaml` uses `dependency_overrides` pointing to the **git** fork (`github.com/adario/flame`, ref `feat/path-svgs`, `packages/{flame,flame_forge2d,flame_test,flame_svg}`); switch to local paths (`../flame/packages/...`) to test unpushed fork changes. Flame source: `../flame` (currently on branch `feat/path-svgs`, merged with upstream `main`). Fixing a bug may mean editing `../flame`, not just this repo.
- Other sibling dirs in `../`: `flame_extended_svg`, `flutter_games_compilation`, `repaint`, `instructions.txt` (original task prompt).
- Kept aligned with `../flame_path_shapes` (fork branch `testbed` = `main` + `feat/path-svgs` + `feat/sprite-warp-grid` + `feat/image-contours`), minus what `feat/path-svgs` lacks: `Sprite.contour` (Collidable SpriteComponent, new Sprite Bodies), `WarpEffect`/`HasWarpGrid` (`stories/sprites/`), `convexPieces` in `flame/geometry` (app-local copy in `lib/commons/convex_pieces.dart`, synced from `testbed`), public `PathComponent.polygonsOf`. Compare with `diff -rq -I 'flame_path_s' lib ../flame_path_shapes/lib`. Examples follow upstream syntax (primary constructors, `package:material_ui/material_ui.dart`); don't run `dart format` on files copied verbatim from shapes (their formatting differs).
- Lints: `flutter_lints` via `analysis_options.yaml` (android/ios/web/macos excluded); `flame_lint` is a dev dependency but not included. `flutter analyze`: 16 pre-existing `info` lints (same as shapes), no errors/warnings (copied example code).
- Tests: `test/convex_pieces_test.dart` (local `convexPieces`, `PathShape` placements, whole SVG paths at the example sizes are valid Box2D polygons ≥ 0.1 m, with 2 documented Domino exceptions: alien2, spaceship), `test/spawn_layout_test.dart`, `test/widget_test.dart` (Flutter template counter test, always fails). CI: `.github/workflows/main.yml`.
- Shell note: `lean-ctx` hooks are active; if file/shell access fails, the `_lc` shell function is likely missing (defined in `../instructions.txt`).

## Layout

```
lib/
  main.dart                 Widgetbook entry (runAsWidgetbook); only
                            collisionDetectionStories, experimentalStories,
                            inputStories, forge2DStories, jointsStories enabled
                            (rest commented out — those example dirs were not
                            copied); disabled use cases are kept commented out
                            in each index file
  commons/
    commons.dart            baseLink() -> upstream examples URL
    example_app.dart        ExampleApp (Widgetbook appBuilder: title bar, info
                            dialog, code link) — copied from fork
    example_use_case.dart   ExampleUseCase (WidgetbookUseCase with codeLink/info,
                            game not restarted on unrelated rebuilds) — from fork
    paths.dart              Paints (whiteStroke, pathStroke, InteractiveStatePaints:
                            lightStrokes/greenStrokes/redStrokes), randomPath(),
                            svgComponent(), pathComponent(), pathComponentWith()
    paths_creation_mixin.dart  PathsCreationMixin on FlameGame: nextRandomPath,
                            randomPosition, addFixedPaths, addTestPaths
    position_paint_component.dart  PositionComponent + HasPaint
    rounded_rect_component.dart, slider_button_component.dart, ember.dart  (from Flame examples)
    button_knob.dart        Widgetbook button knob from the fork's examples:
                            knobs.button(label:, enabled:)
    test_path_knob.dart     testPathKnob/rotateKnob, TestPathSelectable
                            (setShape/setRotate/setShowPieces), TestPathStory
    svg_test_paths.dart     SvgTestPaths: load() (memoized,
                            assets/svgs/<TestPaths.names[i]>.svg),
                            byIndex(i, Size) (index 0, the round rect, has no
                            SVG -> TestPaths), pathOf(SvgPaths) = all SVG
                            paths as one Path (filled paths' contours closed)
    convex_pieces.dart      convexPieces (copy of testbed's flame/geometry one)
  platform/                 page_provider / stub_provider / web_provider (conditional web link opening)
  stories/
    bridge_libraries/flame_forge2d/  forge2d examples + joints; utils/path_shape.dart:
                            PathPlacement, PathShapes mixin (body of placed
                            paths drawn by PathComponents with glowing look,
                            colliding as convexPieces), PathShape (contour
                            defaults to 0, null = whole path; initialAngle/
                            material/angularDamping; static placementComponent/
                            piecesOf used by tests), BallOrTestPath (next()
                            -> TestPaths index or null for ball),
                            ShuffledTestPaths, ShowPieces, HasSvgTestPaths
                            (world mixin: loads SVGs in onLoad,
                            pathOf(index, size)); swappable_body.dart
                            (SwappableBody: Shape knob swaps the body; loads
                            SVGs; pathOf). All PathShapes here use contour:
                            null (whole filtered path) of the SVG file of the
                            test path (vs. test paths in flame_path_shapes):
                            Domino, Contact Callbacks, RevoluteJoint with
                            Motor, Tappable/Draggable Body, joints
                            RevoluteJoint/WeldJoint (only those two joints
                            enabled).
    collision_detection/    12 examples (raycast*, rays_in_shape, multiple_shapes, circles, quadtree, ...)
    experimental/           shapes.dart (Polygon.fromPath), layout_component_* examples
    input/                  23 input examples incl. gesture_hitboxes_example.dart
assets/                     images/audio/svgs/tiles/yarn from Flame examples; assets/svgs/*.svg are used by SvgPaths
```

## The proposed Flame feature (lives in `../flame/packages`)

Branch `feat/path-svgs` vs upstream `main` adds only the SVG/test-path pieces; `PathComponent`/`PathHitbox`/path extensions already exist in `main`:

- `flame/lib/src/geometry/path_component.dart` — `PathComponent extends ShapeComponent`: renders a `Path`, moved to origin (`path.toOrigin`), `size` = path bounds. Builds one polygon per closed contour by sampling (`sampling` default 1.0, `tolerance`, `filter` = drop polygons whose vertices all lie in the largest one, e.g. eyes). Exposes `polygons`, `polygonsPath`, global polygons, line segments; polygons decide point containment.
- `flame/lib/src/collisions/hitboxes/path_hitbox.dart` — `PathHitbox extends PathComponent with ShapeHitbox`: single hitbox over all polygons; collision, containsPoint, `rayIntersection` (closest of all polygons); `render` draws `polygonsPath` when `renderShape`.
- `flame/lib/src/extensions/path.dart` — `PathExtension` (`transform32`, `resizeTo(Size, keepRatio:)`, `walkContours`, `walkContourAt`, `toOrigin`), `PathMetricExtension.walkContour(sampling, tolerance)` (adaptive sampler/simplifier), `PathMetricListExtension`.
- `flame_svg/lib/`: `svg_paths.dart` (`SvgPaths(svgString)` / `SvgPaths.fromFile('assets/svgs/x.svg')` -> `length`, `pathAt(i)` returns `VectorPath`, `paintAt(i)` returns `VectorPaint`; merges only non-overlapping consecutive paths with the same paint), `svg_paths_component.dart` (`SvgPathsComponent.load(name, size:, hitboxes: SvgHitboxes.single|perPath)`), `svg_paths_hitbox.dart` (`SvgPathsHitbox`: rays against the union of polygons), `vector_path.dart`, `vector_paint.dart` (`isFilled`, `isStroked`), `vector_graphics_compiler_extensions.dart`.
- `flame_test/lib/src/test_paths.dart` (import `package:flame_test/test_paths.dart`) — `TestPaths`: `count`, `names`, `byIndex(i, Size)`, `byName`, `roundRect`, `flame`, `invader1-3`, `clover`, `abstractShape`, `alien1-2`, `setup`, `recycle`, `spaceship`. Index 0 is the round rect (no SVG).
- Related Flame APIs used here: `Polygon.fromPath(path, contour:)`, `PolygonHitbox.fromPath`, `ShapeHitbox`, `GestureHitboxes`, `HasCollisionDetection`, `DragCallbacks`, `ScreenHitbox`.

## How the app uses it

- `paths.dart:pathComponentWith(path, size, resize:, ...)` -> `PathComponent` (priority `shapePriority`=1, default anchor center) with a `PathHitbox(path:, filter:)` child; optional `renderHitboxes`/`contourPaint`.
- `svgComponent(index, size)` loads the whole `assets/svgs/<TestPaths.names[i]>.svg` with `SvgPathsComponent.load` (single `SvgPathsHitbox`); index 0 falls back to a test-path `PathComponent`.
- Forge2D: `PathShape`/`PathShapes` bodies from `SvgTestPaths.byIndex(index, size)`, see Layout.
- `multiple_shapes_example.dart`: `MyCollidable` base (drag, collisions, wrap-around), subclasses polygon/path/rectangle/circle/snowman; `CollidablePath` uses `PathHitbox(path: randomPath(size), position: size/2, anchor: center)`. Uses `World` + `CameraComponent` (topLeft anchor) with `HasGameRef`.
- `gesture_hitboxes_example.dart`: `MyPathComponent extends PathComponent` with `PathHitbox` child + gestures; compares against `PolygonHitbox.fromPath`.
- `rays_in_shape_example.dart`, `raycast*_example.dart`, `raytrace_example.dart`: ray casting against path shapes via `PathsCreationMixin`.

## Conventions

- Match Flame style: single quotes, trailing commas, `dart format` (80 cols), `final`/`const` where possible.
- Reuse paints from `paths.dart` (create `Paint`s once, not per frame).
- Example classes expose `static const description`; stories are `ExampleUseCase`s in each folder's `WidgetbookComponent xxxStories()` index file (`collision_detection.dart`, `experimental.dart`, `input.dart`, `flame_forge2d.dart`).

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter run -d macos     # or chrome; Widgetbook shows story list
```
