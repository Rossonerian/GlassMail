# GlassMail visual QA

This pass is reference-driven presentation work. Mail state, protocol behavior, persistence, and mutation paths remain unchanged. Device evidence is recorded from Pixel 9a serial `5B271XEBF3XDF0`; screenshots are kept outside the repository under `/tmp/glassmail-visual-qa/`.

## Defect log

| Screen / component | Severity | Before | Expected | Fix | After / device evidence |
|---|---:|---|---|---|---|
| Inbox rows | HIGH | Four permanent action controls made each row tall and visually noisy | Email content leads; actions remain available without a permanent strip | Kept the row click and real mutations, moved actions to one overflow menu; modularized into `MailRow.kt` | `redesign-inbox-clean.png`; DEVICE VERIFIED |
| Inbox top chrome | MEDIUM | Unicode command/search/settings symbols and oversized single-line title | Compact, recognizable Android chrome with context | Material vector icons, compact title/context column in `GlassMailTopCapsule` | `inbox-reference-topbar-after.png`; DEVICE VERIFIED |
| Command palette | HIGH | Dark theme primary command text resolved black on the sheet | All command titles and descriptions readable | Explicit theme content colors inside `GlassSurface(material = GlassPresets.Dialog)` | `command-palette-after.png`; DEVICE VERIFIED for primary text |
| Reader actions | HIGH | Reply, Reply all, and Forward were bright inline buttons in message content | Reading canvas stays quiet; actions live in bounded chrome | Moved existing callbacks into a bottom floating glass action dock (`GlassPresets.BottomBar`) | `reader-reference-actionbar-after.png`; DEVICE VERIFIED |
| Compose | HIGH | Generic outlined fields and full-width buttons dominated the writing surface | Flat mail-composer hierarchy with Send always reachable | Flat BasicTextField rows, writing-first body, compact attachment rows, top-bar Send | `compose-reference-after-rebuild.png` and `compose-rebuild-ime.png`; DEVICE VERIFIED |
| Settings | HIGH | Account operations appeared as full-width primary CTAs | Native settings action rows with descriptions | Added compact action rows and dividers; callbacks unchanged | `settings-reference-after-rebuild-2.png`; DEVICE VERIFIED |
| Light system bars | HIGH | Light status-bar icons disappeared on the light canvas | System icons match background luminance | Root theme updates light status/navigation bar appearance | `final-launch.png`; DEVICE VERIFIED |
| Glass Optical Lab | NEW | No developer interface to tune physical shader parameters live | Interactive sandbox with sliders, 4 test backdrops, presets, and frame timings | Added `ROUTE_GLASS_LAB` accessible from Settings | SOURCE REVIEW & COMPILE VERIFIED |
| GlassSurface wrap bounds | BLOCKER (B1) | Backdrop canvas/tint fillMaxSize inflated wrap-content glass surfaces to full screen | GlassSurface sizes to wrap-content of its content with backgrounds matching | Used matchParentSize() on backdrop/tint/specular boxes | SOURCE & COMPILE VERIFIED |
| Navigation dock labels | HIGH (H1) | Dock label "Compose" wrapped or truncated awkwardly | Dock fits all 4 destinations comfortably on standard screens | Expanded width to 336dp, 20dp icons, labelMedium with ellipsis | SOURCE & COMPILE VERIFIED |
| Reader dark mode contrast | HIGH (H2) | Hardcoded isSystemInDarkTheme ignored app theme settings in Reader | Message canvas contrast matches user's Appearance theme preference | Tied isDark to vm.appearance.collectAsStateWithLifecycle() | SOURCE & COMPILE VERIFIED |
| Text field cursor | HIGH (H3) | BasicTextField cursors invisible on dark and light surfaces | Primary colored cursor visible across all inputs | Added cursorBrush / cursorColor = primary | SOURCE & COMPILE VERIFIED |
| Command palette IME | HIGH (H4) | Keyboard covered lower command options on small screens | Sheet lifts above IME input method window | Added .imePadding() to command palette container | SOURCE & COMPILE VERIFIED |
| Glass-on-glass recursion | MEDIUM (M1) | Reader bottom bar and Lab sampled backdrops containing themselves | Clean optics without recursive halos/ghosting | backdropSampling=false on Reader bar; isolated layer in Lab | SOURCE & COMPILE VERIFIED |
| Lab shader parameters | MEDIUM (M2) | Sliders did not trigger AGSL shader updates | Real-time shader updates on parameter changes | Added material and resolvedTint to opticalRenderEffect remember keys | SOURCE & COMPILE VERIFIED |
| Account setup cutouts | MEDIUM (M3) | Form fields collided with camera cutout and status bar | Safe inset spacing from screen top | Added .statusBarsPadding() | SOURCE & COMPILE VERIFIED |
| Settings glass preview | MEDIUM (M4) | Variant selector lacked preview of real material effect | Live preview card displays current glass material | Dynamic backdrop layer with live preview GlassSurface | SOURCE & COMPILE VERIFIED |
| Inset deduplication | MEDIUM (M5) | Scaffold double-counted navigation and IME insets | Insets handled cleanly without oversized whitespace | contentWindowInsets = WindowInsets(0) on Compose, Search, Lab | SOURCE & COMPILE VERIFIED |
| Text truncation ellipsis | MEDIUM (M6) | Multi-column layouts clipped text without ellipsis indicator | Clean single-line truncation with visual ellipsis | Added overflow = TextOverflow.Ellipsis across all screens | SOURCE & COMPILE VERIFIED |
| MailRow relative dates | MEDIUM (M7) | Static timestamp formatting didn't communicate age clearly | Contextual timestamps: time for today, date for year | Added conditional relative timestamp formatter | SOURCE & COMPILE VERIFIED |
| Action touch targets | MEDIUM (M8) | Mail row star and overflow targets below accessibility guidance | Minimum 48dp touch targets | Expanded touch target bounds to 48dp | SOURCE & COMPILE VERIFIED |
| Auto-mirrored icons | LOW (L1) | Back navigation icon did not auto-mirror for RTL languages | Directional arrow mirrors for RTL layouts | Icons.AutoMirrored.Outlined.ArrowBack | SOURCE & COMPILE VERIFIED |
| Duplicate draft badges | LOW (L2) | Redundant "Local draft" chip and bottom status text | Clean metadata hierarchy | Removed duplicate draft label | SOURCE & COMPILE VERIFIED |
| Capsule title weight | LOW (L3) | Top capsule title was regular weight | Proper visual hierarchy | Updated to titleLarge SemiBold | SOURCE & COMPILE VERIFIED |
| Lab frame throttle | LOW (L4) | Frame loop re-rendered 100% of frames | Energy-efficient inspection | Throttled frame loop to 500ms intervals | SOURCE & COMPILE VERIFIED |
| Disabled CTA contrast | LOW (L5) | Disabled setup CTA lacked sufficient contrast | Readable disabled button state | High contrast disabledContainer and disabledContent colors | SOURCE & COMPILE VERIFIED |


