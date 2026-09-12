# Manual testing

## A. Synthetic mailbox — no Gmail required

1. Build with a full JDK: `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew --max-workers=2 --no-parallel --priority=low :app:assembleDebug`.
2. Install: `adb install -r app/build/outputs/apk/debug/app-debug.apk`.
3. Launch GlassMail and tap **Use 100-message debug mailbox**.
4. Confirm the Room-backed Inbox appears; open a thread/message.
5. Toggle star and read state using the row controls.
6. Archive a message and confirm it leaves Inbox immediately.
7. Use Search to find sender, subject, or fixture preview text.
8. Open Settings and use the 10/100/1,000/10,000 fixture controls.
9. Force-stop: `adb shell am force-stop com.glassmail.app`; relaunch and confirm fixture persistence.
10. Enable airplane mode and repeat star/read/archive; local state should remain responsive.
11. Seed 10,000 messages, continuously scroll the Inbox, and watch for visual stalls.
12. In Settings switch LIQUID, BLUR, and TRANSPARENT and inspect the glass preview and touch targets.
13. Clear/reseed the dataset before trying another size.

## B. Gmail — dedicated test account only

1. Create/use a dedicated Gmail test account; enable 2-Step Verification and create an App Password.
2. Never put the App Password in a shell command, source file, screenshot, or log.
3. Enter the Gmail address and App Password in setup.
4. Confirm initial sync fetches a bounded UID page; restart and refresh repeatedly to progress history.
5. Force-stop during a later page and relaunch; the durable checkpoint should continue from the next UID range.
6. Compare read/star/archive actions against Gmail after reconnecting.
7. Test airplane mode, then reconnect; pending local mutations should remain visible until acknowledged.
8. Test process kill/relaunch after local actions and after a failed network request.
9. Exercise UIDVALIDITY/mutation behavior only with a disposable mailbox; this needs live-server validation.
10. Troubleshoot with sanitized logs: `adb logcat | rg 'GlassMail|AndroidRuntime'`. Never share credentials or full message bodies.

No live Gmail, device instrumentation, or performance result is claimed until you run it against a dedicated account/device.
