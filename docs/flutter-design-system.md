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
| App shell and themes | `ShadApp` with `RiverThemes` |
| App frame and navigation | `RiverShell` with `RiverDestination`s and a `RiverShellAction` |
| Page scaffold | `RiverPage` with a `RiverPageHeader` |
| Labeled actions | `RiverButton` (primary, secondary, outline, ghost, destructive) |
| Loading, empty, and error regions | `RiverStateView` |
| Content surfaces | `ShadCard` |
| Short status labels | `ShadBadge` |
| Other inline status messages | `ShadAlert` variants |
| Temporary feedback | `ShadToaster` and `ShadToast` |
| Progress | `ShadProgress` with a semantics label |
| Future inputs and selection | `ShadInput`, `ShadSelect`, `ShadCheckbox`, and other `shadcn_ui` controls |
| Icons | `LucideIcons` exported by `shadcn_ui` |

Use Flutter `Text`, `Icon`, `SafeArea`, `Column`, `LayoutBuilder`, `Semantics`, and similar primitives to compose these components. Do not add Material or Cupertino controls, themes, snackbars, buttons, cards, chips, input fields, or progress indicators to app screens. When a needed control is absent in this library version, build a small shared widget from Flutter primitives using the Shad theme, and document it here before using it across screens.

### Kit components

- `RiverButton` wraps `ShadButton`. ShadButton 0.2.6 is 40 pixels tall, cannot wrap its label, and ignores Enter and Space. RiverButton gives a hit area of at least 48 pixels that grows with the text scale, wraps long labels, activates from the keyboard, and exposes one semantics node with its label, role, and state. It is disabled while `busy` or without `onPressed`.
- `RiverPage` fills its region with the background color, applies safe areas, and centers content at a maximum width: `standard` (960), `wide` (1280, for lists and tables), or `full`. It uses 24 pixels of outer padding on compact regions and 48 otherwise. Scrollable pages use the primary scroll controller; set `scrollable: false` when the body scrolls itself.
- `RiverPageHeader` marks its title as a semantic header. Actions sit beside the title, or wrap below it on compact pages.
- `RiverStateView.loading`, `.empty`, and `.error` replace content in the same region. Error messages are live regions and must not contain raw errors, paths, or file contents.

### App shell

- `RiverShell` frames the app with `RiverDestination`s, a selected index, and the body. It reports selections and reselections; routing stays in the app.
- The navigation form follows `context.app.responsive.navigation`: a bottom bar when compact, a rail when medium, and a sidebar when expanded or wider. Sidebar windows shorter than 480 pixels use the rail. The user can collapse the sidebar to the rail.
- The body keeps its state when the form changes. It receives safe-area padding only for edges the navigation does not cover, and a content class for its own width.
- `RiverShellAction` is the app-wide primary action. It sits at the top of the sidebar or rail. With a bottom bar, `RiverPageHeader` shows it first among the page actions.
- The bottom bar hides while the on-screen keyboard is visible.
- Destinations are announced as selected within a group, with badge counts spoken. Arrow keys move between them, Enter and Space select, and ⌘ or Ctrl with 1–9 selects from anywhere. After a selection, focus moves to the new page's title.

### Color contrast

`RiverThemes` adjusts the stock green scheme so text meets WCAG AA (4.5:1). In light mode, primary is green-700 on white, destructive is red-700, and muted text is zinc-600. In dark mode, destructive is red-400 with red-950 text, because alerts draw it as text on the background. `river_themes_test.dart` checks every text and surface pair. Widget tests also run Flutter's text-contrast guideline.

## Interaction and accessibility

- Keep controls usable with a two-times text scale on narrow phones and in landscape. Buttons may grow vertically and wrap labels.
- Show loading and failure states in the same content region so screen readers can follow changes. Mark dynamic errors as live regions.
- Use the library's disabled state while an action is busy. Preserve a visible progress label.
- Give icons accompanying text no separate spoken label. Give icon-only actions a semantic label.
- Preserve system light/dark preference. Check both themes when adding a component.

## Planned UI kit work

[ADR 0003](adr/0003-ui-kit-and-app-shell.md) also covers go_router navigation and app localization. They are not implemented yet, and the app does not use `RiverShell` yet. The library page still uses its own layout code; it moves to `RiverPage` when the shell hosts it.

## Current migration

The library page uses Shad components for its badge, card, actions, alerts, progress, and file-picker error toast. Library startup, import, retry, and privacy behavior remain owned by `LibraryCubit`.

The 0.2.6 package predates Flutter 3.41. The workspace uses a copy in `third_party/shadcn_ui` with a minimal compatibility patch, selected by the root `dependency_overrides`. See that directory's README for the exact changes. Keep the kit's `^0.2.4` declaration and the local patch together until a deliberate package upgrade replaces them. A rollback restores the previous Material shell and screen alongside removal of the dependency, override, and vendored copy; it does not affect stored library data.
