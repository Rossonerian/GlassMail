
### Production-Readiness Validation (v1)

- **Live Gmail features (Sent APPEND, remote Drafts import, unsubscribe, GETQUOTAROOT, IDLE timing, reconnect, two accounts):** NOT RUN. (Reason: No dedicated test Gmail credentials with active IMAP/app passwords provisioned on the build host).
- **Room/Drift migration (8 -> 9 -> 10) on EXISTING database:** NOT RUN. (Reason: Requires a fixture or snapshot of a live user's v8 Room DB running on an Android device to test true in-place SQLite migration).
- **Large-mailbox cache eviction under real volume:** NOT RUN. (Reason: No large corpus test account available on host).
- **Actual phone layout / rotation / process-death behavior:** NOT RUN. (Reason: Requires physical device manipulation and ADB process death injection which is not supported natively via the currently available automated UI tests).
- **Macrobenchmark performance numbers:** NOT RUN. (Reason: Android macrobenchmark suite is not ported to Flutter; relying instead on `flutter run --profile` manual DevTools traces).
- **iOS Build and Push:** NOT RUN. (Reason: Linux host; iOS requires macOS and Xcode. iOS Background Fetch / APNs push cannot be verified).
