# Flutter design system

OpenRiver uses [shadcn_ui](https://pub.dev/packages/shadcn_ui/versions/0.2.6) as its sole **visual component library** across the Flutter app. The app declares `shadcn_ui: ^0.2.4`; the workspace currently resolves version 0.2.6. Flutter's layout, semantics, navigation, and state widgets remain available as framework primitives.

## Foundation

- `OpenRiverApp` owns one `ShadApp` with system-selected light and dark themes.
- `OpenRiverDesignSystem` in `apps/openriver/lib/app/design_system.dart` owns the shared themes and page widths.
- Both themes use `ShadGreenColorScheme`. Read colors from `ShadTheme.of(context).colorScheme`, never from local color literals or `Theme.of(context)`.
- Use `ShadTheme.of(context).textTheme` for headings, body, lead, small, and muted text. The package supplies the Geist font.
- Use the library's default six-pixel corner radius, border, focus ring, and component states. Do not restyle individual screens unless the design system adds a shared variant.
- Pages use a maximum content width of 960 logical pixels, 24 pixels of outer padding below 600 pixels, and 48 pixels at wider widths. Use spacing in multiples of 8, with 12 or 24 where the component composition requires it.

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

## Planned UI kit

[ADR 0003](adr/0003-ui-kit-and-app-shell.md) proposes moving these foundations into `packages/openriver_ui`, adding a responsive app shell, go_router navigation, localization, and the `context.app` accessor. Until it is implemented, the rules on this page describe the current app.

## Current migration

The library page uses Shad components for its badge, card, actions, alerts, progress, and file-picker error toast. Library startup, import, retry, and privacy behavior remain owned by `LibraryCubit`.

The 0.2.6 package predates Flutter 3.41. The workspace uses a copy in `third_party/shadcn_ui` with a minimal compatibility patch, selected by the root `dependency_overrides`. See that directory's README for the exact changes. Keep the app's `^0.2.4` declaration and the local patch together until a deliberate package upgrade replaces them. A rollback restores the previous Material shell and screen alongside removal of the dependency, override, and vendored copy; it does not affect stored library data.
