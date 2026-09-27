## 2023-10-27 - IMAP Password String Conversion
**Vulnerability:** The IMAP client was converting `CharArray` passwords to `String` when executing the LOGIN command, leaving the plaintext password in the JVM heap until garbage collection.
**Learning:** `String` conversion is an easy mistake to make when interacting with stream writers or executing textual protocols like IMAP, but it defeats the purpose of receiving secrets as `CharArray`.
**Prevention:** Construct command bytes manually using `CharBuffer` and `StandardCharsets.UTF_8.encode`, then wipe the resulting `ByteArray` and `CharArray` in a `finally` block before returning.
