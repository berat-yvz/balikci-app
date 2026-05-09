// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalSpotsTable extends LocalSpots
    with TableInfo<$LocalSpotsTable, LocalSpot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSpotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privacyLevelMeta = const VerificationMeta(
    'privacyLevel',
  );
  @override
  late final GeneratedColumn<String> privacyLevel = GeneratedColumn<String>(
    'privacy_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _muhtarIdMeta = const VerificationMeta(
    'muhtarId',
  );
  @override
  late final GeneratedColumn<String> muhtarId = GeneratedColumn<String>(
    'muhtar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    lat,
    lng,
    type,
    privacyLevel,
    description,
    verified,
    muhtarId,
    isSynced,
    createdAt,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_spots';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSpot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('privacy_level')) {
      context.handle(
        _privacyLevelMeta,
        privacyLevel.isAcceptableOrUnknown(
          data['privacy_level']!,
          _privacyLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_privacyLevelMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    }
    if (data.containsKey('muhtar_id')) {
      context.handle(
        _muhtarIdMeta,
        muhtarId.isAcceptableOrUnknown(data['muhtar_id']!, _muhtarIdMeta),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSpot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSpot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      privacyLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}privacy_level'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      muhtarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muhtar_id'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $LocalSpotsTable createAlias(String alias) {
    return $LocalSpotsTable(attachedDatabase, alias);
  }
}

class LocalSpot extends DataClass implements Insertable<LocalSpot> {
  final String id;
  final String userId;
  final String name;
  final double lat;
  final double lng;
  final String? type;
  final String privacyLevel;
  final String? description;
  final bool verified;
  final String? muhtarId;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime cachedAt;
  const LocalSpot({
    required this.id,
    required this.userId,
    required this.name,
    required this.lat,
    required this.lng,
    this.type,
    required this.privacyLevel,
    this.description,
    required this.verified,
    this.muhtarId,
    required this.isSynced,
    required this.createdAt,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    map['privacy_level'] = Variable<String>(privacyLevel);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['verified'] = Variable<bool>(verified);
    if (!nullToAbsent || muhtarId != null) {
      map['muhtar_id'] = Variable<String>(muhtarId);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalSpotsCompanion toCompanion(bool nullToAbsent) {
    return LocalSpotsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      lat: Value(lat),
      lng: Value(lng),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      privacyLevel: Value(privacyLevel),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      verified: Value(verified),
      muhtarId: muhtarId == null && nullToAbsent
          ? const Value.absent()
          : Value(muhtarId),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalSpot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSpot(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      type: serializer.fromJson<String?>(json['type']),
      privacyLevel: serializer.fromJson<String>(json['privacyLevel']),
      description: serializer.fromJson<String?>(json['description']),
      verified: serializer.fromJson<bool>(json['verified']),
      muhtarId: serializer.fromJson<String?>(json['muhtarId']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'type': serializer.toJson<String?>(type),
      'privacyLevel': serializer.toJson<String>(privacyLevel),
      'description': serializer.toJson<String?>(description),
      'verified': serializer.toJson<bool>(verified),
      'muhtarId': serializer.toJson<String?>(muhtarId),
      'isSynced': serializer.toJson<bool>(isSynced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalSpot copyWith({
    String? id,
    String? userId,
    String? name,
    double? lat,
    double? lng,
    Value<String?> type = const Value.absent(),
    String? privacyLevel,
    Value<String?> description = const Value.absent(),
    bool? verified,
    Value<String?> muhtarId = const Value.absent(),
    bool? isSynced,
    DateTime? createdAt,
    DateTime? cachedAt,
  }) => LocalSpot(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    type: type.present ? type.value : this.type,
    privacyLevel: privacyLevel ?? this.privacyLevel,
    description: description.present ? description.value : this.description,
    verified: verified ?? this.verified,
    muhtarId: muhtarId.present ? muhtarId.value : this.muhtarId,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  LocalSpot copyWithCompanion(LocalSpotsCompanion data) {
    return LocalSpot(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      type: data.type.present ? data.type.value : this.type,
      privacyLevel: data.privacyLevel.present
          ? data.privacyLevel.value
          : this.privacyLevel,
      description: data.description.present
          ? data.description.value
          : this.description,
      verified: data.verified.present ? data.verified.value : this.verified,
      muhtarId: data.muhtarId.present ? data.muhtarId.value : this.muhtarId,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSpot(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('type: $type, ')
          ..write('privacyLevel: $privacyLevel, ')
          ..write('description: $description, ')
          ..write('verified: $verified, ')
          ..write('muhtarId: $muhtarId, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    lat,
    lng,
    type,
    privacyLevel,
    description,
    verified,
    muhtarId,
    isSynced,
    createdAt,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSpot &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.type == this.type &&
          other.privacyLevel == this.privacyLevel &&
          other.description == this.description &&
          other.verified == this.verified &&
          other.muhtarId == this.muhtarId &&
          other.isSynced == this.isSynced &&
          other.createdAt == this.createdAt &&
          other.cachedAt == this.cachedAt);
}

class LocalSpotsCompanion extends UpdateCompanion<LocalSpot> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> type;
  final Value<String> privacyLevel;
  final Value<String?> description;
  final Value<bool> verified;
  final Value<String?> muhtarId;
  final Value<bool> isSynced;
  final Value<DateTime> createdAt;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const LocalSpotsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.type = const Value.absent(),
    this.privacyLevel = const Value.absent(),
    this.description = const Value.absent(),
    this.verified = const Value.absent(),
    this.muhtarId = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSpotsCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required double lat,
    required double lng,
    this.type = const Value.absent(),
    required String privacyLevel,
    this.description = const Value.absent(),
    this.verified = const Value.absent(),
    this.muhtarId = const Value.absent(),
    this.isSynced = const Value.absent(),
    required DateTime createdAt,
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       lat = Value(lat),
       lng = Value(lng),
       privacyLevel = Value(privacyLevel),
       createdAt = Value(createdAt);
  static Insertable<LocalSpot> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? type,
    Expression<String>? privacyLevel,
    Expression<String>? description,
    Expression<bool>? verified,
    Expression<String>? muhtarId,
    Expression<bool>? isSynced,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (type != null) 'type': type,
      if (privacyLevel != null) 'privacy_level': privacyLevel,
      if (description != null) 'description': description,
      if (verified != null) 'verified': verified,
      if (muhtarId != null) 'muhtar_id': muhtarId,
      if (isSynced != null) 'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSpotsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? type,
    Value<String>? privacyLevel,
    Value<String?>? description,
    Value<bool>? verified,
    Value<String?>? muhtarId,
    Value<bool>? isSynced,
    Value<DateTime>? createdAt,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return LocalSpotsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      type: type ?? this.type,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      description: description ?? this.description,
      verified: verified ?? this.verified,
      muhtarId: muhtarId ?? this.muhtarId,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (privacyLevel.present) {
      map['privacy_level'] = Variable<String>(privacyLevel.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (muhtarId.present) {
      map['muhtar_id'] = Variable<String>(muhtarId.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSpotsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('type: $type, ')
          ..write('privacyLevel: $privacyLevel, ')
          ..write('description: $description, ')
          ..write('verified: $verified, ')
          ..write('muhtarId: $muhtarId, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tableNameValueMeta = const VerificationMeta(
    'tableNameValue',
  );
  @override
  late final GeneratedColumn<String> tableNameValue = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operation,
    tableNameValue,
    payload,
    retryCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tableNameValueMeta,
        tableNameValue.isAcceptableOrUnknown(
          data['table_name']!,
          _tableNameValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tableNameValueMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      tableNameValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String operation;
  final String tableNameValue;
  final String payload;
  final int retryCount;
  final DateTime createdAt;
  const SyncQueueData({
    required this.id,
    required this.operation,
    required this.tableNameValue,
    required this.payload,
    required this.retryCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation'] = Variable<String>(operation);
    map['table_name'] = Variable<String>(tableNameValue);
    map['payload'] = Variable<String>(payload);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      operation: Value(operation),
      tableNameValue: Value(tableNameValue),
      payload: Value(payload),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      tableNameValue: serializer.fromJson<String>(json['tableNameValue']),
      payload: serializer.fromJson<String>(json['payload']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation': serializer.toJson<String>(operation),
      'tableNameValue': serializer.toJson<String>(tableNameValue),
      'payload': serializer.toJson<String>(payload),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? operation,
    String? tableNameValue,
    String? payload,
    int? retryCount,
    DateTime? createdAt,
  }) => SyncQueueData(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    tableNameValue: tableNameValue ?? this.tableNameValue,
    payload: payload ?? this.payload,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      tableNameValue: data.tableNameValue.present
          ? data.tableNameValue.value
          : this.tableNameValue,
      payload: data.payload.present ? data.payload.value : this.payload,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('tableNameValue: $tableNameValue, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operation,
    tableNameValue,
    payload,
    retryCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.tableNameValue == this.tableNameValue &&
          other.payload == this.payload &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> operation;
  final Value<String> tableNameValue;
  final Value<String> payload;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.tableNameValue = const Value.absent(),
    this.payload = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String operation,
    required String tableNameValue,
    required String payload,
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : operation = Value(operation),
       tableNameValue = Value(tableNameValue),
       payload = Value(payload);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? operation,
    Expression<String>? tableNameValue,
    Expression<String>? payload,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (tableNameValue != null) 'table_name': tableNameValue,
      if (payload != null) 'payload': payload,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? operation,
    Value<String>? tableNameValue,
    Value<String>? payload,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      tableNameValue: tableNameValue ?? this.tableNameValue,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (tableNameValue.present) {
      map['table_name'] = Variable<String>(tableNameValue.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('tableNameValue: $tableNameValue, ')
          ..write('payload: $payload, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalWeatherTable extends LocalWeather
    with TableInfo<$LocalWeatherTable, LocalWeatherData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWeatherTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _regionKeyMeta = const VerificationMeta(
    'regionKey',
  );
  @override
  late final GeneratedColumn<String> regionKey = GeneratedColumn<String>(
    'region_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempCMeta = const VerificationMeta('tempC');
  @override
  late final GeneratedColumn<double> tempC = GeneratedColumn<double>(
    'temp_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _windSpeedKmhMeta = const VerificationMeta(
    'windSpeedKmh',
  );
  @override
  late final GeneratedColumn<double> windSpeedKmh = GeneratedColumn<double>(
    'wind_speed_kmh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waveHeightMMeta = const VerificationMeta(
    'waveHeightM',
  );
  @override
  late final GeneratedColumn<double> waveHeightM = GeneratedColumn<double>(
    'wave_height_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _humidityMeta = const VerificationMeta(
    'humidity',
  );
  @override
  late final GeneratedColumn<double> humidity = GeneratedColumn<double>(
    'humidity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windDirectionMeta = const VerificationMeta(
    'windDirection',
  );
  @override
  late final GeneratedColumn<int> windDirection = GeneratedColumn<int>(
    'wind_direction',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudCoverMeta = const VerificationMeta(
    'cloudCover',
  );
  @override
  late final GeneratedColumn<double> cloudCover = GeneratedColumn<double>(
    'cloud_cover',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visibilityKmMeta = const VerificationMeta(
    'visibilityKm',
  );
  @override
  late final GeneratedColumn<double> visibilityKm = GeneratedColumn<double>(
    'visibility_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _precipitationMeta = const VerificationMeta(
    'precipitation',
  );
  @override
  late final GeneratedColumn<double> precipitation = GeneratedColumn<double>(
    'precipitation',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seaSurfaceTemperatureMeta =
      const VerificationMeta('seaSurfaceTemperature');
  @override
  late final GeneratedColumn<double> seaSurfaceTemperature =
      GeneratedColumn<double>(
        'sea_surface_temperature',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pressureHpaMeta = const VerificationMeta(
    'pressureHpa',
  );
  @override
  late final GeneratedColumn<double> pressureHpa = GeneratedColumn<double>(
    'pressure_hpa',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    regionKey,
    tempC,
    windSpeedKmh,
    waveHeightM,
    humidity,
    cachedAt,
    windDirection,
    cloudCover,
    visibilityKm,
    precipitation,
    seaSurfaceTemperature,
    pressureHpa,
    dataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_weather';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWeatherData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('region_key')) {
      context.handle(
        _regionKeyMeta,
        regionKey.isAcceptableOrUnknown(data['region_key']!, _regionKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_regionKeyMeta);
    }
    if (data.containsKey('temp_c')) {
      context.handle(
        _tempCMeta,
        tempC.isAcceptableOrUnknown(data['temp_c']!, _tempCMeta),
      );
    }
    if (data.containsKey('wind_speed_kmh')) {
      context.handle(
        _windSpeedKmhMeta,
        windSpeedKmh.isAcceptableOrUnknown(
          data['wind_speed_kmh']!,
          _windSpeedKmhMeta,
        ),
      );
    }
    if (data.containsKey('wave_height_m')) {
      context.handle(
        _waveHeightMMeta,
        waveHeightM.isAcceptableOrUnknown(
          data['wave_height_m']!,
          _waveHeightMMeta,
        ),
      );
    }
    if (data.containsKey('humidity')) {
      context.handle(
        _humidityMeta,
        humidity.isAcceptableOrUnknown(data['humidity']!, _humidityMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('wind_direction')) {
      context.handle(
        _windDirectionMeta,
        windDirection.isAcceptableOrUnknown(
          data['wind_direction']!,
          _windDirectionMeta,
        ),
      );
    }
    if (data.containsKey('cloud_cover')) {
      context.handle(
        _cloudCoverMeta,
        cloudCover.isAcceptableOrUnknown(data['cloud_cover']!, _cloudCoverMeta),
      );
    }
    if (data.containsKey('visibility_km')) {
      context.handle(
        _visibilityKmMeta,
        visibilityKm.isAcceptableOrUnknown(
          data['visibility_km']!,
          _visibilityKmMeta,
        ),
      );
    }
    if (data.containsKey('precipitation')) {
      context.handle(
        _precipitationMeta,
        precipitation.isAcceptableOrUnknown(
          data['precipitation']!,
          _precipitationMeta,
        ),
      );
    }
    if (data.containsKey('sea_surface_temperature')) {
      context.handle(
        _seaSurfaceTemperatureMeta,
        seaSurfaceTemperature.isAcceptableOrUnknown(
          data['sea_surface_temperature']!,
          _seaSurfaceTemperatureMeta,
        ),
      );
    }
    if (data.containsKey('pressure_hpa')) {
      context.handle(
        _pressureHpaMeta,
        pressureHpa.isAcceptableOrUnknown(
          data['pressure_hpa']!,
          _pressureHpaMeta,
        ),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {regionKey};
  @override
  LocalWeatherData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWeatherData(
      regionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_key'],
      )!,
      tempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_c'],
      ),
      windSpeedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wind_speed_kmh'],
      ),
      waveHeightM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wave_height_m'],
      ),
      humidity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}humidity'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      windDirection: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wind_direction'],
      ),
      cloudCover: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cloud_cover'],
      ),
      visibilityKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}visibility_km'],
      ),
      precipitation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}precipitation'],
      ),
      seaSurfaceTemperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sea_surface_temperature'],
      ),
      pressureHpa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure_hpa'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      ),
    );
  }

  @override
  $LocalWeatherTable createAlias(String alias) {
    return $LocalWeatherTable(attachedDatabase, alias);
  }
}

class LocalWeatherData extends DataClass
    implements Insertable<LocalWeatherData> {
  final String regionKey;
  final double? tempC;
  final double? windSpeedKmh;
  final double? waveHeightM;
  final double? humidity;
  final DateTime cachedAt;
  final int? windDirection;
  final double? cloudCover;
  final double? visibilityKm;
  final double? precipitation;
  final double? seaSurfaceTemperature;
  final double? pressureHpa;
  final String? dataJson;
  const LocalWeatherData({
    required this.regionKey,
    this.tempC,
    this.windSpeedKmh,
    this.waveHeightM,
    this.humidity,
    required this.cachedAt,
    this.windDirection,
    this.cloudCover,
    this.visibilityKm,
    this.precipitation,
    this.seaSurfaceTemperature,
    this.pressureHpa,
    this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['region_key'] = Variable<String>(regionKey);
    if (!nullToAbsent || tempC != null) {
      map['temp_c'] = Variable<double>(tempC);
    }
    if (!nullToAbsent || windSpeedKmh != null) {
      map['wind_speed_kmh'] = Variable<double>(windSpeedKmh);
    }
    if (!nullToAbsent || waveHeightM != null) {
      map['wave_height_m'] = Variable<double>(waveHeightM);
    }
    if (!nullToAbsent || humidity != null) {
      map['humidity'] = Variable<double>(humidity);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    if (!nullToAbsent || windDirection != null) {
      map['wind_direction'] = Variable<int>(windDirection);
    }
    if (!nullToAbsent || cloudCover != null) {
      map['cloud_cover'] = Variable<double>(cloudCover);
    }
    if (!nullToAbsent || visibilityKm != null) {
      map['visibility_km'] = Variable<double>(visibilityKm);
    }
    if (!nullToAbsent || precipitation != null) {
      map['precipitation'] = Variable<double>(precipitation);
    }
    if (!nullToAbsent || seaSurfaceTemperature != null) {
      map['sea_surface_temperature'] = Variable<double>(seaSurfaceTemperature);
    }
    if (!nullToAbsent || pressureHpa != null) {
      map['pressure_hpa'] = Variable<double>(pressureHpa);
    }
    if (!nullToAbsent || dataJson != null) {
      map['data_json'] = Variable<String>(dataJson);
    }
    return map;
  }

  LocalWeatherCompanion toCompanion(bool nullToAbsent) {
    return LocalWeatherCompanion(
      regionKey: Value(regionKey),
      tempC: tempC == null && nullToAbsent
          ? const Value.absent()
          : Value(tempC),
      windSpeedKmh: windSpeedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(windSpeedKmh),
      waveHeightM: waveHeightM == null && nullToAbsent
          ? const Value.absent()
          : Value(waveHeightM),
      humidity: humidity == null && nullToAbsent
          ? const Value.absent()
          : Value(humidity),
      cachedAt: Value(cachedAt),
      windDirection: windDirection == null && nullToAbsent
          ? const Value.absent()
          : Value(windDirection),
      cloudCover: cloudCover == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudCover),
      visibilityKm: visibilityKm == null && nullToAbsent
          ? const Value.absent()
          : Value(visibilityKm),
      precipitation: precipitation == null && nullToAbsent
          ? const Value.absent()
          : Value(precipitation),
      seaSurfaceTemperature: seaSurfaceTemperature == null && nullToAbsent
          ? const Value.absent()
          : Value(seaSurfaceTemperature),
      pressureHpa: pressureHpa == null && nullToAbsent
          ? const Value.absent()
          : Value(pressureHpa),
      dataJson: dataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(dataJson),
    );
  }

  factory LocalWeatherData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWeatherData(
      regionKey: serializer.fromJson<String>(json['regionKey']),
      tempC: serializer.fromJson<double?>(json['tempC']),
      windSpeedKmh: serializer.fromJson<double?>(json['windSpeedKmh']),
      waveHeightM: serializer.fromJson<double?>(json['waveHeightM']),
      humidity: serializer.fromJson<double?>(json['humidity']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      windDirection: serializer.fromJson<int?>(json['windDirection']),
      cloudCover: serializer.fromJson<double?>(json['cloudCover']),
      visibilityKm: serializer.fromJson<double?>(json['visibilityKm']),
      precipitation: serializer.fromJson<double?>(json['precipitation']),
      seaSurfaceTemperature: serializer.fromJson<double?>(
        json['seaSurfaceTemperature'],
      ),
      pressureHpa: serializer.fromJson<double?>(json['pressureHpa']),
      dataJson: serializer.fromJson<String?>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'regionKey': serializer.toJson<String>(regionKey),
      'tempC': serializer.toJson<double?>(tempC),
      'windSpeedKmh': serializer.toJson<double?>(windSpeedKmh),
      'waveHeightM': serializer.toJson<double?>(waveHeightM),
      'humidity': serializer.toJson<double?>(humidity),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'windDirection': serializer.toJson<int?>(windDirection),
      'cloudCover': serializer.toJson<double?>(cloudCover),
      'visibilityKm': serializer.toJson<double?>(visibilityKm),
      'precipitation': serializer.toJson<double?>(precipitation),
      'seaSurfaceTemperature': serializer.toJson<double?>(
        seaSurfaceTemperature,
      ),
      'pressureHpa': serializer.toJson<double?>(pressureHpa),
      'dataJson': serializer.toJson<String?>(dataJson),
    };
  }

  LocalWeatherData copyWith({
    String? regionKey,
    Value<double?> tempC = const Value.absent(),
    Value<double?> windSpeedKmh = const Value.absent(),
    Value<double?> waveHeightM = const Value.absent(),
    Value<double?> humidity = const Value.absent(),
    DateTime? cachedAt,
    Value<int?> windDirection = const Value.absent(),
    Value<double?> cloudCover = const Value.absent(),
    Value<double?> visibilityKm = const Value.absent(),
    Value<double?> precipitation = const Value.absent(),
    Value<double?> seaSurfaceTemperature = const Value.absent(),
    Value<double?> pressureHpa = const Value.absent(),
    Value<String?> dataJson = const Value.absent(),
  }) => LocalWeatherData(
    regionKey: regionKey ?? this.regionKey,
    tempC: tempC.present ? tempC.value : this.tempC,
    windSpeedKmh: windSpeedKmh.present ? windSpeedKmh.value : this.windSpeedKmh,
    waveHeightM: waveHeightM.present ? waveHeightM.value : this.waveHeightM,
    humidity: humidity.present ? humidity.value : this.humidity,
    cachedAt: cachedAt ?? this.cachedAt,
    windDirection: windDirection.present
        ? windDirection.value
        : this.windDirection,
    cloudCover: cloudCover.present ? cloudCover.value : this.cloudCover,
    visibilityKm: visibilityKm.present ? visibilityKm.value : this.visibilityKm,
    precipitation: precipitation.present
        ? precipitation.value
        : this.precipitation,
    seaSurfaceTemperature: seaSurfaceTemperature.present
        ? seaSurfaceTemperature.value
        : this.seaSurfaceTemperature,
    pressureHpa: pressureHpa.present ? pressureHpa.value : this.pressureHpa,
    dataJson: dataJson.present ? dataJson.value : this.dataJson,
  );
  LocalWeatherData copyWithCompanion(LocalWeatherCompanion data) {
    return LocalWeatherData(
      regionKey: data.regionKey.present ? data.regionKey.value : this.regionKey,
      tempC: data.tempC.present ? data.tempC.value : this.tempC,
      windSpeedKmh: data.windSpeedKmh.present
          ? data.windSpeedKmh.value
          : this.windSpeedKmh,
      waveHeightM: data.waveHeightM.present
          ? data.waveHeightM.value
          : this.waveHeightM,
      humidity: data.humidity.present ? data.humidity.value : this.humidity,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      windDirection: data.windDirection.present
          ? data.windDirection.value
          : this.windDirection,
      cloudCover: data.cloudCover.present
          ? data.cloudCover.value
          : this.cloudCover,
      visibilityKm: data.visibilityKm.present
          ? data.visibilityKm.value
          : this.visibilityKm,
      precipitation: data.precipitation.present
          ? data.precipitation.value
          : this.precipitation,
      seaSurfaceTemperature: data.seaSurfaceTemperature.present
          ? data.seaSurfaceTemperature.value
          : this.seaSurfaceTemperature,
      pressureHpa: data.pressureHpa.present
          ? data.pressureHpa.value
          : this.pressureHpa,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWeatherData(')
          ..write('regionKey: $regionKey, ')
          ..write('tempC: $tempC, ')
          ..write('windSpeedKmh: $windSpeedKmh, ')
          ..write('waveHeightM: $waveHeightM, ')
          ..write('humidity: $humidity, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('windDirection: $windDirection, ')
          ..write('cloudCover: $cloudCover, ')
          ..write('visibilityKm: $visibilityKm, ')
          ..write('precipitation: $precipitation, ')
          ..write('seaSurfaceTemperature: $seaSurfaceTemperature, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    regionKey,
    tempC,
    windSpeedKmh,
    waveHeightM,
    humidity,
    cachedAt,
    windDirection,
    cloudCover,
    visibilityKm,
    precipitation,
    seaSurfaceTemperature,
    pressureHpa,
    dataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWeatherData &&
          other.regionKey == this.regionKey &&
          other.tempC == this.tempC &&
          other.windSpeedKmh == this.windSpeedKmh &&
          other.waveHeightM == this.waveHeightM &&
          other.humidity == this.humidity &&
          other.cachedAt == this.cachedAt &&
          other.windDirection == this.windDirection &&
          other.cloudCover == this.cloudCover &&
          other.visibilityKm == this.visibilityKm &&
          other.precipitation == this.precipitation &&
          other.seaSurfaceTemperature == this.seaSurfaceTemperature &&
          other.pressureHpa == this.pressureHpa &&
          other.dataJson == this.dataJson);
}

class LocalWeatherCompanion extends UpdateCompanion<LocalWeatherData> {
  final Value<String> regionKey;
  final Value<double?> tempC;
  final Value<double?> windSpeedKmh;
  final Value<double?> waveHeightM;
  final Value<double?> humidity;
  final Value<DateTime> cachedAt;
  final Value<int?> windDirection;
  final Value<double?> cloudCover;
  final Value<double?> visibilityKm;
  final Value<double?> precipitation;
  final Value<double?> seaSurfaceTemperature;
  final Value<double?> pressureHpa;
  final Value<String?> dataJson;
  final Value<int> rowid;
  const LocalWeatherCompanion({
    this.regionKey = const Value.absent(),
    this.tempC = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.waveHeightM = const Value.absent(),
    this.humidity = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.windDirection = const Value.absent(),
    this.cloudCover = const Value.absent(),
    this.visibilityKm = const Value.absent(),
    this.precipitation = const Value.absent(),
    this.seaSurfaceTemperature = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWeatherCompanion.insert({
    required String regionKey,
    this.tempC = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.waveHeightM = const Value.absent(),
    this.humidity = const Value.absent(),
    required DateTime cachedAt,
    this.windDirection = const Value.absent(),
    this.cloudCover = const Value.absent(),
    this.visibilityKm = const Value.absent(),
    this.precipitation = const Value.absent(),
    this.seaSurfaceTemperature = const Value.absent(),
    this.pressureHpa = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : regionKey = Value(regionKey),
       cachedAt = Value(cachedAt);
  static Insertable<LocalWeatherData> custom({
    Expression<String>? regionKey,
    Expression<double>? tempC,
    Expression<double>? windSpeedKmh,
    Expression<double>? waveHeightM,
    Expression<double>? humidity,
    Expression<DateTime>? cachedAt,
    Expression<int>? windDirection,
    Expression<double>? cloudCover,
    Expression<double>? visibilityKm,
    Expression<double>? precipitation,
    Expression<double>? seaSurfaceTemperature,
    Expression<double>? pressureHpa,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (regionKey != null) 'region_key': regionKey,
      if (tempC != null) 'temp_c': tempC,
      if (windSpeedKmh != null) 'wind_speed_kmh': windSpeedKmh,
      if (waveHeightM != null) 'wave_height_m': waveHeightM,
      if (humidity != null) 'humidity': humidity,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (windDirection != null) 'wind_direction': windDirection,
      if (cloudCover != null) 'cloud_cover': cloudCover,
      if (visibilityKm != null) 'visibility_km': visibilityKm,
      if (precipitation != null) 'precipitation': precipitation,
      if (seaSurfaceTemperature != null)
        'sea_surface_temperature': seaSurfaceTemperature,
      if (pressureHpa != null) 'pressure_hpa': pressureHpa,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWeatherCompanion copyWith({
    Value<String>? regionKey,
    Value<double?>? tempC,
    Value<double?>? windSpeedKmh,
    Value<double?>? waveHeightM,
    Value<double?>? humidity,
    Value<DateTime>? cachedAt,
    Value<int?>? windDirection,
    Value<double?>? cloudCover,
    Value<double?>? visibilityKm,
    Value<double?>? precipitation,
    Value<double?>? seaSurfaceTemperature,
    Value<double?>? pressureHpa,
    Value<String?>? dataJson,
    Value<int>? rowid,
  }) {
    return LocalWeatherCompanion(
      regionKey: regionKey ?? this.regionKey,
      tempC: tempC ?? this.tempC,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      waveHeightM: waveHeightM ?? this.waveHeightM,
      humidity: humidity ?? this.humidity,
      cachedAt: cachedAt ?? this.cachedAt,
      windDirection: windDirection ?? this.windDirection,
      cloudCover: cloudCover ?? this.cloudCover,
      visibilityKm: visibilityKm ?? this.visibilityKm,
      precipitation: precipitation ?? this.precipitation,
      seaSurfaceTemperature:
          seaSurfaceTemperature ?? this.seaSurfaceTemperature,
      pressureHpa: pressureHpa ?? this.pressureHpa,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (regionKey.present) {
      map['region_key'] = Variable<String>(regionKey.value);
    }
    if (tempC.present) {
      map['temp_c'] = Variable<double>(tempC.value);
    }
    if (windSpeedKmh.present) {
      map['wind_speed_kmh'] = Variable<double>(windSpeedKmh.value);
    }
    if (waveHeightM.present) {
      map['wave_height_m'] = Variable<double>(waveHeightM.value);
    }
    if (humidity.present) {
      map['humidity'] = Variable<double>(humidity.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (windDirection.present) {
      map['wind_direction'] = Variable<int>(windDirection.value);
    }
    if (cloudCover.present) {
      map['cloud_cover'] = Variable<double>(cloudCover.value);
    }
    if (visibilityKm.present) {
      map['visibility_km'] = Variable<double>(visibilityKm.value);
    }
    if (precipitation.present) {
      map['precipitation'] = Variable<double>(precipitation.value);
    }
    if (seaSurfaceTemperature.present) {
      map['sea_surface_temperature'] = Variable<double>(
        seaSurfaceTemperature.value,
      );
    }
    if (pressureHpa.present) {
      map['pressure_hpa'] = Variable<double>(pressureHpa.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWeatherCompanion(')
          ..write('regionKey: $regionKey, ')
          ..write('tempC: $tempC, ')
          ..write('windSpeedKmh: $windSpeedKmh, ')
          ..write('waveHeightM: $waveHeightM, ')
          ..write('humidity: $humidity, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('windDirection: $windDirection, ')
          ..write('cloudCover: $cloudCover, ')
          ..write('visibilityKm: $visibilityKm, ')
          ..write('precipitation: $precipitation, ')
          ..write('seaSurfaceTemperature: $seaSurfaceTemperature, ')
          ..write('pressureHpa: $pressureHpa, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPostsTable extends LocalPosts
    with TableInfo<$LocalPostsTable, LocalPost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fishSpeciesMeta = const VerificationMeta(
    'fishSpecies',
  );
  @override
  late final GeneratedColumn<String> fishSpecies = GeneratedColumn<String>(
    'fish_species',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spotIdMeta = const VerificationMeta('spotId');
  @override
  late final GeneratedColumn<String> spotId = GeneratedColumn<String>(
    'spot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spotPrivacySnapshotMeta =
      const VerificationMeta('spotPrivacySnapshot');
  @override
  late final GeneratedColumn<String> spotPrivacySnapshot =
      GeneratedColumn<String>(
        'spot_privacy_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('public'),
      );
  static const VerificationMeta _spotDistrictMeta = const VerificationMeta(
    'spotDistrict',
  );
  @override
  late final GeneratedColumn<String> spotDistrict = GeneratedColumn<String>(
    'spot_district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _likesCountMeta = const VerificationMeta(
    'likesCount',
  );
  @override
  late final GeneratedColumn<int> likesCount = GeneratedColumn<int>(
    'likes_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commentsCountMeta = const VerificationMeta(
    'commentsCount',
  );
  @override
  late final GeneratedColumn<int> commentsCount = GeneratedColumn<int>(
    'comments_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    photoUrl,
    caption,
    fishSpecies,
    spotId,
    spotPrivacySnapshot,
    spotDistrict,
    likesCount,
    commentsCount,
    isDeleted,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPost> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_photoUrlMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('fish_species')) {
      context.handle(
        _fishSpeciesMeta,
        fishSpecies.isAcceptableOrUnknown(
          data['fish_species']!,
          _fishSpeciesMeta,
        ),
      );
    }
    if (data.containsKey('spot_id')) {
      context.handle(
        _spotIdMeta,
        spotId.isAcceptableOrUnknown(data['spot_id']!, _spotIdMeta),
      );
    }
    if (data.containsKey('spot_privacy_snapshot')) {
      context.handle(
        _spotPrivacySnapshotMeta,
        spotPrivacySnapshot.isAcceptableOrUnknown(
          data['spot_privacy_snapshot']!,
          _spotPrivacySnapshotMeta,
        ),
      );
    }
    if (data.containsKey('spot_district')) {
      context.handle(
        _spotDistrictMeta,
        spotDistrict.isAcceptableOrUnknown(
          data['spot_district']!,
          _spotDistrictMeta,
        ),
      );
    }
    if (data.containsKey('likes_count')) {
      context.handle(
        _likesCountMeta,
        likesCount.isAcceptableOrUnknown(data['likes_count']!, _likesCountMeta),
      );
    }
    if (data.containsKey('comments_count')) {
      context.handle(
        _commentsCountMeta,
        commentsCount.isAcceptableOrUnknown(
          data['comments_count']!,
          _commentsCountMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPost(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      fishSpecies: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fish_species'],
      ),
      spotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spot_id'],
      ),
      spotPrivacySnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spot_privacy_snapshot'],
      )!,
      spotDistrict: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spot_district'],
      ),
      likesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}likes_count'],
      )!,
      commentsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}comments_count'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalPostsTable createAlias(String alias) {
    return $LocalPostsTable(attachedDatabase, alias);
  }
}

class LocalPost extends DataClass implements Insertable<LocalPost> {
  final String id;
  final String userId;

  /// Fotoğraf zorunlu (posts.photo_url NOT NULL ile eşleşir)
  final String photoUrl;
  final String? caption;

  /// Supabase TEXT[] → JSON string (ör. '["levrek","çipura"]')
  final String? fishSpecies;
  final String? spotId;

  /// fishing_spots.privacy_level snapshot'ı (public/friends/private/vip)
  final String spotPrivacySnapshot;
  final String? spotDistrict;
  final int likesCount;
  final int commentsCount;
  final bool isDeleted;
  final DateTime createdAt;
  const LocalPost({
    required this.id,
    required this.userId,
    required this.photoUrl,
    this.caption,
    this.fishSpecies,
    this.spotId,
    required this.spotPrivacySnapshot,
    this.spotDistrict,
    required this.likesCount,
    required this.commentsCount,
    required this.isDeleted,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['photo_url'] = Variable<String>(photoUrl);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || fishSpecies != null) {
      map['fish_species'] = Variable<String>(fishSpecies);
    }
    if (!nullToAbsent || spotId != null) {
      map['spot_id'] = Variable<String>(spotId);
    }
    map['spot_privacy_snapshot'] = Variable<String>(spotPrivacySnapshot);
    if (!nullToAbsent || spotDistrict != null) {
      map['spot_district'] = Variable<String>(spotDistrict);
    }
    map['likes_count'] = Variable<int>(likesCount);
    map['comments_count'] = Variable<int>(commentsCount);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalPostsCompanion toCompanion(bool nullToAbsent) {
    return LocalPostsCompanion(
      id: Value(id),
      userId: Value(userId),
      photoUrl: Value(photoUrl),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      fishSpecies: fishSpecies == null && nullToAbsent
          ? const Value.absent()
          : Value(fishSpecies),
      spotId: spotId == null && nullToAbsent
          ? const Value.absent()
          : Value(spotId),
      spotPrivacySnapshot: Value(spotPrivacySnapshot),
      spotDistrict: spotDistrict == null && nullToAbsent
          ? const Value.absent()
          : Value(spotDistrict),
      likesCount: Value(likesCount),
      commentsCount: Value(commentsCount),
      isDeleted: Value(isDeleted),
      createdAt: Value(createdAt),
    );
  }

  factory LocalPost.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPost(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      photoUrl: serializer.fromJson<String>(json['photoUrl']),
      caption: serializer.fromJson<String?>(json['caption']),
      fishSpecies: serializer.fromJson<String?>(json['fishSpecies']),
      spotId: serializer.fromJson<String?>(json['spotId']),
      spotPrivacySnapshot: serializer.fromJson<String>(
        json['spotPrivacySnapshot'],
      ),
      spotDistrict: serializer.fromJson<String?>(json['spotDistrict']),
      likesCount: serializer.fromJson<int>(json['likesCount']),
      commentsCount: serializer.fromJson<int>(json['commentsCount']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'photoUrl': serializer.toJson<String>(photoUrl),
      'caption': serializer.toJson<String?>(caption),
      'fishSpecies': serializer.toJson<String?>(fishSpecies),
      'spotId': serializer.toJson<String?>(spotId),
      'spotPrivacySnapshot': serializer.toJson<String>(spotPrivacySnapshot),
      'spotDistrict': serializer.toJson<String?>(spotDistrict),
      'likesCount': serializer.toJson<int>(likesCount),
      'commentsCount': serializer.toJson<int>(commentsCount),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalPost copyWith({
    String? id,
    String? userId,
    String? photoUrl,
    Value<String?> caption = const Value.absent(),
    Value<String?> fishSpecies = const Value.absent(),
    Value<String?> spotId = const Value.absent(),
    String? spotPrivacySnapshot,
    Value<String?> spotDistrict = const Value.absent(),
    int? likesCount,
    int? commentsCount,
    bool? isDeleted,
    DateTime? createdAt,
  }) => LocalPost(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    photoUrl: photoUrl ?? this.photoUrl,
    caption: caption.present ? caption.value : this.caption,
    fishSpecies: fishSpecies.present ? fishSpecies.value : this.fishSpecies,
    spotId: spotId.present ? spotId.value : this.spotId,
    spotPrivacySnapshot: spotPrivacySnapshot ?? this.spotPrivacySnapshot,
    spotDistrict: spotDistrict.present ? spotDistrict.value : this.spotDistrict,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalPost copyWithCompanion(LocalPostsCompanion data) {
    return LocalPost(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      caption: data.caption.present ? data.caption.value : this.caption,
      fishSpecies: data.fishSpecies.present
          ? data.fishSpecies.value
          : this.fishSpecies,
      spotId: data.spotId.present ? data.spotId.value : this.spotId,
      spotPrivacySnapshot: data.spotPrivacySnapshot.present
          ? data.spotPrivacySnapshot.value
          : this.spotPrivacySnapshot,
      spotDistrict: data.spotDistrict.present
          ? data.spotDistrict.value
          : this.spotDistrict,
      likesCount: data.likesCount.present
          ? data.likesCount.value
          : this.likesCount,
      commentsCount: data.commentsCount.present
          ? data.commentsCount.value
          : this.commentsCount,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPost(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('caption: $caption, ')
          ..write('fishSpecies: $fishSpecies, ')
          ..write('spotId: $spotId, ')
          ..write('spotPrivacySnapshot: $spotPrivacySnapshot, ')
          ..write('spotDistrict: $spotDistrict, ')
          ..write('likesCount: $likesCount, ')
          ..write('commentsCount: $commentsCount, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    photoUrl,
    caption,
    fishSpecies,
    spotId,
    spotPrivacySnapshot,
    spotDistrict,
    likesCount,
    commentsCount,
    isDeleted,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPost &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.photoUrl == this.photoUrl &&
          other.caption == this.caption &&
          other.fishSpecies == this.fishSpecies &&
          other.spotId == this.spotId &&
          other.spotPrivacySnapshot == this.spotPrivacySnapshot &&
          other.spotDistrict == this.spotDistrict &&
          other.likesCount == this.likesCount &&
          other.commentsCount == this.commentsCount &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt);
}

class LocalPostsCompanion extends UpdateCompanion<LocalPost> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> photoUrl;
  final Value<String?> caption;
  final Value<String?> fishSpecies;
  final Value<String?> spotId;
  final Value<String> spotPrivacySnapshot;
  final Value<String?> spotDistrict;
  final Value<int> likesCount;
  final Value<int> commentsCount;
  final Value<bool> isDeleted;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalPostsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.caption = const Value.absent(),
    this.fishSpecies = const Value.absent(),
    this.spotId = const Value.absent(),
    this.spotPrivacySnapshot = const Value.absent(),
    this.spotDistrict = const Value.absent(),
    this.likesCount = const Value.absent(),
    this.commentsCount = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPostsCompanion.insert({
    required String id,
    required String userId,
    required String photoUrl,
    this.caption = const Value.absent(),
    this.fishSpecies = const Value.absent(),
    this.spotId = const Value.absent(),
    this.spotPrivacySnapshot = const Value.absent(),
    this.spotDistrict = const Value.absent(),
    this.likesCount = const Value.absent(),
    this.commentsCount = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       photoUrl = Value(photoUrl),
       createdAt = Value(createdAt);
  static Insertable<LocalPost> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? photoUrl,
    Expression<String>? caption,
    Expression<String>? fishSpecies,
    Expression<String>? spotId,
    Expression<String>? spotPrivacySnapshot,
    Expression<String>? spotDistrict,
    Expression<int>? likesCount,
    Expression<int>? commentsCount,
    Expression<bool>? isDeleted,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (caption != null) 'caption': caption,
      if (fishSpecies != null) 'fish_species': fishSpecies,
      if (spotId != null) 'spot_id': spotId,
      if (spotPrivacySnapshot != null)
        'spot_privacy_snapshot': spotPrivacySnapshot,
      if (spotDistrict != null) 'spot_district': spotDistrict,
      if (likesCount != null) 'likes_count': likesCount,
      if (commentsCount != null) 'comments_count': commentsCount,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPostsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? photoUrl,
    Value<String?>? caption,
    Value<String?>? fishSpecies,
    Value<String?>? spotId,
    Value<String>? spotPrivacySnapshot,
    Value<String?>? spotDistrict,
    Value<int>? likesCount,
    Value<int>? commentsCount,
    Value<bool>? isDeleted,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalPostsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      photoUrl: photoUrl ?? this.photoUrl,
      caption: caption ?? this.caption,
      fishSpecies: fishSpecies ?? this.fishSpecies,
      spotId: spotId ?? this.spotId,
      spotPrivacySnapshot: spotPrivacySnapshot ?? this.spotPrivacySnapshot,
      spotDistrict: spotDistrict ?? this.spotDistrict,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (fishSpecies.present) {
      map['fish_species'] = Variable<String>(fishSpecies.value);
    }
    if (spotId.present) {
      map['spot_id'] = Variable<String>(spotId.value);
    }
    if (spotPrivacySnapshot.present) {
      map['spot_privacy_snapshot'] = Variable<String>(
        spotPrivacySnapshot.value,
      );
    }
    if (spotDistrict.present) {
      map['spot_district'] = Variable<String>(spotDistrict.value);
    }
    if (likesCount.present) {
      map['likes_count'] = Variable<int>(likesCount.value);
    }
    if (commentsCount.present) {
      map['comments_count'] = Variable<int>(commentsCount.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPostsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('caption: $caption, ')
          ..write('fishSpecies: $fishSpecies, ')
          ..write('spotId: $spotId, ')
          ..write('spotPrivacySnapshot: $spotPrivacySnapshot, ')
          ..write('spotDistrict: $spotDistrict, ')
          ..write('likesCount: $likesCount, ')
          ..write('commentsCount: $commentsCount, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalSpotsTable localSpots = $LocalSpotsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $LocalWeatherTable localWeather = $LocalWeatherTable(this);
  late final $LocalPostsTable localPosts = $LocalPostsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSpots,
    syncQueue,
    localWeather,
    localPosts,
  ];
}

typedef $$LocalSpotsTableCreateCompanionBuilder =
    LocalSpotsCompanion Function({
      required String id,
      required String userId,
      required String name,
      required double lat,
      required double lng,
      Value<String?> type,
      required String privacyLevel,
      Value<String?> description,
      Value<bool> verified,
      Value<String?> muhtarId,
      Value<bool> isSynced,
      required DateTime createdAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$LocalSpotsTableUpdateCompanionBuilder =
    LocalSpotsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<double> lat,
      Value<double> lng,
      Value<String?> type,
      Value<String> privacyLevel,
      Value<String?> description,
      Value<bool> verified,
      Value<String?> muhtarId,
      Value<bool> isSynced,
      Value<DateTime> createdAt,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$LocalSpotsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSpotsTable> {
  $$LocalSpotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muhtarId => $composableBuilder(
    column: $table.muhtarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSpotsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSpotsTable> {
  $$LocalSpotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muhtarId => $composableBuilder(
    column: $table.muhtarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSpotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSpotsTable> {
  $$LocalSpotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<String> get muhtarId =>
      $composableBuilder(column: $table.muhtarId, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalSpotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSpotsTable,
          LocalSpot,
          $$LocalSpotsTableFilterComposer,
          $$LocalSpotsTableOrderingComposer,
          $$LocalSpotsTableAnnotationComposer,
          $$LocalSpotsTableCreateCompanionBuilder,
          $$LocalSpotsTableUpdateCompanionBuilder,
          (
            LocalSpot,
            BaseReferences<_$AppDatabase, $LocalSpotsTable, LocalSpot>,
          ),
          LocalSpot,
          PrefetchHooks Function()
        > {
  $$LocalSpotsTableTableManager(_$AppDatabase db, $LocalSpotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSpotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSpotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSpotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<String> privacyLevel = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<String?> muhtarId = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSpotsCompanion(
                id: id,
                userId: userId,
                name: name,
                lat: lat,
                lng: lng,
                type: type,
                privacyLevel: privacyLevel,
                description: description,
                verified: verified,
                muhtarId: muhtarId,
                isSynced: isSynced,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                required double lat,
                required double lng,
                Value<String?> type = const Value.absent(),
                required String privacyLevel,
                Value<String?> description = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<String?> muhtarId = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSpotsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                lat: lat,
                lng: lng,
                type: type,
                privacyLevel: privacyLevel,
                description: description,
                verified: verified,
                muhtarId: muhtarId,
                isSynced: isSynced,
                createdAt: createdAt,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSpotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSpotsTable,
      LocalSpot,
      $$LocalSpotsTableFilterComposer,
      $$LocalSpotsTableOrderingComposer,
      $$LocalSpotsTableAnnotationComposer,
      $$LocalSpotsTableCreateCompanionBuilder,
      $$LocalSpotsTableUpdateCompanionBuilder,
      (LocalSpot, BaseReferences<_$AppDatabase, $LocalSpotsTable, LocalSpot>),
      LocalSpot,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String operation,
      required String tableNameValue,
      required String payload,
      Value<int> retryCount,
      Value<DateTime> createdAt,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> operation,
      Value<String> tableNameValue,
      Value<String> payload,
      Value<int> retryCount,
      Value<DateTime> createdAt,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableNameValue => $composableBuilder(
    column: $table.tableNameValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableNameValue => $composableBuilder(
    column: $table.tableNameValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get tableNameValue => $composableBuilder(
    column: $table.tableNameValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> tableNameValue = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                operation: operation,
                tableNameValue: tableNameValue,
                payload: payload,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operation,
                required String tableNameValue,
                required String payload,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                operation: operation,
                tableNameValue: tableNameValue,
                payload: payload,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$LocalWeatherTableCreateCompanionBuilder =
    LocalWeatherCompanion Function({
      required String regionKey,
      Value<double?> tempC,
      Value<double?> windSpeedKmh,
      Value<double?> waveHeightM,
      Value<double?> humidity,
      required DateTime cachedAt,
      Value<int?> windDirection,
      Value<double?> cloudCover,
      Value<double?> visibilityKm,
      Value<double?> precipitation,
      Value<double?> seaSurfaceTemperature,
      Value<double?> pressureHpa,
      Value<String?> dataJson,
      Value<int> rowid,
    });
typedef $$LocalWeatherTableUpdateCompanionBuilder =
    LocalWeatherCompanion Function({
      Value<String> regionKey,
      Value<double?> tempC,
      Value<double?> windSpeedKmh,
      Value<double?> waveHeightM,
      Value<double?> humidity,
      Value<DateTime> cachedAt,
      Value<int?> windDirection,
      Value<double?> cloudCover,
      Value<double?> visibilityKm,
      Value<double?> precipitation,
      Value<double?> seaSurfaceTemperature,
      Value<double?> pressureHpa,
      Value<String?> dataJson,
      Value<int> rowid,
    });

class $$LocalWeatherTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWeatherTable> {
  $$LocalWeatherTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get regionKey => $composableBuilder(
    column: $table.regionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get waveHeightM => $composableBuilder(
    column: $table.waveHeightM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get humidity => $composableBuilder(
    column: $table.humidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windDirection => $composableBuilder(
    column: $table.windDirection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cloudCover => $composableBuilder(
    column: $table.cloudCover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get visibilityKm => $composableBuilder(
    column: $table.visibilityKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get precipitation => $composableBuilder(
    column: $table.precipitation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get seaSurfaceTemperature => $composableBuilder(
    column: $table.seaSurfaceTemperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWeatherTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWeatherTable> {
  $$LocalWeatherTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get regionKey => $composableBuilder(
    column: $table.regionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempC => $composableBuilder(
    column: $table.tempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get waveHeightM => $composableBuilder(
    column: $table.waveHeightM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get humidity => $composableBuilder(
    column: $table.humidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windDirection => $composableBuilder(
    column: $table.windDirection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cloudCover => $composableBuilder(
    column: $table.cloudCover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get visibilityKm => $composableBuilder(
    column: $table.visibilityKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get precipitation => $composableBuilder(
    column: $table.precipitation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get seaSurfaceTemperature => $composableBuilder(
    column: $table.seaSurfaceTemperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWeatherTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWeatherTable> {
  $$LocalWeatherTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get regionKey =>
      $composableBuilder(column: $table.regionKey, builder: (column) => column);

  GeneratedColumn<double> get tempC =>
      $composableBuilder(column: $table.tempC, builder: (column) => column);

  GeneratedColumn<double> get windSpeedKmh => $composableBuilder(
    column: $table.windSpeedKmh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get waveHeightM => $composableBuilder(
    column: $table.waveHeightM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get humidity =>
      $composableBuilder(column: $table.humidity, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get windDirection => $composableBuilder(
    column: $table.windDirection,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cloudCover => $composableBuilder(
    column: $table.cloudCover,
    builder: (column) => column,
  );

  GeneratedColumn<double> get visibilityKm => $composableBuilder(
    column: $table.visibilityKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get precipitation => $composableBuilder(
    column: $table.precipitation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get seaSurfaceTemperature => $composableBuilder(
    column: $table.seaSurfaceTemperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pressureHpa => $composableBuilder(
    column: $table.pressureHpa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$LocalWeatherTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWeatherTable,
          LocalWeatherData,
          $$LocalWeatherTableFilterComposer,
          $$LocalWeatherTableOrderingComposer,
          $$LocalWeatherTableAnnotationComposer,
          $$LocalWeatherTableCreateCompanionBuilder,
          $$LocalWeatherTableUpdateCompanionBuilder,
          (
            LocalWeatherData,
            BaseReferences<_$AppDatabase, $LocalWeatherTable, LocalWeatherData>,
          ),
          LocalWeatherData,
          PrefetchHooks Function()
        > {
  $$LocalWeatherTableTableManager(_$AppDatabase db, $LocalWeatherTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWeatherTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalWeatherTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalWeatherTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> regionKey = const Value.absent(),
                Value<double?> tempC = const Value.absent(),
                Value<double?> windSpeedKmh = const Value.absent(),
                Value<double?> waveHeightM = const Value.absent(),
                Value<double?> humidity = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int?> windDirection = const Value.absent(),
                Value<double?> cloudCover = const Value.absent(),
                Value<double?> visibilityKm = const Value.absent(),
                Value<double?> precipitation = const Value.absent(),
                Value<double?> seaSurfaceTemperature = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<String?> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWeatherCompanion(
                regionKey: regionKey,
                tempC: tempC,
                windSpeedKmh: windSpeedKmh,
                waveHeightM: waveHeightM,
                humidity: humidity,
                cachedAt: cachedAt,
                windDirection: windDirection,
                cloudCover: cloudCover,
                visibilityKm: visibilityKm,
                precipitation: precipitation,
                seaSurfaceTemperature: seaSurfaceTemperature,
                pressureHpa: pressureHpa,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String regionKey,
                Value<double?> tempC = const Value.absent(),
                Value<double?> windSpeedKmh = const Value.absent(),
                Value<double?> waveHeightM = const Value.absent(),
                Value<double?> humidity = const Value.absent(),
                required DateTime cachedAt,
                Value<int?> windDirection = const Value.absent(),
                Value<double?> cloudCover = const Value.absent(),
                Value<double?> visibilityKm = const Value.absent(),
                Value<double?> precipitation = const Value.absent(),
                Value<double?> seaSurfaceTemperature = const Value.absent(),
                Value<double?> pressureHpa = const Value.absent(),
                Value<String?> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWeatherCompanion.insert(
                regionKey: regionKey,
                tempC: tempC,
                windSpeedKmh: windSpeedKmh,
                waveHeightM: waveHeightM,
                humidity: humidity,
                cachedAt: cachedAt,
                windDirection: windDirection,
                cloudCover: cloudCover,
                visibilityKm: visibilityKm,
                precipitation: precipitation,
                seaSurfaceTemperature: seaSurfaceTemperature,
                pressureHpa: pressureHpa,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWeatherTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWeatherTable,
      LocalWeatherData,
      $$LocalWeatherTableFilterComposer,
      $$LocalWeatherTableOrderingComposer,
      $$LocalWeatherTableAnnotationComposer,
      $$LocalWeatherTableCreateCompanionBuilder,
      $$LocalWeatherTableUpdateCompanionBuilder,
      (
        LocalWeatherData,
        BaseReferences<_$AppDatabase, $LocalWeatherTable, LocalWeatherData>,
      ),
      LocalWeatherData,
      PrefetchHooks Function()
    >;
typedef $$LocalPostsTableCreateCompanionBuilder =
    LocalPostsCompanion Function({
      required String id,
      required String userId,
      required String photoUrl,
      Value<String?> caption,
      Value<String?> fishSpecies,
      Value<String?> spotId,
      Value<String> spotPrivacySnapshot,
      Value<String?> spotDistrict,
      Value<int> likesCount,
      Value<int> commentsCount,
      Value<bool> isDeleted,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalPostsTableUpdateCompanionBuilder =
    LocalPostsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> photoUrl,
      Value<String?> caption,
      Value<String?> fishSpecies,
      Value<String?> spotId,
      Value<String> spotPrivacySnapshot,
      Value<String?> spotDistrict,
      Value<int> likesCount,
      Value<int> commentsCount,
      Value<bool> isDeleted,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalPostsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPostsTable> {
  $$LocalPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fishSpecies => $composableBuilder(
    column: $table.fishSpecies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spotPrivacySnapshot => $composableBuilder(
    column: $table.spotPrivacySnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spotDistrict => $composableBuilder(
    column: $table.spotDistrict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likesCount => $composableBuilder(
    column: $table.likesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get commentsCount => $composableBuilder(
    column: $table.commentsCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPostsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPostsTable> {
  $$LocalPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fishSpecies => $composableBuilder(
    column: $table.fishSpecies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spotPrivacySnapshot => $composableBuilder(
    column: $table.spotPrivacySnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spotDistrict => $composableBuilder(
    column: $table.spotDistrict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likesCount => $composableBuilder(
    column: $table.likesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get commentsCount => $composableBuilder(
    column: $table.commentsCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPostsTable> {
  $$LocalPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get fishSpecies => $composableBuilder(
    column: $table.fishSpecies,
    builder: (column) => column,
  );

  GeneratedColumn<String> get spotId =>
      $composableBuilder(column: $table.spotId, builder: (column) => column);

  GeneratedColumn<String> get spotPrivacySnapshot => $composableBuilder(
    column: $table.spotPrivacySnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get spotDistrict => $composableBuilder(
    column: $table.spotDistrict,
    builder: (column) => column,
  );

  GeneratedColumn<int> get likesCount => $composableBuilder(
    column: $table.likesCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get commentsCount => $composableBuilder(
    column: $table.commentsCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalPostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPostsTable,
          LocalPost,
          $$LocalPostsTableFilterComposer,
          $$LocalPostsTableOrderingComposer,
          $$LocalPostsTableAnnotationComposer,
          $$LocalPostsTableCreateCompanionBuilder,
          $$LocalPostsTableUpdateCompanionBuilder,
          (
            LocalPost,
            BaseReferences<_$AppDatabase, $LocalPostsTable, LocalPost>,
          ),
          LocalPost,
          PrefetchHooks Function()
        > {
  $$LocalPostsTableTableManager(_$AppDatabase db, $LocalPostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> photoUrl = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> fishSpecies = const Value.absent(),
                Value<String?> spotId = const Value.absent(),
                Value<String> spotPrivacySnapshot = const Value.absent(),
                Value<String?> spotDistrict = const Value.absent(),
                Value<int> likesCount = const Value.absent(),
                Value<int> commentsCount = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPostsCompanion(
                id: id,
                userId: userId,
                photoUrl: photoUrl,
                caption: caption,
                fishSpecies: fishSpecies,
                spotId: spotId,
                spotPrivacySnapshot: spotPrivacySnapshot,
                spotDistrict: spotDistrict,
                likesCount: likesCount,
                commentsCount: commentsCount,
                isDeleted: isDeleted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String photoUrl,
                Value<String?> caption = const Value.absent(),
                Value<String?> fishSpecies = const Value.absent(),
                Value<String?> spotId = const Value.absent(),
                Value<String> spotPrivacySnapshot = const Value.absent(),
                Value<String?> spotDistrict = const Value.absent(),
                Value<int> likesCount = const Value.absent(),
                Value<int> commentsCount = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalPostsCompanion.insert(
                id: id,
                userId: userId,
                photoUrl: photoUrl,
                caption: caption,
                fishSpecies: fishSpecies,
                spotId: spotId,
                spotPrivacySnapshot: spotPrivacySnapshot,
                spotDistrict: spotDistrict,
                likesCount: likesCount,
                commentsCount: commentsCount,
                isDeleted: isDeleted,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPostsTable,
      LocalPost,
      $$LocalPostsTableFilterComposer,
      $$LocalPostsTableOrderingComposer,
      $$LocalPostsTableAnnotationComposer,
      $$LocalPostsTableCreateCompanionBuilder,
      $$LocalPostsTableUpdateCompanionBuilder,
      (LocalPost, BaseReferences<_$AppDatabase, $LocalPostsTable, LocalPost>),
      LocalPost,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalSpotsTableTableManager get localSpots =>
      $$LocalSpotsTableTableManager(_db, _db.localSpots);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$LocalWeatherTableTableManager get localWeather =>
      $$LocalWeatherTableTableManager(_db, _db.localWeather);
  $$LocalPostsTableTableManager get localPosts =>
      $$LocalPostsTableTableManager(_db, _db.localPosts);
}
