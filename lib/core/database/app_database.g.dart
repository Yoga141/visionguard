// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CalibrationsTable extends Calibrations
    with TableInfo<$CalibrationsTable, Calibration> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalibrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _earBaselineMeta =
      const VerificationMeta('earBaseline');
  @override
  late final GeneratedColumn<double> earBaseline = GeneratedColumn<double>(
      'ear_baseline', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _focalPxMeta =
      const VerificationMeta('focalPx');
  @override
  late final GeneratedColumn<double> focalPx = GeneratedColumn<double>(
      'focal_px', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, cameraId, earBaseline, focalPx, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calibrations';
  @override
  VerificationContext validateIntegrity(Insertable<Calibration> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('ear_baseline')) {
      context.handle(
          _earBaselineMeta,
          earBaseline.isAcceptableOrUnknown(
              data['ear_baseline']!, _earBaselineMeta));
    } else if (isInserting) {
      context.missing(_earBaselineMeta);
    }
    if (data.containsKey('focal_px')) {
      context.handle(_focalPxMeta,
          focalPx.isAcceptableOrUnknown(data['focal_px']!, _focalPxMeta));
    } else if (isInserting) {
      context.missing(_focalPxMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Calibration map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Calibration(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_id'])!,
      earBaseline: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ear_baseline'])!,
      focalPx: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}focal_px'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $CalibrationsTable createAlias(String alias) {
    return $CalibrationsTable(attachedDatabase, alias);
  }
}

class Calibration extends DataClass implements Insertable<Calibration> {
  final int id;
  final String cameraId;
  final double earBaseline;
  final double focalPx;
  final String createdAt;
  const Calibration(
      {required this.id,
      required this.cameraId,
      required this.earBaseline,
      required this.focalPx,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['camera_id'] = Variable<String>(cameraId);
    map['ear_baseline'] = Variable<double>(earBaseline);
    map['focal_px'] = Variable<double>(focalPx);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  CalibrationsCompanion toCompanion(bool nullToAbsent) {
    return CalibrationsCompanion(
      id: Value(id),
      cameraId: Value(cameraId),
      earBaseline: Value(earBaseline),
      focalPx: Value(focalPx),
      createdAt: Value(createdAt),
    );
  }

  factory Calibration.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Calibration(
      id: serializer.fromJson<int>(json['id']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      earBaseline: serializer.fromJson<double>(json['earBaseline']),
      focalPx: serializer.fromJson<double>(json['focalPx']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cameraId': serializer.toJson<String>(cameraId),
      'earBaseline': serializer.toJson<double>(earBaseline),
      'focalPx': serializer.toJson<double>(focalPx),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Calibration copyWith(
          {int? id,
          String? cameraId,
          double? earBaseline,
          double? focalPx,
          String? createdAt}) =>
      Calibration(
        id: id ?? this.id,
        cameraId: cameraId ?? this.cameraId,
        earBaseline: earBaseline ?? this.earBaseline,
        focalPx: focalPx ?? this.focalPx,
        createdAt: createdAt ?? this.createdAt,
      );
  Calibration copyWithCompanion(CalibrationsCompanion data) {
    return Calibration(
      id: data.id.present ? data.id.value : this.id,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      earBaseline:
          data.earBaseline.present ? data.earBaseline.value : this.earBaseline,
      focalPx: data.focalPx.present ? data.focalPx.value : this.focalPx,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Calibration(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('earBaseline: $earBaseline, ')
          ..write('focalPx: $focalPx, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cameraId, earBaseline, focalPx, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Calibration &&
          other.id == this.id &&
          other.cameraId == this.cameraId &&
          other.earBaseline == this.earBaseline &&
          other.focalPx == this.focalPx &&
          other.createdAt == this.createdAt);
}

class CalibrationsCompanion extends UpdateCompanion<Calibration> {
  final Value<int> id;
  final Value<String> cameraId;
  final Value<double> earBaseline;
  final Value<double> focalPx;
  final Value<String> createdAt;
  const CalibrationsCompanion({
    this.id = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.earBaseline = const Value.absent(),
    this.focalPx = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CalibrationsCompanion.insert({
    this.id = const Value.absent(),
    required String cameraId,
    required double earBaseline,
    required double focalPx,
    required String createdAt,
  })  : cameraId = Value(cameraId),
        earBaseline = Value(earBaseline),
        focalPx = Value(focalPx),
        createdAt = Value(createdAt);
  static Insertable<Calibration> custom({
    Expression<int>? id,
    Expression<String>? cameraId,
    Expression<double>? earBaseline,
    Expression<double>? focalPx,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cameraId != null) 'camera_id': cameraId,
      if (earBaseline != null) 'ear_baseline': earBaseline,
      if (focalPx != null) 'focal_px': focalPx,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CalibrationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? cameraId,
      Value<double>? earBaseline,
      Value<double>? focalPx,
      Value<String>? createdAt}) {
    return CalibrationsCompanion(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      earBaseline: earBaseline ?? this.earBaseline,
      focalPx: focalPx ?? this.focalPx,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (earBaseline.present) {
      map['ear_baseline'] = Variable<double>(earBaseline.value);
    }
    if (focalPx.present) {
      map['focal_px'] = Variable<double>(focalPx.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationsCompanion(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('earBaseline: $earBaseline, ')
          ..write('focalPx: $focalPx, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  @override
  late final GeneratedColumnWithTypeConverter<SessionMode, String> mode =
      GeneratedColumn<String>('mode', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<SessionMode>($SessionsTable.$convertermode);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
      'started_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<String> endedAt = GeneratedColumn<String>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, mode, startedAt, endedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mode: $SessionsTable.$convertermode.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ended_at']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SessionMode, String, String> $convertermode =
      const EnumNameConverter<SessionMode>(SessionMode.values);
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final SessionMode mode;
  final String startedAt;
  final String? endedAt;
  const Session(
      {required this.id,
      required this.mode,
      required this.startedAt,
      this.endedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['mode'] = Variable<String>($SessionsTable.$convertermode.toSql(mode));
    }
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<String>(endedAt);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      mode: Value(mode),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      mode: $SessionsTable.$convertermode
          .fromJson(serializer.fromJson<String>(json['mode'])),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      endedAt: serializer.fromJson<String?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode':
          serializer.toJson<String>($SessionsTable.$convertermode.toJson(mode)),
      'startedAt': serializer.toJson<String>(startedAt),
      'endedAt': serializer.toJson<String?>(endedAt),
    };
  }

  Session copyWith(
          {int? id,
          SessionMode? mode,
          String? startedAt,
          Value<String?> endedAt = const Value.absent()}) =>
      Session(
        id: id ?? this.id,
        mode: mode ?? this.mode,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mode, startedAt, endedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<SessionMode> mode;
  final Value<String> startedAt;
  final Value<String?> endedAt;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required SessionMode mode,
    required String startedAt,
    this.endedAt = const Value.absent(),
  })  : mode = Value(mode),
        startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<String>? mode,
    Expression<String>? startedAt,
    Expression<String>? endedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
    });
  }

  SessionsCompanion copyWith(
      {Value<int>? id,
      Value<SessionMode>? mode,
      Value<String>? startedAt,
      Value<String?>? endedAt}) {
    return SessionsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] =
          Variable<String>($SessionsTable.$convertermode.toSql(mode.value));
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<String>(endedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }
}

class $MetricSamplesTable extends MetricSamples
    with TableInfo<$MetricSamplesTable, MetricSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetricSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
      'ts', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _blinkRateMeta =
      const VerificationMeta('blinkRate');
  @override
  late final GeneratedColumn<double> blinkRate = GeneratedColumn<double>(
      'blink_rate', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _perclosMeta =
      const VerificationMeta('perclos');
  @override
  late final GeneratedColumn<double> perclos = GeneratedColumn<double>(
      'perclos', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _distanceCmMeta =
      const VerificationMeta('distanceCm');
  @override
  late final GeneratedColumn<double> distanceCm = GeneratedColumn<double>(
      'distance_cm', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _fatigueScoreMeta =
      const VerificationMeta('fatigueScore');
  @override
  late final GeneratedColumn<int> fatigueScore = GeneratedColumn<int>(
      'fatigue_score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _validRatioPctMeta =
      const VerificationMeta('validRatioPct');
  @override
  late final GeneratedColumn<int> validRatioPct = GeneratedColumn<int>(
      'valid_ratio_pct', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        ts,
        blinkRate,
        perclos,
        distanceCm,
        fatigueScore,
        validRatioPct
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metric_samples';
  @override
  VerificationContext validateIntegrity(Insertable<MetricSample> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('blink_rate')) {
      context.handle(_blinkRateMeta,
          blinkRate.isAcceptableOrUnknown(data['blink_rate']!, _blinkRateMeta));
    }
    if (data.containsKey('perclos')) {
      context.handle(_perclosMeta,
          perclos.isAcceptableOrUnknown(data['perclos']!, _perclosMeta));
    }
    if (data.containsKey('distance_cm')) {
      context.handle(
          _distanceCmMeta,
          distanceCm.isAcceptableOrUnknown(
              data['distance_cm']!, _distanceCmMeta));
    }
    if (data.containsKey('fatigue_score')) {
      context.handle(
          _fatigueScoreMeta,
          fatigueScore.isAcceptableOrUnknown(
              data['fatigue_score']!, _fatigueScoreMeta));
    }
    if (data.containsKey('valid_ratio_pct')) {
      context.handle(
          _validRatioPctMeta,
          validRatioPct.isAcceptableOrUnknown(
              data['valid_ratio_pct']!, _validRatioPctMeta));
    } else if (isInserting) {
      context.missing(_validRatioPctMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MetricSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetricSample(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ts'])!,
      blinkRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}blink_rate']),
      perclos: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}perclos']),
      distanceCm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_cm']),
      fatigueScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fatigue_score']),
      validRatioPct: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}valid_ratio_pct'])!,
    );
  }

  @override
  $MetricSamplesTable createAlias(String alias) {
    return $MetricSamplesTable(attachedDatabase, alias);
  }
}

class MetricSample extends DataClass implements Insertable<MetricSample> {
  final int id;
  final int sessionId;
  final String ts;
  final double? blinkRate;
  final double? perclos;
  final double? distanceCm;
  final int? fatigueScore;
  final int validRatioPct;
  const MetricSample(
      {required this.id,
      required this.sessionId,
      required this.ts,
      this.blinkRate,
      this.perclos,
      this.distanceCm,
      this.fatigueScore,
      required this.validRatioPct});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['ts'] = Variable<String>(ts);
    if (!nullToAbsent || blinkRate != null) {
      map['blink_rate'] = Variable<double>(blinkRate);
    }
    if (!nullToAbsent || perclos != null) {
      map['perclos'] = Variable<double>(perclos);
    }
    if (!nullToAbsent || distanceCm != null) {
      map['distance_cm'] = Variable<double>(distanceCm);
    }
    if (!nullToAbsent || fatigueScore != null) {
      map['fatigue_score'] = Variable<int>(fatigueScore);
    }
    map['valid_ratio_pct'] = Variable<int>(validRatioPct);
    return map;
  }

  MetricSamplesCompanion toCompanion(bool nullToAbsent) {
    return MetricSamplesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      ts: Value(ts),
      blinkRate: blinkRate == null && nullToAbsent
          ? const Value.absent()
          : Value(blinkRate),
      perclos: perclos == null && nullToAbsent
          ? const Value.absent()
          : Value(perclos),
      distanceCm: distanceCm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceCm),
      fatigueScore: fatigueScore == null && nullToAbsent
          ? const Value.absent()
          : Value(fatigueScore),
      validRatioPct: Value(validRatioPct),
    );
  }

  factory MetricSample.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetricSample(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      blinkRate: serializer.fromJson<double?>(json['blinkRate']),
      perclos: serializer.fromJson<double?>(json['perclos']),
      distanceCm: serializer.fromJson<double?>(json['distanceCm']),
      fatigueScore: serializer.fromJson<int?>(json['fatigueScore']),
      validRatioPct: serializer.fromJson<int>(json['validRatioPct']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'blinkRate': serializer.toJson<double?>(blinkRate),
      'perclos': serializer.toJson<double?>(perclos),
      'distanceCm': serializer.toJson<double?>(distanceCm),
      'fatigueScore': serializer.toJson<int?>(fatigueScore),
      'validRatioPct': serializer.toJson<int>(validRatioPct),
    };
  }

  MetricSample copyWith(
          {int? id,
          int? sessionId,
          String? ts,
          Value<double?> blinkRate = const Value.absent(),
          Value<double?> perclos = const Value.absent(),
          Value<double?> distanceCm = const Value.absent(),
          Value<int?> fatigueScore = const Value.absent(),
          int? validRatioPct}) =>
      MetricSample(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        ts: ts ?? this.ts,
        blinkRate: blinkRate.present ? blinkRate.value : this.blinkRate,
        perclos: perclos.present ? perclos.value : this.perclos,
        distanceCm: distanceCm.present ? distanceCm.value : this.distanceCm,
        fatigueScore:
            fatigueScore.present ? fatigueScore.value : this.fatigueScore,
        validRatioPct: validRatioPct ?? this.validRatioPct,
      );
  MetricSample copyWithCompanion(MetricSamplesCompanion data) {
    return MetricSample(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      blinkRate: data.blinkRate.present ? data.blinkRate.value : this.blinkRate,
      perclos: data.perclos.present ? data.perclos.value : this.perclos,
      distanceCm:
          data.distanceCm.present ? data.distanceCm.value : this.distanceCm,
      fatigueScore: data.fatigueScore.present
          ? data.fatigueScore.value
          : this.fatigueScore,
      validRatioPct: data.validRatioPct.present
          ? data.validRatioPct.value
          : this.validRatioPct,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetricSample(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('blinkRate: $blinkRate, ')
          ..write('perclos: $perclos, ')
          ..write('distanceCm: $distanceCm, ')
          ..write('fatigueScore: $fatigueScore, ')
          ..write('validRatioPct: $validRatioPct')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, ts, blinkRate, perclos,
      distanceCm, fatigueScore, validRatioPct);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetricSample &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.blinkRate == this.blinkRate &&
          other.perclos == this.perclos &&
          other.distanceCm == this.distanceCm &&
          other.fatigueScore == this.fatigueScore &&
          other.validRatioPct == this.validRatioPct);
}

class MetricSamplesCompanion extends UpdateCompanion<MetricSample> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> ts;
  final Value<double?> blinkRate;
  final Value<double?> perclos;
  final Value<double?> distanceCm;
  final Value<int?> fatigueScore;
  final Value<int> validRatioPct;
  const MetricSamplesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.blinkRate = const Value.absent(),
    this.perclos = const Value.absent(),
    this.distanceCm = const Value.absent(),
    this.fatigueScore = const Value.absent(),
    this.validRatioPct = const Value.absent(),
  });
  MetricSamplesCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String ts,
    this.blinkRate = const Value.absent(),
    this.perclos = const Value.absent(),
    this.distanceCm = const Value.absent(),
    this.fatigueScore = const Value.absent(),
    required int validRatioPct,
  })  : sessionId = Value(sessionId),
        ts = Value(ts),
        validRatioPct = Value(validRatioPct);
  static Insertable<MetricSample> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<double>? blinkRate,
    Expression<double>? perclos,
    Expression<double>? distanceCm,
    Expression<int>? fatigueScore,
    Expression<int>? validRatioPct,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (blinkRate != null) 'blink_rate': blinkRate,
      if (perclos != null) 'perclos': perclos,
      if (distanceCm != null) 'distance_cm': distanceCm,
      if (fatigueScore != null) 'fatigue_score': fatigueScore,
      if (validRatioPct != null) 'valid_ratio_pct': validRatioPct,
    });
  }

  MetricSamplesCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<String>? ts,
      Value<double?>? blinkRate,
      Value<double?>? perclos,
      Value<double?>? distanceCm,
      Value<int?>? fatigueScore,
      Value<int>? validRatioPct}) {
    return MetricSamplesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      blinkRate: blinkRate ?? this.blinkRate,
      perclos: perclos ?? this.perclos,
      distanceCm: distanceCm ?? this.distanceCm,
      fatigueScore: fatigueScore ?? this.fatigueScore,
      validRatioPct: validRatioPct ?? this.validRatioPct,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (blinkRate.present) {
      map['blink_rate'] = Variable<double>(blinkRate.value);
    }
    if (perclos.present) {
      map['perclos'] = Variable<double>(perclos.value);
    }
    if (distanceCm.present) {
      map['distance_cm'] = Variable<double>(distanceCm.value);
    }
    if (fatigueScore.present) {
      map['fatigue_score'] = Variable<int>(fatigueScore.value);
    }
    if (validRatioPct.present) {
      map['valid_ratio_pct'] = Variable<int>(validRatioPct.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetricSamplesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('blinkRate: $blinkRate, ')
          ..write('perclos: $perclos, ')
          ..write('distanceCm: $distanceCm, ')
          ..write('fatigueScore: $fatigueScore, ')
          ..write('validRatioPct: $validRatioPct')
          ..write(')'))
        .toString();
  }
}

class $AlertsTable extends Alerts with TableInfo<$AlertsTable, Alert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
      'ts', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<AlertAction, String> action =
      GeneratedColumn<String>('action', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<AlertAction>($AlertsTable.$converteraction);
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, ts, type, action];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alerts';
  @override
  VerificationContext validateIntegrity(Insertable<Alert> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Alert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Alert(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      ts: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ts'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      action: $AlertsTable.$converteraction.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!),
    );
  }

  @override
  $AlertsTable createAlias(String alias) {
    return $AlertsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AlertAction, String, String> $converteraction =
      const EnumNameConverter<AlertAction>(AlertAction.values);
}

class Alert extends DataClass implements Insertable<Alert> {
  final int id;
  final int sessionId;
  final String ts;
  final String type;
  final AlertAction action;
  const Alert(
      {required this.id,
      required this.sessionId,
      required this.ts,
      required this.type,
      required this.action});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['ts'] = Variable<String>(ts);
    map['type'] = Variable<String>(type);
    {
      map['action'] =
          Variable<String>($AlertsTable.$converteraction.toSql(action));
    }
    return map;
  }

  AlertsCompanion toCompanion(bool nullToAbsent) {
    return AlertsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      ts: Value(ts),
      type: Value(type),
      action: Value(action),
    );
  }

  factory Alert.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Alert(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      type: serializer.fromJson<String>(json['type']),
      action: $AlertsTable.$converteraction
          .fromJson(serializer.fromJson<String>(json['action'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'type': serializer.toJson<String>(type),
      'action': serializer
          .toJson<String>($AlertsTable.$converteraction.toJson(action)),
    };
  }

  Alert copyWith(
          {int? id,
          int? sessionId,
          String? ts,
          String? type,
          AlertAction? action}) =>
      Alert(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        ts: ts ?? this.ts,
        type: type ?? this.type,
        action: action ?? this.action,
      );
  Alert copyWithCompanion(AlertsCompanion data) {
    return Alert(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      type: data.type.present ? data.type.value : this.type,
      action: data.action.present ? data.action.value : this.action,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Alert(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('action: $action')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, ts, type, action);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Alert &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.type == this.type &&
          other.action == this.action);
}

class AlertsCompanion extends UpdateCompanion<Alert> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> ts;
  final Value<String> type;
  final Value<AlertAction> action;
  const AlertsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.type = const Value.absent(),
    this.action = const Value.absent(),
  });
  AlertsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String ts,
    required String type,
    required AlertAction action,
  })  : sessionId = Value(sessionId),
        ts = Value(ts),
        type = Value(type),
        action = Value(action);
  static Insertable<Alert> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<String>? type,
    Expression<String>? action,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (type != null) 'type': type,
      if (action != null) 'action': action,
    });
  }

  AlertsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<String>? ts,
      Value<String>? type,
      Value<AlertAction>? action}) {
    return AlertsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      type: type ?? this.type,
      action: action ?? this.action,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (action.present) {
      map['action'] =
          Variable<String>($AlertsTable.$converteraction.toSql(action.value));
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('type: $type, ')
          ..write('action: $action')
          ..write(')'))
        .toString();
  }
}

