# ADR 0003: UI kit, app shell, and responsive layout

Date: 2026-10-29
Status: Accepted; implementation in progress (steps 1–2 complete)
Scope: `packages/openriver_ui`, the shared Flutter app shell, routing, and localization in `apps/openriver`

## Decision summary

OpenRiver gets a Flutter UI kit package, **`packages/openriver_ui`**. It owns design tokens, themes, responsive layout, the app shell, page scaffolding, and shared state views. It wraps and re-exports `shadcn_ui`, which remains the only visual component library. Feature code imports the kit, not `shadcn_ui` directly.

The app navigates with **go_router** through a `StatefulShellRoute`. It has three top-level destinations, **Library**, **Hands**, and **Settings**. **Import is an action**, not a destination. All screens reach theme, layout, and localized text through one accessor, **`context.app`**.

These are architecture choices. No shell, router, or kit package exists until the implementation lands and its tests pass.

## Context

- `shadcn_ui` 0.2.6 (vendored in `third_party/shadcn_ui`) has no sidebar, rail, tab bar, or navigation bar. [The design system](../flutter-design-system.md) says that missing controls are built from Flutter primitives using the Shad theme. The shell is the first such control used by every screen.
- Layout constants live in `apps/openriver/lib/app/design_system.dart`. `library_page.dart` repeats the breakpoint, padding, and max-width logic inline. Every new page would copy it.
- The app has no router and no localization setup. Strings are hard-coded English.
- The [technical design](../POKER_PLATFORM_TECHNICAL_DESIGN.md) allows a design-system package "only when justified by actual reuse". A shell and page scaffold shared by every feature meet that bar.
- The app targets Windows, macOS, Linux, Android, and iOS from one codebase ([ADR 0001](0001-foundation.md)). Width alone does not identify a device: tablets, resized desktop windows, split screen, foldables, and Android desktop mode all break the assumption.

## Decisions

### 1. Package boundary

`packages/openriver_ui` is a Pub workspace member. It may depend only on Flutter, `flutter_localizations`, and `shadcn_ui`. It must not import `openriver_api`, `flutter_bloc`, `go_router`, or any app feature. The kit receives everything as constructor data and callbacks.

The public library is `package:openriver_ui/openriver_ui.dart`. It re-exports `shadcn_ui` (including `LucideIcons`), so feature code has a single UI import. It also re-exports Material's `ThemeMode`, which `ShadApp.themeMode` requires; it exports no other Material type. Architecture tests in both packages, run by the `melos check` gate, fail on these imports:

- `package:flutter/material.dart` or `package:flutter/cupertino.dart` anywhere in `apps/openriver/lib` or `packages/openriver_ui/lib`
- `package:shadcn_ui/...` outside the kit

```text
packages/openriver_ui/
  lib/openriver_ui.dart          public exports only
  lib/src/foundation/            RiverSpacing, RiverSizes, RiverDurations
  lib/src/theme/                 RiverThemes (light/dark Shad themes; semantic extras later)
  lib/src/layout/                RiverWindowClass, RiverLayout, RiverResponsive, RiverPage, RiverPageHeader
  lib/src/navigation/            RiverDestination, RiverShell, RiverShellAction, sidebar/rail/bottom bar (private)
  lib/src/overlay/               showRiverOverlay (sheet on compact, dialog otherwise)
  lib/src/components/            RiverButton (keyboard activation, 48-pixel target, wrapping labels)
  lib/src/feedback/              RiverStateView (loading, empty, error)
  lib/src/l10n/                  RiverLocalizations for kit-owned strings
  lib/src/context.dart           the context.app accessor
  example/                       catalog app for visual review
  test/                          unit, widget matrix, accessibility, keyboard, golden
```

All public widgets and types use the **`River`** prefix. The prefix avoids collisions with Flutter and Shad names.

### 2. The `context.app` accessor

Screens read shared UI state through one extension namespace instead of calling several `.of(context)` lookups:

```dart
context.app.theme.colors        // ShadColorScheme
context.app.theme.textTheme     // ShadTextTheme
context.app.theme.spacing       // RiverSpacing tokens
context.app.theme.brightness
context.app.theme.radius        // the Shad theme's corner radius
context.app.responsive.isMobile // window is compact
context.app.responsive.content  // RiverWindowClass of the body region
context.app.input.isTouch       // primary input modality
context.app.localizations       // generated AppLocalizations (app only)
```

The rules:

- The kit defines `extension RiverContextAccess on BuildContext { RiverAppContext get app; }`. `RiverAppContext` is a zero-cost Dart `extension type` over `BuildContext`. It has `theme`, `responsive`, `input`, and `riverLocalizations`.
- Localized app strings are generated inside `apps/openriver`, so the kit cannot name their type. The app adds `localizations` with its own extension on `RiverAppContext` (`apps/openriver/lib/app/app_context.dart`). Both kit and app code then use the same `context.app.…` namespace. The kit stays free of app types.
- Every getter performs its lookup when called and is never cached. A widget's rebuild dependencies are therefore exactly what it reads. Do not store `context.app` results across `build` calls or async gaps.
- `responsive` depends on a `RiverLayout` `InheritedModel` with separate aspects for the window class, content class, and insets. A widget reading `isMobile` rebuilds only when the window crosses a breakpoint, not on every pixel of a resize. Pixel-level layout uses `LayoutBuilder`. The accessor does not provide raw widths.
- `theme` reads `ShadTheme.of(context)` plus kit extras. It never reads the Material `Theme`.

