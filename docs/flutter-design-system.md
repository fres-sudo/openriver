# Flutter design system

OpenRiver uses [shadcn_ui](https://pub.dev/packages/shadcn_ui/versions/0.2.6) as its sole **visual component library** across the Flutter app. The UI kit package, `packages/openriver_ui`, declares `shadcn_ui: ^0.2.4` and re-exports it; the workspace currently resolves version 0.2.6. App code imports `package:openriver_ui/openriver_ui.dart`, never `shadcn_ui`, Material, or Cupertino directly. Architecture tests in the app and the kit enforce these imports. Flutter's layout, semantics, navigation, and state widgets remain available as framework primitives.

## Foundation

- `OpenRiverApp` owns one `ShadApp` with system-selected light and dark themes from `RiverThemes`. It registers `RiverLocalizations.delegate` and installs a `RiverLayoutScope` above every route.
- Both themes use `ShadGreenColorScheme`. Read theme values through `context.app.theme`: `colors`, `textTheme`, `brightness`, `radius`, and the `spacing`, `sizes`, and `durations` tokens. Never use local color literals or `Theme.of(context)`.
- Use `context.app.theme.textTheme` for headings, body, lead, small, and muted text. The package supplies the Geist font.
- Use the library's default six-pixel corner radius (`context.app.theme.radius`), border, focus ring, and component states. Do not restyle individual screens unless the design system adds a shared variant.
- Pages use a maximum content width of `sizes.contentMaxWidth` (960 logical pixels), `spacing.xl` (24) outer padding on compact widths, and `spacing.xxxl` (48) at wider widths. Spacing tokens are 4, 8, 12, 16, 24, 32, and 48.

## Responsive layout

- Width classes are `RiverWindowClass` values: compact below 600, medium to 839, expanded to 1199, large to 1599, and extra large from 1600 logical pixels.
- `context.app.responsive.isMobile`, `isTablet`, and `isDesktop` describe the **window width**, not the device; a narrow desktop window is mobile. Use `context.app.input.isTouch` for touch-specific behavior.
- Use `context.app.responsive.content` for layout inside a page. A `RiverContentScope` publishes the width class of its own region, such as the shell body beside a sidebar.
- `context.app.responsive.navigation` divides the window width by the text scale, clamped to 1–2. Only the shell's navigation choice uses it.
- Reading a class rebuilds a widget only when that class changes, not on every pixel of a resize. Use `LayoutBuilder` for pixel-level layout.
- Do not keep `context.app` results across builds or async gaps.

## Component choices

| Purpose | Use |
| --- | --- |
| App shell and themes | `ShadApp`, `ShadThemeData` |
| Primary, secondary, outline, destructive actions | `ShadButton` variants |
| Content surfaces | `ShadCard` |
| Short status labels | `ShadBadge` |
| Inline status and error messages | `ShadAlert` variants |
| Temporary feedback | `ShadToaster` and `ShadToast` |
| Progress | `ShadProgress` with a semantics label |
| Future inputs and selection | `ShadInput`, `ShadSelect`, `ShadCheckbox`, and other `shadcn_ui` controls |
| Icons | `LucideIcons` exported by `shadcn_ui` |

Use Flutter `Text`, `Icon`, `SafeArea`, `Column`, `LayoutBuilder`, `Semantics`, and similar primitives to compose these components. Do not add Material or Cupertino controls, themes, snackbars, buttons, cards, chips, input fields, or progress indicators to app screens. When a needed control is absent in this library version, build a small shared widget from Flutter primitives using the Shad theme, and document it here before using it across screens.

## Interaction and accessibility

- Keep controls usable with a two-times text scale on narrow phones and in landscape. Buttons may grow vertically and wrap labels.
- Show loading and failure states in the same content region so screen readers can follow changes. Mark dynamic errors as live regions.
- Use the library's disabled state while an action is busy. Preserve a visible progress label.
- Give icons accompanying text no separate spoken label. Give icon-only actions a semantic label.
- Preserve system light/dark preference. Check both themes when adding a component.

## Planned UI kit work

[ADR 0003](adr/0003-ui-kit-and-app-shell.md) also covers page scaffolding, the responsive app shell, go_router navigation, and app localization. They are not implemented yet.

## Current migration

The library page uses Shad components for its badge, card, actions, alerts, progress, and file-picker error toast. Library startup, import, retry, and privacy behavior remain owned by `LibraryCubit`.

The 0.2.6 package predates Flutter 3.41. The workspace uses a copy in `third_party/shadcn_ui` with a minimal compatibility patch, selected by the root `dependency_overrides`. See that directory's README for the exact changes. Keep the kit's `^0.2.4` declaration and the local patch together until a deliberate package upgrade replaces them. A rollback restores the previous Material shell and screen alongside removal of the dependency, override, and vendored copy; it does not affect stored library data.