class $DailySummariesTable extends DailySummaries
    with TableInfo<$DailySummariesTable, DailySummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
      'day', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _screenMinutesMeta =
      const VerificationMeta('screenMinutes');
  @override
  late final GeneratedColumn<int> screenMinutes = GeneratedColumn<int>(
      'screen_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _avgBlinkRateMeta =
      const VerificationMeta('avgBlinkRate');
  @override
  late final GeneratedColumn<double> avgBlinkRate = GeneratedColumn<double>(
      'avg_blink_rate', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _avgDistanceCmMeta =
      const VerificationMeta('avgDistanceCm');
  @override
  late final GeneratedColumn<double> avgDistanceCm = GeneratedColumn<double>(
      'avg_distance_cm', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _avgFatigueScoreMeta =
      const VerificationMeta('avgFatigueScore');
  @override
  late final GeneratedColumn<double> avgFatigueScore = GeneratedColumn<double>(
      'avg_fatigue_score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _alertsCountMeta =
      const VerificationMeta('alertsCount');
  @override
  late final GeneratedColumn<int> alertsCount = GeneratedColumn<int>(
      'alerts_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _breaksTakenMeta =
      const VerificationMeta('breaksTaken');
  @override
  late final GeneratedColumn<int> breaksTaken = GeneratedColumn<int>(
      'breaks_taken', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        day,
        screenMinutes,
        avgBlinkRate,
        avgDistanceCm,
        avgFatigueScore,
        alertsCount,
        breaksTaken,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_summaries';
  @override
  VerificationContext validateIntegrity(Insertable<DailySummary> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('screen_minutes')) {
      context.handle(
          _screenMinutesMeta,
          screenMinutes.isAcceptableOrUnknown(
              data['screen_minutes']!, _screenMinutesMeta));
    } else if (isInserting) {
      context.missing(_screenMinutesMeta);
    }
    if (data.containsKey('avg_blink_rate')) {
      context.handle(
          _avgBlinkRateMeta,
          avgBlinkRate.isAcceptableOrUnknown(
              data['avg_blink_rate']!, _avgBlinkRateMeta));
    }
    if (data.containsKey('avg_distance_cm')) {
      context.handle(
          _avgDistanceCmMeta,
          avgDistanceCm.isAcceptableOrUnknown(
              data['avg_distance_cm']!, _avgDistanceCmMeta));
    }
    if (data.containsKey('avg_fatigue_score')) {
      context.handle(
          _avgFatigueScoreMeta,
          avgFatigueScore.isAcceptableOrUnknown(
              data['avg_fatigue_score']!, _avgFatigueScoreMeta));
    }
    if (data.containsKey('alerts_count')) {
      context.handle(
          _alertsCountMeta,
          alertsCount.isAcceptableOrUnknown(
              data['alerts_count']!, _alertsCountMeta));
    } else if (isInserting) {
      context.missing(_alertsCountMeta);
    }
    if (data.containsKey('breaks_taken')) {
      context.handle(
          _breaksTakenMeta,
          breaksTaken.isAcceptableOrUnknown(
              data['breaks_taken']!, _breaksTakenMeta));
    } else if (isInserting) {
      context.missing(_breaksTakenMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailySummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySummary(
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}day'])!,
      screenMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}screen_minutes'])!,
      avgBlinkRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}avg_blink_rate']),
      avgDistanceCm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}avg_distance_cm']),
      avgFatigueScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}avg_fatigue_score']),
      alertsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}alerts_count'])!,
      breaksTaken: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}breaks_taken'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $DailySummariesTable createAlias(String alias) {
    return $DailySummariesTable(attachedDatabase, alias);
  }
}

