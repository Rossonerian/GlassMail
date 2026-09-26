# Manual testing

This is the planned v1 phone verification run. No device test has been performed as part of implementation.

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
13. Verify Theme (System/Light/Dark), Reduce Transparency, and Reduce Motion survive force-stop and relaunch. Open the command palette from the `⌘` action and execute Inbox, Search, Settings, and Refresh; in Reader verify real message actions appear.
14. Clear/reseed the dataset before trying another size.
15. Tap Compose, enter a controlled test recipient, subject, and body, leave and reopen the saved draft from the command palette, then Send only with a dedicated Gmail test account. Verify delivery before testing Reply, Reply all, or Forward.
16. Check that a thread row shows message and participant counts, and that Primary/Social/Promotions/Updates/Forums filter consistently with unread badges.
17. Use Settings to configure each short/long swipe action. Confirm short and long drags invoke the selected action and that an archive snackbar restores the full thread when Undo is tapped.
18. Open an HTML fixture or test message. Confirm remote images stay blocked, links do not navigate, and tiny image tags show a tracker count.
19. Change offline body and attachment limits, then reopen Settings and confirm the choices persist.
20. Rotate the phone, background/reopen the app, and force-stop/relaunch while a draft is open. Draft text should be recovered from Room.

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
11. Compose a test message with the default 10-second window. Confirm the countdown appears, tap Undo, and verify no mail arrives. Send again and verify both delivery and a Sent-folder copy after the delay.
12. Save and edit a draft. Confirm it appears in Gmail Drafts with updated content, then edit it in Gmail and run Sync now to confirm the app imports the newer remote content.
13. Use a disposable mailing list with `List-Unsubscribe-Post: List-Unsubscribe=One-Click`. Tap Unsubscribe and confirm the server records the POST. For a `mailto:` list, confirm the mail app opens with an unsubscribe request for review.
14. Set a small cache limit and sync enough read mail to exercise body eviction. Unread and starred message bodies should remain available. Download attachments until the selected cap is reached and confirm older cached files are evicted.
15. Refresh the Gmail storage quota and compare the used/total numbers with the account's Gmail storage page.
16. Add a second Gmail account, switch between accounts from the inbox avatar, enable Unified inbox, and confirm search/actions open the correct account thread. Confirm a third account is rejected.
17. Leave the app in the foreground/background with the mailbox connection notification present. Send a new message to the account from another client and note IDLE notification timing; disable network briefly and confirm reconnect plus periodic sync.
18. Kill the app during a queued send. On relaunch, if delivery status is marked uncertain, check Gmail Sent before retrying. Do not send the same message twice during this check.

No live Gmail, device instrumentation, screenshot, or performance result is claimed until you run this against a dedicated account/device.
