// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glassmail_database.dart';

// ignore_for_file: type=lint
class Accounts extends Table with TableInfo<Accounts, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Accounts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtEpochMillisMeta =
      const VerificationMeta('createdAtEpochMillis');
  late final GeneratedColumn<int> createdAtEpochMillis = GeneratedColumn<int>(
    'createdAtEpochMillis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'syncState',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _gmailExtensionsEnabledMeta =
      const VerificationMeta('gmailExtensionsEnabled');
  late final GeneratedColumn<int> gmailExtensionsEnabled = GeneratedColumn<int>(
    'gmailExtensionsEnabled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastSyncedAtEpochMillisMeta =
      const VerificationMeta('lastSyncedAtEpochMillis');
  late final GeneratedColumn<int> lastSyncedAtEpochMillis =
      GeneratedColumn<int>(
        'lastSyncedAtEpochMillis',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    email,
    createdAtEpochMillis,
    syncState,
    gmailExtensionsEnabled,
    lastSyncedAtEpochMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('createdAtEpochMillis')) {
      context.handle(
        _createdAtEpochMillisMeta,
        createdAtEpochMillis.isAcceptableOrUnknown(
          data['createdAtEpochMillis']!,
          _createdAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMillisMeta);
    }
    if (data.containsKey('syncState')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['syncState']!, _syncStateMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStateMeta);
    }
    if (data.containsKey('gmailExtensionsEnabled')) {
      context.handle(
        _gmailExtensionsEnabledMeta,
        gmailExtensionsEnabled.isAcceptableOrUnknown(
          data['gmailExtensionsEnabled']!,
          _gmailExtensionsEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gmailExtensionsEnabledMeta);
    }
    if (data.containsKey('lastSyncedAtEpochMillis')) {
      context.handle(
        _lastSyncedAtEpochMillisMeta,
        lastSyncedAtEpochMillis.isAcceptableOrUnknown(
          data['lastSyncedAtEpochMillis']!,
          _lastSyncedAtEpochMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      createdAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAtEpochMillis'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}syncState'],
      )!,
      gmailExtensionsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gmailExtensionsEnabled'],
      )!,
      lastSyncedAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastSyncedAtEpochMillis'],
      ),
    );
  }

  @override
  Accounts createAlias(String alias) {
    return Accounts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Account extends DataClass implements Insertable<Account> {
  final String accountId;
  final String email;
  final int createdAtEpochMillis;
  final String syncState;
  final int gmailExtensionsEnabled;
  final int? lastSyncedAtEpochMillis;
  const Account({
    required this.accountId,
    required this.email,
    required this.createdAtEpochMillis,
    required this.syncState,
    required this.gmailExtensionsEnabled,
    this.lastSyncedAtEpochMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['accountId'] = Variable<String>(accountId);
    map['email'] = Variable<String>(email);
    map['createdAtEpochMillis'] = Variable<int>(createdAtEpochMillis);
    map['syncState'] = Variable<String>(syncState);
    map['gmailExtensionsEnabled'] = Variable<int>(gmailExtensionsEnabled);
    if (!nullToAbsent || lastSyncedAtEpochMillis != null) {
      map['lastSyncedAtEpochMillis'] = Variable<int>(lastSyncedAtEpochMillis);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      accountId: Value(accountId),
      email: Value(email),
      createdAtEpochMillis: Value(createdAtEpochMillis),
      syncState: Value(syncState),
      gmailExtensionsEnabled: Value(gmailExtensionsEnabled),
      lastSyncedAtEpochMillis: lastSyncedAtEpochMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAtEpochMillis),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      accountId: serializer.fromJson<String>(json['accountId']),
      email: serializer.fromJson<String>(json['email']),
      createdAtEpochMillis: serializer.fromJson<int>(
        json['createdAtEpochMillis'],
      ),
      syncState: serializer.fromJson<String>(json['syncState']),
      gmailExtensionsEnabled: serializer.fromJson<int>(
        json['gmailExtensionsEnabled'],
      ),
      lastSyncedAtEpochMillis: serializer.fromJson<int?>(
        json['lastSyncedAtEpochMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'email': serializer.toJson<String>(email),
      'createdAtEpochMillis': serializer.toJson<int>(createdAtEpochMillis),
      'syncState': serializer.toJson<String>(syncState),
      'gmailExtensionsEnabled': serializer.toJson<int>(gmailExtensionsEnabled),
      'lastSyncedAtEpochMillis': serializer.toJson<int?>(
        lastSyncedAtEpochMillis,
      ),
    };
  }

  Account copyWith({
    String? accountId,
    String? email,
    int? createdAtEpochMillis,
    String? syncState,
    int? gmailExtensionsEnabled,
    Value<int?> lastSyncedAtEpochMillis = const Value.absent(),
  }) => Account(
    accountId: accountId ?? this.accountId,
    email: email ?? this.email,
    createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
    syncState: syncState ?? this.syncState,
    gmailExtensionsEnabled:
        gmailExtensionsEnabled ?? this.gmailExtensionsEnabled,
    lastSyncedAtEpochMillis: lastSyncedAtEpochMillis.present
        ? lastSyncedAtEpochMillis.value
        : this.lastSyncedAtEpochMillis,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      email: data.email.present ? data.email.value : this.email,
      createdAtEpochMillis: data.createdAtEpochMillis.present
          ? data.createdAtEpochMillis.value
          : this.createdAtEpochMillis,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      gmailExtensionsEnabled: data.gmailExtensionsEnabled.present
          ? data.gmailExtensionsEnabled.value
          : this.gmailExtensionsEnabled,
      lastSyncedAtEpochMillis: data.lastSyncedAtEpochMillis.present
          ? data.lastSyncedAtEpochMillis.value
          : this.lastSyncedAtEpochMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('syncState: $syncState, ')
          ..write('gmailExtensionsEnabled: $gmailExtensionsEnabled, ')
          ..write('lastSyncedAtEpochMillis: $lastSyncedAtEpochMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    email,
    createdAtEpochMillis,
    syncState,
    gmailExtensionsEnabled,
    lastSyncedAtEpochMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.accountId == this.accountId &&
          other.email == this.email &&
          other.createdAtEpochMillis == this.createdAtEpochMillis &&
          other.syncState == this.syncState &&
          other.gmailExtensionsEnabled == this.gmailExtensionsEnabled &&
          other.lastSyncedAtEpochMillis == this.lastSyncedAtEpochMillis);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> accountId;
  final Value<String> email;
  final Value<int> createdAtEpochMillis;
  final Value<String> syncState;
  final Value<int> gmailExtensionsEnabled;
  final Value<int?> lastSyncedAtEpochMillis;
  final Value<int> rowid;
  const AccountsCompanion({
    this.accountId = const Value.absent(),
    this.email = const Value.absent(),
    this.createdAtEpochMillis = const Value.absent(),
    this.syncState = const Value.absent(),
    this.gmailExtensionsEnabled = const Value.absent(),
    this.lastSyncedAtEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String accountId,
    required String email,
    required int createdAtEpochMillis,
    required String syncState,
    required int gmailExtensionsEnabled,
    this.lastSyncedAtEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       email = Value(email),
       createdAtEpochMillis = Value(createdAtEpochMillis),
       syncState = Value(syncState),
       gmailExtensionsEnabled = Value(gmailExtensionsEnabled);
  static Insertable<Account> custom({
    Expression<String>? accountId,
    Expression<String>? email,
    Expression<int>? createdAtEpochMillis,
    Expression<String>? syncState,
    Expression<int>? gmailExtensionsEnabled,
    Expression<int>? lastSyncedAtEpochMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'accountId': accountId,
      if (email != null) 'email': email,
      if (createdAtEpochMillis != null)
        'createdAtEpochMillis': createdAtEpochMillis,
      if (syncState != null) 'syncState': syncState,
      if (gmailExtensionsEnabled != null)
        'gmailExtensionsEnabled': gmailExtensionsEnabled,
      if (lastSyncedAtEpochMillis != null)
        'lastSyncedAtEpochMillis': lastSyncedAtEpochMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? email,
    Value<int>? createdAtEpochMillis,
    Value<String>? syncState,
    Value<int>? gmailExtensionsEnabled,
    Value<int?>? lastSyncedAtEpochMillis,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
      syncState: syncState ?? this.syncState,
      gmailExtensionsEnabled:
          gmailExtensionsEnabled ?? this.gmailExtensionsEnabled,
      lastSyncedAtEpochMillis:
          lastSyncedAtEpochMillis ?? this.lastSyncedAtEpochMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (createdAtEpochMillis.present) {
      map['createdAtEpochMillis'] = Variable<int>(createdAtEpochMillis.value);
    }
    if (syncState.present) {
      map['syncState'] = Variable<String>(syncState.value);
    }
    if (gmailExtensionsEnabled.present) {
      map['gmailExtensionsEnabled'] = Variable<int>(
        gmailExtensionsEnabled.value,
      );
    }
    if (lastSyncedAtEpochMillis.present) {
      map['lastSyncedAtEpochMillis'] = Variable<int>(
        lastSyncedAtEpochMillis.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('syncState: $syncState, ')
          ..write('gmailExtensionsEnabled: $gmailExtensionsEnabled, ')
          ..write('lastSyncedAtEpochMillis: $lastSyncedAtEpochMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Mailboxes extends Table with TableInfo<Mailboxes, Mailboxe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Mailboxes(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mailboxIdMeta = const VerificationMeta(
    'mailboxId',
  );
  late final GeneratedColumn<String> mailboxId = GeneratedColumn<String>(
    'mailboxId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES accounts(accountId)ON DELETE CASCADE',
  );
  static const VerificationMeta _remoteNameMeta = const VerificationMeta(
    'remoteName',
  );
  late final GeneratedColumn<String> remoteName = GeneratedColumn<String>(
    'remoteName',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _uidValidityMeta = const VerificationMeta(
    'uidValidity',
  );
  late final GeneratedColumn<int> uidValidity = GeneratedColumn<int>(
    'uidValidity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _uidNextMeta = const VerificationMeta(
    'uidNext',
  );
  late final GeneratedColumn<int> uidNext = GeneratedColumn<int>(
    'uidNext',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'messageCount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    mailboxId,
    accountId,
    remoteName,
    uidValidity,
    uidNext,
    messageCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mailboxes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mailboxe> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mailboxId')) {
      context.handle(
        _mailboxIdMeta,
        mailboxId.isAcceptableOrUnknown(data['mailboxId']!, _mailboxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mailboxIdMeta);
    }
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('remoteName')) {
      context.handle(
        _remoteNameMeta,
        remoteName.isAcceptableOrUnknown(data['remoteName']!, _remoteNameMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteNameMeta);
    }
    if (data.containsKey('uidValidity')) {
      context.handle(
        _uidValidityMeta,
        uidValidity.isAcceptableOrUnknown(
          data['uidValidity']!,
          _uidValidityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_uidValidityMeta);
    }
    if (data.containsKey('uidNext')) {
      context.handle(
        _uidNextMeta,
        uidNext.isAcceptableOrUnknown(data['uidNext']!, _uidNextMeta),
      );
    } else if (isInserting) {
      context.missing(_uidNextMeta);
    }
    if (data.containsKey('messageCount')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['messageCount']!,
          _messageCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mailboxId};
  @override
  Mailboxe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mailboxe(
      mailboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailboxId'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      remoteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remoteName'],
      )!,
      uidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uidValidity'],
      )!,
      uidNext: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uidNext'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}messageCount'],
      )!,
    );
  }

  @override
  Mailboxes createAlias(String alias) {
    return Mailboxes(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Mailboxe extends DataClass implements Insertable<Mailboxe> {
  final String mailboxId;
  final String accountId;
  final String remoteName;
  final int uidValidity;
  final int uidNext;
  final int messageCount;
  const Mailboxe({
    required this.mailboxId,
    required this.accountId,
    required this.remoteName,
    required this.uidValidity,
    required this.uidNext,
    required this.messageCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mailboxId'] = Variable<String>(mailboxId);
    map['accountId'] = Variable<String>(accountId);
    map['remoteName'] = Variable<String>(remoteName);
    map['uidValidity'] = Variable<int>(uidValidity);
    map['uidNext'] = Variable<int>(uidNext);
    map['messageCount'] = Variable<int>(messageCount);
    return map;
  }

  MailboxesCompanion toCompanion(bool nullToAbsent) {
    return MailboxesCompanion(
      mailboxId: Value(mailboxId),
      accountId: Value(accountId),
      remoteName: Value(remoteName),
      uidValidity: Value(uidValidity),
      uidNext: Value(uidNext),
      messageCount: Value(messageCount),
    );
  }

  factory Mailboxe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mailboxe(
      mailboxId: serializer.fromJson<String>(json['mailboxId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      remoteName: serializer.fromJson<String>(json['remoteName']),
      uidValidity: serializer.fromJson<int>(json['uidValidity']),
      uidNext: serializer.fromJson<int>(json['uidNext']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mailboxId': serializer.toJson<String>(mailboxId),
      'accountId': serializer.toJson<String>(accountId),
      'remoteName': serializer.toJson<String>(remoteName),
      'uidValidity': serializer.toJson<int>(uidValidity),
      'uidNext': serializer.toJson<int>(uidNext),
      'messageCount': serializer.toJson<int>(messageCount),
    };
  }

  Mailboxe copyWith({
    String? mailboxId,
    String? accountId,
    String? remoteName,
    int? uidValidity,
    int? uidNext,
    int? messageCount,
  }) => Mailboxe(
    mailboxId: mailboxId ?? this.mailboxId,
    accountId: accountId ?? this.accountId,
    remoteName: remoteName ?? this.remoteName,
    uidValidity: uidValidity ?? this.uidValidity,
    uidNext: uidNext ?? this.uidNext,
    messageCount: messageCount ?? this.messageCount,
  );
  Mailboxe copyWithCompanion(MailboxesCompanion data) {
    return Mailboxe(
      mailboxId: data.mailboxId.present ? data.mailboxId.value : this.mailboxId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      remoteName: data.remoteName.present
          ? data.remoteName.value
          : this.remoteName,
      uidValidity: data.uidValidity.present
          ? data.uidValidity.value
          : this.uidValidity,
      uidNext: data.uidNext.present ? data.uidNext.value : this.uidNext,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mailboxe(')
          ..write('mailboxId: $mailboxId, ')
          ..write('accountId: $accountId, ')
          ..write('remoteName: $remoteName, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('uidNext: $uidNext, ')
          ..write('messageCount: $messageCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mailboxId,
    accountId,
    remoteName,
    uidValidity,
    uidNext,
    messageCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mailboxe &&
          other.mailboxId == this.mailboxId &&
          other.accountId == this.accountId &&
          other.remoteName == this.remoteName &&
          other.uidValidity == this.uidValidity &&
          other.uidNext == this.uidNext &&
          other.messageCount == this.messageCount);
}

class MailboxesCompanion extends UpdateCompanion<Mailboxe> {
  final Value<String> mailboxId;
  final Value<String> accountId;
  final Value<String> remoteName;
  final Value<int> uidValidity;
  final Value<int> uidNext;
  final Value<int> messageCount;
  final Value<int> rowid;
  const MailboxesCompanion({
    this.mailboxId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.remoteName = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.uidNext = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailboxesCompanion.insert({
    required String mailboxId,
    required String accountId,
    required String remoteName,
    required int uidValidity,
    required int uidNext,
    required int messageCount,
    this.rowid = const Value.absent(),
  }) : mailboxId = Value(mailboxId),
       accountId = Value(accountId),
       remoteName = Value(remoteName),
       uidValidity = Value(uidValidity),
       uidNext = Value(uidNext),
       messageCount = Value(messageCount);
  static Insertable<Mailboxe> custom({
    Expression<String>? mailboxId,
    Expression<String>? accountId,
    Expression<String>? remoteName,
    Expression<int>? uidValidity,
    Expression<int>? uidNext,
    Expression<int>? messageCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mailboxId != null) 'mailboxId': mailboxId,
      if (accountId != null) 'accountId': accountId,
      if (remoteName != null) 'remoteName': remoteName,
      if (uidValidity != null) 'uidValidity': uidValidity,
      if (uidNext != null) 'uidNext': uidNext,
      if (messageCount != null) 'messageCount': messageCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailboxesCompanion copyWith({
    Value<String>? mailboxId,
    Value<String>? accountId,
    Value<String>? remoteName,
    Value<int>? uidValidity,
    Value<int>? uidNext,
    Value<int>? messageCount,
    Value<int>? rowid,
  }) {
    return MailboxesCompanion(
      mailboxId: mailboxId ?? this.mailboxId,
      accountId: accountId ?? this.accountId,
      remoteName: remoteName ?? this.remoteName,
      uidValidity: uidValidity ?? this.uidValidity,
      uidNext: uidNext ?? this.uidNext,
      messageCount: messageCount ?? this.messageCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mailboxId.present) {
      map['mailboxId'] = Variable<String>(mailboxId.value);
    }
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (remoteName.present) {
      map['remoteName'] = Variable<String>(remoteName.value);
    }
    if (uidValidity.present) {
      map['uidValidity'] = Variable<int>(uidValidity.value);
    }
    if (uidNext.present) {
      map['uidNext'] = Variable<int>(uidNext.value);
    }
    if (messageCount.present) {
      map['messageCount'] = Variable<int>(messageCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailboxesCompanion(')
          ..write('mailboxId: $mailboxId, ')
          ..write('accountId: $accountId, ')
          ..write('remoteName: $remoteName, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('uidNext: $uidNext, ')
          ..write('messageCount: $messageCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Messages extends Table with TableInfo<Messages, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Messages(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'messageId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES accounts(accountId)ON DELETE CASCADE',
  );
  static const VerificationMeta _gmailMessageIdMeta = const VerificationMeta(
    'gmailMessageId',
  );
  late final GeneratedColumn<String> gmailMessageId = GeneratedColumn<String>(
    'gmailMessageId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _gmailThreadIdMeta = const VerificationMeta(
    'gmailThreadId',
  );
  late final GeneratedColumn<String> gmailThreadId = GeneratedColumn<String>(
    'gmailThreadId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sentAtEpochMillisMeta = const VerificationMeta(
    'sentAtEpochMillis',
  );
  late final GeneratedColumn<int> sentAtEpochMillis = GeneratedColumn<int>(
    'sentAtEpochMillis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'sizeBytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'PRIMARY\'',
    defaultValue: const CustomExpression('\'PRIMARY\''),
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _contentKindMeta = const VerificationMeta(
    'contentKind',
  );
  late final GeneratedColumn<String> contentKind = GeneratedColumn<String>(
    'contentKind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bodyDownloadStateMeta = const VerificationMeta(
    'bodyDownloadState',
  );
  late final GeneratedColumn<String> bodyDownloadState =
      GeneratedColumn<String>(
        'bodyDownloadState',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _listUnsubscribeMeta = const VerificationMeta(
    'listUnsubscribe',
  );
  late final GeneratedColumn<String> listUnsubscribe = GeneratedColumn<String>(
    'listUnsubscribe',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _listUnsubscribePostMeta =
      const VerificationMeta('listUnsubscribePost');
  late final GeneratedColumn<String> listUnsubscribePost =
      GeneratedColumn<String>(
        'listUnsubscribePost',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    accountId,
    gmailMessageId,
    gmailThreadId,
    subject,
    sender,
    sentAtEpochMillis,
    sizeBytes,
    category,
    preview,
    body,
    contentKind,
    bodyDownloadState,
    listUnsubscribe,
    listUnsubscribePost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('messageId')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['messageId']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('gmailMessageId')) {
      context.handle(
        _gmailMessageIdMeta,
        gmailMessageId.isAcceptableOrUnknown(
          data['gmailMessageId']!,
          _gmailMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('gmailThreadId')) {
      context.handle(
        _gmailThreadIdMeta,
        gmailThreadId.isAcceptableOrUnknown(
          data['gmailThreadId']!,
          _gmailThreadIdMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    }
    if (data.containsKey('sentAtEpochMillis')) {
      context.handle(
        _sentAtEpochMillisMeta,
        sentAtEpochMillis.isAcceptableOrUnknown(
          data['sentAtEpochMillis']!,
          _sentAtEpochMillisMeta,
        ),
      );
    }
    if (data.containsKey('sizeBytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['sizeBytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('contentKind')) {
      context.handle(
        _contentKindMeta,
        contentKind.isAcceptableOrUnknown(
          data['contentKind']!,
          _contentKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentKindMeta);
    }
    if (data.containsKey('bodyDownloadState')) {
      context.handle(
        _bodyDownloadStateMeta,
        bodyDownloadState.isAcceptableOrUnknown(
          data['bodyDownloadState']!,
          _bodyDownloadStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bodyDownloadStateMeta);
    }
    if (data.containsKey('listUnsubscribe')) {
      context.handle(
        _listUnsubscribeMeta,
        listUnsubscribe.isAcceptableOrUnknown(
          data['listUnsubscribe']!,
          _listUnsubscribeMeta,
        ),
      );
    }
    if (data.containsKey('listUnsubscribePost')) {
      context.handle(
        _listUnsubscribePostMeta,
        listUnsubscribePost.isAcceptableOrUnknown(
          data['listUnsubscribePost']!,
          _listUnsubscribePostMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messageId'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      gmailMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gmailMessageId'],
      ),
      gmailThreadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gmailThreadId'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      ),
      sentAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentAtEpochMillis'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sizeBytes'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      contentKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contentKind'],
      )!,
      bodyDownloadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bodyDownloadState'],
      )!,
      listUnsubscribe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}listUnsubscribe'],
      ),
      listUnsubscribePost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}listUnsubscribePost'],
      ),
    );
  }

  @override
  Messages createAlias(String alias) {
    return Messages(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Message extends DataClass implements Insertable<Message> {
  final String messageId;
  final String accountId;
  final String? gmailMessageId;
  final String? gmailThreadId;
  final String? subject;
  final String? sender;
  final int? sentAtEpochMillis;
  final int? sizeBytes;
  final String category;
  final String? preview;
  final String? body;
  final String contentKind;
  final String bodyDownloadState;
  final String? listUnsubscribe;
  final String? listUnsubscribePost;
  const Message({
    required this.messageId,
    required this.accountId,
    this.gmailMessageId,
    this.gmailThreadId,
    this.subject,
    this.sender,
    this.sentAtEpochMillis,
    this.sizeBytes,
    required this.category,
    this.preview,
    this.body,
    required this.contentKind,
    required this.bodyDownloadState,
    this.listUnsubscribe,
    this.listUnsubscribePost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['messageId'] = Variable<String>(messageId);
    map['accountId'] = Variable<String>(accountId);
    if (!nullToAbsent || gmailMessageId != null) {
      map['gmailMessageId'] = Variable<String>(gmailMessageId);
    }
    if (!nullToAbsent || gmailThreadId != null) {
      map['gmailThreadId'] = Variable<String>(gmailThreadId);
    }
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || sentAtEpochMillis != null) {
      map['sentAtEpochMillis'] = Variable<int>(sentAtEpochMillis);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['sizeBytes'] = Variable<int>(sizeBytes);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || preview != null) {
      map['preview'] = Variable<String>(preview);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['contentKind'] = Variable<String>(contentKind);
    map['bodyDownloadState'] = Variable<String>(bodyDownloadState);
    if (!nullToAbsent || listUnsubscribe != null) {
      map['listUnsubscribe'] = Variable<String>(listUnsubscribe);
    }
    if (!nullToAbsent || listUnsubscribePost != null) {
      map['listUnsubscribePost'] = Variable<String>(listUnsubscribePost);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      messageId: Value(messageId),
      accountId: Value(accountId),
      gmailMessageId: gmailMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(gmailMessageId),
      gmailThreadId: gmailThreadId == null && nullToAbsent
          ? const Value.absent()
          : Value(gmailThreadId),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      sender: sender == null && nullToAbsent
          ? const Value.absent()
          : Value(sender),
      sentAtEpochMillis: sentAtEpochMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAtEpochMillis),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      category: Value(category),
      preview: preview == null && nullToAbsent
          ? const Value.absent()
          : Value(preview),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      contentKind: Value(contentKind),
      bodyDownloadState: Value(bodyDownloadState),
      listUnsubscribe: listUnsubscribe == null && nullToAbsent
          ? const Value.absent()
          : Value(listUnsubscribe),
      listUnsubscribePost: listUnsubscribePost == null && nullToAbsent
          ? const Value.absent()
          : Value(listUnsubscribePost),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      messageId: serializer.fromJson<String>(json['messageId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      gmailMessageId: serializer.fromJson<String?>(json['gmailMessageId']),
      gmailThreadId: serializer.fromJson<String?>(json['gmailThreadId']),
      subject: serializer.fromJson<String?>(json['subject']),
      sender: serializer.fromJson<String?>(json['sender']),
      sentAtEpochMillis: serializer.fromJson<int?>(json['sentAtEpochMillis']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      category: serializer.fromJson<String>(json['category']),
      preview: serializer.fromJson<String?>(json['preview']),
      body: serializer.fromJson<String?>(json['body']),
      contentKind: serializer.fromJson<String>(json['contentKind']),
      bodyDownloadState: serializer.fromJson<String>(json['bodyDownloadState']),
      listUnsubscribe: serializer.fromJson<String?>(json['listUnsubscribe']),
      listUnsubscribePost: serializer.fromJson<String?>(
        json['listUnsubscribePost'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'accountId': serializer.toJson<String>(accountId),
      'gmailMessageId': serializer.toJson<String?>(gmailMessageId),
      'gmailThreadId': serializer.toJson<String?>(gmailThreadId),
      'subject': serializer.toJson<String?>(subject),
      'sender': serializer.toJson<String?>(sender),
      'sentAtEpochMillis': serializer.toJson<int?>(sentAtEpochMillis),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'category': serializer.toJson<String>(category),
      'preview': serializer.toJson<String?>(preview),
      'body': serializer.toJson<String?>(body),
      'contentKind': serializer.toJson<String>(contentKind),
      'bodyDownloadState': serializer.toJson<String>(bodyDownloadState),
      'listUnsubscribe': serializer.toJson<String?>(listUnsubscribe),
      'listUnsubscribePost': serializer.toJson<String?>(listUnsubscribePost),
    };
  }

  Message copyWith({
    String? messageId,
    String? accountId,
    Value<String?> gmailMessageId = const Value.absent(),
    Value<String?> gmailThreadId = const Value.absent(),
    Value<String?> subject = const Value.absent(),
    Value<String?> sender = const Value.absent(),
    Value<int?> sentAtEpochMillis = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    String? category,
    Value<String?> preview = const Value.absent(),
    Value<String?> body = const Value.absent(),
    String? contentKind,
    String? bodyDownloadState,
    Value<String?> listUnsubscribe = const Value.absent(),
    Value<String?> listUnsubscribePost = const Value.absent(),
  }) => Message(
    messageId: messageId ?? this.messageId,
    accountId: accountId ?? this.accountId,
    gmailMessageId: gmailMessageId.present
        ? gmailMessageId.value
        : this.gmailMessageId,
    gmailThreadId: gmailThreadId.present
        ? gmailThreadId.value
        : this.gmailThreadId,
    subject: subject.present ? subject.value : this.subject,
    sender: sender.present ? sender.value : this.sender,
    sentAtEpochMillis: sentAtEpochMillis.present
        ? sentAtEpochMillis.value
        : this.sentAtEpochMillis,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    category: category ?? this.category,
    preview: preview.present ? preview.value : this.preview,
    body: body.present ? body.value : this.body,
    contentKind: contentKind ?? this.contentKind,
    bodyDownloadState: bodyDownloadState ?? this.bodyDownloadState,
    listUnsubscribe: listUnsubscribe.present
        ? listUnsubscribe.value
        : this.listUnsubscribe,
    listUnsubscribePost: listUnsubscribePost.present
        ? listUnsubscribePost.value
        : this.listUnsubscribePost,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      gmailMessageId: data.gmailMessageId.present
          ? data.gmailMessageId.value
          : this.gmailMessageId,
      gmailThreadId: data.gmailThreadId.present
          ? data.gmailThreadId.value
          : this.gmailThreadId,
      subject: data.subject.present ? data.subject.value : this.subject,
      sender: data.sender.present ? data.sender.value : this.sender,
      sentAtEpochMillis: data.sentAtEpochMillis.present
          ? data.sentAtEpochMillis.value
          : this.sentAtEpochMillis,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      category: data.category.present ? data.category.value : this.category,
      preview: data.preview.present ? data.preview.value : this.preview,
      body: data.body.present ? data.body.value : this.body,
      contentKind: data.contentKind.present
          ? data.contentKind.value
          : this.contentKind,
      bodyDownloadState: data.bodyDownloadState.present
          ? data.bodyDownloadState.value
          : this.bodyDownloadState,
      listUnsubscribe: data.listUnsubscribe.present
          ? data.listUnsubscribe.value
          : this.listUnsubscribe,
      listUnsubscribePost: data.listUnsubscribePost.present
          ? data.listUnsubscribePost.value
          : this.listUnsubscribePost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('messageId: $messageId, ')
          ..write('accountId: $accountId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('gmailThreadId: $gmailThreadId, ')
          ..write('subject: $subject, ')
          ..write('sender: $sender, ')
          ..write('sentAtEpochMillis: $sentAtEpochMillis, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('category: $category, ')
          ..write('preview: $preview, ')
          ..write('body: $body, ')
          ..write('contentKind: $contentKind, ')
          ..write('bodyDownloadState: $bodyDownloadState, ')
          ..write('listUnsubscribe: $listUnsubscribe, ')
          ..write('listUnsubscribePost: $listUnsubscribePost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    accountId,
    gmailMessageId,
    gmailThreadId,
    subject,
    sender,
    sentAtEpochMillis,
    sizeBytes,
    category,
    preview,
    body,
    contentKind,
    bodyDownloadState,
    listUnsubscribe,
    listUnsubscribePost,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.messageId == this.messageId &&
          other.accountId == this.accountId &&
          other.gmailMessageId == this.gmailMessageId &&
          other.gmailThreadId == this.gmailThreadId &&
          other.subject == this.subject &&
          other.sender == this.sender &&
          other.sentAtEpochMillis == this.sentAtEpochMillis &&
          other.sizeBytes == this.sizeBytes &&
          other.category == this.category &&
          other.preview == this.preview &&
          other.body == this.body &&
          other.contentKind == this.contentKind &&
          other.bodyDownloadState == this.bodyDownloadState &&
          other.listUnsubscribe == this.listUnsubscribe &&
          other.listUnsubscribePost == this.listUnsubscribePost);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> messageId;
  final Value<String> accountId;
  final Value<String?> gmailMessageId;
  final Value<String?> gmailThreadId;
  final Value<String?> subject;
  final Value<String?> sender;
  final Value<int?> sentAtEpochMillis;
  final Value<int?> sizeBytes;
  final Value<String> category;
  final Value<String?> preview;
  final Value<String?> body;
  final Value<String> contentKind;
  final Value<String> bodyDownloadState;
  final Value<String?> listUnsubscribe;
  final Value<String?> listUnsubscribePost;
  final Value<int> rowid;
  const MessagesCompanion({
    this.messageId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.gmailMessageId = const Value.absent(),
    this.gmailThreadId = const Value.absent(),
    this.subject = const Value.absent(),
    this.sender = const Value.absent(),
    this.sentAtEpochMillis = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.category = const Value.absent(),
    this.preview = const Value.absent(),
    this.body = const Value.absent(),
    this.contentKind = const Value.absent(),
    this.bodyDownloadState = const Value.absent(),
    this.listUnsubscribe = const Value.absent(),
    this.listUnsubscribePost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String messageId,
    required String accountId,
    this.gmailMessageId = const Value.absent(),
    this.gmailThreadId = const Value.absent(),
    this.subject = const Value.absent(),
    this.sender = const Value.absent(),
    this.sentAtEpochMillis = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.category = const Value.absent(),
    this.preview = const Value.absent(),
    this.body = const Value.absent(),
    required String contentKind,
    required String bodyDownloadState,
    this.listUnsubscribe = const Value.absent(),
    this.listUnsubscribePost = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       accountId = Value(accountId),
       contentKind = Value(contentKind),
       bodyDownloadState = Value(bodyDownloadState);
  static Insertable<Message> custom({
    Expression<String>? messageId,
    Expression<String>? accountId,
    Expression<String>? gmailMessageId,
    Expression<String>? gmailThreadId,
    Expression<String>? subject,
    Expression<String>? sender,
    Expression<int>? sentAtEpochMillis,
    Expression<int>? sizeBytes,
    Expression<String>? category,
    Expression<String>? preview,
    Expression<String>? body,
    Expression<String>? contentKind,
    Expression<String>? bodyDownloadState,
    Expression<String>? listUnsubscribe,
    Expression<String>? listUnsubscribePost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'messageId': messageId,
      if (accountId != null) 'accountId': accountId,
      if (gmailMessageId != null) 'gmailMessageId': gmailMessageId,
      if (gmailThreadId != null) 'gmailThreadId': gmailThreadId,
      if (subject != null) 'subject': subject,
      if (sender != null) 'sender': sender,
      if (sentAtEpochMillis != null) 'sentAtEpochMillis': sentAtEpochMillis,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (category != null) 'category': category,
      if (preview != null) 'preview': preview,
      if (body != null) 'body': body,
      if (contentKind != null) 'contentKind': contentKind,
      if (bodyDownloadState != null) 'bodyDownloadState': bodyDownloadState,
      if (listUnsubscribe != null) 'listUnsubscribe': listUnsubscribe,
      if (listUnsubscribePost != null)
        'listUnsubscribePost': listUnsubscribePost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? accountId,
    Value<String?>? gmailMessageId,
    Value<String?>? gmailThreadId,
    Value<String?>? subject,
    Value<String?>? sender,
    Value<int?>? sentAtEpochMillis,
    Value<int?>? sizeBytes,
    Value<String>? category,
    Value<String?>? preview,
    Value<String?>? body,
    Value<String>? contentKind,
    Value<String>? bodyDownloadState,
    Value<String?>? listUnsubscribe,
    Value<String?>? listUnsubscribePost,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      messageId: messageId ?? this.messageId,
      accountId: accountId ?? this.accountId,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      gmailThreadId: gmailThreadId ?? this.gmailThreadId,
      subject: subject ?? this.subject,
      sender: sender ?? this.sender,
      sentAtEpochMillis: sentAtEpochMillis ?? this.sentAtEpochMillis,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      category: category ?? this.category,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      contentKind: contentKind ?? this.contentKind,
      bodyDownloadState: bodyDownloadState ?? this.bodyDownloadState,
      listUnsubscribe: listUnsubscribe ?? this.listUnsubscribe,
      listUnsubscribePost: listUnsubscribePost ?? this.listUnsubscribePost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['messageId'] = Variable<String>(messageId.value);
    }
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (gmailMessageId.present) {
      map['gmailMessageId'] = Variable<String>(gmailMessageId.value);
    }
    if (gmailThreadId.present) {
      map['gmailThreadId'] = Variable<String>(gmailThreadId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (sentAtEpochMillis.present) {
      map['sentAtEpochMillis'] = Variable<int>(sentAtEpochMillis.value);
    }
    if (sizeBytes.present) {
      map['sizeBytes'] = Variable<int>(sizeBytes.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (contentKind.present) {
      map['contentKind'] = Variable<String>(contentKind.value);
    }
    if (bodyDownloadState.present) {
      map['bodyDownloadState'] = Variable<String>(bodyDownloadState.value);
    }
    if (listUnsubscribe.present) {
      map['listUnsubscribe'] = Variable<String>(listUnsubscribe.value);
    }
    if (listUnsubscribePost.present) {
      map['listUnsubscribePost'] = Variable<String>(listUnsubscribePost.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('accountId: $accountId, ')
          ..write('gmailMessageId: $gmailMessageId, ')
          ..write('gmailThreadId: $gmailThreadId, ')
          ..write('subject: $subject, ')
          ..write('sender: $sender, ')
          ..write('sentAtEpochMillis: $sentAtEpochMillis, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('category: $category, ')
          ..write('preview: $preview, ')
          ..write('body: $body, ')
          ..write('contentKind: $contentKind, ')
          ..write('bodyDownloadState: $bodyDownloadState, ')
          ..write('listUnsubscribe: $listUnsubscribe, ')
          ..write('listUnsubscribePost: $listUnsubscribePost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MailboxMessages extends Table
    with TableInfo<MailboxMessages, MailboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MailboxMessages(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mailboxIdMeta = const VerificationMeta(
    'mailboxId',
  );
  late final GeneratedColumn<String> mailboxId = GeneratedColumn<String>(
    'mailboxId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES mailboxes(mailboxId)ON DELETE CASCADE',
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  late final GeneratedColumn<int> uid = GeneratedColumn<int>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'messageId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES messages(messageId)ON DELETE CASCADE',
  );
  static const VerificationMeta _flagsMeta = const VerificationMeta('flags');
  late final GeneratedColumn<String> flags = GeneratedColumn<String>(
    'flags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _labelsMeta = const VerificationMeta('labels');
  late final GeneratedColumn<String> labels = GeneratedColumn<String>(
    'labels',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    mailboxId,
    uid,
    messageId,
    flags,
    labels,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mailbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MailboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mailboxId')) {
      context.handle(
        _mailboxIdMeta,
        mailboxId.isAcceptableOrUnknown(data['mailboxId']!, _mailboxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mailboxIdMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('messageId')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['messageId']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('flags')) {
      context.handle(
        _flagsMeta,
        flags.isAcceptableOrUnknown(data['flags']!, _flagsMeta),
      );
    } else if (isInserting) {
      context.missing(_flagsMeta);
    }
    if (data.containsKey('labels')) {
      context.handle(
        _labelsMeta,
        labels.isAcceptableOrUnknown(data['labels']!, _labelsMeta),
      );
    } else if (isInserting) {
      context.missing(_labelsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mailboxId, uid};
  @override
  MailboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MailboxMessage(
      mailboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailboxId'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messageId'],
      )!,
      flags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flags'],
      )!,
      labels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}labels'],
      )!,
    );
  }

  @override
  MailboxMessages createAlias(String alias) {
    return MailboxMessages(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(mailboxId, uid)'];
  @override
  bool get dontWriteConstraints => true;
}

class MailboxMessage extends DataClass implements Insertable<MailboxMessage> {
  final String mailboxId;
  final int uid;
  final String messageId;
  final String flags;
  final String labels;
  const MailboxMessage({
    required this.mailboxId,
    required this.uid,
    required this.messageId,
    required this.flags,
    required this.labels,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mailboxId'] = Variable<String>(mailboxId);
    map['uid'] = Variable<int>(uid);
    map['messageId'] = Variable<String>(messageId);
    map['flags'] = Variable<String>(flags);
    map['labels'] = Variable<String>(labels);
    return map;
  }

  MailboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return MailboxMessagesCompanion(
      mailboxId: Value(mailboxId),
      uid: Value(uid),
      messageId: Value(messageId),
      flags: Value(flags),
      labels: Value(labels),
    );
  }

  factory MailboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MailboxMessage(
      mailboxId: serializer.fromJson<String>(json['mailboxId']),
      uid: serializer.fromJson<int>(json['uid']),
      messageId: serializer.fromJson<String>(json['messageId']),
      flags: serializer.fromJson<String>(json['flags']),
      labels: serializer.fromJson<String>(json['labels']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mailboxId': serializer.toJson<String>(mailboxId),
      'uid': serializer.toJson<int>(uid),
      'messageId': serializer.toJson<String>(messageId),
      'flags': serializer.toJson<String>(flags),
      'labels': serializer.toJson<String>(labels),
    };
  }

  MailboxMessage copyWith({
    String? mailboxId,
    int? uid,
    String? messageId,
    String? flags,
    String? labels,
  }) => MailboxMessage(
    mailboxId: mailboxId ?? this.mailboxId,
    uid: uid ?? this.uid,
    messageId: messageId ?? this.messageId,
    flags: flags ?? this.flags,
    labels: labels ?? this.labels,
  );
  MailboxMessage copyWithCompanion(MailboxMessagesCompanion data) {
    return MailboxMessage(
      mailboxId: data.mailboxId.present ? data.mailboxId.value : this.mailboxId,
      uid: data.uid.present ? data.uid.value : this.uid,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      flags: data.flags.present ? data.flags.value : this.flags,
      labels: data.labels.present ? data.labels.value : this.labels,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MailboxMessage(')
          ..write('mailboxId: $mailboxId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('flags: $flags, ')
          ..write('labels: $labels')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mailboxId, uid, messageId, flags, labels);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MailboxMessage &&
          other.mailboxId == this.mailboxId &&
          other.uid == this.uid &&
          other.messageId == this.messageId &&
          other.flags == this.flags &&
          other.labels == this.labels);
}

class MailboxMessagesCompanion extends UpdateCompanion<MailboxMessage> {
  final Value<String> mailboxId;
  final Value<int> uid;
  final Value<String> messageId;
  final Value<String> flags;
  final Value<String> labels;
  final Value<int> rowid;
  const MailboxMessagesCompanion({
    this.mailboxId = const Value.absent(),
    this.uid = const Value.absent(),
    this.messageId = const Value.absent(),
    this.flags = const Value.absent(),
    this.labels = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MailboxMessagesCompanion.insert({
    required String mailboxId,
    required int uid,
    required String messageId,
    required String flags,
    required String labels,
    this.rowid = const Value.absent(),
  }) : mailboxId = Value(mailboxId),
       uid = Value(uid),
       messageId = Value(messageId),
       flags = Value(flags),
       labels = Value(labels);
  static Insertable<MailboxMessage> custom({
    Expression<String>? mailboxId,
    Expression<int>? uid,
    Expression<String>? messageId,
    Expression<String>? flags,
    Expression<String>? labels,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mailboxId != null) 'mailboxId': mailboxId,
      if (uid != null) 'uid': uid,
      if (messageId != null) 'messageId': messageId,
      if (flags != null) 'flags': flags,
      if (labels != null) 'labels': labels,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MailboxMessagesCompanion copyWith({
    Value<String>? mailboxId,
    Value<int>? uid,
    Value<String>? messageId,
    Value<String>? flags,
    Value<String>? labels,
    Value<int>? rowid,
  }) {
    return MailboxMessagesCompanion(
      mailboxId: mailboxId ?? this.mailboxId,
      uid: uid ?? this.uid,
      messageId: messageId ?? this.messageId,
      flags: flags ?? this.flags,
      labels: labels ?? this.labels,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mailboxId.present) {
      map['mailboxId'] = Variable<String>(mailboxId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<int>(uid.value);
    }
    if (messageId.present) {
      map['messageId'] = Variable<String>(messageId.value);
    }
    if (flags.present) {
      map['flags'] = Variable<String>(flags.value);
    }
    if (labels.present) {
      map['labels'] = Variable<String>(labels.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MailboxMessagesCompanion(')
          ..write('mailboxId: $mailboxId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('flags: $flags, ')
          ..write('labels: $labels, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MessageLabels extends Table with TableInfo<MessageLabels, MessageLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MessageLabels(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'messageId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES messages(messageId)ON DELETE CASCADE',
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('messageId')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['messageId']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, label};
  @override
  MessageLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageLabel(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messageId'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  MessageLabels createAlias(String alias) {
    return MessageLabels(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(messageId, label)'];
  @override
  bool get dontWriteConstraints => true;
}

class MessageLabel extends DataClass implements Insertable<MessageLabel> {
  final String messageId;
  final String label;
  const MessageLabel({required this.messageId, required this.label});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['messageId'] = Variable<String>(messageId);
    map['label'] = Variable<String>(label);
    return map;
  }

  MessageLabelsCompanion toCompanion(bool nullToAbsent) {
    return MessageLabelsCompanion(
      messageId: Value(messageId),
      label: Value(label),
    );
  }

  factory MessageLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageLabel(
      messageId: serializer.fromJson<String>(json['messageId']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'label': serializer.toJson<String>(label),
    };
  }

  MessageLabel copyWith({String? messageId, String? label}) => MessageLabel(
    messageId: messageId ?? this.messageId,
    label: label ?? this.label,
  );
  MessageLabel copyWithCompanion(MessageLabelsCompanion data) {
    return MessageLabel(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageLabel(')
          ..write('messageId: $messageId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageLabel &&
          other.messageId == this.messageId &&
          other.label == this.label);
}

class MessageLabelsCompanion extends UpdateCompanion<MessageLabel> {
  final Value<String> messageId;
  final Value<String> label;
  final Value<int> rowid;
  const MessageLabelsCompanion({
    this.messageId = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageLabelsCompanion.insert({
    required String messageId,
    required String label,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       label = Value(label);
  static Insertable<MessageLabel> custom({
    Expression<String>? messageId,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'messageId': messageId,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageLabelsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? label,
    Value<int>? rowid,
  }) {
    return MessageLabelsCompanion(
      messageId: messageId ?? this.messageId,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['messageId'] = Variable<String>(messageId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageLabelsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Attachments extends Table with TableInfo<Attachments, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Attachments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachmentId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'messageId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES messages(messageId)ON DELETE CASCADE',
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'partId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'fileName',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mimeType',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'sizeBytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _downloadStateMeta = const VerificationMeta(
    'downloadState',
  );
  late final GeneratedColumn<String> downloadState = GeneratedColumn<String>(
    'downloadState',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastAccessedAtEpochMillisMeta =
      const VerificationMeta('lastAccessedAtEpochMillis');
  late final GeneratedColumn<int> lastAccessedAtEpochMillis =
      GeneratedColumn<int>(
        'lastAccessedAtEpochMillis',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 0',
        defaultValue: const CustomExpression('0'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    attachmentId,
    messageId,
    partId,
    fileName,
    mimeType,
    sizeBytes,
    downloadState,
    lastAccessedAtEpochMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attachmentId')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachmentId']!,
          _attachmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentIdMeta);
    }
    if (data.containsKey('messageId')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['messageId']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('partId')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['partId']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('fileName')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['fileName']!, _fileNameMeta),
      );
    }
    if (data.containsKey('mimeType')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mimeType']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('sizeBytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['sizeBytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('downloadState')) {
      context.handle(
        _downloadStateMeta,
        downloadState.isAcceptableOrUnknown(
          data['downloadState']!,
          _downloadStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadStateMeta);
    }
    if (data.containsKey('lastAccessedAtEpochMillis')) {
      context.handle(
        _lastAccessedAtEpochMillisMeta,
        lastAccessedAtEpochMillis.isAcceptableOrUnknown(
          data['lastAccessedAtEpochMillis']!,
          _lastAccessedAtEpochMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attachmentId};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachmentId'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messageId'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partId'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fileName'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mimeType'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sizeBytes'],
      ),
      downloadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}downloadState'],
      )!,
      lastAccessedAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastAccessedAtEpochMillis'],
      )!,
    );
  }

  @override
  Attachments createAlias(String alias) {
    return Attachments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String attachmentId;
  final String messageId;
  final String partId;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String downloadState;
  final int lastAccessedAtEpochMillis;
  const Attachment({
    required this.attachmentId,
    required this.messageId,
    required this.partId,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    required this.downloadState,
    required this.lastAccessedAtEpochMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attachmentId'] = Variable<String>(attachmentId);
    map['messageId'] = Variable<String>(messageId);
    map['partId'] = Variable<String>(partId);
    if (!nullToAbsent || fileName != null) {
      map['fileName'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mimeType'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['sizeBytes'] = Variable<int>(sizeBytes);
    }
    map['downloadState'] = Variable<String>(downloadState);
    map['lastAccessedAtEpochMillis'] = Variable<int>(lastAccessedAtEpochMillis);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      attachmentId: Value(attachmentId),
      messageId: Value(messageId),
      partId: Value(partId),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      downloadState: Value(downloadState),
      lastAccessedAtEpochMillis: Value(lastAccessedAtEpochMillis),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      attachmentId: serializer.fromJson<String>(json['attachmentId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      partId: serializer.fromJson<String>(json['partId']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      downloadState: serializer.fromJson<String>(json['downloadState']),
      lastAccessedAtEpochMillis: serializer.fromJson<int>(
        json['lastAccessedAtEpochMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attachmentId': serializer.toJson<String>(attachmentId),
      'messageId': serializer.toJson<String>(messageId),
      'partId': serializer.toJson<String>(partId),
      'fileName': serializer.toJson<String?>(fileName),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'downloadState': serializer.toJson<String>(downloadState),
      'lastAccessedAtEpochMillis': serializer.toJson<int>(
        lastAccessedAtEpochMillis,
      ),
    };
  }

  Attachment copyWith({
    String? attachmentId,
    String? messageId,
    String? partId,
    Value<String?> fileName = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    String? downloadState,
    int? lastAccessedAtEpochMillis,
  }) => Attachment(
    attachmentId: attachmentId ?? this.attachmentId,
    messageId: messageId ?? this.messageId,
    partId: partId ?? this.partId,
    fileName: fileName.present ? fileName.value : this.fileName,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    downloadState: downloadState ?? this.downloadState,
    lastAccessedAtEpochMillis:
        lastAccessedAtEpochMillis ?? this.lastAccessedAtEpochMillis,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      partId: data.partId.present ? data.partId.value : this.partId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      downloadState: data.downloadState.present
          ? data.downloadState.value
          : this.downloadState,
      lastAccessedAtEpochMillis: data.lastAccessedAtEpochMillis.present
          ? data.lastAccessedAtEpochMillis.value
          : this.lastAccessedAtEpochMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('attachmentId: $attachmentId, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadState: $downloadState, ')
          ..write('lastAccessedAtEpochMillis: $lastAccessedAtEpochMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    attachmentId,
    messageId,
    partId,
    fileName,
    mimeType,
    sizeBytes,
    downloadState,
    lastAccessedAtEpochMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.attachmentId == this.attachmentId &&
          other.messageId == this.messageId &&
          other.partId == this.partId &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.downloadState == this.downloadState &&
          other.lastAccessedAtEpochMillis == this.lastAccessedAtEpochMillis);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> attachmentId;
  final Value<String> messageId;
  final Value<String> partId;
  final Value<String?> fileName;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<String> downloadState;
  final Value<int> lastAccessedAtEpochMillis;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.attachmentId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.partId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadState = const Value.absent(),
    this.lastAccessedAtEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String attachmentId,
    required String messageId,
    required String partId,
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    required String downloadState,
    this.lastAccessedAtEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : attachmentId = Value(attachmentId),
       messageId = Value(messageId),
       partId = Value(partId),
       downloadState = Value(downloadState);
  static Insertable<Attachment> custom({
    Expression<String>? attachmentId,
    Expression<String>? messageId,
    Expression<String>? partId,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? downloadState,
    Expression<int>? lastAccessedAtEpochMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attachmentId != null) 'attachmentId': attachmentId,
      if (messageId != null) 'messageId': messageId,
      if (partId != null) 'partId': partId,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (downloadState != null) 'downloadState': downloadState,
      if (lastAccessedAtEpochMillis != null)
        'lastAccessedAtEpochMillis': lastAccessedAtEpochMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? attachmentId,
    Value<String>? messageId,
    Value<String>? partId,
    Value<String?>? fileName,
    Value<String?>? mimeType,
    Value<int?>? sizeBytes,
    Value<String>? downloadState,
    Value<int>? lastAccessedAtEpochMillis,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      attachmentId: attachmentId ?? this.attachmentId,
      messageId: messageId ?? this.messageId,
      partId: partId ?? this.partId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadState: downloadState ?? this.downloadState,
      lastAccessedAtEpochMillis:
          lastAccessedAtEpochMillis ?? this.lastAccessedAtEpochMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attachmentId.present) {
      map['attachmentId'] = Variable<String>(attachmentId.value);
    }
    if (messageId.present) {
      map['messageId'] = Variable<String>(messageId.value);
    }
    if (partId.present) {
      map['partId'] = Variable<String>(partId.value);
    }
    if (fileName.present) {
      map['fileName'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mimeType'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['sizeBytes'] = Variable<int>(sizeBytes.value);
    }
    if (downloadState.present) {
      map['downloadState'] = Variable<String>(downloadState.value);
    }
    if (lastAccessedAtEpochMillis.present) {
      map['lastAccessedAtEpochMillis'] = Variable<int>(
        lastAccessedAtEpochMillis.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('attachmentId: $attachmentId, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadState: $downloadState, ')
          ..write('lastAccessedAtEpochMillis: $lastAccessedAtEpochMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class CacheConfig extends Table with TableInfo<CacheConfig, CacheConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  CacheConfig(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _offlineMessageCountMeta =
      const VerificationMeta('offlineMessageCount');
  late final GeneratedColumn<int> offlineMessageCount = GeneratedColumn<int>(
    'offlineMessageCount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 200',
    defaultValue: const CustomExpression('200'),
  );
  static const VerificationMeta _attachmentCacheLimitMbMeta =
      const VerificationMeta('attachmentCacheLimitMb');
  late final GeneratedColumn<int> attachmentCacheLimitMb = GeneratedColumn<int>(
    'attachmentCacheLimitMb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 500',
    defaultValue: const CustomExpression('500'),
  );
  static const VerificationMeta _autoEvictReadOlderThanDaysMeta =
      const VerificationMeta('autoEvictReadOlderThanDays');
  late final GeneratedColumn<int> autoEvictReadOlderThanDays =
      GeneratedColumn<int>(
        'autoEvictReadOlderThanDays',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT 60',
        defaultValue: const CustomExpression('60'),
      );
  static const VerificationMeta _prefetchUnreadBodiesMeta =
      const VerificationMeta('prefetchUnreadBodies');
  late final GeneratedColumn<int> prefetchUnreadBodies = GeneratedColumn<int>(
    'prefetchUnreadBodies',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1',
    defaultValue: const CustomExpression('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    offlineMessageCount,
    attachmentCacheLimitMb,
    autoEvictReadOlderThanDays,
    prefetchUnreadBodies,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('offlineMessageCount')) {
      context.handle(
        _offlineMessageCountMeta,
        offlineMessageCount.isAcceptableOrUnknown(
          data['offlineMessageCount']!,
          _offlineMessageCountMeta,
        ),
      );
    }
    if (data.containsKey('attachmentCacheLimitMb')) {
      context.handle(
        _attachmentCacheLimitMbMeta,
        attachmentCacheLimitMb.isAcceptableOrUnknown(
          data['attachmentCacheLimitMb']!,
          _attachmentCacheLimitMbMeta,
        ),
      );
    }
    if (data.containsKey('autoEvictReadOlderThanDays')) {
      context.handle(
        _autoEvictReadOlderThanDaysMeta,
        autoEvictReadOlderThanDays.isAcceptableOrUnknown(
          data['autoEvictReadOlderThanDays']!,
          _autoEvictReadOlderThanDaysMeta,
        ),
      );
    }
    if (data.containsKey('prefetchUnreadBodies')) {
      context.handle(
        _prefetchUnreadBodiesMeta,
        prefetchUnreadBodies.isAcceptableOrUnknown(
          data['prefetchUnreadBodies']!,
          _prefetchUnreadBodiesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  CacheConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheConfigData(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      offlineMessageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offlineMessageCount'],
      )!,
      attachmentCacheLimitMb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attachmentCacheLimitMb'],
      )!,
      autoEvictReadOlderThanDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}autoEvictReadOlderThanDays'],
      )!,
      prefetchUnreadBodies: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prefetchUnreadBodies'],
      )!,
    );
  }

  @override
  CacheConfig createAlias(String alias) {
    return CacheConfig(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CacheConfigData extends DataClass implements Insertable<CacheConfigData> {
  final String accountId;
  final int offlineMessageCount;
  final int attachmentCacheLimitMb;
  final int autoEvictReadOlderThanDays;
  final int prefetchUnreadBodies;
  const CacheConfigData({
    required this.accountId,
    required this.offlineMessageCount,
    required this.attachmentCacheLimitMb,
    required this.autoEvictReadOlderThanDays,
    required this.prefetchUnreadBodies,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['accountId'] = Variable<String>(accountId);
    map['offlineMessageCount'] = Variable<int>(offlineMessageCount);
    map['attachmentCacheLimitMb'] = Variable<int>(attachmentCacheLimitMb);
    map['autoEvictReadOlderThanDays'] = Variable<int>(
      autoEvictReadOlderThanDays,
    );
    map['prefetchUnreadBodies'] = Variable<int>(prefetchUnreadBodies);
    return map;
  }

  CacheConfigCompanion toCompanion(bool nullToAbsent) {
    return CacheConfigCompanion(
      accountId: Value(accountId),
      offlineMessageCount: Value(offlineMessageCount),
      attachmentCacheLimitMb: Value(attachmentCacheLimitMb),
      autoEvictReadOlderThanDays: Value(autoEvictReadOlderThanDays),
      prefetchUnreadBodies: Value(prefetchUnreadBodies),
    );
  }

  factory CacheConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheConfigData(
      accountId: serializer.fromJson<String>(json['accountId']),
      offlineMessageCount: serializer.fromJson<int>(
        json['offlineMessageCount'],
      ),
      attachmentCacheLimitMb: serializer.fromJson<int>(
        json['attachmentCacheLimitMb'],
      ),
      autoEvictReadOlderThanDays: serializer.fromJson<int>(
        json['autoEvictReadOlderThanDays'],
      ),
      prefetchUnreadBodies: serializer.fromJson<int>(
        json['prefetchUnreadBodies'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'offlineMessageCount': serializer.toJson<int>(offlineMessageCount),
      'attachmentCacheLimitMb': serializer.toJson<int>(attachmentCacheLimitMb),
      'autoEvictReadOlderThanDays': serializer.toJson<int>(
        autoEvictReadOlderThanDays,
      ),
      'prefetchUnreadBodies': serializer.toJson<int>(prefetchUnreadBodies),
    };
  }

  CacheConfigData copyWith({
    String? accountId,
    int? offlineMessageCount,
    int? attachmentCacheLimitMb,
    int? autoEvictReadOlderThanDays,
    int? prefetchUnreadBodies,
  }) => CacheConfigData(
    accountId: accountId ?? this.accountId,
    offlineMessageCount: offlineMessageCount ?? this.offlineMessageCount,
    attachmentCacheLimitMb:
        attachmentCacheLimitMb ?? this.attachmentCacheLimitMb,
    autoEvictReadOlderThanDays:
        autoEvictReadOlderThanDays ?? this.autoEvictReadOlderThanDays,
    prefetchUnreadBodies: prefetchUnreadBodies ?? this.prefetchUnreadBodies,
  );
  CacheConfigData copyWithCompanion(CacheConfigCompanion data) {
    return CacheConfigData(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      offlineMessageCount: data.offlineMessageCount.present
          ? data.offlineMessageCount.value
          : this.offlineMessageCount,
      attachmentCacheLimitMb: data.attachmentCacheLimitMb.present
          ? data.attachmentCacheLimitMb.value
          : this.attachmentCacheLimitMb,
      autoEvictReadOlderThanDays: data.autoEvictReadOlderThanDays.present
          ? data.autoEvictReadOlderThanDays.value
          : this.autoEvictReadOlderThanDays,
      prefetchUnreadBodies: data.prefetchUnreadBodies.present
          ? data.prefetchUnreadBodies.value
          : this.prefetchUnreadBodies,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheConfigData(')
          ..write('accountId: $accountId, ')
          ..write('offlineMessageCount: $offlineMessageCount, ')
          ..write('attachmentCacheLimitMb: $attachmentCacheLimitMb, ')
          ..write('autoEvictReadOlderThanDays: $autoEvictReadOlderThanDays, ')
          ..write('prefetchUnreadBodies: $prefetchUnreadBodies')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    offlineMessageCount,
    attachmentCacheLimitMb,
    autoEvictReadOlderThanDays,
    prefetchUnreadBodies,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheConfigData &&
          other.accountId == this.accountId &&
          other.offlineMessageCount == this.offlineMessageCount &&
          other.attachmentCacheLimitMb == this.attachmentCacheLimitMb &&
          other.autoEvictReadOlderThanDays == this.autoEvictReadOlderThanDays &&
          other.prefetchUnreadBodies == this.prefetchUnreadBodies);
}

class CacheConfigCompanion extends UpdateCompanion<CacheConfigData> {
  final Value<String> accountId;
  final Value<int> offlineMessageCount;
  final Value<int> attachmentCacheLimitMb;
  final Value<int> autoEvictReadOlderThanDays;
  final Value<int> prefetchUnreadBodies;
  final Value<int> rowid;
  const CacheConfigCompanion({
    this.accountId = const Value.absent(),
    this.offlineMessageCount = const Value.absent(),
    this.attachmentCacheLimitMb = const Value.absent(),
    this.autoEvictReadOlderThanDays = const Value.absent(),
    this.prefetchUnreadBodies = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheConfigCompanion.insert({
    required String accountId,
    this.offlineMessageCount = const Value.absent(),
    this.attachmentCacheLimitMb = const Value.absent(),
    this.autoEvictReadOlderThanDays = const Value.absent(),
    this.prefetchUnreadBodies = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<CacheConfigData> custom({
    Expression<String>? accountId,
    Expression<int>? offlineMessageCount,
    Expression<int>? attachmentCacheLimitMb,
    Expression<int>? autoEvictReadOlderThanDays,
    Expression<int>? prefetchUnreadBodies,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'accountId': accountId,
      if (offlineMessageCount != null)
        'offlineMessageCount': offlineMessageCount,
      if (attachmentCacheLimitMb != null)
        'attachmentCacheLimitMb': attachmentCacheLimitMb,
      if (autoEvictReadOlderThanDays != null)
        'autoEvictReadOlderThanDays': autoEvictReadOlderThanDays,
      if (prefetchUnreadBodies != null)
        'prefetchUnreadBodies': prefetchUnreadBodies,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheConfigCompanion copyWith({
    Value<String>? accountId,
    Value<int>? offlineMessageCount,
    Value<int>? attachmentCacheLimitMb,
    Value<int>? autoEvictReadOlderThanDays,
    Value<int>? prefetchUnreadBodies,
    Value<int>? rowid,
  }) {
    return CacheConfigCompanion(
      accountId: accountId ?? this.accountId,
      offlineMessageCount: offlineMessageCount ?? this.offlineMessageCount,
      attachmentCacheLimitMb:
          attachmentCacheLimitMb ?? this.attachmentCacheLimitMb,
      autoEvictReadOlderThanDays:
          autoEvictReadOlderThanDays ?? this.autoEvictReadOlderThanDays,
      prefetchUnreadBodies: prefetchUnreadBodies ?? this.prefetchUnreadBodies,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (offlineMessageCount.present) {
      map['offlineMessageCount'] = Variable<int>(offlineMessageCount.value);
    }
    if (attachmentCacheLimitMb.present) {
      map['attachmentCacheLimitMb'] = Variable<int>(
        attachmentCacheLimitMb.value,
      );
    }
    if (autoEvictReadOlderThanDays.present) {
      map['autoEvictReadOlderThanDays'] = Variable<int>(
        autoEvictReadOlderThanDays.value,
      );
    }
    if (prefetchUnreadBodies.present) {
      map['prefetchUnreadBodies'] = Variable<int>(prefetchUnreadBodies.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheConfigCompanion(')
          ..write('accountId: $accountId, ')
          ..write('offlineMessageCount: $offlineMessageCount, ')
          ..write('attachmentCacheLimitMb: $attachmentCacheLimitMb, ')
          ..write('autoEvictReadOlderThanDays: $autoEvictReadOlderThanDays, ')
          ..write('prefetchUnreadBodies: $prefetchUnreadBodies, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StorageQuota extends Table
    with TableInfo<StorageQuota, StorageQuotaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StorageQuota(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _usedKbMeta = const VerificationMeta('usedKb');
  late final GeneratedColumn<int> usedKb = GeneratedColumn<int>(
    'usedKb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _limitKbMeta = const VerificationMeta(
    'limitKb',
  );
  late final GeneratedColumn<int> limitKb = GeneratedColumn<int>(
    'limitKb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _checkedAtEpochMillisMeta =
      const VerificationMeta('checkedAtEpochMillis');
  late final GeneratedColumn<int> checkedAtEpochMillis = GeneratedColumn<int>(
    'checkedAtEpochMillis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    usedKb,
    limitKb,
    checkedAtEpochMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_quota';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageQuotaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('usedKb')) {
      context.handle(
        _usedKbMeta,
        usedKb.isAcceptableOrUnknown(data['usedKb']!, _usedKbMeta),
      );
    } else if (isInserting) {
      context.missing(_usedKbMeta);
    }
    if (data.containsKey('limitKb')) {
      context.handle(
        _limitKbMeta,
        limitKb.isAcceptableOrUnknown(data['limitKb']!, _limitKbMeta),
      );
    } else if (isInserting) {
      context.missing(_limitKbMeta);
    }
    if (data.containsKey('checkedAtEpochMillis')) {
      context.handle(
        _checkedAtEpochMillisMeta,
        checkedAtEpochMillis.isAcceptableOrUnknown(
          data['checkedAtEpochMillis']!,
          _checkedAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkedAtEpochMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  StorageQuotaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageQuotaData(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      usedKb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usedKb'],
      )!,
      limitKb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limitKb'],
      )!,
      checkedAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkedAtEpochMillis'],
      )!,
    );
  }

  @override
  StorageQuota createAlias(String alias) {
    return StorageQuota(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class StorageQuotaData extends DataClass
    implements Insertable<StorageQuotaData> {
  final String accountId;
  final int usedKb;
  final int limitKb;
  final int checkedAtEpochMillis;
  const StorageQuotaData({
    required this.accountId,
    required this.usedKb,
    required this.limitKb,
    required this.checkedAtEpochMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['accountId'] = Variable<String>(accountId);
    map['usedKb'] = Variable<int>(usedKb);
    map['limitKb'] = Variable<int>(limitKb);
    map['checkedAtEpochMillis'] = Variable<int>(checkedAtEpochMillis);
    return map;
  }

  StorageQuotaCompanion toCompanion(bool nullToAbsent) {
    return StorageQuotaCompanion(
      accountId: Value(accountId),
      usedKb: Value(usedKb),
      limitKb: Value(limitKb),
      checkedAtEpochMillis: Value(checkedAtEpochMillis),
    );
  }

  factory StorageQuotaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageQuotaData(
      accountId: serializer.fromJson<String>(json['accountId']),
      usedKb: serializer.fromJson<int>(json['usedKb']),
      limitKb: serializer.fromJson<int>(json['limitKb']),
      checkedAtEpochMillis: serializer.fromJson<int>(
        json['checkedAtEpochMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'usedKb': serializer.toJson<int>(usedKb),
      'limitKb': serializer.toJson<int>(limitKb),
      'checkedAtEpochMillis': serializer.toJson<int>(checkedAtEpochMillis),
    };
  }

  StorageQuotaData copyWith({
    String? accountId,
    int? usedKb,
    int? limitKb,
    int? checkedAtEpochMillis,
  }) => StorageQuotaData(
    accountId: accountId ?? this.accountId,
    usedKb: usedKb ?? this.usedKb,
    limitKb: limitKb ?? this.limitKb,
    checkedAtEpochMillis: checkedAtEpochMillis ?? this.checkedAtEpochMillis,
  );
  StorageQuotaData copyWithCompanion(StorageQuotaCompanion data) {
    return StorageQuotaData(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      usedKb: data.usedKb.present ? data.usedKb.value : this.usedKb,
      limitKb: data.limitKb.present ? data.limitKb.value : this.limitKb,
      checkedAtEpochMillis: data.checkedAtEpochMillis.present
          ? data.checkedAtEpochMillis.value
          : this.checkedAtEpochMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageQuotaData(')
          ..write('accountId: $accountId, ')
          ..write('usedKb: $usedKb, ')
          ..write('limitKb: $limitKb, ')
          ..write('checkedAtEpochMillis: $checkedAtEpochMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountId, usedKb, limitKb, checkedAtEpochMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageQuotaData &&
          other.accountId == this.accountId &&
          other.usedKb == this.usedKb &&
          other.limitKb == this.limitKb &&
          other.checkedAtEpochMillis == this.checkedAtEpochMillis);
}

class StorageQuotaCompanion extends UpdateCompanion<StorageQuotaData> {
  final Value<String> accountId;
  final Value<int> usedKb;
  final Value<int> limitKb;
  final Value<int> checkedAtEpochMillis;
  final Value<int> rowid;
  const StorageQuotaCompanion({
    this.accountId = const Value.absent(),
    this.usedKb = const Value.absent(),
    this.limitKb = const Value.absent(),
    this.checkedAtEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageQuotaCompanion.insert({
    required String accountId,
    required int usedKb,
    required int limitKb,
    required int checkedAtEpochMillis,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       usedKb = Value(usedKb),
       limitKb = Value(limitKb),
       checkedAtEpochMillis = Value(checkedAtEpochMillis);
  static Insertable<StorageQuotaData> custom({
    Expression<String>? accountId,
    Expression<int>? usedKb,
    Expression<int>? limitKb,
    Expression<int>? checkedAtEpochMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'accountId': accountId,
      if (usedKb != null) 'usedKb': usedKb,
      if (limitKb != null) 'limitKb': limitKb,
      if (checkedAtEpochMillis != null)
        'checkedAtEpochMillis': checkedAtEpochMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageQuotaCompanion copyWith({
    Value<String>? accountId,
    Value<int>? usedKb,
    Value<int>? limitKb,
    Value<int>? checkedAtEpochMillis,
    Value<int>? rowid,
  }) {
    return StorageQuotaCompanion(
      accountId: accountId ?? this.accountId,
      usedKb: usedKb ?? this.usedKb,
      limitKb: limitKb ?? this.limitKb,
      checkedAtEpochMillis: checkedAtEpochMillis ?? this.checkedAtEpochMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (usedKb.present) {
      map['usedKb'] = Variable<int>(usedKb.value);
    }
    if (limitKb.present) {
      map['limitKb'] = Variable<int>(limitKb.value);
    }
    if (checkedAtEpochMillis.present) {
      map['checkedAtEpochMillis'] = Variable<int>(checkedAtEpochMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageQuotaCompanion(')
          ..write('accountId: $accountId, ')
          ..write('usedKb: $usedKb, ')
          ..write('limitKb: $limitKb, ')
          ..write('checkedAtEpochMillis: $checkedAtEpochMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PendingMutations extends Table
    with TableInfo<PendingMutations, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PendingMutations(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutationId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES accounts(accountId)ON DELETE CASCADE',
  );
  static const VerificationMeta _mailboxIdMeta = const VerificationMeta(
    'mailboxId',
  );
  late final GeneratedColumn<String> mailboxId = GeneratedColumn<String>(
    'mailboxId',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'messageId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES messages(messageId)ON DELETE CASCADE',
  );
  static const VerificationMeta _targetUidMeta = const VerificationMeta(
    'targetUid',
  );
  late final GeneratedColumn<int> targetUid = GeneratedColumn<int>(
    'targetUid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retryCount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtEpochMillisMeta =
      const VerificationMeta('createdAtEpochMillis');
  late final GeneratedColumn<int> createdAtEpochMillis = GeneratedColumn<int>(
    'createdAtEpochMillis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'lastErrorCode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _previousFlagsMeta = const VerificationMeta(
    'previousFlags',
  );
  late final GeneratedColumn<String> previousFlags = GeneratedColumn<String>(
    'previousFlags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _previousLabelsMeta = const VerificationMeta(
    'previousLabels',
  );
  late final GeneratedColumn<String> previousLabels = GeneratedColumn<String>(
    'previousLabels',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    mutationId,
    accountId,
    mailboxId,
    messageId,
    targetUid,
    type,
    payload,
    state,
    retryCount,
    createdAtEpochMillis,
    lastErrorCode,
    previousFlags,
    previousLabels,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mutationId')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutationId']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('mailboxId')) {
      context.handle(
        _mailboxIdMeta,
        mailboxId.isAcceptableOrUnknown(data['mailboxId']!, _mailboxIdMeta),
      );
    }
    if (data.containsKey('messageId')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['messageId']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('targetUid')) {
      context.handle(
        _targetUidMeta,
        targetUid.isAcceptableOrUnknown(data['targetUid']!, _targetUidMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('retryCount')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retryCount']!, _retryCountMeta),
      );
    } else if (isInserting) {
      context.missing(_retryCountMeta);
    }
    if (data.containsKey('createdAtEpochMillis')) {
      context.handle(
        _createdAtEpochMillisMeta,
        createdAtEpochMillis.isAcceptableOrUnknown(
          data['createdAtEpochMillis']!,
          _createdAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMillisMeta);
    }
    if (data.containsKey('lastErrorCode')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['lastErrorCode']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('previousFlags')) {
      context.handle(
        _previousFlagsMeta,
        previousFlags.isAcceptableOrUnknown(
          data['previousFlags']!,
          _previousFlagsMeta,
        ),
      );
    }
    if (data.containsKey('previousLabels')) {
      context.handle(
        _previousLabelsMeta,
        previousLabels.isAcceptableOrUnknown(
          data['previousLabels']!,
          _previousLabelsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mutationId};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutationId'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      mailboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailboxId'],
      ),
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}messageId'],
      )!,
      targetUid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}targetUid'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retryCount'],
      )!,
      createdAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}createdAtEpochMillis'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lastErrorCode'],
      ),
      previousFlags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previousFlags'],
      )!,
      previousLabels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previousLabels'],
      )!,
    );
  }

  @override
  PendingMutations createAlias(String alias) {
    return PendingMutations(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final String mutationId;
  final String accountId;
  final String? mailboxId;
  final String messageId;
  final int? targetUid;
  final String type;
  final String? payload;
  final String state;
  final int retryCount;
  final int createdAtEpochMillis;
  final String? lastErrorCode;
  final String previousFlags;
  final String previousLabels;
  const PendingMutation({
    required this.mutationId,
    required this.accountId,
    this.mailboxId,
    required this.messageId,
    this.targetUid,
    required this.type,
    this.payload,
    required this.state,
    required this.retryCount,
    required this.createdAtEpochMillis,
    this.lastErrorCode,
    required this.previousFlags,
    required this.previousLabels,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mutationId'] = Variable<String>(mutationId);
    map['accountId'] = Variable<String>(accountId);
    if (!nullToAbsent || mailboxId != null) {
      map['mailboxId'] = Variable<String>(mailboxId);
    }
    map['messageId'] = Variable<String>(messageId);
    if (!nullToAbsent || targetUid != null) {
      map['targetUid'] = Variable<int>(targetUid);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['state'] = Variable<String>(state);
    map['retryCount'] = Variable<int>(retryCount);
    map['createdAtEpochMillis'] = Variable<int>(createdAtEpochMillis);
    if (!nullToAbsent || lastErrorCode != null) {
      map['lastErrorCode'] = Variable<String>(lastErrorCode);
    }
    map['previousFlags'] = Variable<String>(previousFlags);
    map['previousLabels'] = Variable<String>(previousLabels);
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      mutationId: Value(mutationId),
      accountId: Value(accountId),
      mailboxId: mailboxId == null && nullToAbsent
          ? const Value.absent()
          : Value(mailboxId),
      messageId: Value(messageId),
      targetUid: targetUid == null && nullToAbsent
          ? const Value.absent()
          : Value(targetUid),
      type: Value(type),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      state: Value(state),
      retryCount: Value(retryCount),
      createdAtEpochMillis: Value(createdAtEpochMillis),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      previousFlags: Value(previousFlags),
      previousLabels: Value(previousLabels),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      mutationId: serializer.fromJson<String>(json['mutationId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      mailboxId: serializer.fromJson<String?>(json['mailboxId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      targetUid: serializer.fromJson<int?>(json['targetUid']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<String?>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAtEpochMillis: serializer.fromJson<int>(
        json['createdAtEpochMillis'],
      ),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      previousFlags: serializer.fromJson<String>(json['previousFlags']),
      previousLabels: serializer.fromJson<String>(json['previousLabels']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mutationId': serializer.toJson<String>(mutationId),
      'accountId': serializer.toJson<String>(accountId),
      'mailboxId': serializer.toJson<String?>(mailboxId),
      'messageId': serializer.toJson<String>(messageId),
      'targetUid': serializer.toJson<int?>(targetUid),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<String?>(payload),
      'state': serializer.toJson<String>(state),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAtEpochMillis': serializer.toJson<int>(createdAtEpochMillis),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'previousFlags': serializer.toJson<String>(previousFlags),
      'previousLabels': serializer.toJson<String>(previousLabels),
    };
  }

  PendingMutation copyWith({
    String? mutationId,
    String? accountId,
    Value<String?> mailboxId = const Value.absent(),
    String? messageId,
    Value<int?> targetUid = const Value.absent(),
    String? type,
    Value<String?> payload = const Value.absent(),
    String? state,
    int? retryCount,
    int? createdAtEpochMillis,
    Value<String?> lastErrorCode = const Value.absent(),
    String? previousFlags,
    String? previousLabels,
  }) => PendingMutation(
    mutationId: mutationId ?? this.mutationId,
    accountId: accountId ?? this.accountId,
    mailboxId: mailboxId.present ? mailboxId.value : this.mailboxId,
    messageId: messageId ?? this.messageId,
    targetUid: targetUid.present ? targetUid.value : this.targetUid,
    type: type ?? this.type,
    payload: payload.present ? payload.value : this.payload,
    state: state ?? this.state,
    retryCount: retryCount ?? this.retryCount,
    createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    previousFlags: previousFlags ?? this.previousFlags,
    previousLabels: previousLabels ?? this.previousLabels,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      mailboxId: data.mailboxId.present ? data.mailboxId.value : this.mailboxId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      targetUid: data.targetUid.present ? data.targetUid.value : this.targetUid,
      type: data.type.present ? data.type.value : this.type,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAtEpochMillis: data.createdAtEpochMillis.present
          ? data.createdAtEpochMillis.value
          : this.createdAtEpochMillis,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      previousFlags: data.previousFlags.present
          ? data.previousFlags.value
          : this.previousFlags,
      previousLabels: data.previousLabels.present
          ? data.previousLabels.value
          : this.previousLabels,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('mailboxId: $mailboxId, ')
          ..write('messageId: $messageId, ')
          ..write('targetUid: $targetUid, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('previousFlags: $previousFlags, ')
          ..write('previousLabels: $previousLabels')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mutationId,
    accountId,
    mailboxId,
    messageId,
    targetUid,
    type,
    payload,
    state,
    retryCount,
    createdAtEpochMillis,
    lastErrorCode,
    previousFlags,
    previousLabels,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.mutationId == this.mutationId &&
          other.accountId == this.accountId &&
          other.mailboxId == this.mailboxId &&
          other.messageId == this.messageId &&
          other.targetUid == this.targetUid &&
          other.type == this.type &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.retryCount == this.retryCount &&
          other.createdAtEpochMillis == this.createdAtEpochMillis &&
          other.lastErrorCode == this.lastErrorCode &&
          other.previousFlags == this.previousFlags &&
          other.previousLabels == this.previousLabels);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<String> mutationId;
  final Value<String> accountId;
  final Value<String?> mailboxId;
  final Value<String> messageId;
  final Value<int?> targetUid;
  final Value<String> type;
  final Value<String?> payload;
  final Value<String> state;
  final Value<int> retryCount;
  final Value<int> createdAtEpochMillis;
  final Value<String?> lastErrorCode;
  final Value<String> previousFlags;
  final Value<String> previousLabels;
  final Value<int> rowid;
  const PendingMutationsCompanion({
    this.mutationId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.mailboxId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.targetUid = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAtEpochMillis = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.previousFlags = const Value.absent(),
    this.previousLabels = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    required String mutationId,
    required String accountId,
    this.mailboxId = const Value.absent(),
    required String messageId,
    this.targetUid = const Value.absent(),
    required String type,
    this.payload = const Value.absent(),
    required String state,
    required int retryCount,
    required int createdAtEpochMillis,
    this.lastErrorCode = const Value.absent(),
    this.previousFlags = const Value.absent(),
    this.previousLabels = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mutationId = Value(mutationId),
       accountId = Value(accountId),
       messageId = Value(messageId),
       type = Value(type),
       state = Value(state),
       retryCount = Value(retryCount),
       createdAtEpochMillis = Value(createdAtEpochMillis);
  static Insertable<PendingMutation> custom({
    Expression<String>? mutationId,
    Expression<String>? accountId,
    Expression<String>? mailboxId,
    Expression<String>? messageId,
    Expression<int>? targetUid,
    Expression<String>? type,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<int>? retryCount,
    Expression<int>? createdAtEpochMillis,
    Expression<String>? lastErrorCode,
    Expression<String>? previousFlags,
    Expression<String>? previousLabels,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mutationId != null) 'mutationId': mutationId,
      if (accountId != null) 'accountId': accountId,
      if (mailboxId != null) 'mailboxId': mailboxId,
      if (messageId != null) 'messageId': messageId,
      if (targetUid != null) 'targetUid': targetUid,
      if (type != null) 'type': type,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (retryCount != null) 'retryCount': retryCount,
      if (createdAtEpochMillis != null)
        'createdAtEpochMillis': createdAtEpochMillis,
      if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
      if (previousFlags != null) 'previousFlags': previousFlags,
      if (previousLabels != null) 'previousLabels': previousLabels,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<String>? mutationId,
    Value<String>? accountId,
    Value<String?>? mailboxId,
    Value<String>? messageId,
    Value<int?>? targetUid,
    Value<String>? type,
    Value<String?>? payload,
    Value<String>? state,
    Value<int>? retryCount,
    Value<int>? createdAtEpochMillis,
    Value<String?>? lastErrorCode,
    Value<String>? previousFlags,
    Value<String>? previousLabels,
    Value<int>? rowid,
  }) {
    return PendingMutationsCompanion(
      mutationId: mutationId ?? this.mutationId,
      accountId: accountId ?? this.accountId,
      mailboxId: mailboxId ?? this.mailboxId,
      messageId: messageId ?? this.messageId,
      targetUid: targetUid ?? this.targetUid,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      previousFlags: previousFlags ?? this.previousFlags,
      previousLabels: previousLabels ?? this.previousLabels,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mutationId.present) {
      map['mutationId'] = Variable<String>(mutationId.value);
    }
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (mailboxId.present) {
      map['mailboxId'] = Variable<String>(mailboxId.value);
    }
    if (messageId.present) {
      map['messageId'] = Variable<String>(messageId.value);
    }
    if (targetUid.present) {
      map['targetUid'] = Variable<int>(targetUid.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (retryCount.present) {
      map['retryCount'] = Variable<int>(retryCount.value);
    }
    if (createdAtEpochMillis.present) {
      map['createdAtEpochMillis'] = Variable<int>(createdAtEpochMillis.value);
    }
    if (lastErrorCode.present) {
      map['lastErrorCode'] = Variable<String>(lastErrorCode.value);
    }
    if (previousFlags.present) {
      map['previousFlags'] = Variable<String>(previousFlags.value);
    }
    if (previousLabels.present) {
      map['previousLabels'] = Variable<String>(previousLabels.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('mutationId: $mutationId, ')
          ..write('accountId: $accountId, ')
          ..write('mailboxId: $mailboxId, ')
          ..write('messageId: $messageId, ')
          ..write('targetUid: $targetUid, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('previousFlags: $previousFlags, ')
          ..write('previousLabels: $previousLabels, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncCheckpoints extends Table
    with TableInfo<SyncCheckpoints, SyncCheckpoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncCheckpoints(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mailboxIdMeta = const VerificationMeta(
    'mailboxId',
  );
  late final GeneratedColumn<String> mailboxId = GeneratedColumn<String>(
    'mailboxId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL PRIMARY KEY REFERENCES mailboxes(mailboxId)ON DELETE CASCADE',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES accounts(accountId)ON DELETE CASCADE',
  );
  static const VerificationMeta _uidValidityMeta = const VerificationMeta(
    'uidValidity',
  );
  late final GeneratedColumn<int> uidValidity = GeneratedColumn<int>(
    'uidValidity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _highestKnownUidMeta = const VerificationMeta(
    'highestKnownUid',
  );
  late final GeneratedColumn<int> highestKnownUid = GeneratedColumn<int>(
    'highestKnownUid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _syncGenerationMeta = const VerificationMeta(
    'syncGeneration',
  );
  late final GeneratedColumn<int> syncGeneration = GeneratedColumn<int>(
    'syncGeneration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastSuccessfulSyncEpochMillisMeta =
      const VerificationMeta('lastSuccessfulSyncEpochMillis');
  late final GeneratedColumn<int> lastSuccessfulSyncEpochMillis =
      GeneratedColumn<int>(
        'lastSuccessfulSyncEpochMillis',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    mailboxId,
    accountId,
    uidValidity,
    highestKnownUid,
    syncGeneration,
    lastSuccessfulSyncEpochMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCheckpoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mailboxId')) {
      context.handle(
        _mailboxIdMeta,
        mailboxId.isAcceptableOrUnknown(data['mailboxId']!, _mailboxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mailboxIdMeta);
    }
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('uidValidity')) {
      context.handle(
        _uidValidityMeta,
        uidValidity.isAcceptableOrUnknown(
          data['uidValidity']!,
          _uidValidityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_uidValidityMeta);
    }
    if (data.containsKey('highestKnownUid')) {
      context.handle(
        _highestKnownUidMeta,
        highestKnownUid.isAcceptableOrUnknown(
          data['highestKnownUid']!,
          _highestKnownUidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highestKnownUidMeta);
    }
    if (data.containsKey('syncGeneration')) {
      context.handle(
        _syncGenerationMeta,
        syncGeneration.isAcceptableOrUnknown(
          data['syncGeneration']!,
          _syncGenerationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncGenerationMeta);
    }
    if (data.containsKey('lastSuccessfulSyncEpochMillis')) {
      context.handle(
        _lastSuccessfulSyncEpochMillisMeta,
        lastSuccessfulSyncEpochMillis.isAcceptableOrUnknown(
          data['lastSuccessfulSyncEpochMillis']!,
          _lastSuccessfulSyncEpochMillisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mailboxId};
  @override
  SyncCheckpoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCheckpoint(
      mailboxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mailboxId'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      uidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uidValidity'],
      )!,
      highestKnownUid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highestKnownUid'],
      )!,
      syncGeneration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}syncGeneration'],
      )!,
      lastSuccessfulSyncEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lastSuccessfulSyncEpochMillis'],
      ),
    );
  }

  @override
  SyncCheckpoints createAlias(String alias) {
    return SyncCheckpoints(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncCheckpoint extends DataClass implements Insertable<SyncCheckpoint> {
  final String mailboxId;
  final String accountId;
  final int uidValidity;
  final int highestKnownUid;
  final int syncGeneration;
  final int? lastSuccessfulSyncEpochMillis;
  const SyncCheckpoint({
    required this.mailboxId,
    required this.accountId,
    required this.uidValidity,
    required this.highestKnownUid,
    required this.syncGeneration,
    this.lastSuccessfulSyncEpochMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mailboxId'] = Variable<String>(mailboxId);
    map['accountId'] = Variable<String>(accountId);
    map['uidValidity'] = Variable<int>(uidValidity);
    map['highestKnownUid'] = Variable<int>(highestKnownUid);
    map['syncGeneration'] = Variable<int>(syncGeneration);
    if (!nullToAbsent || lastSuccessfulSyncEpochMillis != null) {
      map['lastSuccessfulSyncEpochMillis'] = Variable<int>(
        lastSuccessfulSyncEpochMillis,
      );
    }
    return map;
  }

  SyncCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return SyncCheckpointsCompanion(
      mailboxId: Value(mailboxId),
      accountId: Value(accountId),
      uidValidity: Value(uidValidity),
      highestKnownUid: Value(highestKnownUid),
      syncGeneration: Value(syncGeneration),
      lastSuccessfulSyncEpochMillis:
          lastSuccessfulSyncEpochMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulSyncEpochMillis),
    );
  }

  factory SyncCheckpoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCheckpoint(
      mailboxId: serializer.fromJson<String>(json['mailboxId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      uidValidity: serializer.fromJson<int>(json['uidValidity']),
      highestKnownUid: serializer.fromJson<int>(json['highestKnownUid']),
      syncGeneration: serializer.fromJson<int>(json['syncGeneration']),
      lastSuccessfulSyncEpochMillis: serializer.fromJson<int?>(
        json['lastSuccessfulSyncEpochMillis'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mailboxId': serializer.toJson<String>(mailboxId),
      'accountId': serializer.toJson<String>(accountId),
      'uidValidity': serializer.toJson<int>(uidValidity),
      'highestKnownUid': serializer.toJson<int>(highestKnownUid),
      'syncGeneration': serializer.toJson<int>(syncGeneration),
      'lastSuccessfulSyncEpochMillis': serializer.toJson<int?>(
        lastSuccessfulSyncEpochMillis,
      ),
    };
  }

  SyncCheckpoint copyWith({
    String? mailboxId,
    String? accountId,
    int? uidValidity,
    int? highestKnownUid,
    int? syncGeneration,
    Value<int?> lastSuccessfulSyncEpochMillis = const Value.absent(),
  }) => SyncCheckpoint(
    mailboxId: mailboxId ?? this.mailboxId,
    accountId: accountId ?? this.accountId,
    uidValidity: uidValidity ?? this.uidValidity,
    highestKnownUid: highestKnownUid ?? this.highestKnownUid,
    syncGeneration: syncGeneration ?? this.syncGeneration,
    lastSuccessfulSyncEpochMillis: lastSuccessfulSyncEpochMillis.present
        ? lastSuccessfulSyncEpochMillis.value
        : this.lastSuccessfulSyncEpochMillis,
  );
  SyncCheckpoint copyWithCompanion(SyncCheckpointsCompanion data) {
    return SyncCheckpoint(
      mailboxId: data.mailboxId.present ? data.mailboxId.value : this.mailboxId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      uidValidity: data.uidValidity.present
          ? data.uidValidity.value
          : this.uidValidity,
      highestKnownUid: data.highestKnownUid.present
          ? data.highestKnownUid.value
          : this.highestKnownUid,
      syncGeneration: data.syncGeneration.present
          ? data.syncGeneration.value
          : this.syncGeneration,
      lastSuccessfulSyncEpochMillis: data.lastSuccessfulSyncEpochMillis.present
          ? data.lastSuccessfulSyncEpochMillis.value
          : this.lastSuccessfulSyncEpochMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCheckpoint(')
          ..write('mailboxId: $mailboxId, ')
          ..write('accountId: $accountId, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestKnownUid: $highestKnownUid, ')
          ..write('syncGeneration: $syncGeneration, ')
          ..write(
            'lastSuccessfulSyncEpochMillis: $lastSuccessfulSyncEpochMillis',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mailboxId,
    accountId,
    uidValidity,
    highestKnownUid,
    syncGeneration,
    lastSuccessfulSyncEpochMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCheckpoint &&
          other.mailboxId == this.mailboxId &&
          other.accountId == this.accountId &&
          other.uidValidity == this.uidValidity &&
          other.highestKnownUid == this.highestKnownUid &&
          other.syncGeneration == this.syncGeneration &&
          other.lastSuccessfulSyncEpochMillis ==
              this.lastSuccessfulSyncEpochMillis);
}

class SyncCheckpointsCompanion extends UpdateCompanion<SyncCheckpoint> {
  final Value<String> mailboxId;
  final Value<String> accountId;
  final Value<int> uidValidity;
  final Value<int> highestKnownUid;
  final Value<int> syncGeneration;
  final Value<int?> lastSuccessfulSyncEpochMillis;
  final Value<int> rowid;
  const SyncCheckpointsCompanion({
    this.mailboxId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.highestKnownUid = const Value.absent(),
    this.syncGeneration = const Value.absent(),
    this.lastSuccessfulSyncEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCheckpointsCompanion.insert({
    required String mailboxId,
    required String accountId,
    required int uidValidity,
    required int highestKnownUid,
    required int syncGeneration,
    this.lastSuccessfulSyncEpochMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mailboxId = Value(mailboxId),
       accountId = Value(accountId),
       uidValidity = Value(uidValidity),
       highestKnownUid = Value(highestKnownUid),
       syncGeneration = Value(syncGeneration);
  static Insertable<SyncCheckpoint> custom({
    Expression<String>? mailboxId,
    Expression<String>? accountId,
    Expression<int>? uidValidity,
    Expression<int>? highestKnownUid,
    Expression<int>? syncGeneration,
    Expression<int>? lastSuccessfulSyncEpochMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mailboxId != null) 'mailboxId': mailboxId,
      if (accountId != null) 'accountId': accountId,
      if (uidValidity != null) 'uidValidity': uidValidity,
      if (highestKnownUid != null) 'highestKnownUid': highestKnownUid,
      if (syncGeneration != null) 'syncGeneration': syncGeneration,
      if (lastSuccessfulSyncEpochMillis != null)
        'lastSuccessfulSyncEpochMillis': lastSuccessfulSyncEpochMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCheckpointsCompanion copyWith({
    Value<String>? mailboxId,
    Value<String>? accountId,
    Value<int>? uidValidity,
    Value<int>? highestKnownUid,
    Value<int>? syncGeneration,
    Value<int?>? lastSuccessfulSyncEpochMillis,
    Value<int>? rowid,
  }) {
    return SyncCheckpointsCompanion(
      mailboxId: mailboxId ?? this.mailboxId,
      accountId: accountId ?? this.accountId,
      uidValidity: uidValidity ?? this.uidValidity,
      highestKnownUid: highestKnownUid ?? this.highestKnownUid,
      syncGeneration: syncGeneration ?? this.syncGeneration,
      lastSuccessfulSyncEpochMillis:
          lastSuccessfulSyncEpochMillis ?? this.lastSuccessfulSyncEpochMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mailboxId.present) {
      map['mailboxId'] = Variable<String>(mailboxId.value);
    }
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (uidValidity.present) {
      map['uidValidity'] = Variable<int>(uidValidity.value);
    }
    if (highestKnownUid.present) {
      map['highestKnownUid'] = Variable<int>(highestKnownUid.value);
    }
    if (syncGeneration.present) {
      map['syncGeneration'] = Variable<int>(syncGeneration.value);
    }
    if (lastSuccessfulSyncEpochMillis.present) {
      map['lastSuccessfulSyncEpochMillis'] = Variable<int>(
        lastSuccessfulSyncEpochMillis.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCheckpointsCompanion(')
          ..write('mailboxId: $mailboxId, ')
          ..write('accountId: $accountId, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('highestKnownUid: $highestKnownUid, ')
          ..write('syncGeneration: $syncGeneration, ')
          ..write(
            'lastSuccessfulSyncEpochMillis: $lastSuccessfulSyncEpochMillis, ',
          )
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Drafts extends Table with TableInfo<Drafts, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Drafts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draftId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES accounts(accountId)ON DELETE CASCADE',
  );
  static const VerificationMeta _toAddressesMeta = const VerificationMeta(
    'toAddresses',
  );
  late final GeneratedColumn<String> toAddresses = GeneratedColumn<String>(
    'toAddresses',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ccAddressesMeta = const VerificationMeta(
    'ccAddresses',
  );
  late final GeneratedColumn<String> ccAddresses = GeneratedColumn<String>(
    'ccAddresses',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bccAddressesMeta = const VerificationMeta(
    'bccAddresses',
  );
  late final GeneratedColumn<String> bccAddresses = GeneratedColumn<String>(
    'bccAddresses',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _inReplyToMeta = const VerificationMeta(
    'inReplyTo',
  );
  late final GeneratedColumn<String> inReplyTo = GeneratedColumn<String>(
    'inReplyTo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _referencesMeta = const VerificationMeta(
    'references',
  );
  late final GeneratedColumn<String> references = GeneratedColumn<String>(
    'references',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtEpochMillisMeta =
      const VerificationMeta('updatedAtEpochMillis');
  late final GeneratedColumn<int> updatedAtEpochMillis = GeneratedColumn<int>(
    'updatedAtEpochMillis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    draftId,
    accountId,
    toAddresses,
    ccAddresses,
    bccAddresses,
    subject,
    body,
    inReplyTo,
    references,
    status,
    updatedAtEpochMillis,
    attachments,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('draftId')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draftId']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('toAddresses')) {
      context.handle(
        _toAddressesMeta,
        toAddresses.isAcceptableOrUnknown(
          data['toAddresses']!,
          _toAddressesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toAddressesMeta);
    }
    if (data.containsKey('ccAddresses')) {
      context.handle(
        _ccAddressesMeta,
        ccAddresses.isAcceptableOrUnknown(
          data['ccAddresses']!,
          _ccAddressesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ccAddressesMeta);
    }
    if (data.containsKey('bccAddresses')) {
      context.handle(
        _bccAddressesMeta,
        bccAddresses.isAcceptableOrUnknown(
          data['bccAddresses']!,
          _bccAddressesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bccAddressesMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('inReplyTo')) {
      context.handle(
        _inReplyToMeta,
        inReplyTo.isAcceptableOrUnknown(data['inReplyTo']!, _inReplyToMeta),
      );
    }
    if (data.containsKey('references')) {
      context.handle(
        _referencesMeta,
        references.isAcceptableOrUnknown(data['references']!, _referencesMeta),
      );
    } else if (isInserting) {
      context.missing(_referencesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('updatedAtEpochMillis')) {
      context.handle(
        _updatedAtEpochMillisMeta,
        updatedAtEpochMillis.isAcceptableOrUnknown(
          data['updatedAtEpochMillis']!,
          _updatedAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMillisMeta);
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attachmentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {draftId};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draftId'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      toAddresses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toAddresses'],
      )!,
      ccAddresses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ccAddresses'],
      )!,
      bccAddresses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bccAddresses'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      inReplyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inReplyTo'],
      ),
      references: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}references'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updatedAtEpochMillis'],
      )!,
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      )!,
    );
  }

  @override
  Drafts createAlias(String alias) {
    return Drafts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Draft extends DataClass implements Insertable<Draft> {
  final String draftId;
  final String accountId;
  final String toAddresses;
  final String ccAddresses;
  final String bccAddresses;
  final String subject;
  final String body;
  final String? inReplyTo;
  final String references;
  final String status;
  final int updatedAtEpochMillis;
  final String attachments;
  const Draft({
    required this.draftId,
    required this.accountId,
    required this.toAddresses,
    required this.ccAddresses,
    required this.bccAddresses,
    required this.subject,
    required this.body,
    this.inReplyTo,
    required this.references,
    required this.status,
    required this.updatedAtEpochMillis,
    required this.attachments,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['draftId'] = Variable<String>(draftId);
    map['accountId'] = Variable<String>(accountId);
    map['toAddresses'] = Variable<String>(toAddresses);
    map['ccAddresses'] = Variable<String>(ccAddresses);
    map['bccAddresses'] = Variable<String>(bccAddresses);
    map['subject'] = Variable<String>(subject);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || inReplyTo != null) {
      map['inReplyTo'] = Variable<String>(inReplyTo);
    }
    map['references'] = Variable<String>(references);
    map['status'] = Variable<String>(status);
    map['updatedAtEpochMillis'] = Variable<int>(updatedAtEpochMillis);
    map['attachments'] = Variable<String>(attachments);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      draftId: Value(draftId),
      accountId: Value(accountId),
      toAddresses: Value(toAddresses),
      ccAddresses: Value(ccAddresses),
      bccAddresses: Value(bccAddresses),
      subject: Value(subject),
      body: Value(body),
      inReplyTo: inReplyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(inReplyTo),
      references: Value(references),
      status: Value(status),
      updatedAtEpochMillis: Value(updatedAtEpochMillis),
      attachments: Value(attachments),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      draftId: serializer.fromJson<String>(json['draftId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAddresses: serializer.fromJson<String>(json['toAddresses']),
      ccAddresses: serializer.fromJson<String>(json['ccAddresses']),
      bccAddresses: serializer.fromJson<String>(json['bccAddresses']),
      subject: serializer.fromJson<String>(json['subject']),
      body: serializer.fromJson<String>(json['body']),
      inReplyTo: serializer.fromJson<String?>(json['inReplyTo']),
      references: serializer.fromJson<String>(json['references']),
      status: serializer.fromJson<String>(json['status']),
      updatedAtEpochMillis: serializer.fromJson<int>(
        json['updatedAtEpochMillis'],
      ),
      attachments: serializer.fromJson<String>(json['attachments']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'draftId': serializer.toJson<String>(draftId),
      'accountId': serializer.toJson<String>(accountId),
      'toAddresses': serializer.toJson<String>(toAddresses),
      'ccAddresses': serializer.toJson<String>(ccAddresses),
      'bccAddresses': serializer.toJson<String>(bccAddresses),
      'subject': serializer.toJson<String>(subject),
      'body': serializer.toJson<String>(body),
      'inReplyTo': serializer.toJson<String?>(inReplyTo),
      'references': serializer.toJson<String>(references),
      'status': serializer.toJson<String>(status),
      'updatedAtEpochMillis': serializer.toJson<int>(updatedAtEpochMillis),
      'attachments': serializer.toJson<String>(attachments),
    };
  }

  Draft copyWith({
    String? draftId,
    String? accountId,
    String? toAddresses,
    String? ccAddresses,
    String? bccAddresses,
    String? subject,
    String? body,
    Value<String?> inReplyTo = const Value.absent(),
    String? references,
    String? status,
    int? updatedAtEpochMillis,
    String? attachments,
  }) => Draft(
    draftId: draftId ?? this.draftId,
    accountId: accountId ?? this.accountId,
    toAddresses: toAddresses ?? this.toAddresses,
    ccAddresses: ccAddresses ?? this.ccAddresses,
    bccAddresses: bccAddresses ?? this.bccAddresses,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    inReplyTo: inReplyTo.present ? inReplyTo.value : this.inReplyTo,
    references: references ?? this.references,
    status: status ?? this.status,
    updatedAtEpochMillis: updatedAtEpochMillis ?? this.updatedAtEpochMillis,
    attachments: attachments ?? this.attachments,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAddresses: data.toAddresses.present
          ? data.toAddresses.value
          : this.toAddresses,
      ccAddresses: data.ccAddresses.present
          ? data.ccAddresses.value
          : this.ccAddresses,
      bccAddresses: data.bccAddresses.present
          ? data.bccAddresses.value
          : this.bccAddresses,
      subject: data.subject.present ? data.subject.value : this.subject,
      body: data.body.present ? data.body.value : this.body,
      inReplyTo: data.inReplyTo.present ? data.inReplyTo.value : this.inReplyTo,
      references: data.references.present
          ? data.references.value
          : this.references,
      status: data.status.present ? data.status.value : this.status,
      updatedAtEpochMillis: data.updatedAtEpochMillis.present
          ? data.updatedAtEpochMillis.value
          : this.updatedAtEpochMillis,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('draftId: $draftId, ')
          ..write('accountId: $accountId, ')
          ..write('toAddresses: $toAddresses, ')
          ..write('ccAddresses: $ccAddresses, ')
          ..write('bccAddresses: $bccAddresses, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('references: $references, ')
          ..write('status: $status, ')
          ..write('updatedAtEpochMillis: $updatedAtEpochMillis, ')
          ..write('attachments: $attachments')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    draftId,
    accountId,
    toAddresses,
    ccAddresses,
    bccAddresses,
    subject,
    body,
    inReplyTo,
    references,
    status,
    updatedAtEpochMillis,
    attachments,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.draftId == this.draftId &&
          other.accountId == this.accountId &&
          other.toAddresses == this.toAddresses &&
          other.ccAddresses == this.ccAddresses &&
          other.bccAddresses == this.bccAddresses &&
          other.subject == this.subject &&
          other.body == this.body &&
          other.inReplyTo == this.inReplyTo &&
          other.references == this.references &&
          other.status == this.status &&
          other.updatedAtEpochMillis == this.updatedAtEpochMillis &&
          other.attachments == this.attachments);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<String> draftId;
  final Value<String> accountId;
  final Value<String> toAddresses;
  final Value<String> ccAddresses;
  final Value<String> bccAddresses;
  final Value<String> subject;
  final Value<String> body;
  final Value<String?> inReplyTo;
  final Value<String> references;
  final Value<String> status;
  final Value<int> updatedAtEpochMillis;
  final Value<String> attachments;
  final Value<int> rowid;
  const DraftsCompanion({
    this.draftId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAddresses = const Value.absent(),
    this.ccAddresses = const Value.absent(),
    this.bccAddresses = const Value.absent(),
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.references = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAtEpochMillis = const Value.absent(),
    this.attachments = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String draftId,
    required String accountId,
    required String toAddresses,
    required String ccAddresses,
    required String bccAddresses,
    required String subject,
    required String body,
    this.inReplyTo = const Value.absent(),
    required String references,
    required String status,
    required int updatedAtEpochMillis,
    required String attachments,
    this.rowid = const Value.absent(),
  }) : draftId = Value(draftId),
       accountId = Value(accountId),
       toAddresses = Value(toAddresses),
       ccAddresses = Value(ccAddresses),
       bccAddresses = Value(bccAddresses),
       subject = Value(subject),
       body = Value(body),
       references = Value(references),
       status = Value(status),
       updatedAtEpochMillis = Value(updatedAtEpochMillis),
       attachments = Value(attachments);
  static Insertable<Draft> custom({
    Expression<String>? draftId,
    Expression<String>? accountId,
    Expression<String>? toAddresses,
    Expression<String>? ccAddresses,
    Expression<String>? bccAddresses,
    Expression<String>? subject,
    Expression<String>? body,
    Expression<String>? inReplyTo,
    Expression<String>? references,
    Expression<String>? status,
    Expression<int>? updatedAtEpochMillis,
    Expression<String>? attachments,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (draftId != null) 'draftId': draftId,
      if (accountId != null) 'accountId': accountId,
      if (toAddresses != null) 'toAddresses': toAddresses,
      if (ccAddresses != null) 'ccAddresses': ccAddresses,
      if (bccAddresses != null) 'bccAddresses': bccAddresses,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (inReplyTo != null) 'inReplyTo': inReplyTo,
      if (references != null) 'references': references,
      if (status != null) 'status': status,
      if (updatedAtEpochMillis != null)
        'updatedAtEpochMillis': updatedAtEpochMillis,
      if (attachments != null) 'attachments': attachments,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? draftId,
    Value<String>? accountId,
    Value<String>? toAddresses,
    Value<String>? ccAddresses,
    Value<String>? bccAddresses,
    Value<String>? subject,
    Value<String>? body,
    Value<String?>? inReplyTo,
    Value<String>? references,
    Value<String>? status,
    Value<int>? updatedAtEpochMillis,
    Value<String>? attachments,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      draftId: draftId ?? this.draftId,
      accountId: accountId ?? this.accountId,
      toAddresses: toAddresses ?? this.toAddresses,
      ccAddresses: ccAddresses ?? this.ccAddresses,
      bccAddresses: bccAddresses ?? this.bccAddresses,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      references: references ?? this.references,
      status: status ?? this.status,
      updatedAtEpochMillis: updatedAtEpochMillis ?? this.updatedAtEpochMillis,
      attachments: attachments ?? this.attachments,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (draftId.present) {
      map['draftId'] = Variable<String>(draftId.value);
    }
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (toAddresses.present) {
      map['toAddresses'] = Variable<String>(toAddresses.value);
    }
    if (ccAddresses.present) {
      map['ccAddresses'] = Variable<String>(ccAddresses.value);
    }
    if (bccAddresses.present) {
      map['bccAddresses'] = Variable<String>(bccAddresses.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (inReplyTo.present) {
      map['inReplyTo'] = Variable<String>(inReplyTo.value);
    }
    if (references.present) {
      map['references'] = Variable<String>(references.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAtEpochMillis.present) {
      map['updatedAtEpochMillis'] = Variable<int>(updatedAtEpochMillis.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('draftId: $draftId, ')
          ..write('accountId: $accountId, ')
          ..write('toAddresses: $toAddresses, ')
          ..write('ccAddresses: $ccAddresses, ')
          ..write('bccAddresses: $bccAddresses, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('references: $references, ')
          ..write('status: $status, ')
          ..write('updatedAtEpochMillis: $updatedAtEpochMillis, ')
          ..write('attachments: $attachments, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class NotificationState extends Table
    with TableInfo<NotificationState, NotificationStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  NotificationState(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'accountId',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _baselineEstablishedMeta =
      const VerificationMeta('baselineEstablished');
  late final GeneratedColumn<int> baselineEstablished = GeneratedColumn<int>(
    'baselineEstablished',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, baselineEstablished];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('accountId')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['accountId']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('baselineEstablished')) {
      context.handle(
        _baselineEstablishedMeta,
        baselineEstablished.isAcceptableOrUnknown(
          data['baselineEstablished']!,
          _baselineEstablishedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baselineEstablishedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  NotificationStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationStateData(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accountId'],
      )!,
      baselineEstablished: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}baselineEstablished'],
      )!,
    );
  }

  @override
  NotificationState createAlias(String alias) {
    return NotificationState(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class NotificationStateData extends DataClass
    implements Insertable<NotificationStateData> {
  final String accountId;
  final int baselineEstablished;
  const NotificationStateData({
    required this.accountId,
    required this.baselineEstablished,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['accountId'] = Variable<String>(accountId);
    map['baselineEstablished'] = Variable<int>(baselineEstablished);
    return map;
  }

  NotificationStateCompanion toCompanion(bool nullToAbsent) {
    return NotificationStateCompanion(
      accountId: Value(accountId),
      baselineEstablished: Value(baselineEstablished),
    );
  }

  factory NotificationStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationStateData(
      accountId: serializer.fromJson<String>(json['accountId']),
      baselineEstablished: serializer.fromJson<int>(
        json['baselineEstablished'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'baselineEstablished': serializer.toJson<int>(baselineEstablished),
    };
  }

  NotificationStateData copyWith({
    String? accountId,
    int? baselineEstablished,
  }) => NotificationStateData(
    accountId: accountId ?? this.accountId,
    baselineEstablished: baselineEstablished ?? this.baselineEstablished,
  );
  NotificationStateData copyWithCompanion(NotificationStateCompanion data) {
    return NotificationStateData(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      baselineEstablished: data.baselineEstablished.present
          ? data.baselineEstablished.value
          : this.baselineEstablished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationStateData(')
          ..write('accountId: $accountId, ')
          ..write('baselineEstablished: $baselineEstablished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, baselineEstablished);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationStateData &&
          other.accountId == this.accountId &&
          other.baselineEstablished == this.baselineEstablished);
}

class NotificationStateCompanion
    extends UpdateCompanion<NotificationStateData> {
  final Value<String> accountId;
  final Value<int> baselineEstablished;
  final Value<int> rowid;
  const NotificationStateCompanion({
    this.accountId = const Value.absent(),
    this.baselineEstablished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationStateCompanion.insert({
    required String accountId,
    required int baselineEstablished,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       baselineEstablished = Value(baselineEstablished);
  static Insertable<NotificationStateData> custom({
    Expression<String>? accountId,
    Expression<int>? baselineEstablished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'accountId': accountId,
      if (baselineEstablished != null)
        'baselineEstablished': baselineEstablished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationStateCompanion copyWith({
    Value<String>? accountId,
    Value<int>? baselineEstablished,
    Value<int>? rowid,
  }) {
    return NotificationStateCompanion(
      accountId: accountId ?? this.accountId,
      baselineEstablished: baselineEstablished ?? this.baselineEstablished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['accountId'] = Variable<String>(accountId.value);
    }
    if (baselineEstablished.present) {
      map['baselineEstablished'] = Variable<int>(baselineEstablished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationStateCompanion(')
          ..write('accountId: $accountId, ')
          ..write('baselineEstablished: $baselineEstablished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GlassMailDatabase extends GeneratedDatabase {
  _$GlassMailDatabase(QueryExecutor e) : super(e);
  $GlassMailDatabaseManager get managers => $GlassMailDatabaseManager(this);
  late final Accounts accounts = Accounts(this);
  late final Index indexAccountsEmail = Index(
    'index_accounts_email',
    'CREATE UNIQUE INDEX index_accounts_email ON accounts (email)',
  );
  late final Mailboxes mailboxes = Mailboxes(this);
  late final Index indexMailboxesAccountIdRemoteName = Index(
    'index_mailboxes_accountId_remoteName',
    'CREATE UNIQUE INDEX index_mailboxes_accountId_remoteName ON mailboxes (accountId, remoteName)',
  );
  late final Messages messages = Messages(this);
  late final Index indexMessagesAccountIdGmailMessageId = Index(
    'index_messages_accountId_gmailMessageId',
    'CREATE UNIQUE INDEX index_messages_accountId_gmailMessageId ON messages (accountId, gmailMessageId)',
  );
  late final Index indexMessagesAccountIdGmailThreadId = Index(
    'index_messages_accountId_gmailThreadId',
    'CREATE INDEX index_messages_accountId_gmailThreadId ON messages (accountId, gmailThreadId)',
  );
  late final Index indexMessagesAccountIdCategory = Index(
    'index_messages_accountId_category',
    'CREATE INDEX index_messages_accountId_category ON messages (accountId, category)',
  );
  late final MailboxMessages mailboxMessages = MailboxMessages(this);
  late final Index indexMailboxMessagesMessageId = Index(
    'index_mailbox_messages_messageId',
    'CREATE INDEX index_mailbox_messages_messageId ON mailbox_messages (messageId)',
  );
  late final Index indexMailboxMessagesMailboxIdUid = Index(
    'index_mailbox_messages_mailboxId_uid',
    'CREATE UNIQUE INDEX index_mailbox_messages_mailboxId_uid ON mailbox_messages (mailboxId, uid)',
  );
  late final MessageLabels messageLabels = MessageLabels(this);
  late final Index indexMessageLabelsLabel = Index(
    'index_message_labels_label',
    'CREATE INDEX index_message_labels_label ON message_labels (label)',
  );
  late final Attachments attachments = Attachments(this);
  late final Index indexAttachmentsMessageId = Index(
    'index_attachments_messageId',
    'CREATE INDEX index_attachments_messageId ON attachments (messageId)',
  );
  late final Index indexAttachmentsDownloadState = Index(
    'index_attachments_downloadState',
    'CREATE INDEX index_attachments_downloadState ON attachments (downloadState)',
  );
  late final CacheConfig cacheConfig = CacheConfig(this);
  late final StorageQuota storageQuota = StorageQuota(this);
  late final PendingMutations pendingMutations = PendingMutations(this);
  late final Index indexPendingMutationsAccountIdState = Index(
    'index_pending_mutations_accountId_state',
    'CREATE INDEX index_pending_mutations_accountId_state ON pending_mutations (accountId, state)',
  );
  late final Index indexPendingMutationsMessageIdState = Index(
    'index_pending_mutations_messageId_state',
    'CREATE INDEX index_pending_mutations_messageId_state ON pending_mutations (messageId, state)',
  );
  late final Index indexPendingMutationsMailboxId = Index(
    'index_pending_mutations_mailboxId',
    'CREATE INDEX index_pending_mutations_mailboxId ON pending_mutations (mailboxId)',
  );
  late final SyncCheckpoints syncCheckpoints = SyncCheckpoints(this);
  late final Index indexSyncCheckpointsAccountId = Index(
    'index_sync_checkpoints_accountId',
    'CREATE INDEX index_sync_checkpoints_accountId ON sync_checkpoints (accountId)',
  );
  late final Index indexSyncCheckpointsMailboxId = Index(
    'index_sync_checkpoints_mailboxId',
    'CREATE UNIQUE INDEX index_sync_checkpoints_mailboxId ON sync_checkpoints (mailboxId)',
  );
  late final Drafts drafts = Drafts(this);
  late final Index indexDraftsAccountIdUpdatedAtEpochMillis = Index(
    'index_drafts_accountId_updatedAtEpochMillis',
    'CREATE INDEX index_drafts_accountId_updatedAtEpochMillis ON drafts (accountId, updatedAtEpochMillis)',
  );
  late final NotificationState notificationState = NotificationState(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    indexAccountsEmail,
    mailboxes,
    indexMailboxesAccountIdRemoteName,
    messages,
    indexMessagesAccountIdGmailMessageId,
    indexMessagesAccountIdGmailThreadId,
    indexMessagesAccountIdCategory,
    mailboxMessages,
    indexMailboxMessagesMessageId,
    indexMailboxMessagesMailboxIdUid,
    messageLabels,
    indexMessageLabelsLabel,
    attachments,
    indexAttachmentsMessageId,
    indexAttachmentsDownloadState,
    cacheConfig,
    storageQuota,
    pendingMutations,
    indexPendingMutationsAccountIdState,
    indexPendingMutationsMessageIdState,
    indexPendingMutationsMailboxId,
    syncCheckpoints,
    indexSyncCheckpointsAccountId,
    indexSyncCheckpointsMailboxId,
    drafts,
    indexDraftsAccountIdUpdatedAtEpochMillis,
    notificationState,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mailboxes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mailboxes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mailbox_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mailbox_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pending_mutations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pending_mutations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mailboxes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_checkpoints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_checkpoints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('drafts', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $AccountsCreateCompanionBuilder =
    AccountsCompanion Function({
      required String accountId,
      required String email,
      required int createdAtEpochMillis,
      required String syncState,
      required int gmailExtensionsEnabled,
      Value<int?> lastSyncedAtEpochMillis,
      Value<int> rowid,
    });
typedef $AccountsUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> accountId,
      Value<String> email,
      Value<int> createdAtEpochMillis,
      Value<String> syncState,
      Value<int> gmailExtensionsEnabled,
      Value<int?> lastSyncedAtEpochMillis,
      Value<int> rowid,
    });

final class $AccountsReferences
    extends BaseReferences<_$GlassMailDatabase, Accounts, Account> {
  $AccountsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Mailboxes, List<Mailboxe>> _mailboxesRefsTable(
    _$GlassMailDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.mailboxes,
    aliasName: 'accounts__accountId__mailboxes__accountId',
  );

  $MailboxesProcessedTableManager get mailboxesRefs {
    final manager = $MailboxesTableManager($_db, $_db.mailboxes).filter(
      (f) =>
          f.accountId.accountId.sqlEquals($_itemColumn<String>('accountId')!),
    );

    final cache = $_typedResult.readTableOrNull(_mailboxesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Messages, List<Message>> _messagesRefsTable(
    _$GlassMailDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'accounts__accountId__messages__accountId',
  );

  $MessagesProcessedTableManager get messagesRefs {
    final manager = $MessagesTableManager($_db, $_db.messages).filter(
      (f) =>
          f.accountId.accountId.sqlEquals($_itemColumn<String>('accountId')!),
    );

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<PendingMutations, List<PendingMutation>>
  _pendingMutationsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pendingMutations,
        aliasName: 'accounts__accountId__pending_mutations__accountId',
      );

  $PendingMutationsProcessedTableManager get pendingMutationsRefs {
    final manager = $PendingMutationsTableManager($_db, $_db.pendingMutations)
        .filter(
          (f) => f.accountId.accountId.sqlEquals(
            $_itemColumn<String>('accountId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _pendingMutationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<SyncCheckpoints, List<SyncCheckpoint>>
  _syncCheckpointsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.syncCheckpoints,
        aliasName: 'accounts__accountId__sync_checkpoints__accountId',
      );

  $SyncCheckpointsProcessedTableManager get syncCheckpointsRefs {
    final manager = $SyncCheckpointsTableManager($_db, $_db.syncCheckpoints)
        .filter(
          (f) => f.accountId.accountId.sqlEquals(
            $_itemColumn<String>('accountId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _syncCheckpointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Drafts, List<Draft>> _draftsRefsTable(
    _$GlassMailDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.drafts,
    aliasName: 'accounts__accountId__drafts__accountId',
  );

  $DraftsProcessedTableManager get draftsRefs {
    final manager = $DraftsTableManager($_db, $_db.drafts).filter(
      (f) =>
          f.accountId.accountId.sqlEquals($_itemColumn<String>('accountId')!),
    );

    final cache = $_typedResult.readTableOrNull(_draftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $AccountsFilterComposer extends Composer<_$GlassMailDatabase, Accounts> {
  $AccountsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gmailExtensionsEnabled => $composableBuilder(
    column: $table.gmailExtensionsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAtEpochMillis => $composableBuilder(
    column: $table.lastSyncedAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mailboxesRefs(
    Expression<bool> Function($MailboxesFilterComposer f) f,
  ) {
    final $MailboxesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesFilterComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($MessagesFilterComposer f) f,
  ) {
    final $MessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingMutationsRefs(
    Expression<bool> Function($PendingMutationsFilterComposer f) f,
  ) {
    final $PendingMutationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PendingMutationsFilterComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncCheckpointsRefs(
    Expression<bool> Function($SyncCheckpointsFilterComposer f) f,
  ) {
    final $SyncCheckpointsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.syncCheckpoints,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncCheckpointsFilterComposer(
            $db: $db,
            $table: $db.syncCheckpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> draftsRefs(
    Expression<bool> Function($DraftsFilterComposer f) f,
  ) {
    final $DraftsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DraftsFilterComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $AccountsOrderingComposer
    extends Composer<_$GlassMailDatabase, Accounts> {
  $AccountsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gmailExtensionsEnabled => $composableBuilder(
    column: $table.gmailExtensionsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAtEpochMillis => $composableBuilder(
    column: $table.lastSyncedAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AccountsAnnotationComposer
    extends Composer<_$GlassMailDatabase, Accounts> {
  $AccountsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get gmailExtensionsEnabled => $composableBuilder(
    column: $table.gmailExtensionsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAtEpochMillis => $composableBuilder(
    column: $table.lastSyncedAtEpochMillis,
    builder: (column) => column,
  );

  Expression<T> mailboxesRefs<T extends Object>(
    Expression<T> Function($MailboxesAnnotationComposer a) f,
  ) {
    final $MailboxesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesAnnotationComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($MessagesAnnotationComposer a) f,
  ) {
    final $MessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pendingMutationsRefs<T extends Object>(
    Expression<T> Function($PendingMutationsAnnotationComposer a) f,
  ) {
    final $PendingMutationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PendingMutationsAnnotationComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncCheckpointsRefs<T extends Object>(
    Expression<T> Function($SyncCheckpointsAnnotationComposer a) f,
  ) {
    final $SyncCheckpointsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.syncCheckpoints,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncCheckpointsAnnotationComposer(
            $db: $db,
            $table: $db.syncCheckpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> draftsRefs<T extends Object>(
    Expression<T> Function($DraftsAnnotationComposer a) f,
  ) {
    final $DraftsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DraftsAnnotationComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $AccountsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          Accounts,
          Account,
          $AccountsFilterComposer,
          $AccountsOrderingComposer,
          $AccountsAnnotationComposer,
          $AccountsCreateCompanionBuilder,
          $AccountsUpdateCompanionBuilder,
          (Account, $AccountsReferences),
          Account,
          PrefetchHooks Function({
            bool mailboxesRefs,
            bool messagesRefs,
            bool pendingMutationsRefs,
            bool syncCheckpointsRefs,
            bool draftsRefs,
          })
        > {
  $AccountsTableManager(_$GlassMailDatabase db, Accounts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AccountsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AccountsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AccountsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int> createdAtEpochMillis = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> gmailExtensionsEnabled = const Value.absent(),
                Value<int?> lastSyncedAtEpochMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                accountId: accountId,
                email: email,
                createdAtEpochMillis: createdAtEpochMillis,
                syncState: syncState,
                gmailExtensionsEnabled: gmailExtensionsEnabled,
                lastSyncedAtEpochMillis: lastSyncedAtEpochMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String email,
                required int createdAtEpochMillis,
                required String syncState,
                required int gmailExtensionsEnabled,
                Value<int?> lastSyncedAtEpochMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                accountId: accountId,
                email: email,
                createdAtEpochMillis: createdAtEpochMillis,
                syncState: syncState,
                gmailExtensionsEnabled: gmailExtensionsEnabled,
                lastSyncedAtEpochMillis: lastSyncedAtEpochMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Accounts, Account>(table),
                  $AccountsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                mailboxesRefs = false,
                messagesRefs = false,
                pendingMutationsRefs = false,
                syncCheckpointsRefs = false,
                draftsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mailboxesRefs) db.mailboxes,
                    if (messagesRefs) db.messages,
                    if (pendingMutationsRefs) db.pendingMutations,
                    if (syncCheckpointsRefs) db.syncCheckpoints,
                    if (draftsRefs) db.drafts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mailboxesRefs)
                        await $_getPrefetchedData<Account, Accounts, Mailboxe>(
                          currentTable: table,
                          referencedTable: $AccountsReferences
                              ._mailboxesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $AccountsReferences(db, table, p0).mailboxesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.accountId,
                              ),
                          typedResults: items,
                        ),
                      if (messagesRefs)
                        await $_getPrefetchedData<Account, Accounts, Message>(
                          currentTable: table,
                          referencedTable: $AccountsReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $AccountsReferences(db, table, p0).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.accountId,
                              ),
                          typedResults: items,
                        ),
                      if (pendingMutationsRefs)
                        await $_getPrefetchedData<
                          Account,
                          Accounts,
                          PendingMutation
                        >(
                          currentTable: table,
                          referencedTable: $AccountsReferences
                              ._pendingMutationsRefsTable(db),
                          managerFromTypedResult: (p0) => $AccountsReferences(
                            db,
                            table,
                            p0,
                          ).pendingMutationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.accountId,
                              ),
                          typedResults: items,
                        ),
                      if (syncCheckpointsRefs)
                        await $_getPrefetchedData<
                          Account,
                          Accounts,
                          SyncCheckpoint
                        >(
                          currentTable: table,
                          referencedTable: $AccountsReferences
                              ._syncCheckpointsRefsTable(db),
                          managerFromTypedResult: (p0) => $AccountsReferences(
                            db,
                            table,
                            p0,
                          ).syncCheckpointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.accountId,
                              ),
                          typedResults: items,
                        ),
                      if (draftsRefs)
                        await $_getPrefetchedData<Account, Accounts, Draft>(
                          currentTable: table,
                          referencedTable: $AccountsReferences._draftsRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $AccountsReferences(db, table, p0).draftsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.accountId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $AccountsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      Accounts,
      Account,
      $AccountsFilterComposer,
      $AccountsOrderingComposer,
      $AccountsAnnotationComposer,
      $AccountsCreateCompanionBuilder,
      $AccountsUpdateCompanionBuilder,
      (Account, $AccountsReferences),
      Account,
      PrefetchHooks Function({
        bool mailboxesRefs,
        bool messagesRefs,
        bool pendingMutationsRefs,
        bool syncCheckpointsRefs,
        bool draftsRefs,
      })
    >;
typedef $MailboxesCreateCompanionBuilder =
    MailboxesCompanion Function({
      required String mailboxId,
      required String accountId,
      required String remoteName,
      required int uidValidity,
      required int uidNext,
      required int messageCount,
      Value<int> rowid,
    });
typedef $MailboxesUpdateCompanionBuilder =
    MailboxesCompanion Function({
      Value<String> mailboxId,
      Value<String> accountId,
      Value<String> remoteName,
      Value<int> uidValidity,
      Value<int> uidNext,
      Value<int> messageCount,
      Value<int> rowid,
    });

final class $MailboxesReferences
    extends BaseReferences<_$GlassMailDatabase, Mailboxes, Mailboxe> {
  $MailboxesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Accounts _accountIdTable(_$GlassMailDatabase db) =>
      db.accounts.createAlias('mailboxes__accountId__accounts__accountId');

  $AccountsProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('accountId')!;

    final manager = $AccountsTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.accountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<MailboxMessages, List<MailboxMessage>>
  _mailboxMessagesRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mailboxMessages,
        aliasName: 'mailboxes__mailboxId__mailbox_messages__mailboxId',
      );

  $MailboxMessagesProcessedTableManager get mailboxMessagesRefs {
    final manager = $MailboxMessagesTableManager($_db, $_db.mailboxMessages)
        .filter(
          (f) => f.mailboxId.mailboxId.sqlEquals(
            $_itemColumn<String>('mailboxId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _mailboxMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<SyncCheckpoints, List<SyncCheckpoint>>
  _syncCheckpointsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.syncCheckpoints,
        aliasName: 'mailboxes__mailboxId__sync_checkpoints__mailboxId',
      );

  $SyncCheckpointsProcessedTableManager get syncCheckpointsRefs {
    final manager = $SyncCheckpointsTableManager($_db, $_db.syncCheckpoints)
        .filter(
          (f) => f.mailboxId.mailboxId.sqlEquals(
            $_itemColumn<String>('mailboxId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _syncCheckpointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $MailboxesFilterComposer
    extends Composer<_$GlassMailDatabase, Mailboxes> {
  $MailboxesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mailboxId => $composableBuilder(
    column: $table.mailboxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  $AccountsFilterComposer get accountId {
    final $AccountsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mailboxMessagesRefs(
    Expression<bool> Function($MailboxMessagesFilterComposer f) f,
  ) {
    final $MailboxMessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxMessages,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxMessagesFilterComposer(
            $db: $db,
            $table: $db.mailboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncCheckpointsRefs(
    Expression<bool> Function($SyncCheckpointsFilterComposer f) f,
  ) {
    final $SyncCheckpointsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.syncCheckpoints,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncCheckpointsFilterComposer(
            $db: $db,
            $table: $db.syncCheckpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MailboxesOrderingComposer
    extends Composer<_$GlassMailDatabase, Mailboxes> {
  $MailboxesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mailboxId => $composableBuilder(
    column: $table.mailboxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  $AccountsOrderingComposer get accountId {
    final $AccountsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MailboxesAnnotationComposer
    extends Composer<_$GlassMailDatabase, Mailboxes> {
  $MailboxesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mailboxId =>
      $composableBuilder(column: $table.mailboxId, builder: (column) => column);

  GeneratedColumn<String> get remoteName => $composableBuilder(
    column: $table.remoteName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uidNext =>
      $composableBuilder(column: $table.uidNext, builder: (column) => column);

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  $AccountsAnnotationComposer get accountId {
    final $AccountsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mailboxMessagesRefs<T extends Object>(
    Expression<T> Function($MailboxMessagesAnnotationComposer a) f,
  ) {
    final $MailboxMessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxMessages,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxMessagesAnnotationComposer(
            $db: $db,
            $table: $db.mailboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncCheckpointsRefs<T extends Object>(
    Expression<T> Function($SyncCheckpointsAnnotationComposer a) f,
  ) {
    final $SyncCheckpointsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.syncCheckpoints,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncCheckpointsAnnotationComposer(
            $db: $db,
            $table: $db.syncCheckpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MailboxesTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          Mailboxes,
          Mailboxe,
          $MailboxesFilterComposer,
          $MailboxesOrderingComposer,
          $MailboxesAnnotationComposer,
          $MailboxesCreateCompanionBuilder,
          $MailboxesUpdateCompanionBuilder,
          (Mailboxe, $MailboxesReferences),
          Mailboxe,
          PrefetchHooks Function({
            bool accountId,
            bool mailboxMessagesRefs,
            bool syncCheckpointsRefs,
          })
        > {
  $MailboxesTableManager(_$GlassMailDatabase db, Mailboxes table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MailboxesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MailboxesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MailboxesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mailboxId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> remoteName = const Value.absent(),
                Value<int> uidValidity = const Value.absent(),
                Value<int> uidNext = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MailboxesCompanion(
                mailboxId: mailboxId,
                accountId: accountId,
                remoteName: remoteName,
                uidValidity: uidValidity,
                uidNext: uidNext,
                messageCount: messageCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mailboxId,
                required String accountId,
                required String remoteName,
                required int uidValidity,
                required int uidNext,
                required int messageCount,
                Value<int> rowid = const Value.absent(),
              }) => MailboxesCompanion.insert(
                mailboxId: mailboxId,
                accountId: accountId,
                remoteName: remoteName,
                uidValidity: uidValidity,
                uidNext: uidNext,
                messageCount: messageCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Mailboxes, Mailboxe>(table),
                  $MailboxesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                mailboxMessagesRefs = false,
                syncCheckpointsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mailboxMessagesRefs) db.mailboxMessages,
                    if (syncCheckpointsRefs) db.syncCheckpoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $MailboxesReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $MailboxesReferences
                                        ._accountIdTable(db)
                                        .accountId,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mailboxMessagesRefs)
                        await $_getPrefetchedData<
                          Mailboxe,
                          Mailboxes,
                          MailboxMessage
                        >(
                          currentTable: table,
                          referencedTable: $MailboxesReferences
                              ._mailboxMessagesRefsTable(db),
                          managerFromTypedResult: (p0) => $MailboxesReferences(
                            db,
                            table,
                            p0,
                          ).mailboxMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mailboxId == item.mailboxId,
                              ),
                          typedResults: items,
                        ),
                      if (syncCheckpointsRefs)
                        await $_getPrefetchedData<
                          Mailboxe,
                          Mailboxes,
                          SyncCheckpoint
                        >(
                          currentTable: table,
                          referencedTable: $MailboxesReferences
                              ._syncCheckpointsRefsTable(db),
                          managerFromTypedResult: (p0) => $MailboxesReferences(
                            db,
                            table,
                            p0,
                          ).syncCheckpointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mailboxId == item.mailboxId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $MailboxesProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      Mailboxes,
      Mailboxe,
      $MailboxesFilterComposer,
      $MailboxesOrderingComposer,
      $MailboxesAnnotationComposer,
      $MailboxesCreateCompanionBuilder,
      $MailboxesUpdateCompanionBuilder,
      (Mailboxe, $MailboxesReferences),
      Mailboxe,
      PrefetchHooks Function({
        bool accountId,
        bool mailboxMessagesRefs,
        bool syncCheckpointsRefs,
      })
    >;
typedef $MessagesCreateCompanionBuilder =
    MessagesCompanion Function({
      required String messageId,
      required String accountId,
      Value<String?> gmailMessageId,
      Value<String?> gmailThreadId,
      Value<String?> subject,
      Value<String?> sender,
      Value<int?> sentAtEpochMillis,
      Value<int?> sizeBytes,
      Value<String> category,
      Value<String?> preview,
      Value<String?> body,
      required String contentKind,
      required String bodyDownloadState,
      Value<String?> listUnsubscribe,
      Value<String?> listUnsubscribePost,
      Value<int> rowid,
    });
typedef $MessagesUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> messageId,
      Value<String> accountId,
      Value<String?> gmailMessageId,
      Value<String?> gmailThreadId,
      Value<String?> subject,
      Value<String?> sender,
      Value<int?> sentAtEpochMillis,
      Value<int?> sizeBytes,
      Value<String> category,
      Value<String?> preview,
      Value<String?> body,
      Value<String> contentKind,
      Value<String> bodyDownloadState,
      Value<String?> listUnsubscribe,
      Value<String?> listUnsubscribePost,
      Value<int> rowid,
    });

final class $MessagesReferences
    extends BaseReferences<_$GlassMailDatabase, Messages, Message> {
  $MessagesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Accounts _accountIdTable(_$GlassMailDatabase db) =>
      db.accounts.createAlias('messages__accountId__accounts__accountId');

  $AccountsProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('accountId')!;

    final manager = $AccountsTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.accountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<MailboxMessages, List<MailboxMessage>>
  _mailboxMessagesRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mailboxMessages,
        aliasName: 'messages__messageId__mailbox_messages__messageId',
      );

  $MailboxMessagesProcessedTableManager get mailboxMessagesRefs {
    final manager = $MailboxMessagesTableManager($_db, $_db.mailboxMessages)
        .filter(
          (f) => f.messageId.messageId.sqlEquals(
            $_itemColumn<String>('messageId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _mailboxMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<MessageLabels, List<MessageLabel>>
  _messageLabelsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.messageLabels,
        aliasName: 'messages__messageId__message_labels__messageId',
      );

  $MessageLabelsProcessedTableManager get messageLabelsRefs {
    final manager = $MessageLabelsTableManager($_db, $_db.messageLabels).filter(
      (f) =>
          f.messageId.messageId.sqlEquals($_itemColumn<String>('messageId')!),
    );

    final cache = $_typedResult.readTableOrNull(_messageLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Attachments, List<Attachment>>
  _attachmentsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attachments,
        aliasName: 'messages__messageId__attachments__messageId',
      );

  $AttachmentsProcessedTableManager get attachmentsRefs {
    final manager = $AttachmentsTableManager($_db, $_db.attachments).filter(
      (f) =>
          f.messageId.messageId.sqlEquals($_itemColumn<String>('messageId')!),
    );

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<PendingMutations, List<PendingMutation>>
  _pendingMutationsRefsTable(_$GlassMailDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pendingMutations,
        aliasName: 'messages__messageId__pending_mutations__messageId',
      );

  $PendingMutationsProcessedTableManager get pendingMutationsRefs {
    final manager = $PendingMutationsTableManager($_db, $_db.pendingMutations)
        .filter(
          (f) => f.messageId.messageId.sqlEquals(
            $_itemColumn<String>('messageId')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _pendingMutationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $MessagesFilterComposer extends Composer<_$GlassMailDatabase, Messages> {
  $MessagesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAtEpochMillis => $composableBuilder(
    column: $table.sentAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyDownloadState => $composableBuilder(
    column: $table.bodyDownloadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listUnsubscribe => $composableBuilder(
    column: $table.listUnsubscribe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listUnsubscribePost => $composableBuilder(
    column: $table.listUnsubscribePost,
    builder: (column) => ColumnFilters(column),
  );

  $AccountsFilterComposer get accountId {
    final $AccountsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mailboxMessagesRefs(
    Expression<bool> Function($MailboxMessagesFilterComposer f) f,
  ) {
    final $MailboxMessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.mailboxMessages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxMessagesFilterComposer(
            $db: $db,
            $table: $db.mailboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messageLabelsRefs(
    Expression<bool> Function($MessageLabelsFilterComposer f) f,
  ) {
    final $MessageLabelsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageLabels,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessageLabelsFilterComposer(
            $db: $db,
            $table: $db.messageLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($AttachmentsFilterComposer f) f,
  ) {
    final $AttachmentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AttachmentsFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pendingMutationsRefs(
    Expression<bool> Function($PendingMutationsFilterComposer f) f,
  ) {
    final $PendingMutationsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PendingMutationsFilterComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MessagesOrderingComposer
    extends Composer<_$GlassMailDatabase, Messages> {
  $MessagesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAtEpochMillis => $composableBuilder(
    column: $table.sentAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyDownloadState => $composableBuilder(
    column: $table.bodyDownloadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listUnsubscribe => $composableBuilder(
    column: $table.listUnsubscribe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listUnsubscribePost => $composableBuilder(
    column: $table.listUnsubscribePost,
    builder: (column) => ColumnOrderings(column),
  );

  $AccountsOrderingComposer get accountId {
    final $AccountsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessagesAnnotationComposer
    extends Composer<_$GlassMailDatabase, Messages> {
  $MessagesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get gmailMessageId => $composableBuilder(
    column: $table.gmailMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gmailThreadId => $composableBuilder(
    column: $table.gmailThreadId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<int> get sentAtEpochMillis => $composableBuilder(
    column: $table.sentAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get contentKind => $composableBuilder(
    column: $table.contentKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyDownloadState => $composableBuilder(
    column: $table.bodyDownloadState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get listUnsubscribe => $composableBuilder(
    column: $table.listUnsubscribe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get listUnsubscribePost => $composableBuilder(
    column: $table.listUnsubscribePost,
    builder: (column) => column,
  );

  $AccountsAnnotationComposer get accountId {
    final $AccountsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mailboxMessagesRefs<T extends Object>(
    Expression<T> Function($MailboxMessagesAnnotationComposer a) f,
  ) {
    final $MailboxMessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.mailboxMessages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxMessagesAnnotationComposer(
            $db: $db,
            $table: $db.mailboxMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messageLabelsRefs<T extends Object>(
    Expression<T> Function($MessageLabelsAnnotationComposer a) f,
  ) {
    final $MessageLabelsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messageLabels,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessageLabelsAnnotationComposer(
            $db: $db,
            $table: $db.messageLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($AttachmentsAnnotationComposer a) f,
  ) {
    final $AttachmentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AttachmentsAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pendingMutationsRefs<T extends Object>(
    Expression<T> Function($PendingMutationsAnnotationComposer a) f,
  ) {
    final $PendingMutationsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.pendingMutations,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PendingMutationsAnnotationComposer(
            $db: $db,
            $table: $db.pendingMutations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MessagesTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          Messages,
          Message,
          $MessagesFilterComposer,
          $MessagesOrderingComposer,
          $MessagesAnnotationComposer,
          $MessagesCreateCompanionBuilder,
          $MessagesUpdateCompanionBuilder,
          (Message, $MessagesReferences),
          Message,
          PrefetchHooks Function({
            bool accountId,
            bool mailboxMessagesRefs,
            bool messageLabelsRefs,
            bool attachmentsRefs,
            bool pendingMutationsRefs,
          })
        > {
  $MessagesTableManager(_$GlassMailDatabase db, Messages table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MessagesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MessagesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MessagesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> gmailMessageId = const Value.absent(),
                Value<String?> gmailThreadId = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> sender = const Value.absent(),
                Value<int?> sentAtEpochMillis = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> preview = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String> contentKind = const Value.absent(),
                Value<String> bodyDownloadState = const Value.absent(),
                Value<String?> listUnsubscribe = const Value.absent(),
                Value<String?> listUnsubscribePost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                messageId: messageId,
                accountId: accountId,
                gmailMessageId: gmailMessageId,
                gmailThreadId: gmailThreadId,
                subject: subject,
                sender: sender,
                sentAtEpochMillis: sentAtEpochMillis,
                sizeBytes: sizeBytes,
                category: category,
                preview: preview,
                body: body,
                contentKind: contentKind,
                bodyDownloadState: bodyDownloadState,
                listUnsubscribe: listUnsubscribe,
                listUnsubscribePost: listUnsubscribePost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String accountId,
                Value<String?> gmailMessageId = const Value.absent(),
                Value<String?> gmailThreadId = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> sender = const Value.absent(),
                Value<int?> sentAtEpochMillis = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> preview = const Value.absent(),
                Value<String?> body = const Value.absent(),
                required String contentKind,
                required String bodyDownloadState,
                Value<String?> listUnsubscribe = const Value.absent(),
                Value<String?> listUnsubscribePost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                messageId: messageId,
                accountId: accountId,
                gmailMessageId: gmailMessageId,
                gmailThreadId: gmailThreadId,
                subject: subject,
                sender: sender,
                sentAtEpochMillis: sentAtEpochMillis,
                sizeBytes: sizeBytes,
                category: category,
                preview: preview,
                body: body,
                contentKind: contentKind,
                bodyDownloadState: bodyDownloadState,
                listUnsubscribe: listUnsubscribe,
                listUnsubscribePost: listUnsubscribePost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Messages, Message>(table),
                  $MessagesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                mailboxMessagesRefs = false,
                messageLabelsRefs = false,
                attachmentsRefs = false,
                pendingMutationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mailboxMessagesRefs) db.mailboxMessages,
                    if (messageLabelsRefs) db.messageLabels,
                    if (attachmentsRefs) db.attachments,
                    if (pendingMutationsRefs) db.pendingMutations,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (accountId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.accountId,
                                    referencedTable: $MessagesReferences
                                        ._accountIdTable(db),
                                    referencedColumn: $MessagesReferences
                                        ._accountIdTable(db)
                                        .accountId,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mailboxMessagesRefs)
                        await $_getPrefetchedData<
                          Message,
                          Messages,
                          MailboxMessage
                        >(
                          currentTable: table,
                          referencedTable: $MessagesReferences
                              ._mailboxMessagesRefsTable(db),
                          managerFromTypedResult: (p0) => $MessagesReferences(
                            db,
                            table,
                            p0,
                          ).mailboxMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.messageId,
                              ),
                          typedResults: items,
                        ),
                      if (messageLabelsRefs)
                        await $_getPrefetchedData<
                          Message,
                          Messages,
                          MessageLabel
                        >(
                          currentTable: table,
                          referencedTable: $MessagesReferences
                              ._messageLabelsRefsTable(db),
                          managerFromTypedResult: (p0) => $MessagesReferences(
                            db,
                            table,
                            p0,
                          ).messageLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.messageId,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Message,
                          Messages,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $MessagesReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) => $MessagesReferences(
                            db,
                            table,
                            p0,
                          ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.messageId,
                              ),
                          typedResults: items,
                        ),
                      if (pendingMutationsRefs)
                        await $_getPrefetchedData<
                          Message,
                          Messages,
                          PendingMutation
                        >(
                          currentTable: table,
                          referencedTable: $MessagesReferences
                              ._pendingMutationsRefsTable(db),
                          managerFromTypedResult: (p0) => $MessagesReferences(
                            db,
                            table,
                            p0,
                          ).pendingMutationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.messageId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $MessagesProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      Messages,
      Message,
      $MessagesFilterComposer,
      $MessagesOrderingComposer,
      $MessagesAnnotationComposer,
      $MessagesCreateCompanionBuilder,
      $MessagesUpdateCompanionBuilder,
      (Message, $MessagesReferences),
      Message,
      PrefetchHooks Function({
        bool accountId,
        bool mailboxMessagesRefs,
        bool messageLabelsRefs,
        bool attachmentsRefs,
        bool pendingMutationsRefs,
      })
    >;
typedef $MailboxMessagesCreateCompanionBuilder =
    MailboxMessagesCompanion Function({
      required String mailboxId,
      required int uid,
      required String messageId,
      required String flags,
      required String labels,
      Value<int> rowid,
    });
typedef $MailboxMessagesUpdateCompanionBuilder =
    MailboxMessagesCompanion Function({
      Value<String> mailboxId,
      Value<int> uid,
      Value<String> messageId,
      Value<String> flags,
      Value<String> labels,
      Value<int> rowid,
    });

final class $MailboxMessagesReferences
    extends
        BaseReferences<_$GlassMailDatabase, MailboxMessages, MailboxMessage> {
  $MailboxMessagesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Mailboxes _mailboxIdTable(_$GlassMailDatabase db) => db.mailboxes
      .createAlias('mailbox_messages__mailboxId__mailboxes__mailboxId');

  $MailboxesProcessedTableManager get mailboxId {
    final $_column = $_itemColumn<String>('mailboxId')!;

    final manager = $MailboxesTableManager(
      $_db,
      $_db.mailboxes,
    ).filter((f) => f.mailboxId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mailboxIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Messages _messageIdTable(_$GlassMailDatabase db) => db.messages
      .createAlias('mailbox_messages__messageId__messages__messageId');

  $MessagesProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('messageId')!;

    final manager = $MessagesTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.messageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $MailboxMessagesFilterComposer
    extends Composer<_$GlassMailDatabase, MailboxMessages> {
  $MailboxMessagesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnFilters(column),
  );

  $MailboxesFilterComposer get mailboxId {
    final $MailboxesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesFilterComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesFilterComposer get messageId {
    final $MessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MailboxMessagesOrderingComposer
    extends Composer<_$GlassMailDatabase, MailboxMessages> {
  $MailboxMessagesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flags => $composableBuilder(
    column: $table.flags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnOrderings(column),
  );

  $MailboxesOrderingComposer get mailboxId {
    final $MailboxesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesOrderingComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesOrderingComposer get messageId {
    final $MessagesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MailboxMessagesAnnotationComposer
    extends Composer<_$GlassMailDatabase, MailboxMessages> {
  $MailboxMessagesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get flags =>
      $composableBuilder(column: $table.flags, builder: (column) => column);

  GeneratedColumn<String> get labels =>
      $composableBuilder(column: $table.labels, builder: (column) => column);

  $MailboxesAnnotationComposer get mailboxId {
    final $MailboxesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesAnnotationComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesAnnotationComposer get messageId {
    final $MessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MailboxMessagesTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          MailboxMessages,
          MailboxMessage,
          $MailboxMessagesFilterComposer,
          $MailboxMessagesOrderingComposer,
          $MailboxMessagesAnnotationComposer,
          $MailboxMessagesCreateCompanionBuilder,
          $MailboxMessagesUpdateCompanionBuilder,
          (MailboxMessage, $MailboxMessagesReferences),
          MailboxMessage,
          PrefetchHooks Function({bool mailboxId, bool messageId})
        > {
  $MailboxMessagesTableManager(_$GlassMailDatabase db, MailboxMessages table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MailboxMessagesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MailboxMessagesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MailboxMessagesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mailboxId = const Value.absent(),
                Value<int> uid = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> flags = const Value.absent(),
                Value<String> labels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MailboxMessagesCompanion(
                mailboxId: mailboxId,
                uid: uid,
                messageId: messageId,
                flags: flags,
                labels: labels,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mailboxId,
                required int uid,
                required String messageId,
                required String flags,
                required String labels,
                Value<int> rowid = const Value.absent(),
              }) => MailboxMessagesCompanion.insert(
                mailboxId: mailboxId,
                uid: uid,
                messageId: messageId,
                flags: flags,
                labels: labels,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MailboxMessages, MailboxMessage>(table),
                  $MailboxMessagesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mailboxId = false, messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mailboxId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mailboxId,
                                referencedTable: $MailboxMessagesReferences
                                    ._mailboxIdTable(db),
                                referencedColumn: $MailboxMessagesReferences
                                    ._mailboxIdTable(db)
                                    .mailboxId,
                              )
                              as T;
                    }
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $MailboxMessagesReferences
                                    ._messageIdTable(db),
                                referencedColumn: $MailboxMessagesReferences
                                    ._messageIdTable(db)
                                    .messageId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MailboxMessagesProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      MailboxMessages,
      MailboxMessage,
      $MailboxMessagesFilterComposer,
      $MailboxMessagesOrderingComposer,
      $MailboxMessagesAnnotationComposer,
      $MailboxMessagesCreateCompanionBuilder,
      $MailboxMessagesUpdateCompanionBuilder,
      (MailboxMessage, $MailboxMessagesReferences),
      MailboxMessage,
      PrefetchHooks Function({bool mailboxId, bool messageId})
    >;
typedef $MessageLabelsCreateCompanionBuilder =
    MessageLabelsCompanion Function({
      required String messageId,
      required String label,
      Value<int> rowid,
    });
typedef $MessageLabelsUpdateCompanionBuilder =
    MessageLabelsCompanion Function({
      Value<String> messageId,
      Value<String> label,
      Value<int> rowid,
    });

final class $MessageLabelsReferences
    extends BaseReferences<_$GlassMailDatabase, MessageLabels, MessageLabel> {
  $MessageLabelsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Messages _messageIdTable(_$GlassMailDatabase db) =>
      db.messages.createAlias('message_labels__messageId__messages__messageId');

  $MessagesProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('messageId')!;

    final manager = $MessagesTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.messageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $MessageLabelsFilterComposer
    extends Composer<_$GlassMailDatabase, MessageLabels> {
  $MessageLabelsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  $MessagesFilterComposer get messageId {
    final $MessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageLabelsOrderingComposer
    extends Composer<_$GlassMailDatabase, MessageLabels> {
  $MessageLabelsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  $MessagesOrderingComposer get messageId {
    final $MessagesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageLabelsAnnotationComposer
    extends Composer<_$GlassMailDatabase, MessageLabels> {
  $MessageLabelsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $MessagesAnnotationComposer get messageId {
    final $MessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MessageLabelsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          MessageLabels,
          MessageLabel,
          $MessageLabelsFilterComposer,
          $MessageLabelsOrderingComposer,
          $MessageLabelsAnnotationComposer,
          $MessageLabelsCreateCompanionBuilder,
          $MessageLabelsUpdateCompanionBuilder,
          (MessageLabel, $MessageLabelsReferences),
          MessageLabel,
          PrefetchHooks Function({bool messageId})
        > {
  $MessageLabelsTableManager(_$GlassMailDatabase db, MessageLabels table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MessageLabelsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MessageLabelsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MessageLabelsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageLabelsCompanion(
                messageId: messageId,
                label: label,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String label,
                Value<int> rowid = const Value.absent(),
              }) => MessageLabelsCompanion.insert(
                messageId: messageId,
                label: label,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MessageLabels, MessageLabel>(table),
                  $MessageLabelsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $MessageLabelsReferences
                                    ._messageIdTable(db),
                                referencedColumn: $MessageLabelsReferences
                                    ._messageIdTable(db)
                                    .messageId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MessageLabelsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      MessageLabels,
      MessageLabel,
      $MessageLabelsFilterComposer,
      $MessageLabelsOrderingComposer,
      $MessageLabelsAnnotationComposer,
      $MessageLabelsCreateCompanionBuilder,
      $MessageLabelsUpdateCompanionBuilder,
      (MessageLabel, $MessageLabelsReferences),
      MessageLabel,
      PrefetchHooks Function({bool messageId})
    >;
typedef $AttachmentsCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String attachmentId,
      required String messageId,
      required String partId,
      Value<String?> fileName,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      required String downloadState,
      Value<int> lastAccessedAtEpochMillis,
      Value<int> rowid,
    });
typedef $AttachmentsUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> attachmentId,
      Value<String> messageId,
      Value<String> partId,
      Value<String?> fileName,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<String> downloadState,
      Value<int> lastAccessedAtEpochMillis,
      Value<int> rowid,
    });

final class $AttachmentsReferences
    extends BaseReferences<_$GlassMailDatabase, Attachments, Attachment> {
  $AttachmentsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Messages _messageIdTable(_$GlassMailDatabase db) =>
      db.messages.createAlias('attachments__messageId__messages__messageId');

  $MessagesProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('messageId')!;

    final manager = $MessagesTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.messageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $AttachmentsFilterComposer
    extends Composer<_$GlassMailDatabase, Attachments> {
  $AttachmentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAtEpochMillis => $composableBuilder(
    column: $table.lastAccessedAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  $MessagesFilterComposer get messageId {
    final $MessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AttachmentsOrderingComposer
    extends Composer<_$GlassMailDatabase, Attachments> {
  $AttachmentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAtEpochMillis => $composableBuilder(
    column: $table.lastAccessedAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  $MessagesOrderingComposer get messageId {
    final $MessagesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AttachmentsAnnotationComposer
    extends Composer<_$GlassMailDatabase, Attachments> {
  $AttachmentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get downloadState => $composableBuilder(
    column: $table.downloadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAccessedAtEpochMillis => $composableBuilder(
    column: $table.lastAccessedAtEpochMillis,
    builder: (column) => column,
  );

  $MessagesAnnotationComposer get messageId {
    final $MessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AttachmentsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          Attachments,
          Attachment,
          $AttachmentsFilterComposer,
          $AttachmentsOrderingComposer,
          $AttachmentsAnnotationComposer,
          $AttachmentsCreateCompanionBuilder,
          $AttachmentsUpdateCompanionBuilder,
          (Attachment, $AttachmentsReferences),
          Attachment,
          PrefetchHooks Function({bool messageId})
        > {
  $AttachmentsTableManager(_$GlassMailDatabase db, Attachments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AttachmentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AttachmentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AttachmentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> attachmentId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String> downloadState = const Value.absent(),
                Value<int> lastAccessedAtEpochMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                attachmentId: attachmentId,
                messageId: messageId,
                partId: partId,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                downloadState: downloadState,
                lastAccessedAtEpochMillis: lastAccessedAtEpochMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String attachmentId,
                required String messageId,
                required String partId,
                Value<String?> fileName = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                required String downloadState,
                Value<int> lastAccessedAtEpochMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                attachmentId: attachmentId,
                messageId: messageId,
                partId: partId,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                downloadState: downloadState,
                lastAccessedAtEpochMillis: lastAccessedAtEpochMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Attachments, Attachment>(table),
                  $AttachmentsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $AttachmentsReferences
                                    ._messageIdTable(db),
                                referencedColumn: $AttachmentsReferences
                                    ._messageIdTable(db)
                                    .messageId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $AttachmentsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      Attachments,
      Attachment,
      $AttachmentsFilterComposer,
      $AttachmentsOrderingComposer,
      $AttachmentsAnnotationComposer,
      $AttachmentsCreateCompanionBuilder,
      $AttachmentsUpdateCompanionBuilder,
      (Attachment, $AttachmentsReferences),
      Attachment,
      PrefetchHooks Function({bool messageId})
    >;
typedef $CacheConfigCreateCompanionBuilder =
    CacheConfigCompanion Function({
      required String accountId,
      Value<int> offlineMessageCount,
      Value<int> attachmentCacheLimitMb,
      Value<int> autoEvictReadOlderThanDays,
      Value<int> prefetchUnreadBodies,
      Value<int> rowid,
    });
typedef $CacheConfigUpdateCompanionBuilder =
    CacheConfigCompanion Function({
      Value<String> accountId,
      Value<int> offlineMessageCount,
      Value<int> attachmentCacheLimitMb,
      Value<int> autoEvictReadOlderThanDays,
      Value<int> prefetchUnreadBodies,
      Value<int> rowid,
    });

class $CacheConfigFilterComposer
    extends Composer<_$GlassMailDatabase, CacheConfig> {
  $CacheConfigFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offlineMessageCount => $composableBuilder(
    column: $table.offlineMessageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attachmentCacheLimitMb => $composableBuilder(
    column: $table.attachmentCacheLimitMb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoEvictReadOlderThanDays => $composableBuilder(
    column: $table.autoEvictReadOlderThanDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prefetchUnreadBodies => $composableBuilder(
    column: $table.prefetchUnreadBodies,
    builder: (column) => ColumnFilters(column),
  );
}

class $CacheConfigOrderingComposer
    extends Composer<_$GlassMailDatabase, CacheConfig> {
  $CacheConfigOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offlineMessageCount => $composableBuilder(
    column: $table.offlineMessageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attachmentCacheLimitMb => $composableBuilder(
    column: $table.attachmentCacheLimitMb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoEvictReadOlderThanDays => $composableBuilder(
    column: $table.autoEvictReadOlderThanDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prefetchUnreadBodies => $composableBuilder(
    column: $table.prefetchUnreadBodies,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CacheConfigAnnotationComposer
    extends Composer<_$GlassMailDatabase, CacheConfig> {
  $CacheConfigAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get offlineMessageCount => $composableBuilder(
    column: $table.offlineMessageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attachmentCacheLimitMb => $composableBuilder(
    column: $table.attachmentCacheLimitMb,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoEvictReadOlderThanDays => $composableBuilder(
    column: $table.autoEvictReadOlderThanDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prefetchUnreadBodies => $composableBuilder(
    column: $table.prefetchUnreadBodies,
    builder: (column) => column,
  );
}

class $CacheConfigTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          CacheConfig,
          CacheConfigData,
          $CacheConfigFilterComposer,
          $CacheConfigOrderingComposer,
          $CacheConfigAnnotationComposer,
          $CacheConfigCreateCompanionBuilder,
          $CacheConfigUpdateCompanionBuilder,
          (
            CacheConfigData,
            BaseReferences<_$GlassMailDatabase, CacheConfig, CacheConfigData>,
          ),
          CacheConfigData,
          PrefetchHooks Function()
        > {
  $CacheConfigTableManager(_$GlassMailDatabase db, CacheConfig table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CacheConfigFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CacheConfigOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CacheConfigAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<int> offlineMessageCount = const Value.absent(),
                Value<int> attachmentCacheLimitMb = const Value.absent(),
                Value<int> autoEvictReadOlderThanDays = const Value.absent(),
                Value<int> prefetchUnreadBodies = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheConfigCompanion(
                accountId: accountId,
                offlineMessageCount: offlineMessageCount,
                attachmentCacheLimitMb: attachmentCacheLimitMb,
                autoEvictReadOlderThanDays: autoEvictReadOlderThanDays,
                prefetchUnreadBodies: prefetchUnreadBodies,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                Value<int> offlineMessageCount = const Value.absent(),
                Value<int> attachmentCacheLimitMb = const Value.absent(),
                Value<int> autoEvictReadOlderThanDays = const Value.absent(),
                Value<int> prefetchUnreadBodies = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheConfigCompanion.insert(
                accountId: accountId,
                offlineMessageCount: offlineMessageCount,
                attachmentCacheLimitMb: attachmentCacheLimitMb,
                autoEvictReadOlderThanDays: autoEvictReadOlderThanDays,
                prefetchUnreadBodies: prefetchUnreadBodies,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<CacheConfig, CacheConfigData>(table),
                  BaseReferences<
                    _$GlassMailDatabase,
                    CacheConfig,
                    CacheConfigData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CacheConfigProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      CacheConfig,
      CacheConfigData,
      $CacheConfigFilterComposer,
      $CacheConfigOrderingComposer,
      $CacheConfigAnnotationComposer,
      $CacheConfigCreateCompanionBuilder,
      $CacheConfigUpdateCompanionBuilder,
      (
        CacheConfigData,
        BaseReferences<_$GlassMailDatabase, CacheConfig, CacheConfigData>,
      ),
      CacheConfigData,
      PrefetchHooks Function()
    >;
typedef $StorageQuotaCreateCompanionBuilder =
    StorageQuotaCompanion Function({
      required String accountId,
      required int usedKb,
      required int limitKb,
      required int checkedAtEpochMillis,
      Value<int> rowid,
    });
typedef $StorageQuotaUpdateCompanionBuilder =
    StorageQuotaCompanion Function({
      Value<String> accountId,
      Value<int> usedKb,
      Value<int> limitKb,
      Value<int> checkedAtEpochMillis,
      Value<int> rowid,
    });

class $StorageQuotaFilterComposer
    extends Composer<_$GlassMailDatabase, StorageQuota> {
  $StorageQuotaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedKb => $composableBuilder(
    column: $table.usedKb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitKb => $composableBuilder(
    column: $table.limitKb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAtEpochMillis => $composableBuilder(
    column: $table.checkedAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $StorageQuotaOrderingComposer
    extends Composer<_$GlassMailDatabase, StorageQuota> {
  $StorageQuotaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedKb => $composableBuilder(
    column: $table.usedKb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitKb => $composableBuilder(
    column: $table.limitKb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAtEpochMillis => $composableBuilder(
    column: $table.checkedAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $StorageQuotaAnnotationComposer
    extends Composer<_$GlassMailDatabase, StorageQuota> {
  $StorageQuotaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get usedKb =>
      $composableBuilder(column: $table.usedKb, builder: (column) => column);

  GeneratedColumn<int> get limitKb =>
      $composableBuilder(column: $table.limitKb, builder: (column) => column);

  GeneratedColumn<int> get checkedAtEpochMillis => $composableBuilder(
    column: $table.checkedAtEpochMillis,
    builder: (column) => column,
  );
}

class $StorageQuotaTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          StorageQuota,
          StorageQuotaData,
          $StorageQuotaFilterComposer,
          $StorageQuotaOrderingComposer,
          $StorageQuotaAnnotationComposer,
          $StorageQuotaCreateCompanionBuilder,
          $StorageQuotaUpdateCompanionBuilder,
          (
            StorageQuotaData,
            BaseReferences<_$GlassMailDatabase, StorageQuota, StorageQuotaData>,
          ),
          StorageQuotaData,
          PrefetchHooks Function()
        > {
  $StorageQuotaTableManager(_$GlassMailDatabase db, StorageQuota table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $StorageQuotaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $StorageQuotaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $StorageQuotaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<int> usedKb = const Value.absent(),
                Value<int> limitKb = const Value.absent(),
                Value<int> checkedAtEpochMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageQuotaCompanion(
                accountId: accountId,
                usedKb: usedKb,
                limitKb: limitKb,
                checkedAtEpochMillis: checkedAtEpochMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required int usedKb,
                required int limitKb,
                required int checkedAtEpochMillis,
                Value<int> rowid = const Value.absent(),
              }) => StorageQuotaCompanion.insert(
                accountId: accountId,
                usedKb: usedKb,
                limitKb: limitKb,
                checkedAtEpochMillis: checkedAtEpochMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<StorageQuota, StorageQuotaData>(table),
                  BaseReferences<
                    _$GlassMailDatabase,
                    StorageQuota,
                    StorageQuotaData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $StorageQuotaProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      StorageQuota,
      StorageQuotaData,
      $StorageQuotaFilterComposer,
      $StorageQuotaOrderingComposer,
      $StorageQuotaAnnotationComposer,
      $StorageQuotaCreateCompanionBuilder,
      $StorageQuotaUpdateCompanionBuilder,
      (
        StorageQuotaData,
        BaseReferences<_$GlassMailDatabase, StorageQuota, StorageQuotaData>,
      ),
      StorageQuotaData,
      PrefetchHooks Function()
    >;
typedef $PendingMutationsCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      required String mutationId,
      required String accountId,
      Value<String?> mailboxId,
      required String messageId,
      Value<int?> targetUid,
      required String type,
      Value<String?> payload,
      required String state,
      required int retryCount,
      required int createdAtEpochMillis,
      Value<String?> lastErrorCode,
      Value<String> previousFlags,
      Value<String> previousLabels,
      Value<int> rowid,
    });
typedef $PendingMutationsUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<String> mutationId,
      Value<String> accountId,
      Value<String?> mailboxId,
      Value<String> messageId,
      Value<int?> targetUid,
      Value<String> type,
      Value<String?> payload,
      Value<String> state,
      Value<int> retryCount,
      Value<int> createdAtEpochMillis,
      Value<String?> lastErrorCode,
      Value<String> previousFlags,
      Value<String> previousLabels,
      Value<int> rowid,
    });

final class $PendingMutationsReferences
    extends
        BaseReferences<_$GlassMailDatabase, PendingMutations, PendingMutation> {
  $PendingMutationsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Accounts _accountIdTable(_$GlassMailDatabase db) => db.accounts
      .createAlias('pending_mutations__accountId__accounts__accountId');

  $AccountsProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('accountId')!;

    final manager = $AccountsTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.accountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Messages _messageIdTable(_$GlassMailDatabase db) => db.messages
      .createAlias('pending_mutations__messageId__messages__messageId');

  $MessagesProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('messageId')!;

    final manager = $MessagesTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.messageId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $PendingMutationsFilterComposer
    extends Composer<_$GlassMailDatabase, PendingMutations> {
  $PendingMutationsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mailboxId => $composableBuilder(
    column: $table.mailboxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetUid => $composableBuilder(
    column: $table.targetUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousFlags => $composableBuilder(
    column: $table.previousFlags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousLabels => $composableBuilder(
    column: $table.previousLabels,
    builder: (column) => ColumnFilters(column),
  );

  $AccountsFilterComposer get accountId {
    final $AccountsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesFilterComposer get messageId {
    final $MessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PendingMutationsOrderingComposer
    extends Composer<_$GlassMailDatabase, PendingMutations> {
  $PendingMutationsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mailboxId => $composableBuilder(
    column: $table.mailboxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetUid => $composableBuilder(
    column: $table.targetUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousFlags => $composableBuilder(
    column: $table.previousFlags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousLabels => $composableBuilder(
    column: $table.previousLabels,
    builder: (column) => ColumnOrderings(column),
  );

  $AccountsOrderingComposer get accountId {
    final $AccountsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesOrderingComposer get messageId {
    final $MessagesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PendingMutationsAnnotationComposer
    extends Composer<_$GlassMailDatabase, PendingMutations> {
  $PendingMutationsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mailboxId =>
      $composableBuilder(column: $table.mailboxId, builder: (column) => column);

  GeneratedColumn<int> get targetUid =>
      $composableBuilder(column: $table.targetUid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousFlags => $composableBuilder(
    column: $table.previousFlags,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previousLabels => $composableBuilder(
    column: $table.previousLabels,
    builder: (column) => column,
  );

  $AccountsAnnotationComposer get accountId {
    final $AccountsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MessagesAnnotationComposer get messageId {
    final $MessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MessagesAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PendingMutationsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          PendingMutations,
          PendingMutation,
          $PendingMutationsFilterComposer,
          $PendingMutationsOrderingComposer,
          $PendingMutationsAnnotationComposer,
          $PendingMutationsCreateCompanionBuilder,
          $PendingMutationsUpdateCompanionBuilder,
          (PendingMutation, $PendingMutationsReferences),
          PendingMutation,
          PrefetchHooks Function({bool accountId, bool messageId})
        > {
  $PendingMutationsTableManager(_$GlassMailDatabase db, PendingMutations table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PendingMutationsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PendingMutationsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PendingMutationsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mutationId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> mailboxId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<int?> targetUid = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> createdAtEpochMillis = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String> previousFlags = const Value.absent(),
                Value<String> previousLabels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion(
                mutationId: mutationId,
                accountId: accountId,
                mailboxId: mailboxId,
                messageId: messageId,
                targetUid: targetUid,
                type: type,
                payload: payload,
                state: state,
                retryCount: retryCount,
                createdAtEpochMillis: createdAtEpochMillis,
                lastErrorCode: lastErrorCode,
                previousFlags: previousFlags,
                previousLabels: previousLabels,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mutationId,
                required String accountId,
                Value<String?> mailboxId = const Value.absent(),
                required String messageId,
                Value<int?> targetUid = const Value.absent(),
                required String type,
                Value<String?> payload = const Value.absent(),
                required String state,
                required int retryCount,
                required int createdAtEpochMillis,
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String> previousFlags = const Value.absent(),
                Value<String> previousLabels = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion.insert(
                mutationId: mutationId,
                accountId: accountId,
                mailboxId: mailboxId,
                messageId: messageId,
                targetUid: targetUid,
                type: type,
                payload: payload,
                state: state,
                retryCount: retryCount,
                createdAtEpochMillis: createdAtEpochMillis,
                lastErrorCode: lastErrorCode,
                previousFlags: previousFlags,
                previousLabels: previousLabels,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PendingMutations, PendingMutation>(table),
                  $PendingMutationsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $PendingMutationsReferences
                                    ._accountIdTable(db),
                                referencedColumn: $PendingMutationsReferences
                                    ._accountIdTable(db)
                                    .accountId,
                              )
                              as T;
                    }
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $PendingMutationsReferences
                                    ._messageIdTable(db),
                                referencedColumn: $PendingMutationsReferences
                                    ._messageIdTable(db)
                                    .messageId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $PendingMutationsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      PendingMutations,
      PendingMutation,
      $PendingMutationsFilterComposer,
      $PendingMutationsOrderingComposer,
      $PendingMutationsAnnotationComposer,
      $PendingMutationsCreateCompanionBuilder,
      $PendingMutationsUpdateCompanionBuilder,
      (PendingMutation, $PendingMutationsReferences),
      PendingMutation,
      PrefetchHooks Function({bool accountId, bool messageId})
    >;
typedef $SyncCheckpointsCreateCompanionBuilder =
    SyncCheckpointsCompanion Function({
      required String mailboxId,
      required String accountId,
      required int uidValidity,
      required int highestKnownUid,
      required int syncGeneration,
      Value<int?> lastSuccessfulSyncEpochMillis,
      Value<int> rowid,
    });
typedef $SyncCheckpointsUpdateCompanionBuilder =
    SyncCheckpointsCompanion Function({
      Value<String> mailboxId,
      Value<String> accountId,
      Value<int> uidValidity,
      Value<int> highestKnownUid,
      Value<int> syncGeneration,
      Value<int?> lastSuccessfulSyncEpochMillis,
      Value<int> rowid,
    });

final class $SyncCheckpointsReferences
    extends
        BaseReferences<_$GlassMailDatabase, SyncCheckpoints, SyncCheckpoint> {
  $SyncCheckpointsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Mailboxes _mailboxIdTable(_$GlassMailDatabase db) => db.mailboxes
      .createAlias('sync_checkpoints__mailboxId__mailboxes__mailboxId');

  $MailboxesProcessedTableManager get mailboxId {
    final $_column = $_itemColumn<String>('mailboxId')!;

    final manager = $MailboxesTableManager(
      $_db,
      $_db.mailboxes,
    ).filter((f) => f.mailboxId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mailboxIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Accounts _accountIdTable(_$GlassMailDatabase db) => db.accounts
      .createAlias('sync_checkpoints__accountId__accounts__accountId');

  $AccountsProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('accountId')!;

    final manager = $AccountsTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.accountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $SyncCheckpointsFilterComposer
    extends Composer<_$GlassMailDatabase, SyncCheckpoints> {
  $SyncCheckpointsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestKnownUid => $composableBuilder(
    column: $table.highestKnownUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncGeneration => $composableBuilder(
    column: $table.syncGeneration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessfulSyncEpochMillis => $composableBuilder(
    column: $table.lastSuccessfulSyncEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  $MailboxesFilterComposer get mailboxId {
    final $MailboxesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesFilterComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $AccountsFilterComposer get accountId {
    final $AccountsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncCheckpointsOrderingComposer
    extends Composer<_$GlassMailDatabase, SyncCheckpoints> {
  $SyncCheckpointsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestKnownUid => $composableBuilder(
    column: $table.highestKnownUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncGeneration => $composableBuilder(
    column: $table.syncGeneration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessfulSyncEpochMillis => $composableBuilder(
    column: $table.lastSuccessfulSyncEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  $MailboxesOrderingComposer get mailboxId {
    final $MailboxesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesOrderingComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $AccountsOrderingComposer get accountId {
    final $AccountsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncCheckpointsAnnotationComposer
    extends Composer<_$GlassMailDatabase, SyncCheckpoints> {
  $SyncCheckpointsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestKnownUid => $composableBuilder(
    column: $table.highestKnownUid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncGeneration => $composableBuilder(
    column: $table.syncGeneration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSuccessfulSyncEpochMillis => $composableBuilder(
    column: $table.lastSuccessfulSyncEpochMillis,
    builder: (column) => column,
  );

  $MailboxesAnnotationComposer get mailboxId {
    final $MailboxesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mailboxId,
      referencedTable: $db.mailboxes,
      getReferencedColumn: (t) => t.mailboxId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MailboxesAnnotationComposer(
            $db: $db,
            $table: $db.mailboxes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $AccountsAnnotationComposer get accountId {
    final $AccountsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncCheckpointsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          SyncCheckpoints,
          SyncCheckpoint,
          $SyncCheckpointsFilterComposer,
          $SyncCheckpointsOrderingComposer,
          $SyncCheckpointsAnnotationComposer,
          $SyncCheckpointsCreateCompanionBuilder,
          $SyncCheckpointsUpdateCompanionBuilder,
          (SyncCheckpoint, $SyncCheckpointsReferences),
          SyncCheckpoint,
          PrefetchHooks Function({bool mailboxId, bool accountId})
        > {
  $SyncCheckpointsTableManager(_$GlassMailDatabase db, SyncCheckpoints table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncCheckpointsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncCheckpointsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncCheckpointsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mailboxId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> uidValidity = const Value.absent(),
                Value<int> highestKnownUid = const Value.absent(),
                Value<int> syncGeneration = const Value.absent(),
                Value<int?> lastSuccessfulSyncEpochMillis =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCheckpointsCompanion(
                mailboxId: mailboxId,
                accountId: accountId,
                uidValidity: uidValidity,
                highestKnownUid: highestKnownUid,
                syncGeneration: syncGeneration,
                lastSuccessfulSyncEpochMillis: lastSuccessfulSyncEpochMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mailboxId,
                required String accountId,
                required int uidValidity,
                required int highestKnownUid,
                required int syncGeneration,
                Value<int?> lastSuccessfulSyncEpochMillis =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCheckpointsCompanion.insert(
                mailboxId: mailboxId,
                accountId: accountId,
                uidValidity: uidValidity,
                highestKnownUid: highestKnownUid,
                syncGeneration: syncGeneration,
                lastSuccessfulSyncEpochMillis: lastSuccessfulSyncEpochMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncCheckpoints, SyncCheckpoint>(table),
                  $SyncCheckpointsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mailboxId = false, accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mailboxId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mailboxId,
                                referencedTable: $SyncCheckpointsReferences
                                    ._mailboxIdTable(db),
                                referencedColumn: $SyncCheckpointsReferences
                                    ._mailboxIdTable(db)
                                    .mailboxId,
                              )
                              as T;
                    }
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $SyncCheckpointsReferences
                                    ._accountIdTable(db),
                                referencedColumn: $SyncCheckpointsReferences
                                    ._accountIdTable(db)
                                    .accountId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $SyncCheckpointsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      SyncCheckpoints,
      SyncCheckpoint,
      $SyncCheckpointsFilterComposer,
      $SyncCheckpointsOrderingComposer,
      $SyncCheckpointsAnnotationComposer,
      $SyncCheckpointsCreateCompanionBuilder,
      $SyncCheckpointsUpdateCompanionBuilder,
      (SyncCheckpoint, $SyncCheckpointsReferences),
      SyncCheckpoint,
      PrefetchHooks Function({bool mailboxId, bool accountId})
    >;
typedef $DraftsCreateCompanionBuilder =
    DraftsCompanion Function({
      required String draftId,
      required String accountId,
      required String toAddresses,
      required String ccAddresses,
      required String bccAddresses,
      required String subject,
      required String body,
      Value<String?> inReplyTo,
      required String references,
      required String status,
      required int updatedAtEpochMillis,
      required String attachments,
      Value<int> rowid,
    });
typedef $DraftsUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<String> draftId,
      Value<String> accountId,
      Value<String> toAddresses,
      Value<String> ccAddresses,
      Value<String> bccAddresses,
      Value<String> subject,
      Value<String> body,
      Value<String?> inReplyTo,
      Value<String> references,
      Value<String> status,
      Value<int> updatedAtEpochMillis,
      Value<String> attachments,
      Value<int> rowid,
    });

final class $DraftsReferences
    extends BaseReferences<_$GlassMailDatabase, Drafts, Draft> {
  $DraftsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Accounts _accountIdTable(_$GlassMailDatabase db) =>
      db.accounts.createAlias('drafts__accountId__accounts__accountId');

  $AccountsProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('accountId')!;

    final manager = $AccountsTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.accountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DraftsFilterComposer extends Composer<_$GlassMailDatabase, Drafts> {
  $DraftsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAddresses => $composableBuilder(
    column: $table.toAddresses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccAddresses => $composableBuilder(
    column: $table.ccAddresses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bccAddresses => $composableBuilder(
    column: $table.bccAddresses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMillis => $composableBuilder(
    column: $table.updatedAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  $AccountsFilterComposer get accountId {
    final $AccountsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsOrderingComposer extends Composer<_$GlassMailDatabase, Drafts> {
  $DraftsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAddresses => $composableBuilder(
    column: $table.toAddresses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccAddresses => $composableBuilder(
    column: $table.ccAddresses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bccAddresses => $composableBuilder(
    column: $table.bccAddresses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMillis => $composableBuilder(
    column: $table.updatedAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  $AccountsOrderingComposer get accountId {
    final $AccountsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsAnnotationComposer extends Composer<_$GlassMailDatabase, Drafts> {
  $DraftsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get toAddresses => $composableBuilder(
    column: $table.toAddresses,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ccAddresses => $composableBuilder(
    column: $table.ccAddresses,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bccAddresses => $composableBuilder(
    column: $table.bccAddresses,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get inReplyTo =>
      $composableBuilder(column: $table.inReplyTo, builder: (column) => column);

  GeneratedColumn<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get updatedAtEpochMillis => $composableBuilder(
    column: $table.updatedAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  $AccountsAnnotationComposer get accountId {
    final $AccountsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AccountsAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DraftsTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          Drafts,
          Draft,
          $DraftsFilterComposer,
          $DraftsOrderingComposer,
          $DraftsAnnotationComposer,
          $DraftsCreateCompanionBuilder,
          $DraftsUpdateCompanionBuilder,
          (Draft, $DraftsReferences),
          Draft,
          PrefetchHooks Function({bool accountId})
        > {
  $DraftsTableManager(_$GlassMailDatabase db, Drafts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DraftsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DraftsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DraftsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> draftId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> toAddresses = const Value.absent(),
                Value<String> ccAddresses = const Value.absent(),
                Value<String> bccAddresses = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String> references = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> updatedAtEpochMillis = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                draftId: draftId,
                accountId: accountId,
                toAddresses: toAddresses,
                ccAddresses: ccAddresses,
                bccAddresses: bccAddresses,
                subject: subject,
                body: body,
                inReplyTo: inReplyTo,
                references: references,
                status: status,
                updatedAtEpochMillis: updatedAtEpochMillis,
                attachments: attachments,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String draftId,
                required String accountId,
                required String toAddresses,
                required String ccAddresses,
                required String bccAddresses,
                required String subject,
                required String body,
                Value<String?> inReplyTo = const Value.absent(),
                required String references,
                required String status,
                required int updatedAtEpochMillis,
                required String attachments,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                draftId: draftId,
                accountId: accountId,
                toAddresses: toAddresses,
                ccAddresses: ccAddresses,
                bccAddresses: bccAddresses,
                subject: subject,
                body: body,
                inReplyTo: inReplyTo,
                references: references,
                status: status,
                updatedAtEpochMillis: updatedAtEpochMillis,
                attachments: attachments,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Drafts, Draft>(table),
                  $DraftsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $DraftsReferences
                                    ._accountIdTable(db),
                                referencedColumn: $DraftsReferences
                                    ._accountIdTable(db)
                                    .accountId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DraftsProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      Drafts,
      Draft,
      $DraftsFilterComposer,
      $DraftsOrderingComposer,
      $DraftsAnnotationComposer,
      $DraftsCreateCompanionBuilder,
      $DraftsUpdateCompanionBuilder,
      (Draft, $DraftsReferences),
      Draft,
      PrefetchHooks Function({bool accountId})
    >;
typedef $NotificationStateCreateCompanionBuilder =
    NotificationStateCompanion Function({
      required String accountId,
      required int baselineEstablished,
      Value<int> rowid,
    });
typedef $NotificationStateUpdateCompanionBuilder =
    NotificationStateCompanion Function({
      Value<String> accountId,
      Value<int> baselineEstablished,
      Value<int> rowid,
    });

class $NotificationStateFilterComposer
    extends Composer<_$GlassMailDatabase, NotificationState> {
  $NotificationStateFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baselineEstablished => $composableBuilder(
    column: $table.baselineEstablished,
    builder: (column) => ColumnFilters(column),
  );
}

class $NotificationStateOrderingComposer
    extends Composer<_$GlassMailDatabase, NotificationState> {
  $NotificationStateOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baselineEstablished => $composableBuilder(
    column: $table.baselineEstablished,
    builder: (column) => ColumnOrderings(column),
  );
}

class $NotificationStateAnnotationComposer
    extends Composer<_$GlassMailDatabase, NotificationState> {
  $NotificationStateAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get baselineEstablished => $composableBuilder(
    column: $table.baselineEstablished,
    builder: (column) => column,
  );
}

class $NotificationStateTableManager
    extends
        RootTableManager<
          _$GlassMailDatabase,
          NotificationState,
          NotificationStateData,
          $NotificationStateFilterComposer,
          $NotificationStateOrderingComposer,
          $NotificationStateAnnotationComposer,
          $NotificationStateCreateCompanionBuilder,
          $NotificationStateUpdateCompanionBuilder,
          (
            NotificationStateData,
            BaseReferences<
              _$GlassMailDatabase,
              NotificationState,
              NotificationStateData
            >,
          ),
          NotificationStateData,
          PrefetchHooks Function()
        > {
  $NotificationStateTableManager(
    _$GlassMailDatabase db,
    NotificationState table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $NotificationStateFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $NotificationStateOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $NotificationStateAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<int> baselineEstablished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationStateCompanion(
                accountId: accountId,
                baselineEstablished: baselineEstablished,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required int baselineEstablished,
                Value<int> rowid = const Value.absent(),
              }) => NotificationStateCompanion.insert(
                accountId: accountId,
                baselineEstablished: baselineEstablished,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<NotificationState, NotificationStateData>(table),
                  BaseReferences<
                    _$GlassMailDatabase,
                    NotificationState,
                    NotificationStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $NotificationStateProcessedTableManager =
    ProcessedTableManager<
      _$GlassMailDatabase,
      NotificationState,
      NotificationStateData,
      $NotificationStateFilterComposer,
      $NotificationStateOrderingComposer,
      $NotificationStateAnnotationComposer,
      $NotificationStateCreateCompanionBuilder,
      $NotificationStateUpdateCompanionBuilder,
      (
        NotificationStateData,
        BaseReferences<
          _$GlassMailDatabase,
          NotificationState,
          NotificationStateData
        >,
      ),
      NotificationStateData,
      PrefetchHooks Function()
    >;

class $GlassMailDatabaseManager {
  final _$GlassMailDatabase _db;
  $GlassMailDatabaseManager(this._db);
  $AccountsTableManager get accounts =>
      $AccountsTableManager(_db, _db.accounts);
  $MailboxesTableManager get mailboxes =>
      $MailboxesTableManager(_db, _db.mailboxes);
  $MessagesTableManager get messages =>
      $MessagesTableManager(_db, _db.messages);
  $MailboxMessagesTableManager get mailboxMessages =>
      $MailboxMessagesTableManager(_db, _db.mailboxMessages);
  $MessageLabelsTableManager get messageLabels =>
      $MessageLabelsTableManager(_db, _db.messageLabels);
  $AttachmentsTableManager get attachments =>
      $AttachmentsTableManager(_db, _db.attachments);
  $CacheConfigTableManager get cacheConfig =>
      $CacheConfigTableManager(_db, _db.cacheConfig);
  $StorageQuotaTableManager get storageQuota =>
      $StorageQuotaTableManager(_db, _db.storageQuota);
  $PendingMutationsTableManager get pendingMutations =>
      $PendingMutationsTableManager(_db, _db.pendingMutations);
  $SyncCheckpointsTableManager get syncCheckpoints =>
      $SyncCheckpointsTableManager(_db, _db.syncCheckpoints);
  $DraftsTableManager get drafts => $DraftsTableManager(_db, _db.drafts);
  $NotificationStateTableManager get notificationState =>
      $NotificationStateTableManager(_db, _db.notificationState);
}