class DailySummary extends DataClass implements Insertable<DailySummary> {
  final String day;
  final int screenMinutes;
  final double? avgBlinkRate;
  final double? avgDistanceCm;
  final double? avgFatigueScore;
  final int alertsCount;
  final int breaksTaken;
  final bool synced;
  const DailySummary(
      {required this.day,
      required this.screenMinutes,
      this.avgBlinkRate,
      this.avgDistanceCm,
      this.avgFatigueScore,
      required this.alertsCount,
      required this.breaksTaken,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['screen_minutes'] = Variable<int>(screenMinutes);
    if (!nullToAbsent || avgBlinkRate != null) {
      map['avg_blink_rate'] = Variable<double>(avgBlinkRate);
    }
    if (!nullToAbsent || avgDistanceCm != null) {
      map['avg_distance_cm'] = Variable<double>(avgDistanceCm);
    }
    if (!nullToAbsent || avgFatigueScore != null) {
      map['avg_fatigue_score'] = Variable<double>(avgFatigueScore);
    }
    map['alerts_count'] = Variable<int>(alertsCount);
    map['breaks_taken'] = Variable<int>(breaksTaken);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  DailySummariesCompanion toCompanion(bool nullToAbsent) {
    return DailySummariesCompanion(
      day: Value(day),
      screenMinutes: Value(screenMinutes),
      avgBlinkRate: avgBlinkRate == null && nullToAbsent
          ? const Value.absent()
          : Value(avgBlinkRate),
      avgDistanceCm: avgDistanceCm == null && nullToAbsent
          ? const Value.absent()
          : Value(avgDistanceCm),
      avgFatigueScore: avgFatigueScore == null && nullToAbsent
          ? const Value.absent()
          : Value(avgFatigueScore),
      alertsCount: Value(alertsCount),
      breaksTaken: Value(breaksTaken),
      synced: Value(synced),
    );
  }

  factory DailySummary.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySummary(
      day: serializer.fromJson<String>(json['day']),
      screenMinutes: serializer.fromJson<int>(json['screenMinutes']),
      avgBlinkRate: serializer.fromJson<double?>(json['avgBlinkRate']),
      avgDistanceCm: serializer.fromJson<double?>(json['avgDistanceCm']),
      avgFatigueScore: serializer.fromJson<double?>(json['avgFatigueScore']),
      alertsCount: serializer.fromJson<int>(json['alertsCount']),
      breaksTaken: serializer.fromJson<int>(json['breaksTaken']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'screenMinutes': serializer.toJson<int>(screenMinutes),
      'avgBlinkRate': serializer.toJson<double?>(avgBlinkRate),
      'avgDistanceCm': serializer.toJson<double?>(avgDistanceCm),
      'avgFatigueScore': serializer.toJson<double?>(avgFatigueScore),
      'alertsCount': serializer.toJson<int>(alertsCount),
      'breaksTaken': serializer.toJson<int>(breaksTaken),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  DailySummary copyWith(
          {String? day,
          int? screenMinutes,
          Value<double?> avgBlinkRate = const Value.absent(),
          Value<double?> avgDistanceCm = const Value.absent(),
          Value<double?> avgFatigueScore = const Value.absent(),
          int? alertsCount,
          int? breaksTaken,
          bool? synced}) =>
      DailySummary(
        day: day ?? this.day,
        screenMinutes: screenMinutes ?? this.screenMinutes,
        avgBlinkRate:
            avgBlinkRate.present ? avgBlinkRate.value : this.avgBlinkRate,
        avgDistanceCm:
            avgDistanceCm.present ? avgDistanceCm.value : this.avgDistanceCm,
        avgFatigueScore: avgFatigueScore.present
            ? avgFatigueScore.value
            : this.avgFatigueScore,
        alertsCount: alertsCount ?? this.alertsCount,
        breaksTaken: breaksTaken ?? this.breaksTaken,
        synced: synced ?? this.synced,
      );
  DailySummary copyWithCompanion(DailySummariesCompanion data) {
    return DailySummary(
      day: data.day.present ? data.day.value : this.day,
      screenMinutes: data.screenMinutes.present
          ? data.screenMinutes.value
          : this.screenMinutes,
      avgBlinkRate: data.avgBlinkRate.present
          ? data.avgBlinkRate.value
          : this.avgBlinkRate,
      avgDistanceCm: data.avgDistanceCm.present
          ? data.avgDistanceCm.value
          : this.avgDistanceCm,
      avgFatigueScore: data.avgFatigueScore.present
          ? data.avgFatigueScore.value
          : this.avgFatigueScore,
      alertsCount:
          data.alertsCount.present ? data.alertsCount.value : this.alertsCount,
      breaksTaken:
          data.breaksTaken.present ? data.breaksTaken.value : this.breaksTaken,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySummary(')
          ..write('day: $day, ')
          ..write('screenMinutes: $screenMinutes, ')
          ..write('avgBlinkRate: $avgBlinkRate, ')
          ..write('avgDistanceCm: $avgDistanceCm, ')
          ..write('avgFatigueScore: $avgFatigueScore, ')
          ..write('alertsCount: $alertsCount, ')
          ..write('breaksTaken: $breaksTaken, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, screenMinutes, avgBlinkRate,
      avgDistanceCm, avgFatigueScore, alertsCount, breaksTaken, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySummary &&
          other.day == this.day &&
          other.screenMinutes == this.screenMinutes &&
          other.avgBlinkRate == this.avgBlinkRate &&
          other.avgDistanceCm == this.avgDistanceCm &&
          other.avgFatigueScore == this.avgFatigueScore &&
          other.alertsCount == this.alertsCount &&
          other.breaksTaken == this.breaksTaken &&
          other.synced == this.synced);
}

class DailySummariesCompanion extends UpdateCompanion<DailySummary> {
  final Value<String> day;
  final Value<int> screenMinutes;
  final Value<double?> avgBlinkRate;
  final Value<double?> avgDistanceCm;
  final Value<double?> avgFatigueScore;
  final Value<int> alertsCount;
  final Value<int> breaksTaken;
  final Value<bool> synced;
  final Value<int> rowid;
  const DailySummariesCompanion({
    this.day = const Value.absent(),
    this.screenMinutes = const Value.absent(),
    this.avgBlinkRate = const Value.absent(),
    this.avgDistanceCm = const Value.absent(),
    this.avgFatigueScore = const Value.absent(),
    this.alertsCount = const Value.absent(),
    this.breaksTaken = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailySummariesCompanion.insert({
    required String day,
    required int screenMinutes,
    this.avgBlinkRate = const Value.absent(),
    this.avgDistanceCm = const Value.absent(),
    this.avgFatigueScore = const Value.absent(),
    required int alertsCount,
    required int breaksTaken,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : day = Value(day),
        screenMinutes = Value(screenMinutes),
        alertsCount = Value(alertsCount),
        breaksTaken = Value(breaksTaken);
  static Insertable<DailySummary> custom({
    Expression<String>? day,
    Expression<int>? screenMinutes,
    Expression<double>? avgBlinkRate,
    Expression<double>? avgDistanceCm,
    Expression<double>? avgFatigueScore,
    Expression<int>? alertsCount,
    Expression<int>? breaksTaken,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (screenMinutes != null) 'screen_minutes': screenMinutes,
      if (avgBlinkRate != null) 'avg_blink_rate': avgBlinkRate,
      if (avgDistanceCm != null) 'avg_distance_cm': avgDistanceCm,
      if (avgFatigueScore != null) 'avg_fatigue_score': avgFatigueScore,
      if (alertsCount != null) 'alerts_count': alertsCount,
      if (breaksTaken != null) 'breaks_taken': breaksTaken,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailySummariesCompanion copyWith(
      {Value<String>? day,
      Value<int>? screenMinutes,
      Value<double?>? avgBlinkRate,
      Value<double?>? avgDistanceCm,
      Value<double?>? avgFatigueScore,
      Value<int>? alertsCount,
      Value<int>? breaksTaken,
      Value<bool>? synced,
      Value<int>? rowid}) {
    return DailySummariesCompanion(
      day: day ?? this.day,
      screenMinutes: screenMinutes ?? this.screenMinutes,
      avgBlinkRate: avgBlinkRate ?? this.avgBlinkRate,
      avgDistanceCm: avgDistanceCm ?? this.avgDistanceCm,
      avgFatigueScore: avgFatigueScore ?? this.avgFatigueScore,
      alertsCount: alertsCount ?? this.alertsCount,
      breaksTaken: breaksTaken ?? this.breaksTaken,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (screenMinutes.present) {
      map['screen_minutes'] = Variable<int>(screenMinutes.value);
    }
    if (avgBlinkRate.present) {
      map['avg_blink_rate'] = Variable<double>(avgBlinkRate.value);
    }
    if (avgDistanceCm.present) {
      map['avg_distance_cm'] = Variable<double>(avgDistanceCm.value);
    }
    if (avgFatigueScore.present) {
      map['avg_fatigue_score'] = Variable<double>(avgFatigueScore.value);
    }
    if (alertsCount.present) {
      map['alerts_count'] = Variable<int>(alertsCount.value);
    }
    if (breaksTaken.present) {
      map['breaks_taken'] = Variable<int>(breaksTaken.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySummariesCompanion(')
          ..write('day: $day, ')
          ..write('screenMinutes: $screenMinutes, ')
          ..write('avgBlinkRate: $avgBlinkRate, ')
          ..write('avgDistanceCm: $avgDistanceCm, ')
          ..write('avgFatigueScore: $avgFatigueScore, ')
          ..write('alertsCount: $alertsCount, ')
          ..write('breaksTaken: $breaksTaken, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CalibrationsTable calibrations = $CalibrationsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MetricSamplesTable metricSamples = $MetricSamplesTable(this);
  late final $AlertsTable alerts = $AlertsTable(this);
  late final $DailySummariesTable dailySummaries = $DailySummariesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [calibrations, sessions, metricSamples, alerts, dailySummaries, settings];
}

typedef $$CalibrationsTableCreateCompanionBuilder = CalibrationsCompanion
    Function({
  Value<int> id,
  required String cameraId,
  required double earBaseline,
  required double focalPx,
  required String createdAt,
});
typedef $$CalibrationsTableUpdateCompanionBuilder = CalibrationsCompanion
    Function({
  Value<int> id,
  Value<String> cameraId,
  Value<double> earBaseline,
  Value<double> focalPx,
  Value<String> createdAt,
});

class $$CalibrationsTableFilterComposer
    extends Composer<_$AppDatabase, $CalibrationsTable> {
  $$CalibrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cameraId => $composableBuilder(
      column: $table.cameraId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get earBaseline => $composableBuilder(
      column: $table.earBaseline, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get focalPx => $composableBuilder(
      column: $table.focalPx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$CalibrationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalibrationsTable> {
  $$CalibrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cameraId => $composableBuilder(
      column: $table.cameraId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get earBaseline => $composableBuilder(
      column: $table.earBaseline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get focalPx => $composableBuilder(
      column: $table.focalPx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$CalibrationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalibrationsTable> {
  $$CalibrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cameraId =>
      $composableBuilder(column: $table.cameraId, builder: (column) => column);

  GeneratedColumn<double> get earBaseline => $composableBuilder(
      column: $table.earBaseline, builder: (column) => column);

  GeneratedColumn<double> get focalPx =>
      $composableBuilder(column: $table.focalPx, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CalibrationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalibrationsTable,
    Calibration,
    $$CalibrationsTableFilterComposer,
    $$CalibrationsTableOrderingComposer,
    $$CalibrationsTableAnnotationComposer,
    $$CalibrationsTableCreateCompanionBuilder,
    $$CalibrationsTableUpdateCompanionBuilder,
    (
      Calibration,
      BaseReferences<_$AppDatabase, $CalibrationsTable, Calibration>
    ),
    Calibration,
    PrefetchHooks Function()> {
  $$CalibrationsTableTableManager(_$AppDatabase db, $CalibrationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalibrationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalibrationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalibrationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> cameraId = const Value.absent(),
            Value<double> earBaseline = const Value.absent(),
            Value<double> focalPx = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
          }) =>
              CalibrationsCompanion(
            id: id,
            cameraId: cameraId,
            earBaseline: earBaseline,
            focalPx: focalPx,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String cameraId,
            required double earBaseline,
            required double focalPx,
            required String createdAt,
          }) =>
              CalibrationsCompanion.insert(
            id: id,
            cameraId: cameraId,
            earBaseline: earBaseline,
            focalPx: focalPx,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CalibrationsTable, Calibration>(table),
                    BaseReferences<_$AppDatabase, $CalibrationsTable,
                        Calibration>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalibrationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalibrationsTable,
    Calibration,
    $$CalibrationsTableFilterComposer,
    $$CalibrationsTableOrderingComposer,
    $$CalibrationsTableAnnotationComposer,
    $$CalibrationsTableCreateCompanionBuilder,
    $$CalibrationsTableUpdateCompanionBuilder,
    (
      Calibration,
      BaseReferences<_$AppDatabase, $CalibrationsTable, Calibration>
    ),
    Calibration,
    PrefetchHooks Function()>;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required SessionMode mode,
  required String startedAt,
  Value<String?> endedAt,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<SessionMode> mode,
  Value<String> startedAt,
  Value<String?> endedAt,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MetricSamplesTable, List<MetricSample>>
      _metricSamplesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.metricSamples,
              aliasName: 'sessions__id__metric_samples__session_id');

  $$MetricSamplesTableProcessedTableManager get metricSamplesRefs {
    final manager = $$MetricSamplesTableTableManager($_db, $_db.metricSamples)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_metricSamplesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AlertsTable, List<Alert>> _alertsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.alerts,
          aliasName: 'sessions__id__alerts__session_id');

  $$AlertsTableProcessedTableManager get alertsRefs {
    final manager = $$AlertsTableTableManager($_db, $_db.alerts)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_alertsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SessionMode, SessionMode, String> get mode =>
      $composableBuilder(
          column: $table.mode,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> metricSamplesRefs(
      Expression<bool> Function($$MetricSamplesTableFilterComposer f) f) {
    final $$MetricSamplesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.metricSamples,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MetricSamplesTableFilterComposer(
              $db: $db,
              $table: $db.metricSamples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> alertsRefs(
      Expression<bool> Function($$AlertsTableFilterComposer f) f) {
    final $$AlertsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.alerts,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AlertsTableFilterComposer(
              $db: $db,
              $table: $db.alerts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SessionMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  Expression<T> metricSamplesRefs<T extends Object>(
      Expression<T> Function($$MetricSamplesTableAnnotationComposer a) f) {
    final $$MetricSamplesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.metricSamples,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MetricSamplesTableAnnotationComposer(
              $db: $db,
              $table: $db.metricSamples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> alertsRefs<T extends Object>(
      Expression<T> Function($$AlertsTableAnnotationComposer a) f) {
    final $$AlertsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.alerts,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AlertsTableAnnotationComposer(
              $db: $db,
              $table: $db.alerts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool metricSamplesRefs, bool alertsRefs})> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<SessionMode> mode = const Value.absent(),
            Value<String> startedAt = const Value.absent(),
            Value<String?> endedAt = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            mode: mode,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required SessionMode mode,
            required String startedAt,
            Value<String?> endedAt = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            mode: mode,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SessionsTable, Session>(table),
                    $$SessionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {metricSamplesRefs = false, alertsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (metricSamplesRefs) db.metricSamples,
                if (alertsRefs) db.alerts
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (metricSamplesRefs)
                    await $_getPrefetchedDataByColumns<Session, $SessionsTable,
                            MetricSample, $MetricSamplesTable>(
                        currentTable: table,
                        referencedTable: $$SessionsTableReferences
                            ._metricSamplesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0)
                                .metricSamplesRefs,
                        currentColumn: 'id',
                        referencedColumn: 'session_id',
                        typedResults: items),
                  if (alertsRefs)
                    await $_getPrefetchedDataByColumns<Session, $SessionsTable,
                            Alert, $AlertsTable>(
                        currentTable: table,
                        referencedTable:
                            $$SessionsTableReferences._alertsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0).alertsRefs,
                        currentColumn: 'id',
                        referencedColumn: 'session_id',
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool metricSamplesRefs, bool alertsRefs})>;
typedef $$MetricSamplesTableCreateCompanionBuilder = MetricSamplesCompanion
    Function({
  Value<int> id,
  required int sessionId,
  required String ts,
  Value<double?> blinkRate,
  Value<double?> perclos,
  Value<double?> distanceCm,
  Value<int?> fatigueScore,
  required int validRatioPct,
});
typedef $$MetricSamplesTableUpdateCompanionBuilder = MetricSamplesCompanion
    Function({
  Value<int> id,
  Value<int> sessionId,
  Value<String> ts,
  Value<double?> blinkRate,
  Value<double?> perclos,
  Value<double?> distanceCm,
  Value<int?> fatigueScore,
  Value<int> validRatioPct,
});

final class $$MetricSamplesTableReferences
    extends BaseReferences<_$AppDatabase, $MetricSamplesTable, MetricSample> {
  $$MetricSamplesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('metric_samples__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MetricSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $MetricSamplesTable> {
  $$MetricSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get blinkRate => $composableBuilder(
      column: $table.blinkRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get perclos => $composableBuilder(
      column: $table.perclos, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceCm => $composableBuilder(
      column: $table.distanceCm, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fatigueScore => $composableBuilder(
      column: $table.fatigueScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get validRatioPct => $composableBuilder(
      column: $table.validRatioPct, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MetricSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $MetricSamplesTable> {
  $$MetricSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get blinkRate => $composableBuilder(
      column: $table.blinkRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get perclos => $composableBuilder(
      column: $table.perclos, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceCm => $composableBuilder(
      column: $table.distanceCm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fatigueScore => $composableBuilder(
      column: $table.fatigueScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get validRatioPct => $composableBuilder(
      column: $table.validRatioPct,
      builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MetricSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetricSamplesTable> {
  $$MetricSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<double> get blinkRate =>
      $composableBuilder(column: $table.blinkRate, builder: (column) => column);

  GeneratedColumn<double> get perclos =>
      $composableBuilder(column: $table.perclos, builder: (column) => column);

  GeneratedColumn<double> get distanceCm => $composableBuilder(
      column: $table.distanceCm, builder: (column) => column);

  GeneratedColumn<int> get fatigueScore => $composableBuilder(
      column: $table.fatigueScore, builder: (column) => column);

  GeneratedColumn<int> get validRatioPct => $composableBuilder(
      column: $table.validRatioPct, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MetricSamplesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MetricSamplesTable,
    MetricSample,
    $$MetricSamplesTableFilterComposer,
    $$MetricSamplesTableOrderingComposer,
    $$MetricSamplesTableAnnotationComposer,
    $$MetricSamplesTableCreateCompanionBuilder,
    $$MetricSamplesTableUpdateCompanionBuilder,
    (MetricSample, $$MetricSamplesTableReferences),
    MetricSample,
    PrefetchHooks Function({bool sessionId})> {
  $$MetricSamplesTableTableManager(_$AppDatabase db, $MetricSamplesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetricSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetricSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetricSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> ts = const Value.absent(),
            Value<double?> blinkRate = const Value.absent(),
            Value<double?> perclos = const Value.absent(),
            Value<double?> distanceCm = const Value.absent(),
            Value<int?> fatigueScore = const Value.absent(),
            Value<int> validRatioPct = const Value.absent(),
          }) =>
              MetricSamplesCompanion(
            id: id,
            sessionId: sessionId,
            ts: ts,
            blinkRate: blinkRate,
            perclos: perclos,
            distanceCm: distanceCm,
            fatigueScore: fatigueScore,
            validRatioPct: validRatioPct,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required String ts,
            Value<double?> blinkRate = const Value.absent(),
            Value<double?> perclos = const Value.absent(),
            Value<double?> distanceCm = const Value.absent(),
            Value<int?> fatigueScore = const Value.absent(),
            required int validRatioPct,
          }) =>
              MetricSamplesCompanion.insert(
            id: id,
            sessionId: sessionId,
            ts: ts,
            blinkRate: blinkRate,
            perclos: perclos,
            distanceCm: distanceCm,
            fatigueScore: fatigueScore,
            validRatioPct: validRatioPct,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MetricSamplesTable, MetricSample>(table),
                    $$MetricSamplesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$MetricSamplesTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$MetricSamplesTableReferences._sessionIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MetricSamplesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MetricSamplesTable,
    MetricSample,
    $$MetricSamplesTableFilterComposer,
    $$MetricSamplesTableOrderingComposer,
    $$MetricSamplesTableAnnotationComposer,
    $$MetricSamplesTableCreateCompanionBuilder,
    $$MetricSamplesTableUpdateCompanionBuilder,
    (MetricSample, $$MetricSamplesTableReferences),
    MetricSample,
    PrefetchHooks Function({bool sessionId})>;
typedef $$AlertsTableCreateCompanionBuilder = AlertsCompanion Function({
  Value<int> id,
  required int sessionId,
  required String ts,
  required String type,
  required AlertAction action,
});
typedef $$AlertsTableUpdateCompanionBuilder = AlertsCompanion Function({
  Value<int> id,
  Value<int> sessionId,
  Value<String> ts,
  Value<String> type,
  Value<AlertAction> action,
});

final class $$AlertsTableReferences
    extends BaseReferences<_$AppDatabase, $AlertsTable, Alert> {
  $$AlertsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('alerts__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AlertsTableFilterComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AlertAction, AlertAction, String> get action =>
      $composableBuilder(
          column: $table.action,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ts => $composableBuilder(
      column: $table.ts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AlertAction, String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AlertsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AlertsTable,
    Alert,
    $$AlertsTableFilterComposer,
    $$AlertsTableOrderingComposer,
    $$AlertsTableAnnotationComposer,
    $$AlertsTableCreateCompanionBuilder,
    $$AlertsTableUpdateCompanionBuilder,
    (Alert, $$AlertsTableReferences),
    Alert,
    PrefetchHooks Function({bool sessionId})> {
  $$AlertsTableTableManager(_$AppDatabase db, $AlertsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<String> ts = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<AlertAction> action = const Value.absent(),
          }) =>
              AlertsCompanion(
            id: id,
            sessionId: sessionId,
            ts: ts,
            type: type,
            action: action,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required String ts,
            required String type,
            required AlertAction action,
          }) =>
              AlertsCompanion.insert(
            id: id,
            sessionId: sessionId,
            ts: ts,
            type: type,
            action: action,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AlertsTable, Alert>(table),
                    $$AlertsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$AlertsTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$AlertsTableReferences._sessionIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AlertsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AlertsTable,
    Alert,
    $$AlertsTableFilterComposer,
    $$AlertsTableOrderingComposer,
    $$AlertsTableAnnotationComposer,
    $$AlertsTableCreateCompanionBuilder,
    $$AlertsTableUpdateCompanionBuilder,
    (Alert, $$AlertsTableReferences),
    Alert,
    PrefetchHooks Function({bool sessionId})>;
typedef $$DailySummariesTableCreateCompanionBuilder = DailySummariesCompanion
    Function({
  required String day,
  required int screenMinutes,
  Value<double?> avgBlinkRate,
  Value<double?> avgDistanceCm,
  Value<double?> avgFatigueScore,
  required int alertsCount,
  required int breaksTaken,
  Value<bool> synced,
  Value<int> rowid,
});
typedef $$DailySummariesTableUpdateCompanionBuilder = DailySummariesCompanion
    Function({
  Value<String> day,
  Value<int> screenMinutes,
  Value<double?> avgBlinkRate,
  Value<double?> avgDistanceCm,
  Value<double?> avgFatigueScore,
  Value<int> alertsCount,
  Value<int> breaksTaken,
  Value<bool> synced,
  Value<int> rowid,
});

class $$DailySummariesTableFilterComposer
    extends Composer<_$AppDatabase, $DailySummariesTable> {
  $$DailySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get screenMinutes => $composableBuilder(
      column: $table.screenMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get avgBlinkRate => $composableBuilder(
      column: $table.avgBlinkRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get avgDistanceCm => $composableBuilder(
      column: $table.avgDistanceCm, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get avgFatigueScore => $composableBuilder(
      column: $table.avgFatigueScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get alertsCount => $composableBuilder(
      column: $table.alertsCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get breaksTaken => $composableBuilder(
      column: $table.breaksTaken, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$DailySummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySummariesTable> {
  $$DailySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get screenMinutes => $composableBuilder(
      column: $table.screenMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get avgBlinkRate => $composableBuilder(
      column: $table.avgBlinkRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get avgDistanceCm => $composableBuilder(
      column: $table.avgDistanceCm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get avgFatigueScore => $composableBuilder(
      column: $table.avgFatigueScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get alertsCount => $composableBuilder(
      column: $table.alertsCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get breaksTaken => $composableBuilder(
      column: $table.breaksTaken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$DailySummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySummariesTable> {
  $$DailySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get screenMinutes => $composableBuilder(
      column: $table.screenMinutes, builder: (column) => column);

  GeneratedColumn<double> get avgBlinkRate => $composableBuilder(
      column: $table.avgBlinkRate, builder: (column) => column);

  GeneratedColumn<double> get avgDistanceCm => $composableBuilder(
      column: $table.avgDistanceCm, builder: (column) => column);

  GeneratedColumn<double> get avgFatigueScore => $composableBuilder(
      column: $table.avgFatigueScore, builder: (column) => column);

  GeneratedColumn<int> get alertsCount => $composableBuilder(
      column: $table.alertsCount, builder: (column) => column);

  GeneratedColumn<int> get breaksTaken => $composableBuilder(
      column: $table.breaksTaken, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$DailySummariesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailySummariesTable,
    DailySummary,
    $$DailySummariesTableFilterComposer,
    $$DailySummariesTableOrderingComposer,
    $$DailySummariesTableAnnotationComposer,
    $$DailySummariesTableCreateCompanionBuilder,
    $$DailySummariesTableUpdateCompanionBuilder,
    (
      DailySummary,
      BaseReferences<_$AppDatabase, $DailySummariesTable, DailySummary>
    ),
    DailySummary,
    PrefetchHooks Function()> {
  $$DailySummariesTableTableManager(
      _$AppDatabase db, $DailySummariesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> day = const Value.absent(),
            Value<int> screenMinutes = const Value.absent(),
            Value<double?> avgBlinkRate = const Value.absent(),
            Value<double?> avgDistanceCm = const Value.absent(),
            Value<double?> avgFatigueScore = const Value.absent(),
            Value<int> alertsCount = const Value.absent(),
            Value<int> breaksTaken = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailySummariesCompanion(
            day: day,
            screenMinutes: screenMinutes,
            avgBlinkRate: avgBlinkRate,
            avgDistanceCm: avgDistanceCm,
            avgFatigueScore: avgFatigueScore,
            alertsCount: alertsCount,
            breaksTaken: breaksTaken,
            synced: synced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String day,
            required int screenMinutes,
            Value<double?> avgBlinkRate = const Value.absent(),
            Value<double?> avgDistanceCm = const Value.absent(),
            Value<double?> avgFatigueScore = const Value.absent(),
            required int alertsCount,
            required int breaksTaken,
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailySummariesCompanion.insert(
            day: day,
            screenMinutes: screenMinutes,
            avgBlinkRate: avgBlinkRate,
            avgDistanceCm: avgDistanceCm,
            avgFatigueScore: avgFatigueScore,
            alertsCount: alertsCount,
            breaksTaken: breaksTaken,
            synced: synced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DailySummariesTable, DailySummary>(table),
                    BaseReferences<_$AppDatabase, $DailySummariesTable,
                        DailySummary>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailySummariesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailySummariesTable,
    DailySummary,
    $$DailySummariesTableFilterComposer,
    $$DailySummariesTableOrderingComposer,
    $$DailySummariesTableAnnotationComposer,
    $$DailySummariesTableCreateCompanionBuilder,
    $$DailySummariesTableUpdateCompanionBuilder,
    (
      DailySummary,
      BaseReferences<_$AppDatabase, $DailySummariesTable, DailySummary>
    ),
    DailySummary,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsTable, Setting>(table),
                    BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CalibrationsTableTableManager get calibrations =>
      $$CalibrationsTableTableManager(_db, _db.calibrations);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MetricSamplesTableTableManager get metricSamples =>
      $$MetricSamplesTableTableManager(_db, _db.metricSamples);
  $$AlertsTableTableManager get alerts =>
      $$AlertsTableTableManager(_db, _db.alerts);
  $$DailySummariesTableTableManager get dailySummaries =>
      $$DailySummariesTableTableManager(_db, _db.dailySummaries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
