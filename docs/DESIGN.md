# Udaimania visual redesign

The working design file is [Udaimania — App states, components & assets](https://www.figma.com/design/YFE7QhNjopYeVDfnRnOwMv?node-id=4-402).

The file is ordered as **Design System → Assets → States & Layouts**. Its overview
links to each page. Existing asset, screen, and component master IDs are preserved.

## Design System

- **00 · Design System / Overview:** file navigation, inventory, and editing guidance.
- **01 · Design System / Foundations:** all 31 current semantic colors in Light
  and Dark, 13 text styles, the bundled Nunito family, 19 spacing values, 9 radii,
  and references for surfaces, gradients, shadows, and inner glows.
- **02 · Design System / Components:** 11 control families with all 29 existing
  variants shown as connected instances, with usage and state labels.
- **03 · Design System / Layout & behavior:** app-shell anatomy, layout rules,
  source interaction timings, state vocabulary, accessibility handoff notes,
  source paths, and coverage limits.

The palette documents the current Figma system. Some colors resolve native
opacity or gradient treatments into simpler fills; the surfaces board identifies
these differences. The interaction notes describe source behavior, not animated
Figma prototypes. Eight additional navigation icon masters live in Assets and
retain their existing instance connections.

## Assets

All 230 source files from `macos/Udaimania/Assets.xcassets` are retained. Their
SHA-256 digests are unique; distinct source resolutions remain separately labeled.

| Page | Source assets |
| --- | ---: |
| **10 · Assets / Logos & identity** | 15 |
| **11 · Assets / Interface icons** | 48 |
| **12 · Assets / App & website icons** | 48 |
| **13 · Assets / Artwork & backgrounds** | 24 |
| **14 · Assets / Characters & motion** | 84 |
| **15 · Assets / Reference images** | 11 |

The interface-icons page also contains the 8 connected navigation masters and
10 native SF Symbol exports. These are additional to the 230 source-catalog files.

The 105 SVG imports contain editable vector layers. The 125 raster imports retain
their original image content; text baked into images is not editable. Animation
frames and sprite sheets are included as assets, without playback timing. Asset
names, original upstream artwork, and third-party logos are retained for traceability.

## States & Layouts

- **20 · States & Layouts / Onboarding:** 8 role, preference, provider, CLI setup,
  and permission states.
- **21 · States & Layouts / Timeline:** 10 empty, populated, detail, paused,
  generating, failed, week, dark, category, and goal states.
- **22 · States & Layouts / Workspace:** 14 Chat, Daily, Weekly, Agents, Flow,
  and Support views.
- **23 · States & Layouts / Settings:** the first viewport of all eight settings tabs.

The 40 editable frames use 1200 × 800 viewports, arranged in three-column grids
with separate source captions. They are static SwiftUI reconstructions with
synthetic activity and runtime data. The role-selection screen was compared with
the running development app. They are not screenshots of personal activity or an
exhaustive runtime state machine. Complex charts, native permission guidance,
and animated Flow scenery are simplified. Hosted Flow sessions and AgentPlayback
dashboard interiors are not included. Account price labels are source-code list
prices, not live billing offers.

SF Pro is listed by the Figma renderer but draws blank. The three Agents system
headings use an explicitly named Figtree fallback style. Ten SF Symbol icons
were exported from the native AppKit symbols used by SwiftUI. Other screen
typography uses the app's Figtree and Instrument Serif families; Nunito is also
bundled and documented in the typography reference.

## Source maps and handoff

- [design-system-map.json](design/design-system-map.json) records the page order,
  documentation boards, variables, text styles, component families, and counts.
- [screen-map.json](design/screen-map.json) records screen and component IDs,
  source views, and reconstruction limits.
- [asset-map.json](design/asset-map.json) maps each source filename and SHA-256
  digest to its preserved Figma node, category, and destination page.

The reorganization was checked for preservation of all 230 source asset nodes,
40 screen frames, 37 component masters, and 11 component sets. Top-level boards
do not overlap. New and rebuilt reference boards were visually reviewed.

Figma edits do not automatically change the app. Share the edited frame link,
implement the chosen changes in the fork, and rebuild the Udaimania development
scheme to review them in the local app.