### 3. Responsive model

There are three independent inputs. Code must use the one that matches the decision being made.

| Input | Used for | Source |
| --- | --- | --- |
| **Window class** | Which navigation the shell shows; form-factor-level choices | `MediaQuery.sizeOf` and text scale, computed once by the shell |
| **Content class** | Page padding, column count, max width, card layout | Width of the shell body after navigation, published by `RiverLayout` |
| **Input modality** | Hover affordances, tooltips, density, hit target | Platform default (touch on Android/iOS, pointer on desktop), not width |

Breakpoints follow the Material 3 window size class widths. Only the numbers are borrowed; no Material widgets are used.

| Class | Width (logical px) | `responsive` helper |
| --- | --- | --- |
| `compact` | < 600 | `isMobile` |
| `medium` | 600–839 | `isTablet` |
| `expanded` | 840–1199 | `isDesktop` |
| `large` | 1200–1599 | `isDesktop` |
| `extraLarge` | ≥ 1600 | `isDesktop` |

`isMobile`, `isTablet`, and `isDesktop` describe the **window width class**, not the operating system. A narrow desktop window is `isMobile`. Use `input.isTouch` for touch-specific behavior and `responsive.content` for layout inside a page.

For **accessibility**, the shell chooses its navigation from an *effective width*: the width divided by the text scale, clamped to 1–2. At twice the text size on a 700-pixel tablet, the shell uses the bottom bar rather than squeezing rail labels. Page content classes use the actual width.

`RiverPage` replaces the inline layout code in screens. It applies:

- a maximum content width of 960, or a wider variant for data-dense pages such as the hand list
- outer padding of 24 on compact content and 48 on wider content
- safe-area handling
- scrolling, a `RiverPageHeader` with title, description, and actions, and a heading marked as a semantic header

### 4. App shell

`RiverShell` is data-driven and does not know about routing:

```dart
RiverShell(
  destinations: const [
    RiverDestination(label: …, icon: LucideIcons.library),
    RiverDestination(label: …, icon: LucideIcons.list),
    RiverDestination(label: …, icon: LucideIcons.settings),
  ],
  selectedIndex: shell.currentIndex,
  onDestinationSelected: shell.goBranch,
  primaryAction: RiverShellAction(label: …, icon: LucideIcons.upload, onPressed: …, busy: importing),
  body: shell,
)
```

| Window class (effective) | Navigation | Primary action |
| --- | --- | --- |
| compact | Bottom bar with labels; at most 5 destinations (asserted) | Shown in the page header actions by `RiverPage` |
| medium | 80-pixel rail with icons and labels | Icon button at the top of the rail, with tooltip and semantic label |
| expanded and wider | 256-pixel sidebar with labels; the user can collapse it to the rail | Full-width button at the top of the sidebar |

The behaviors below are requirements. Each has a test.

- **Stable body identity.** The body keeps one position in the element tree across every layout, using a single slotted layout. It never alternates between `Column` and `Row` parents. Crossing a breakpoint while resizing must not reset page state, scroll position, or input text.
- **Per-destination state.** Each destination keeps its own navigator stack and scroll position. Selecting the active destination again pops it to its root. Selecting it again at the root scrolls it to the top.
- **Insets.** The bottom bar consumes the bottom safe area. The rail or sidebar consumes the start-side safe area, which covers a landscape notch. The body receives `MediaQuery.removePadding` for consumed sides so pages do not pad twice.
- **Keyboard on mobile.** The bottom bar hides while the on-screen keyboard is visible.
- **Android back.** Back pops within the current destination. At a non-Library destination's root, back goes to Library. At Library's root, back leaves the app. This is compatible with predictive back.
- **Keyboard and focus.**
  - Navigation and body are separate focus traversal groups.
  - Arrow keys move between destinations.
  - Enter and Space activate a destination.
  - ⌘1–3 (macOS) and Ctrl+1–3 (Windows, Linux) select destinations.
  - After a destination change, focus moves to the new page's heading.
- **Semantics.**
  - Destinations announce their label, selected state, and position in a mutually exclusive group.
  - Collapsed or icon-only controls have semantic labels and tooltips.
  - Badges include a spoken count.
- **Motion.** Sidebar collapse and layout transitions use `RiverDurations`. They are disabled when `MediaQuery.disableAnimations` is true.
- **Direction.** All spacing is directional. The navigation sits on the start side in right-to-left locales.
- **Targets.** All interactive navigation is at least 48 by 48 logical pixels.
- **Desktop minimum.** Desktop windows have a minimum size of 360 by 560, which avoids unusable layouts below the compact class.

The sidebar's collapsed state is kept for the session. Persisting it across launches is deferred until there is a local preferences store.

