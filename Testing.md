# Testing

JVM tests cover IMAP parsing, mailbox reduction, and sparse-UID page continuation. Android test sources cover real in-memory Room creation, Flow projection, UID uniqueness/replacement, checkpoint persistence, pending mutation persistence, unique WorkManager scheduling, retry/authentication mapping, and cancellation propagation.

```bash
./gradlew --max-workers=2 --no-parallel --priority=low test
./gradlew --max-workers=2 --no-parallel --priority=low :core:database:connectedCheck :sync:connectedCheck
```

Connected tests and Macrobenchmarks require an Android device/emulator. Live Gmail requires a dedicated test account and App Password. The current host JDK is missing `jlink`, which blocks final Android package/benchmark transforms until `JAVA_HOME` points to a full JDK.
