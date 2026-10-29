# shadcn_ui 0.2.6 compatibility copy

This directory contains the published `shadcn_ui` 0.2.6 package's runtime source, assets, fonts, pubspec, and upstream MIT license. It is selected by the workspace's `dependency_overrides` because the published package does not compile with Flutter 3.41.2.

Only these upstream source changes are intended:

- `lib/src/app.dart`: omit the removed `WidgetsApp` checkerboard arguments.
- `lib/src/components/image.dart`: hide Rive's `Image` name so Flutter's `Image` is unambiguous.

The public component API and version remain 0.2.6. When upgrading, remove the path override and this directory after verifying the replacement package against the Flutter SDK and app tests.