### 5. Import as an action

Import is reached from `RiverShell.primaryAction` and from contextual page actions, such as an empty hand list. The flow:

1. Choosing the action opens the platform file chooser.
2. The existing `LibraryCubit` imports through Rust.
3. Progress shows in the action's busy state and on the Library page.
4. The import report opens with `showRiverOverlay`: a bottom sheet on compact windows and a dialog otherwise.

Import logic stays in `LibraryCubit`. An import-history route can later be added under `/library/imports` without changing navigation.

### 6. Routing

go_router (first-party, flutter.dev publisher) is pinned to a release compatible with the pinned Flutter 3.41.2 (17.5.0 requires Flutter ≥ 3.38). The router lives in `apps/openriver/lib/app/router.dart` and is passed to `ShadApp.router`.

| Path | Destination |
| --- | --- |
| `/library` (initial) | Library |
| `/hands` | Hands; `/hands/:id` is reserved for a later detail view |
| `/settings` | Settings |

The routes use `StatefulShellRoute.indexedStack`, with one branch per destination. Route paths are constants in one file; widgets do not use string literals for navigation. `LibraryCubit` is provided above the router, because Library, the shell action, and Hands share it. Unknown paths redirect to `/library`.

### 7. Localization

The app uses Flutter's `gen-l10n` with ARB files in `apps/openriver/lib/l10n`, starting with English. Generated Dart is checked in, matching the bridge-code policy. The check gate verifies that it is up to date. `ShadApp.router` receives the app, kit, and Flutter localization delegates.

The kit's own strings, such as "Collapse sidebar", "Navigation", and "Close", come from `RiverLocalizations`. It has English defaults and can be overridden by the app. Kit widgets never hard-code user-facing English.

New and touched UI uses `context.app.localizations`. Existing Library strings move to ARB in a separate change, to avoid conflicts with concurrent import work.

### 8. Testing

The kit is accepted only with these suites:

- **Unit:**
  - window-class boundaries: 599/600, 839/840, 1199/1200, 1599/1600
  - effective-width rule at text scales 1, 1.5, 2, and 3 (clamped)
  - `InheritedModel` aspect rebuild counts
- **Widget matrix:** a shared `pumpAcross` helper runs the shell and each page across:
  - sizes: 320×568, 390×844, 844×390, 768×1024, 1024×768, 1280×800, 1920×1080
  - text scales: 1, 1.5, 2
  - light and dark themes
  - left-to-right and right-to-left directions

  Each run asserts no overflow or other framework exception, the expected navigation form, and correct selected semantics.
- **Accessibility:** Flutter's built-in `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, and `textContrastGuideline` pass for every navigation form in both themes.
- **Keyboard:** traversal order, arrow movement, activation, destination shortcuts, and focus placement after navigation.
- **State:**
  - A stateful body survives compact → expanded → compact resizing.
  - Each branch keeps its scroll position.
  - Re-selection pops to root.
  - Back behavior follows the rules above.
- **Golden:** each navigation form and the state views in light and dark themes, with the bundled Geist font loaded. Goldens run in CI on Linux only, because text rasterization differs by OS. Other platforms run every non-golden test.
- **Integration:** the packaged macOS smoke test reaches import through the shell action and verifies the report overlay.

The `example/` catalog app renders every kit component in both themes and at chosen sizes for manual review. It is not a substitute for tests.

## Consequences

- One more workspace package and two new dependencies (`go_router` and `intl` through `gen-l10n`). Melos scripts must include the kit's tests and formatting paths.
- `design_system.dart` moves into the kit as `RiverThemes` and tokens. App code reads it through `context.app`.
- Feature code stops importing `shadcn_ui` directly. Upgrading or replacing the vendored Shad copy is then limited to the kit.
- The kit's first increment covers what the shell and existing screens need. Inputs, tables, poker widgets (cards, chips, seats), and adaptive overlays beyond the import report are added when a feature needs them, and recorded in [the design system](../flutter-design-system.md).

## Delivery sequence

Each step lands with its tests and a Conventional Commit.

1. Create the package with foundation tokens, `RiverThemes`, `RiverLayout`/window classes, the `context.app` accessor, and `RiverLocalizations`. Add the import-rule check.
2. Add `RiverPage`, `RiverPageHeader`, `RiverStateView`, and `RiverButton`. ShadButton 0.2.6 lacks keyboard activation, a 48-pixel target, and label wrapping. Adjust theme colors that fail WCAG AA contrast.
3. Add `RiverShell` with bottom bar, rail, and sidebar, and the full widget-matrix, accessibility, keyboard, and state suites.
4. Wire up app localization (`gen-l10n`), go_router, Library/Hands/Settings branches, and Import as the shell action with the report overlay. Keep `library_page.dart` hosted with minimal change.
5. Add goldens, the catalog example, the integration test update, and design-system documentation.

## Rollback

The app can return to a single `ShadApp` home page by removing the router and shell. Stored library data and Rust code are unaffected. The kit can remain as a dependency, or its contents can move back into `apps/openriver/lib/app`.
