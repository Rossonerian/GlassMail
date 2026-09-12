# Architecture

```text
Compose → ViewModel StateFlow → MailRepository → Room Flow
                                         ↘ IMAP / WorkManager
```

Room is the durable source of truth. `:app` consumes domain models only; it does not use DAOs, IMAP, or WorkManager. `:data:mail` maps Room rows to domain inbox/search/message models. `:core:database` owns entities and transaction boundaries. `:designsystem:glass` owns visual quality/rendering APIs; features only call `GlassSurface`.

Modules: `:app`, `:core:model`, `:core:security`, `:core:database`, `:core:imap`, `:domain:mail`, `:data:mail`, `:sync`, `:designsystem`, `:designsystem:glass`, and `:benchmark`.

Debug fixtures flow through the same Room/repository/ViewModel path as IMAP metadata. Settings hides fixture controls in non-debug builds.
