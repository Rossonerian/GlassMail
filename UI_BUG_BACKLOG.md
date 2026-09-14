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