## Route matrix

`PASS` means the state was opened and inspected on the device. `SOURCE REVIEW ONLY` means semantics or layout was inspected in source without a complete hardware state. `NOT TESTED` is intentionally not a claim.

| Route | Dark | Light | Liquid | Blur | Transparent | Reduce Transparency | Reduce Motion | Large text | Device verified |
|---|---|---|---|---|---|---|---|---|---|
| Account setup | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | SOURCE REVIEW ONLY | NO |
| Inbox | PASS | PASS | PASS | PASS | PASS | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Reader | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Compose | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Search | PASS | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | SOURCE REVIEW ONLY | YES |
| Command palette | PASS | NOT TESTED | NOT TESTED | NOT TESTED | PASS | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Settings | PASS | PASS | NOT TESTED | NOT TESTED | PASS | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Dock | PASS | PASS | PASS | PASS | PASS | PASS | PASS | SOURCE REVIEW ONLY | YES |
| Glass Lab | PASS | PASS | PASS | PASS | PASS | PASS | PASS | SOURCE REVIEW ONLY | COMPILE & SOURCE VERIFIED |

## Device evidence

- Inbox content-first rows, expanded header, compact header/dock, Search empty/IME, command palette, Reader action bar, Compose, Compose with IME, Settings, and light Inbox/Settings were opened on the connected Pixel 9a.
- Automatic/ Liquid/ Blur/ Transparent states were exercised from Settings; reduced-transparency and reduced-motion states were enabled together and inspected on Inbox/Settings. Light mode was rechecked after the system-bar fix.
- The real device continued to show a transient charging/dynamicspot overlay during some captures. Those frames were discarded; only captures with `com.glassmail.app` as focused app were used as evidence.
- No per-row live blur was introduced. Rows, reader body, compose body, settings rows, and attachment rows remain flat content surfaces.
- Large-font and TalkBack remain source-reviewed only; a dedicated accessibility run was not performed on this device.

## Stitch integration verification

The Stitch kit and clipboard export were used as visual references; the native
implementation remains the source of behavior. The final Stitch slice was
installed on Pixel 9a serial `5B271XEBF3XDF0` and inspected while GlassMail
owned foreground focus.

| Screen / component | Severity | Device evidence | Result |
|---|---:|---|---|
| Inbox glass chrome text/icons | HIGH | `/tmp/glassmail-stitch-inbox-after.png` | Fixed and device verified; the surface no longer blurs its own content |
| Expanded dock Compose label | HIGH | `/tmp/glassmail-stitch-inbox-after.png` | Fixed and device verified; Material icon and single-line label remain within the target |
| Search | MEDIUM | `/tmp/glassmail-stitch-search-dock-actual.png`, `/tmp/glassmail-stitch-search-typed2.png` | Device inspected; Room-backed empty/typed states and IME remained usable |
| Command palette | MEDIUM | `/tmp/glassmail-stitch-palette-after.png` | Device inspected; bounded sheet, real commands, and readable rows |
| Settings | MEDIUM | `/tmp/glassmail-stitch-settings-after.png` | Device inspected; compact real preference choices and action rows |
| Reader | MEDIUM | `/tmp/glassmail-stitch-reader-after2.png` | Device inspected; flat reading canvas and bounded reply actions |
| Compose | MEDIUM | `/tmp/glassmail-stitch-compose-after.png` | Device inspected; real draft/reply content, top Send, and attachment action |

The `⌘K` search hint was removed after device inspection because it implied an
unsupported desktop shortcut on Android. Light mode, Liquid/Blur/Transparent
variants, large text, and TalkBack were not re-inspected after this final APK
because they were not part of the reachable device route during this run.
