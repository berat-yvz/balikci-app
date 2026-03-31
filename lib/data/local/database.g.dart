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

class $LocalFishLogsTable extends LocalFishLogs
    with TableInfo<$LocalFishLogsTable, LocalFishLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFishLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _spotIdMeta = const VerificationMeta('spotId');
  @override
  late final GeneratedColumn<String> spotId = GeneratedColumn<String>(
    'spot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speciesMeta = const VerificationMeta(
    'species',
  );
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
    'species',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<double> length = GeneratedColumn<double>(
    'length',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoUrlMeta = const VerificationMeta(
    'photoUrl',
  );
  @override
  late final GeneratedColumn<String> photoUrl = GeneratedColumn<String>(
    'photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    spotId,
    species,
    weight,
    length,
    photoUrl,
    isPrivate,
    isSynced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_fish_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFishLog> instance, {
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
    if (data.containsKey('spot_id')) {
      context.handle(
        _spotIdMeta,
        spotId.isAcceptableOrUnknown(data['spot_id']!, _spotIdMeta),
      );
    }
    if (data.containsKey('species')) {
      context.handle(
        _speciesMeta,
        species.isAcceptableOrUnknown(data['species']!, _speciesMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    }
    if (data.containsKey('photo_url')) {
      context.handle(
        _photoUrlMeta,
        photoUrl.isAcceptableOrUnknown(data['photo_url']!, _photoUrlMeta),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    } else if (isInserting) {
      context.missing(_isPrivateMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFishLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFishLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      spotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spot_id'],
      ),
      species: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      ),
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length'],
      ),
      photoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_url'],
      ),
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalFishLogsTable createAlias(String alias) {
    return $LocalFishLogsTable(attachedDatabase, alias);
  }
}

class LocalFishLog extends DataClass implements Insertable<LocalFishLog> {
  final String id;
  final String userId;
  final String? spotId;
  final String species;
  final double? weight;
  final double? length;
  final String? photoUrl;
  final bool isPrivate;
  final bool isSynced;
  final DateTime createdAt;
  const LocalFishLog({
    required this.id,
    required this.userId,
    this.spotId,
    required this.species,
    this.weight,
    this.length,
    this.photoUrl,
    required this.isPrivate,
    required this.isSynced,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || spotId != null) {
      map['spot_id'] = Variable<String>(spotId);
    }
    map['species'] = Variable<String>(species);
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || length != null) {
      map['length'] = Variable<double>(length);
    }
    if (!nullToAbsent || photoUrl != null) {
      map['photo_url'] = Variable<String>(photoUrl);
    }
    map['is_private'] = Variable<bool>(isPrivate);
    map['is_synced'] = Variable<bool>(isSynced);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalFishLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalFishLogsCompanion(
      id: Value(id),
      userId: Value(userId),
      spotId: spotId == null && nullToAbsent
          ? const Value.absent()
          : Value(spotId),
      species: Value(species),
      weight: weight == null && nullToAbsent
          ? const Value.absent()
          : Value(weight),
      length: length == null && nullToAbsent
          ? const Value.absent()
          : Value(length),
      photoUrl: photoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(photoUrl),
      isPrivate: Value(isPrivate),
      isSynced: Value(isSynced),
      createdAt: Value(createdAt),
    );
  }

  factory LocalFishLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFishLog(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      spotId: serializer.fromJson<String?>(json['spotId']),
      species: serializer.fromJson<String>(json['species']),
      weight: serializer.fromJson<double?>(json['weight']),
      length: serializer.fromJson<double?>(json['length']),
      photoUrl: serializer.fromJson<String?>(json['photoUrl']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'spotId': serializer.toJson<String?>(spotId),
      'species': serializer.toJson<String>(species),
      'weight': serializer.toJson<double?>(weight),
      'length': serializer.toJson<double?>(length),
      'photoUrl': serializer.toJson<String?>(photoUrl),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'isSynced': serializer.toJson<bool>(isSynced),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalFishLog copyWith({
    String? id,
    String? userId,
    Value<String?> spotId = const Value.absent(),
    String? species,
    Value<double?> weight = const Value.absent(),
    Value<double?> length = const Value.absent(),
    Value<String?> photoUrl = const Value.absent(),
    bool? isPrivate,
    bool? isSynced,
    DateTime? createdAt,
  }) => LocalFishLog(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    spotId: spotId.present ? spotId.value : this.spotId,
    species: species ?? this.species,
    weight: weight.present ? weight.value : this.weight,
    length: length.present ? length.value : this.length,
    photoUrl: photoUrl.present ? photoUrl.value : this.photoUrl,
    isPrivate: isPrivate ?? this.isPrivate,
    isSynced: isSynced ?? this.isSynced,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalFishLog copyWithCompanion(LocalFishLogsCompanion data) {
    return LocalFishLog(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      spotId: data.spotId.present ? data.spotId.value : this.spotId,
      species: data.species.present ? data.species.value : this.species,
      weight: data.weight.present ? data.weight.value : this.weight,
      length: data.length.present ? data.length.value : this.length,
      photoUrl: data.photoUrl.present ? data.photoUrl.value : this.photoUrl,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFishLog(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('spotId: $spotId, ')
          ..write('species: $species, ')
          ..write('weight: $weight, ')
          ..write('length: $length, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    spotId,
    species,
    weight,
    length,
    photoUrl,
    isPrivate,
    isSynced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFishLog &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.spotId == this.spotId &&
          other.species == this.species &&
          other.weight == this.weight &&
          other.length == this.length &&
          other.photoUrl == this.photoUrl &&
          other.isPrivate == this.isPrivate &&
          other.isSynced == this.isSynced &&
          other.createdAt == this.createdAt);
}

class LocalFishLogsCompanion extends UpdateCompanion<LocalFishLog> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> spotId;
  final Value<String> species;
  final Value<double?> weight;
  final Value<double?> length;
  final Value<String?> photoUrl;
  final Value<bool> isPrivate;
  final Value<bool> isSynced;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalFishLogsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.spotId = const Value.absent(),
    this.species = const Value.absent(),
    this.weight = const Value.absent(),
    this.length = const Value.absent(),
    this.photoUrl = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFishLogsCompanion.insert({
    required String id,
    required String userId,
    this.spotId = const Value.absent(),
    required String species,
    this.weight = const Value.absent(),
    this.length = const Value.absent(),
    this.photoUrl = const Value.absent(),
    required bool isPrivate,
    this.isSynced = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       species = Value(species),
       isPrivate = Value(isPrivate),
       createdAt = Value(createdAt);
  static Insertable<LocalFishLog> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? spotId,
    Expression<String>? species,
    Expression<double>? weight,
    Expression<double>? length,
    Expression<String>? photoUrl,
    Expression<bool>? isPrivate,
    Expression<bool>? isSynced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (spotId != null) 'spot_id': spotId,
      if (species != null) 'species': species,
      if (weight != null) 'weight': weight,
      if (length != null) 'length': length,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (isPrivate != null) 'is_private': isPrivate,
      if (isSynced != null) 'is_synced': isSynced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFishLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? spotId,
    Value<String>? species,
    Value<double?>? weight,
    Value<double?>? length,
    Value<String?>? photoUrl,
    Value<bool>? isPrivate,
    Value<bool>? isSynced,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalFishLogsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      spotId: spotId ?? this.spotId,
      species: species ?? this.species,
      weight: weight ?? this.weight,
      length: length ?? this.length,
      photoUrl: photoUrl ?? this.photoUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      isSynced: isSynced ?? this.isSynced,
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
    if (spotId.present) {
      map['spot_id'] = Variable<String>(spotId.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (length.present) {
      map['length'] = Variable<double>(length.value);
    }
    if (photoUrl.present) {
      map['photo_url'] = Variable<String>(photoUrl.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
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
    return (StringBuffer('LocalFishLogsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('spotId: $spotId, ')
          ..write('species: $species, ')
          ..write('weight: $weight, ')
          ..write('length: $length, ')
          ..write('photoUrl: $photoUrl, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('isSynced: $isSynced, ')
          ..write('createdAt: $createdAt, ')
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
  @override
  List<GeneratedColumn> get $columns => [
    regionKey,
    tempC,
    windSpeedKmh,
    waveHeightM,
    humidity,
    cachedAt,
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
  const LocalWeatherData({
    required this.regionKey,
    this.tempC,
    this.windSpeedKmh,
    this.waveHeightM,
    this.humidity,
    required this.cachedAt,
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
    };
  }

  LocalWeatherData copyWith({
    String? regionKey,
    Value<double?> tempC = const Value.absent(),
    Value<double?> windSpeedKmh = const Value.absent(),
    Value<double?> waveHeightM = const Value.absent(),
    Value<double?> humidity = const Value.absent(),
    DateTime? cachedAt,
  }) => LocalWeatherData(
    regionKey: regionKey ?? this.regionKey,
    tempC: tempC.present ? tempC.value : this.tempC,
    windSpeedKmh: windSpeedKmh.present ? windSpeedKmh.value : this.windSpeedKmh,
    waveHeightM: waveHeightM.present ? waveHeightM.value : this.waveHeightM,
    humidity: humidity.present ? humidity.value : this.humidity,
    cachedAt: cachedAt ?? this.cachedAt,
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
          ..write('cachedAt: $cachedAt')
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
          other.cachedAt == this.cachedAt);
}

class LocalWeatherCompanion extends UpdateCompanion<LocalWeatherData> {
  final Value<String> regionKey;
  final Value<double?> tempC;
  final Value<double?> windSpeedKmh;
  final Value<double?> waveHeightM;
  final Value<double?> humidity;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const LocalWeatherCompanion({
    this.regionKey = const Value.absent(),
    this.tempC = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.waveHeightM = const Value.absent(),
    this.humidity = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWeatherCompanion.insert({
    required String regionKey,
    this.tempC = const Value.absent(),
    this.windSpeedKmh = const Value.absent(),
    this.waveHeightM = const Value.absent(),
    this.humidity = const Value.absent(),
    required DateTime cachedAt,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (regionKey != null) 'region_key': regionKey,
      if (tempC != null) 'temp_c': tempC,
      if (windSpeedKmh != null) 'wind_speed_kmh': windSpeedKmh,
      if (waveHeightM != null) 'wave_height_m': waveHeightM,
      if (humidity != null) 'humidity': humidity,
      if (cachedAt != null) 'cached_at': cachedAt,
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
    Value<int>? rowid,
  }) {
    return LocalWeatherCompanion(
      regionKey: regionKey ?? this.regionKey,
      tempC: tempC ?? this.tempC,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      waveHeightM: waveHeightM ?? this.waveHeightM,
      humidity: humidity ?? this.humidity,
      cachedAt: cachedAt ?? this.cachedAt,
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
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalSpotsTable localSpots = $LocalSpotsTable(this);
  late final $LocalFishLogsTable localFishLogs = $LocalFishLogsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $LocalWeatherTable localWeather = $LocalWeatherTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSpots,
    localFishLogs,
    syncQueue,
    localWeather,
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
typedef $$LocalFishLogsTableCreateCompanionBuilder =
    LocalFishLogsCompanion Function({
      required String id,
      required String userId,
      Value<String?> spotId,
      required String species,
      Value<double?> weight,
      Value<double?> length,
      Value<String?> photoUrl,
      required bool isPrivate,
      Value<bool> isSynced,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalFishLogsTableUpdateCompanionBuilder =
    LocalFishLogsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> spotId,
      Value<String> species,
      Value<double?> weight,
      Value<double?> length,
      Value<String?> photoUrl,
      Value<bool> isPrivate,
      Value<bool> isSynced,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalFishLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFishLogsTable> {
  $$LocalFishLogsTableFilterComposer({
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

  ColumnFilters<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
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
}

class $$LocalFishLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFishLogsTable> {
  $$LocalFishLogsTableOrderingComposer({
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

  ColumnOrderings<String> get spotId => $composableBuilder(
    column: $table.spotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoUrl => $composableBuilder(
    column: $table.photoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
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
}

class $$LocalFishLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFishLogsTable> {
  $$LocalFishLogsTableAnnotationComposer({
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

  GeneratedColumn<String> get spotId =>
      $composableBuilder(column: $table.spotId, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<double> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<String> get photoUrl =>
      $composableBuilder(column: $table.photoUrl, builder: (column) => column);

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalFishLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFishLogsTable,
          LocalFishLog,
          $$LocalFishLogsTableFilterComposer,
          $$LocalFishLogsTableOrderingComposer,
          $$LocalFishLogsTableAnnotationComposer,
          $$LocalFishLogsTableCreateCompanionBuilder,
          $$LocalFishLogsTableUpdateCompanionBuilder,
          (
            LocalFishLog,
            BaseReferences<_$AppDatabase, $LocalFishLogsTable, LocalFishLog>,
          ),
          LocalFishLog,
          PrefetchHooks Function()
        > {
  $$LocalFishLogsTableTableManager(_$AppDatabase db, $LocalFishLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFishLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFishLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFishLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> spotId = const Value.absent(),
                Value<String> species = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<double?> length = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFishLogsCompanion(
                id: id,
                userId: userId,
                spotId: spotId,
                species: species,
                weight: weight,
                length: length,
                photoUrl: photoUrl,
                isPrivate: isPrivate,
                isSynced: isSynced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> spotId = const Value.absent(),
                required String species,
                Value<double?> weight = const Value.absent(),
                Value<double?> length = const Value.absent(),
                Value<String?> photoUrl = const Value.absent(),
                required bool isPrivate,
                Value<bool> isSynced = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFishLogsCompanion.insert(
                id: id,
                userId: userId,
                spotId: spotId,
                species: species,
                weight: weight,
                length: length,
                photoUrl: photoUrl,
                isPrivate: isPrivate,
                isSynced: isSynced,
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

typedef $$LocalFishLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFishLogsTable,
      LocalFishLog,
      $$LocalFishLogsTableFilterComposer,
      $$LocalFishLogsTableOrderingComposer,
      $$LocalFishLogsTableAnnotationComposer,
      $$LocalFishLogsTableCreateCompanionBuilder,
      $$LocalFishLogsTableUpdateCompanionBuilder,
      (
        LocalFishLog,
        BaseReferences<_$AppDatabase, $LocalFishLogsTable, LocalFishLog>,
      ),
      LocalFishLog,
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
                Value<int> rowid = const Value.absent(),
              }) => LocalWeatherCompanion(
                regionKey: regionKey,
                tempC: tempC,
                windSpeedKmh: windSpeedKmh,
                waveHeightM: waveHeightM,
                humidity: humidity,
                cachedAt: cachedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => LocalWeatherCompanion.insert(
                regionKey: regionKey,
                tempC: tempC,
                windSpeedKmh: windSpeedKmh,
                waveHeightM: waveHeightM,
                humidity: humidity,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalSpotsTableTableManager get localSpots =>
      $$LocalSpotsTableTableManager(_db, _db.localSpots);
  $$LocalFishLogsTableTableManager get localFishLogs =>
      $$LocalFishLogsTableTableManager(_db, _db.localFishLogs);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$LocalWeatherTableTableManager get localWeather =>
      $$LocalWeatherTableTableManager(_db, _db.localWeather);
}
