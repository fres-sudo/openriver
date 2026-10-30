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
| Sheets and dialogs | `showRiverOverlay` |
| Icon-only actions | `RiverIconButton` |
| Labeled actions | `RiverButton` (primary, secondary, outline, ghost, destructive) |
| Loading, empty, and error regions | `RiverStateView` |
| Content surfaces | `ShadCard` |
| Short status labels | `ShadBadge` |
| Other inline status messages | `ShadAlert` variants |
| Temporary feedback | `ShadToaster` and `ShadToast` |
| Progress | `ShadProgress` with a semantics label |
| Future inputs and selection | `ShadInput`, `ShadSelect`, `ShadCheckbox`, and other `shadcn_ui` controls |
| Icons | `LucideIcons` exported by `shadcn_ui` |
| Choosing a whole number in a range, such as a replay step | `RiverStepSlider` |
| Cards, chips, felt, and seats | The replay table widgets below |

Use Flutter `Text`, `Icon`, `SafeArea`, `Column`, `LayoutBuilder`, `Semantics`, and similar primitives to compose these components. Do not add Material or Cupertino controls, themes, snackbars, buttons, cards, chips, input fields, or progress indicators to app screens. When a needed control is absent in this library version, build a small shared widget from Flutter primitives using the Shad theme, and document it here before using it across screens.

### Kit components

- `RiverButton` wraps `ShadButton`. ShadButton 0.2.6 is 40 pixels tall, cannot wrap its label, and ignores Enter and Space. RiverButton gives a hit area of at least 48 pixels that grows with the text scale, wraps long labels, activates from the keyboard, and exposes one semantics node with its label, role, and state. It is disabled while `busy` or without `onPressed`.
- `RiverPage` fills its region with the background color, applies safe areas, and centers content at a maximum width: `standard` (960), `wide` (1280, for lists and tables), or `full`. It uses 24 pixels of outer padding on compact regions and 48 otherwise. Scrollable pages use the primary scroll controller; set `scrollable: false` when the body scrolls itself.
- `RiverPageHeader` marks its title as a semantic header. Actions sit beside the title, or wrap below it on compact pages.
- `showRiverOverlay` shows a bottom sheet in compact windows and a centered dialog otherwise, switching if the window crosses compact. It has a titled header, a labeled 48-pixel close button, and a scrolling body, closes with Escape, the barrier, or system back, names its route for screen readers, and skips its transition with reduced motion. Use it instead of `showShadDialog` and `showShadSheet`, whose close button is a 20-pixel unlabeled target.
- `RiverIconButton` is an icon-only action with a spoken label and tooltip.
- `RiverStateView.loading`, `.empty`, and `.error` replace content in the same region. Error messages are live regions and must not contain raw errors, paths, or file contents.
- `RiverStepSlider` chooses a whole number from 0 to `max`. shadcn_ui 0.2.6's `ShadSlider` wraps Material's `Slider`, which asserts without a Material ancestor, so the kit builds its own from primitives. It is 48 pixels tall, responds to taps and drags, takes arrow keys, Home, and End while focused, mirrors in right-to-left layouts, and exposes slider semantics with a spoken value and increase and decrease actions.

### Replay table widgets

These are poker-specific, so they live in `apps/openriver/lib/features/replay/` rather than the kit. They take every color from `context.app.theme` through `TablePalette` and render replay snapshots exactly as Rust computed them; they derive no pots, positions, turn order, or legality.

- `TablePalette` names the table colors. The felt is the primary color at 16% over the background. Card faces use the card surface. Black suits use the card foreground and red suits the destructive color, which `RiverThemes` keeps at AA contrast on that surface in both themes. Card backs use the primary color.
- `PlayingCardWidget` draws a card face up (rank over suit glyph) or face down, sized by `width` at a 1.4 aspect ratio. Its glyphs follow the card size rather than the text scale. The glyph (♠ ♥ ♦ ♣) tells suits apart without relying on color. Pass `label` to give it a spoken name; seats describe their own cards instead.
- `ChipStack` shows an amount beside a small stack of chips, for bets and the pot. Long amounts ellipsize rather than overflow.
- `TableFelt` is the oval playing surface.
- `SeatWidget` shows the name, position badge, stack, hole cards, last action, all-in and winnings badges, and a ring when the seat acts next. It is drawn at a 128-pixel design width and scaled to its slot. A folded seat dims its cards and mutes its text, keeping AA contrast. It is one semantics node, such as "Seat 3, Cy, button, stack $1.00, bet $2.00, all-in". `EmptySeat` marks an unoccupied seat.
- `ReplayTable` places seats on an ellipse for 2–10 seats, numbered clockwise with the focus seat at bottom center. Each bet and the dealer button sit just outside their seat, on the line to the center. Narrow tables are tall ovals with the pot in a wrapping row above the felt. Wide tables put the pot and side pots on either side of the board. The table is a scaled drawing, so it caps text scale at 1 when tall and 1.5 when wide. The seats' spoken labels, the step announcement, the action log, and the controls follow the full text scale.

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

## App structure

- `OpenRiverApp` provides `LibraryCubit` and the file chooser above a go_router `StatefulShellRoute` with Library, Hands, and Settings branches. `AppShell` wraps the branches in `RiverShell`; Import is its primary action.
- Navigate with `AppRoutes` constants. Each destination keeps its own pages and scroll position. Reselecting a destination returns to its root page, or scrolls to the top if already there. System back goes to the library before leaving the app.
- Strings come from `lib/l10n/app_en.arb` through `context.app.localizations`. Do not hard-code user-facing text in widgets.

[ADR 0003](adr/0003-ui-kit-and-app-shell.md) lists the remaining kit work: goldens and a catalog example.

## Hand replayer

`ReplayView` composes the table, a live-region announcement of each step, `ReplayControls`, and `ActionLog`, driven by `ReplayCubit`. Expanded and wider content regions put the log beside the table. Medium regions put it in a bottom panel. Compact regions open it in a `showRiverOverlay` sheet. Keyboard: ← and → step, Home and End jump to the ends, 1–5 jump to a street, and Space plays or pauses unless a focused control handles activation. Debug builds open a sample replay from the Hands page.

## Current migration

Every screen uses the kit. `LibraryCubit` still produces its own English error messages; they move to the ARB file separately.

The 0.2.6 package predates Flutter 3.41. The workspace uses a copy in `third_party/shadcn_ui` with a minimal compatibility patch, selected by the root `dependency_overrides`. See that directory's README for the exact changes. Keep the kit's `^0.2.4` declaration and the local patch together until a deliberate package upgrade replaces them. Removing shadcn_ui means removing the dependency, override, and vendored copy, and replacing the kit's Shad-based components; it does not affect stored library data.
