# GlassMail Stitch integration map

Stitch is used as the presentation reference. Existing GlassMail state, routes,
ViewModels, repositories, protocol adapters, persistence, and security remain
authoritative. No Stitch HTML, JavaScript, remote fonts, sample people, or
unsupported provider/product behavior is shipped.

## Design sources

| Stitch element | Design source | Existing GlassMail equivalent | Decision |
|---|---|---|---|
| Calm dense inbox composition | `inbox_calm_uncluttered/screen.png` | Room-backed `InboxUiState` and `MailRow` | ADAPT_TO_EXISTING_FUNCTION |
| Dynamic floating header and collapsing chrome | `inbox_dynamic_ios_glass_collapsible_chrome/screen.png` | Existing passive Inbox collapse and bounded glass surfaces | ADAPT_TO_EXISTING_FUNCTION |
| Inbox category tabs: Priority, Updates, Newsletters, Personal | `inbox_calm_uncluttered`, `inbox_dynamic_ios_glass_collapsible_chrome` | No real category classifier/filter routes | OMIT_UNSUPPORTED |
| Inbox rows and unread marker | Aether + `inbox_calm_uncluttered` | Real Room-derived sender, subject, preview, labels, unread state | ADAPT_TO_EXISTING_FUNCTION |
| Row overflow actions | Aether content-canvas rule | Existing read, star, archive, trash mutations | ADAPT_TO_EXISTING_FUNCTION |
| Starred/Snoozed dock destinations | Inbox Stitch variants | No supported Starred/Snoozed routes | OMIT_UNSUPPORTED |
| Real navigation dock | Aether + dynamic inbox screen | Existing Inbox, Search, Settings routes | ADAPT_TO_EXISTING_FUNCTION |
| Compose action | Inbox/Compose Stitch screens | Existing durable Compose route and SMTP send | ADAPT_TO_EXISTING_FUNCTION |
| Reader reading-first layout | `reader_calm_spacious/screen.png` | Existing `ReaderUiState`, thread/body/labels/attachments | ADAPT_TO_EXISTING_FUNCTION |
| Reader chroma and bounded action dock | `reader_dark_chroma_decay/screen.png` | Existing sender/context chroma decay and reply actions | ADAPT_TO_EXISTING_FUNCTION |
| Reader technical tags and PGP status | Reader Stitch variants | No such domain state | OMIT_UNSUPPORTED |
| Reader attachment row | Reader Stitch variants | Real attachment metadata/download/open flow | ADAPT_TO_EXISTING_FUNCTION |
| Minimal Compose header and writing canvas | `compose_dark/screen.png` | Existing ComposeViewModel, autosave, validation, send | ADAPT_TO_EXISTING_FUNCTION |
| Recipient chip/autocomplete | `compose_dark` | Existing plain recipient bindings; no autocomplete model | OMIT_UNSUPPORTED |
| Markdown, formatting, PGP/encryption controls | `compose_dark` | No implemented feature support | OMIT_UNSUPPORTED |
| Command sheet geometry and frosted surface | `command_palette_dark/screen.png` | Existing typed `CommandPaletteAction` overlay | ADAPT_TO_EXISTING_FUNCTION |
| Command search/keyboard metadata | `command_palette_dark` | Existing touch command list; no keyboard shortcut engine | ADAPT_TO_EXISTING_FUNCTION |
| Archive-all, move-to-folder, contact jumps | `command_palette_dark` | No matching real mutation/navigation support | OMIT_UNSUPPORTED |
| Settings hierarchy and segmented choices | `settings_dark/screen.png` | Existing appearance, accessibility, notification, account, debug state | ADAPT_TO_EXISTING_FUNCTION |
| PGP, WebSocket Push, SQLite usage totals, Vim bindings, swipe settings | `settings_dark` | No supported GlassMail settings | OMIT_UNSUPPORTED |
| Flat first-run branding and technical labels | `account_setup_first_run_flat/screen.png` | Existing Gmail/App Password setup and debug seed | ADAPT_TO_EXISTING_FUNCTION |
| Google, M365, Custom IMAP, JMAP provider grid | `account_setup_first_run_flat` | Current architecture supports Gmail/App Password only | OMIT_UNSUPPORTED |
| GlassMail emblem | Stitch screenshots/HTML | Existing brand behavior/assets where available | ADAPT_TO_EXISTING_FUNCTION |
| Inter / JetBrains Mono typography | Aether DESIGN.md | Existing Compose typography; no runtime web font loading | ADAPT_TO_EXISTING_FUNCTION |
| Aether dark/light token system | `aether_mail/DESIGN.md` | Existing `GlassMailPalette` and Material color scheme | ADAPT_TO_EXISTING_FUNCTION |
| Glacier frost, tint, luminous rim | `glacier/DESIGN.md` | Existing reusable `GlassSurface` renderer | ADAPT_TO_EXISTING_FUNCTION |
| Ambient off-screen chroma | Aether DESIGN.md | Existing `AmbientCanvas` and context mapping | ADAPT_TO_EXISTING_FUNCTION |
| Live glass on content rows/cards | Aether explicitly forbids it | Existing flat list/body/editor/settings content | OMIT_UNSUPPORTED |

## Screen variant priority

- Inbox content: `inbox_calm_uncluttered`.
- Inbox chrome: `inbox_dynamic_ios_glass_collapsible_chrome`, translated to
  Android Material interaction and insets.
- Reader content: `reader_calm_spacious`.
- Reader chroma/action treatment: `reader_dark_chroma_decay`.
- Compose, palette, settings, and setup: their named Stitch screens.
- Aether is the primary token and layout authority; Glacier only informs glass
  depth and rim restraint.

## Native implementation rules

- Content remains flat: inbox/search rows, message body, editor, settings rows,
  and attachment rows do not receive live blur or refraction.
- Glass is bounded to navigation, search, floating actions, reader actions,
  command sheets, and other control chrome.
- Every visual control maps to an existing callback or is omitted.
- Android Back, WindowInsets, Material icons, TalkBack semantics, and 48dp
  effective targets take precedence over browser prototype behavior.
- Remote Google Fonts, Material Symbols web fonts, Tailwind, WebView, HTML, and
  Stitch sample data are reference-only and are not production dependencies.

