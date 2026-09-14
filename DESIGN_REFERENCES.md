# GlassMail reference principles

This document records conceptual references used for the visual rebuild. No source code, proprietary assets, icons, copy, or layouts are copied from these products.

## Superhuman Mail

Reference: [Superhuman Mail](https://superhuman.com/) and its [Android listing](https://play.google.com/store/apps/details?id=com.superhuman.mail).

Principle borrowed: email-first information hierarchy, fast access to important actions, and persistent useful navigation.

Not copied: product-specific shortcuts, branding, AI integrations, team features, or proprietary layouts.

GlassMail interpretation: keep sender/subject/snippet readable and dense; move visual emphasis away from per-row controls and toward a small number of predictable navigation/action surfaces.

## Spark Mail

Reference: [Spark Mail](https://sparkmailapp.com/) and its [Android listing](https://play.google.com/store/apps/details?id=com.readdle.spark).

Principle borrowed: compact mailbox scanning, restrained status/color treatment, and navigation that supports quick triage.

Not copied: Smart Inbox categories, account-specific product features, proprietary assets, or interaction details.

GlassMail interpretation: use one quiet divider per message, reserve accent color for unread/priority state, and keep the mailbox a flat content canvas.

## Apple Liquid Glass

Reference: [Apple's Liquid Glass design documentation](https://developer.apple.com/).

Principle borrowed: adaptive translucent chrome, coherent physical layering, and glass as navigation/control material rather than content decoration.

Not copied: iOS-only controls, iconography, system UI, or Apple implementation APIs.

GlassMail interpretation: use the existing bounded GlassSurface only for top chrome, dock, floating actions, search, sheets, and reader actions. Message rows, body text, editor content, settings rows, and attachments remain flat.

## Material 3 Android

Reference: [Android mobile layout and navigation guidance](https://developer.android.com/guide/topics/ui/look-and-feel/). 

Principle borrowed: predictable Android navigation, accessible touch targets, system insets, clear selected states, and platform-consistent controls.

Not copied: default Material screen compositions or a generic card-per-row design.

GlassMail interpretation: retain Android back behavior, Material iconography and semantics, and proper IME/navigation insets while applying GlassMail's graphite/pearl token system.

## Design decision

GlassMail is a high-quality email client whose navigation and controls use responsive glass. Content remains the primary surface. The signature is a calm, dense mail canvas with a single bounded control layer that can become transparent without losing hierarchy.
