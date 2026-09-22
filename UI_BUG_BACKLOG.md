# UI bug backlog

Presentation defects are tracked separately from functional behavior. Cosmetic items remain intentionally open for later polish.

| Status | Screen | Defect | Severity | Functional impact | Later action |
|---|---|---|---:|---|---|
| OPEN | Compose | Recipient inputs are plain delimited text rather than chips/autocomplete | MEDIUM | None for valid comma/semicolon addresses | Defer; recipient model is intentionally unchanged |
| OPEN | Compose | Attachment rows remain compact metadata rows without thumbnails/progress | MEDIUM | Download/send controls remain usable | Consider richer preview later |
| DEVICE_VERIFIED | Compose | IME could cover attachment/send controls | HIGH | Send or attachment actions could become unreachable with keyboard open | Keep regression coverage |
| DEVICE_VERIFIED | Settings | Appearance/account controls read as large actions | HIGH | Settings hierarchy was harder to scan | Compact action rows verified on Pixel 9a |
| DEVICE_VERIFIED | Inbox | Permanent row action strip made rows too tall | HIGH | Mail density and scanning suffered | Overflow menu verified on Pixel 9a |
| DEVICE_VERIFIED | Inbox | Unicode top controls were visually inconsistent | MEDIUM | Navigation remained available but symbols were ambiguous | Material vector icons verified on Pixel 9a |
| DEVICE_VERIFIED | Inbox | Row action hit targets were undersized in the prior layout | HIGH | Common actions were difficult to activate reliably | Keep 48dp overflow target |
| DEVICE_VERIFIED | Dock | Compact dock could clip touch targets at its previous width | HIGH | Route destinations could be difficult to activate | Keep 168dp compact width and safe inset |
| DEVICE_VERIFIED | Reader | Sender chroma overpowered message reading canvas | HIGH | Reading contrast suffered | Reduced blend verified on Pixel 9a |
| DEVICE_VERIFIED | Reader | Reply controls were inline bright buttons | HIGH | Reading surface was visually interrupted | Bottom action bar verified on Pixel 9a |
| DEVICE_VERIFIED | Command palette | Dark sheet command titles were unreadable | HIGH | Commands could not be confidently selected | Explicit content colors verified on Pixel 9a |
| DEVICE_VERIFIED | Light system bars | Status-bar icon contrast after theme switch | HIGH | Light status icons can disappear on porcelain canvas | Final APK verified on Pixel 9a |
| DEVICE_VERIFIED | Glass chrome | Blur/refraction effect processed chrome's own text and icons | HIGH | Header and dock content was unreadable | Keep content on the unprocessed foreground layer |
| DEVICE_VERIFIED | Dock | Four expanded destinations allowed the Compose label to wrap | HIGH | Dock label presentation was clipped/wrapped | Keep labels single-line with native vector icons |
| RESOLVED | GlassSurface | B1: GlassSurface inflated to full screen without explicit size constraints | BLOCKER | Scaffold topBar collapsed route content body to 0 height | Switched backdrop, tint, and specular modifiers from fillMaxSize() to matchParentSize() |
| RESOLVED | Dock | H1: Expanded dock tab label wrapping and small touch target | HIGH | Tab labels wrapped or truncated awkwardly | Widened dock to 336dp, sized icons to 20dp, typography to labelMedium with ellipsis |
| RESOLVED | Reader | H2: Dark mode contrast mismatch in explicit Dark/Light theme | HIGH | Canvas colors were tied to system theme instead of AppTheme state | Tied Reader surface to vm.appearance state |
| RESOLVED | Text Fields | H3: Invisible text cursor on dark/light BasicTextFields | HIGH | Cursor was difficult or impossible to locate | Added explicit cursorBrush and cursorColor using MaterialTheme.colorScheme.primary |
| RESOLVED | Command palette | H4: Palette clipped by IME soft keyboard | HIGH | Lower command options covered when typing | Added .imePadding() to command palette sheet container |
| RESOLVED | Reader / Lab | M1: Glass-on-glass self-sampling halo in floating bars | MEDIUM | Recursive sampling artifact on backdrops | Disabled backdrop sampling on floating action bar and used isolated layer in Glass Lab |
| RESOLVED | Glass Lab | M2: Physical shader parameters did not update dynamically | MEDIUM | Lab controls did not update AGSL shader in real-time | Added material and resolvedTint to opticalRenderEffect remember keys |
| RESOLVED | Account Setup | M3: Top input field collided with status bar / camera cutout | MEDIUM | Email field partially obscured under status bar | Added .statusBarsPadding() to Account Setup container |
| RESOLVED | Settings | M4: Material variant preview tile was static | MEDIUM | User could not see visual effect of Liquid/Blur/Transparent | Added live dynamic backdrop layer and preview GlassSurface |
| RESOLVED | Compose / Search | M5: Double navigation bar / IME insets on Scaffold | MEDIUM | Extra padding gap below keyboard and navigation bars | Added contentWindowInsets = WindowInsets(0) to Scaffolds |
| RESOLVED | Global UI | M6: Long subject/sender/filename strings overflowed unclipped | MEDIUM | Text collided across columns or pushed controls offscreen | Added overflow = TextOverflow.Ellipsis to all single-line Text components |
| RESOLVED | Inbox | M7: MailRow timestamps were static or poorly contextualized | MEDIUM | Difficult to distinguish today's mail from past mail | Formatted timestamps conditionally (HH:mm for today, MMM d for year, MM/dd/yy for past) |
| RESOLVED | Inbox | M8: MailRow star and overflow touch targets under 48dp | MEDIUM | Actions hard to tap reliably on small screens | Expanded touch targets to 48dp minimum |
| RESOLVED | Compose | L1: Back arrow was not auto-mirrored for RTL | LOW | Directional arrow did not mirror in RTL layouts | Replaced Icons.Outlined.ArrowBack with Icons.AutoMirrored.Outlined.ArrowBack |
| RESOLVED | Compose | L2: Duplicate "Local draft" chip and redundant status text | LOW | Visual clutter in compose bottom row | Removed duplicate draft label and consolidated status |
| RESOLVED | Header Chrome | L3: Top capsule title typography too thin | LOW | Title lacked visual anchor hierarchy | Changed title typography to titleLarge SemiBold |
| RESOLVED | Glass Lab | L4: Frame timing loop running at 100% recomposition | LOW | Sandbox warmed device with unnecessary updates | Throttled frame delta update loop to 500ms intervals |
| RESOLVED | Account Setup | L5: Disabled CTA button lacked sufficient contrast | LOW | Disabled button text difficult to read | Set explicit disabled container and content colors matching theme |
