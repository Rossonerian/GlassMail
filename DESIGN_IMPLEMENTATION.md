# GlassMail design implementation

| Specification | Route | State | Status |
|---|---|---|---|
| Four-layer ambient shell | all | navigation/UI state | Implemented |
| Dense Priority inbox | inbox | `InboxUiState` | Implemented |
| Reader chrome and chroma decay | reader | `ReaderUiState` | Implemented |
| Local search / command palette | search/all | `SearchUiState` + typed actions | Implemented |
| Appearance settings | settings | persisted local preferences | Implemented |

P1 swipe archive is limited to the existing archive mutation. Snooze, Gatekeeper, bundles and account switching are deferred because their domain models do not exist. P2 AI summaries, drafting and automation are intentionally absent.

Appearance choices are stored in the app's scoped appearance preferences and applied at the root: System/Light/Dark controls the Material 3 scheme, while Automatic/Liquid/Blur/Transparent controls bounded glass surfaces. Reduce Transparency forces a near-opaque tonal surface; Reduce Motion removes press compression and is reserved for motion changes that are added to chrome.

The command palette exposes only navigation, refresh, and current-reader message mutations when a real Room-backed message is selected. It does not expose AI or unsupported mailbox features. Device performance measurements and connected benchmark results remain unverified until run on a target device.
