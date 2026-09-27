# Visual QA

## Render Targets
- **Inbox:** Flat rows, smooth scroll behind Top Capsule and Dock.
- **Top Capsule:** Refracts background content slightly. Edges must not bleed or halo heavily.
- **Dock:** Interactive squircle, glows lightly on touch (`GlassGlow`) and organically squashes (`LiquidStretch`).
- **Command Palette:** Modal bottom sheet uses standard Glass dialog settings.

## Success Criteria
- [x] Text remains readable on mail rows.
- [x] Background scrolls seamlessly beneath glass without layout pop.
- [x] Reduced Transparency mode completely disables blur.
- [x] Dock animates width smoothly without squishing interior icons.
- [x] Shadows cut out the foreground shape (new upstream behavior).
