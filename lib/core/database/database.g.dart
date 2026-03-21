// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SemestersTable extends Semesters
    with TableInfo<$SemestersTable, Semester> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SemestersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startYearMeta = const VerificationMeta(
    'startYear',
  );
  @override
  late final GeneratedColumn<int> startYear = GeneratedColumn<int>(
    'start_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endYearMeta = const VerificationMeta(
    'endYear',
  );
  @override
  late final GeneratedColumn<int> endYear = GeneratedColumn<int>(
    'end_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startDate,
    endDate,
    startYear,
    endYear,
    type,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'semesters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Semester> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('start_year')) {
      context.handle(
        _startYearMeta,
        startYear.isAcceptableOrUnknown(data['start_year']!, _startYearMeta),
      );
    } else if (isInserting) {
      context.missing(_startYearMeta);
    }
    if (data.containsKey('end_year')) {
      context.handle(
        _endYearMeta,
        endYear.isAcceptableOrUnknown(data['end_year']!, _endYearMeta),
      );
    } else if (isInserting) {
      context.missing(_endYearMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Semester map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Semester(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      )!,
      startYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_year'],
      )!,
      endYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_year'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
    );
  }

  @override
  $SemestersTable createAlias(String alias) {
    return $SemestersTable(attachedDatabase, alias);
  }
}

class Semester extends DataClass implements Insertable<Semester> {
  final String id;
  final String startDate;
  final String endDate;
  final int startYear;
  final int endYear;
  final String type;
  const Semester({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.startYear,
    required this.endYear,
    required this.type,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['start_date'] = Variable<String>(startDate);
    map['end_date'] = Variable<String>(endDate);
    map['start_year'] = Variable<int>(startYear);
    map['end_year'] = Variable<int>(endYear);
    map['type'] = Variable<String>(type);
    return map;
  }

  SemestersCompanion toCompanion(bool nullToAbsent) {
    return SemestersCompanion(
      id: Value(id),
      startDate: Value(startDate),
      endDate: Value(endDate),
      startYear: Value(startYear),
      endYear: Value(endYear),
      type: Value(type),
    );
  }

  factory Semester.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Semester(
      id: serializer.fromJson<String>(json['id']),
      startDate: serializer.fromJson<String>(json['startDate']),
      endDate: serializer.fromJson<String>(json['endDate']),
      startYear: serializer.fromJson<int>(json['startYear']),
      endYear: serializer.fromJson<int>(json['endYear']),
      type: serializer.fromJson<String>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startDate': serializer.toJson<String>(startDate),
      'endDate': serializer.toJson<String>(endDate),
      'startYear': serializer.toJson<int>(startYear),
      'endYear': serializer.toJson<int>(endYear),
      'type': serializer.toJson<String>(type),
    };
  }

  Semester copyWith({
    String? id,
    String? startDate,
    String? endDate,
    int? startYear,
    int? endYear,
    String? type,
  }) => Semester(
    id: id ?? this.id,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startYear: startYear ?? this.startYear,
    endYear: endYear ?? this.endYear,
    type: type ?? this.type,
  );
  Semester copyWithCompanion(SemestersCompanion data) {
    return Semester(
      id: data.id.present ? data.id.value : this.id,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      startYear: data.startYear.present ? data.startYear.value : this.startYear,
      endYear: data.endYear.present ? data.endYear.value : this.endYear,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Semester(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startYear: $startYear, ')
          ..write('endYear: $endYear, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startDate, endDate, startYear, endYear, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Semester &&
          other.id == this.id &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.startYear == this.startYear &&
          other.endYear == this.endYear &&
          other.type == this.type);
}

class SemestersCompanion extends UpdateCompanion<Semester> {
  final Value<String> id;
  final Value<String> startDate;
  final Value<String> endDate;
  final Value<int> startYear;
  final Value<int> endYear;
  final Value<String> type;
  final Value<int> rowid;
  const SemestersCompanion({
    this.id = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.startYear = const Value.absent(),
    this.endYear = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SemestersCompanion.insert({
    required String id,
    required String startDate,
    required String endDate,
    required int startYear,
    required int endYear,
    required String type,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startDate = Value(startDate),
       endDate = Value(endDate),
       startYear = Value(startYear),
       endYear = Value(endYear),
       type = Value(type);
  static Insertable<Semester> custom({
    Expression<String>? id,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<int>? startYear,
    Expression<int>? endYear,
    Expression<String>? type,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (startYear != null) 'start_year': startYear,
      if (endYear != null) 'end_year': endYear,
      if (type != null) 'type': type,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SemestersCompanion copyWith({
    Value<String>? id,
    Value<String>? startDate,
    Value<String>? endDate,
    Value<int>? startYear,
    Value<int>? endYear,
    Value<String>? type,
    Value<int>? rowid,
  }) {
    return SemestersCompanion(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      type: type ?? this.type,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (startYear.present) {
      map['start_year'] = Variable<int>(startYear.value);
    }
    if (endYear.present) {
      map['end_year'] = Variable<int>(endYear.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SemestersCompanion(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startYear: $startYear, ')
          ..write('endYear: $endYear, ')
          ..write('type: $type, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _chineseNameMeta = const VerificationMeta(
    'chineseName',
  );
  @override
  late final GeneratedColumn<String> chineseName = GeneratedColumn<String>(
    'chinese_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _englishNameMeta = const VerificationMeta(
    'englishName',
  );
  @override
  late final GeneratedColumn<String> englishName = GeneratedColumn<String>(
    'english_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _teacherNameMeta = const VerificationMeta(
    'teacherName',
  );
  @override
  late final GeneratedColumn<String> teacherName = GeneratedColumn<String>(
    'teacher_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _teacherNumberMeta = const VerificationMeta(
    'teacherNumber',
  );
  @override
  late final GeneratedColumn<String> teacherNumber = GeneratedColumn<String>(
    'teacher_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _courseNumberMeta = const VerificationMeta(
    'courseNumber',
  );
  @override
  late final GeneratedColumn<String> courseNumber = GeneratedColumn<String>(
    'course_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _courseIndexMeta = const VerificationMeta(
    'courseIndex',
  );
  @override
  late final GeneratedColumn<int> courseIndex = GeneratedColumn<int>(
    'course_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _courseTypeMeta = const VerificationMeta(
    'courseType',
  );
  @override
  late final GeneratedColumn<String> courseType = GeneratedColumn<String>(
    'course_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semesterIdMeta = const VerificationMeta(
    'semesterId',
  );
  @override
  late final GeneratedColumn<String> semesterId = GeneratedColumn<String>(
    'semester_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeAndLocationJsonMeta =
      const VerificationMeta('timeAndLocationJson');
  @override
  late final GeneratedColumn<String> timeAndLocationJson =
      GeneratedColumn<String>(
        'time_and_location_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedMeta = const VerificationMeta(
    'lastSynced',
  );
  @override
  late final GeneratedColumn<DateTime> lastSynced = GeneratedColumn<DateTime>(
    'last_synced',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    chineseName,
    englishName,
    teacherName,
    teacherNumber,
    courseNumber,
    courseIndex,
    courseType,
    semesterId,
    timeAndLocationJson,
    sortOrder,
    lastSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Course> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('chinese_name')) {
      context.handle(
        _chineseNameMeta,
        chineseName.isAcceptableOrUnknown(
          data['chinese_name']!,
          _chineseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chineseNameMeta);
    }
    if (data.containsKey('english_name')) {
      context.handle(
        _englishNameMeta,
        englishName.isAcceptableOrUnknown(
          data['english_name']!,
          _englishNameMeta,
        ),
      );
    }
    if (data.containsKey('teacher_name')) {
      context.handle(
        _teacherNameMeta,
        teacherName.isAcceptableOrUnknown(
          data['teacher_name']!,
          _teacherNameMeta,
        ),
      );
    }
    if (data.containsKey('teacher_number')) {
      context.handle(
        _teacherNumberMeta,
        teacherNumber.isAcceptableOrUnknown(
          data['teacher_number']!,
          _teacherNumberMeta,
        ),
      );
    }
    if (data.containsKey('course_number')) {
      context.handle(
        _courseNumberMeta,
        courseNumber.isAcceptableOrUnknown(
          data['course_number']!,
          _courseNumberMeta,
        ),
      );
    }
    if (data.containsKey('course_index')) {
      context.handle(
        _courseIndexMeta,
        courseIndex.isAcceptableOrUnknown(
          data['course_index']!,
          _courseIndexMeta,
        ),
      );
    }
    if (data.containsKey('course_type')) {
      context.handle(
        _courseTypeMeta,
        courseType.isAcceptableOrUnknown(data['course_type']!, _courseTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_courseTypeMeta);
    }
    if (data.containsKey('semester_id')) {
      context.handle(
        _semesterIdMeta,
        semesterId.isAcceptableOrUnknown(data['semester_id']!, _semesterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_semesterIdMeta);
    }
    if (data.containsKey('time_and_location_json')) {
      context.handle(
        _timeAndLocationJsonMeta,
        timeAndLocationJson.isAcceptableOrUnknown(
          data['time_and_location_json']!,
          _timeAndLocationJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('last_synced')) {
      context.handle(
        _lastSyncedMeta,
        lastSynced.isAcceptableOrUnknown(data['last_synced']!, _lastSyncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      chineseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chinese_name'],
      )!,
      englishName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}english_name'],
      )!,
      teacherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_name'],
      )!,
      teacherNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}teacher_number'],
      )!,
      courseNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_number'],
      )!,
      courseIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_index'],
      )!,
      courseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_type'],
      )!,
      semesterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semester_id'],
      )!,
      timeAndLocationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_and_location_json'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      lastSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced'],
      ),
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final String id;
  final String name;
  final String chineseName;
  final String englishName;
  final String teacherName;
  final String teacherNumber;
  final String courseNumber;
  final int courseIndex;
  final String courseType;
  final String semesterId;
  final String timeAndLocationJson;
  final int sortOrder;
  final DateTime? lastSynced;
  const Course({
    required this.id,
    required this.name,
    required this.chineseName,
    required this.englishName,
    required this.teacherName,
    required this.teacherNumber,
    required this.courseNumber,
    required this.courseIndex,
    required this.courseType,
    required this.semesterId,
    required this.timeAndLocationJson,
    required this.sortOrder,
    this.lastSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['chinese_name'] = Variable<String>(chineseName);
    map['english_name'] = Variable<String>(englishName);
    map['teacher_name'] = Variable<String>(teacherName);
    map['teacher_number'] = Variable<String>(teacherNumber);
    map['course_number'] = Variable<String>(courseNumber);
    map['course_index'] = Variable<int>(courseIndex);
    map['course_type'] = Variable<String>(courseType);
    map['semester_id'] = Variable<String>(semesterId);
    map['time_and_location_json'] = Variable<String>(timeAndLocationJson);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || lastSynced != null) {
      map['last_synced'] = Variable<DateTime>(lastSynced);
    }
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      name: Value(name),
      chineseName: Value(chineseName),
      englishName: Value(englishName),
      teacherName: Value(teacherName),
      teacherNumber: Value(teacherNumber),
      courseNumber: Value(courseNumber),
      courseIndex: Value(courseIndex),
      courseType: Value(courseType),
      semesterId: Value(semesterId),
      timeAndLocationJson: Value(timeAndLocationJson),
      sortOrder: Value(sortOrder),
      lastSynced: lastSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSynced),
    );
  }

  factory Course.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      chineseName: serializer.fromJson<String>(json['chineseName']),
      englishName: serializer.fromJson<String>(json['englishName']),
      teacherName: serializer.fromJson<String>(json['teacherName']),
      teacherNumber: serializer.fromJson<String>(json['teacherNumber']),
      courseNumber: serializer.fromJson<String>(json['courseNumber']),
      courseIndex: serializer.fromJson<int>(json['courseIndex']),
      courseType: serializer.fromJson<String>(json['courseType']),
      semesterId: serializer.fromJson<String>(json['semesterId']),
      timeAndLocationJson: serializer.fromJson<String>(
        json['timeAndLocationJson'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      lastSynced: serializer.fromJson<DateTime?>(json['lastSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'chineseName': serializer.toJson<String>(chineseName),
      'englishName': serializer.toJson<String>(englishName),
      'teacherName': serializer.toJson<String>(teacherName),
      'teacherNumber': serializer.toJson<String>(teacherNumber),
      'courseNumber': serializer.toJson<String>(courseNumber),
      'courseIndex': serializer.toJson<int>(courseIndex),
      'courseType': serializer.toJson<String>(courseType),
      'semesterId': serializer.toJson<String>(semesterId),
      'timeAndLocationJson': serializer.toJson<String>(timeAndLocationJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'lastSynced': serializer.toJson<DateTime?>(lastSynced),
    };
  }

  Course copyWith({
    String? id,
    String? name,
    String? chineseName,
    String? englishName,
    String? teacherName,
    String? teacherNumber,
    String? courseNumber,
    int? courseIndex,
    String? courseType,
    String? semesterId,
    String? timeAndLocationJson,
    int? sortOrder,
    Value<DateTime?> lastSynced = const Value.absent(),
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    chineseName: chineseName ?? this.chineseName,
    englishName: englishName ?? this.englishName,
    teacherName: teacherName ?? this.teacherName,
    teacherNumber: teacherNumber ?? this.teacherNumber,
    courseNumber: courseNumber ?? this.courseNumber,
    courseIndex: courseIndex ?? this.courseIndex,
    courseType: courseType ?? this.courseType,
    semesterId: semesterId ?? this.semesterId,
    timeAndLocationJson: timeAndLocationJson ?? this.timeAndLocationJson,
    sortOrder: sortOrder ?? this.sortOrder,
    lastSynced: lastSynced.present ? lastSynced.value : this.lastSynced,
  );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      chineseName: data.chineseName.present
          ? data.chineseName.value
          : this.chineseName,
      englishName: data.englishName.present
          ? data.englishName.value
          : this.englishName,
      teacherName: data.teacherName.present
          ? data.teacherName.value
          : this.teacherName,
      teacherNumber: data.teacherNumber.present
          ? data.teacherNumber.value
          : this.teacherNumber,
      courseNumber: data.courseNumber.present
          ? data.courseNumber.value
          : this.courseNumber,
      courseIndex: data.courseIndex.present
          ? data.courseIndex.value
          : this.courseIndex,
      courseType: data.courseType.present
          ? data.courseType.value
          : this.courseType,
      semesterId: data.semesterId.present
          ? data.semesterId.value
          : this.semesterId,
      timeAndLocationJson: data.timeAndLocationJson.present
          ? data.timeAndLocationJson.value
          : this.timeAndLocationJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      lastSynced: data.lastSynced.present
          ? data.lastSynced.value
          : this.lastSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('chineseName: $chineseName, ')
          ..write('englishName: $englishName, ')
          ..write('teacherName: $teacherName, ')
          ..write('teacherNumber: $teacherNumber, ')
          ..write('courseNumber: $courseNumber, ')
          ..write('courseIndex: $courseIndex, ')
          ..write('courseType: $courseType, ')
          ..write('semesterId: $semesterId, ')
          ..write('timeAndLocationJson: $timeAndLocationJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastSynced: $lastSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    chineseName,
    englishName,
    teacherName,
    teacherNumber,
    courseNumber,
    courseIndex,
    courseType,
    semesterId,
    timeAndLocationJson,
    sortOrder,
    lastSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.name == this.name &&
          other.chineseName == this.chineseName &&
          other.englishName == this.englishName &&
          other.teacherName == this.teacherName &&
          other.teacherNumber == this.teacherNumber &&
          other.courseNumber == this.courseNumber &&
          other.courseIndex == this.courseIndex &&
          other.courseType == this.courseType &&
          other.semesterId == this.semesterId &&
          other.timeAndLocationJson == this.timeAndLocationJson &&
          other.sortOrder == this.sortOrder &&
          other.lastSynced == this.lastSynced);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> chineseName;
  final Value<String> englishName;
  final Value<String> teacherName;
  final Value<String> teacherNumber;
  final Value<String> courseNumber;
  final Value<int> courseIndex;
  final Value<String> courseType;
  final Value<String> semesterId;
  final Value<String> timeAndLocationJson;
  final Value<int> sortOrder;
  final Value<DateTime?> lastSynced;
  final Value<int> rowid;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.chineseName = const Value.absent(),
    this.englishName = const Value.absent(),
    this.teacherName = const Value.absent(),
    this.teacherNumber = const Value.absent(),
    this.courseNumber = const Value.absent(),
    this.courseIndex = const Value.absent(),
    this.courseType = const Value.absent(),
    this.semesterId = const Value.absent(),
    this.timeAndLocationJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lastSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoursesCompanion.insert({
    required String id,
    required String name,
    required String chineseName,
    this.englishName = const Value.absent(),
    this.teacherName = const Value.absent(),
    this.teacherNumber = const Value.absent(),
    this.courseNumber = const Value.absent(),
    this.courseIndex = const Value.absent(),
    required String courseType,
    required String semesterId,
    this.timeAndLocationJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lastSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       chineseName = Value(chineseName),
       courseType = Value(courseType),
       semesterId = Value(semesterId);
  static Insertable<Course> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? chineseName,
    Expression<String>? englishName,
    Expression<String>? teacherName,
    Expression<String>? teacherNumber,
    Expression<String>? courseNumber,
    Expression<int>? courseIndex,
    Expression<String>? courseType,
    Expression<String>? semesterId,
    Expression<String>? timeAndLocationJson,
    Expression<int>? sortOrder,
    Expression<DateTime>? lastSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (chineseName != null) 'chinese_name': chineseName,
      if (englishName != null) 'english_name': englishName,
      if (teacherName != null) 'teacher_name': teacherName,
      if (teacherNumber != null) 'teacher_number': teacherNumber,
      if (courseNumber != null) 'course_number': courseNumber,
      if (courseIndex != null) 'course_index': courseIndex,
      if (courseType != null) 'course_type': courseType,
      if (semesterId != null) 'semester_id': semesterId,
      if (timeAndLocationJson != null)
        'time_and_location_json': timeAndLocationJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (lastSynced != null) 'last_synced': lastSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoursesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? chineseName,
    Value<String>? englishName,
    Value<String>? teacherName,
    Value<String>? teacherNumber,
    Value<String>? courseNumber,
    Value<int>? courseIndex,
    Value<String>? courseType,
    Value<String>? semesterId,
    Value<String>? timeAndLocationJson,
    Value<int>? sortOrder,
    Value<DateTime?>? lastSynced,
    Value<int>? rowid,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      chineseName: chineseName ?? this.chineseName,
      englishName: englishName ?? this.englishName,
      teacherName: teacherName ?? this.teacherName,
      teacherNumber: teacherNumber ?? this.teacherNumber,
      courseNumber: courseNumber ?? this.courseNumber,
      courseIndex: courseIndex ?? this.courseIndex,
      courseType: courseType ?? this.courseType,
      semesterId: semesterId ?? this.semesterId,
      timeAndLocationJson: timeAndLocationJson ?? this.timeAndLocationJson,
      sortOrder: sortOrder ?? this.sortOrder,
      lastSynced: lastSynced ?? this.lastSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (chineseName.present) {
      map['chinese_name'] = Variable<String>(chineseName.value);
    }
    if (englishName.present) {
      map['english_name'] = Variable<String>(englishName.value);
    }
    if (teacherName.present) {
      map['teacher_name'] = Variable<String>(teacherName.value);
    }
    if (teacherNumber.present) {
      map['teacher_number'] = Variable<String>(teacherNumber.value);
    }
    if (courseNumber.present) {
      map['course_number'] = Variable<String>(courseNumber.value);
    }
    if (courseIndex.present) {
      map['course_index'] = Variable<int>(courseIndex.value);
    }
    if (courseType.present) {
      map['course_type'] = Variable<String>(courseType.value);
    }
    if (semesterId.present) {
      map['semester_id'] = Variable<String>(semesterId.value);
    }
    if (timeAndLocationJson.present) {
      map['time_and_location_json'] = Variable<String>(
        timeAndLocationJson.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (lastSynced.present) {
      map['last_synced'] = Variable<DateTime>(lastSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('chineseName: $chineseName, ')
          ..write('englishName: $englishName, ')
          ..write('teacherName: $teacherName, ')
          ..write('teacherNumber: $teacherNumber, ')
          ..write('courseNumber: $courseNumber, ')
          ..write('courseIndex: $courseIndex, ')
          ..write('courseType: $courseType, ')
          ..write('semesterId: $semesterId, ')
          ..write('timeAndLocationJson: $timeAndLocationJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastSynced: $lastSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _publishTimeMeta = const VerificationMeta(
    'publishTime',
  );
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
    'publish_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expireTimeMeta = const VerificationMeta(
    'expireTime',
  );
  @override
  late final GeneratedColumn<String> expireTime = GeneratedColumn<String>(
    'expire_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasReadMeta = const VerificationMeta(
    'hasRead',
  );
  @override
  late final GeneratedColumn<bool> hasRead = GeneratedColumn<bool>(
    'has_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasReadLocalMeta = const VerificationMeta(
    'hasReadLocal',
  );
  @override
  late final GeneratedColumn<bool> hasReadLocal = GeneratedColumn<bool>(
    'has_read_local',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_read_local" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _markedImportantMeta = const VerificationMeta(
    'markedImportant',
  );
  @override
  late final GeneratedColumn<bool> markedImportant = GeneratedColumn<bool>(
    'marked_important',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marked_important" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentJsonMeta = const VerificationMeta(
    'attachmentJson',
  );
  @override
  late final GeneratedColumn<String> attachmentJson = GeneratedColumn<String>(
    'attachment_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    title,
    content,
    publisher,
    publishTime,
    expireTime,
    hasRead,
    hasReadLocal,
    markedImportant,
    isFavorite,
    comment,
    attachmentJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Notification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    }
    if (data.containsKey('publish_time')) {
      context.handle(
        _publishTimeMeta,
        publishTime.isAcceptableOrUnknown(
          data['publish_time']!,
          _publishTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('expire_time')) {
      context.handle(
        _expireTimeMeta,
        expireTime.isAcceptableOrUnknown(data['expire_time']!, _expireTimeMeta),
      );
    }
    if (data.containsKey('has_read')) {
      context.handle(
        _hasReadMeta,
        hasRead.isAcceptableOrUnknown(data['has_read']!, _hasReadMeta),
      );
    }
    if (data.containsKey('has_read_local')) {
      context.handle(
        _hasReadLocalMeta,
        hasReadLocal.isAcceptableOrUnknown(
          data['has_read_local']!,
          _hasReadLocalMeta,
        ),
      );
    }
    if (data.containsKey('marked_important')) {
      context.handle(
        _markedImportantMeta,
        markedImportant.isAcceptableOrUnknown(
          data['marked_important']!,
          _markedImportantMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('attachment_json')) {
      context.handle(
        _attachmentJsonMeta,
        attachmentJson.isAcceptableOrUnknown(
          data['attachment_json']!,
          _attachmentJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      )!,
      publishTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publish_time'],
      )!,
      expireTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expire_time'],
      ),
      hasRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_read'],
      )!,
      hasReadLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_read_local'],
      )!,
      markedImportant: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marked_important'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      attachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_json'],
      ),
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class Notification extends DataClass implements Insertable<Notification> {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String publisher;
  final String publishTime;
  final String? expireTime;
  final bool hasRead;
  final bool hasReadLocal;
  final bool markedImportant;
  final bool isFavorite;
  final String? comment;
  final String? attachmentJson;
  const Notification({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.publisher,
    required this.publishTime,
    this.expireTime,
    required this.hasRead,
    required this.hasReadLocal,
    required this.markedImportant,
    required this.isFavorite,
    this.comment,
    this.attachmentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['course_id'] = Variable<String>(courseId);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['publisher'] = Variable<String>(publisher);
    map['publish_time'] = Variable<String>(publishTime);
    if (!nullToAbsent || expireTime != null) {
      map['expire_time'] = Variable<String>(expireTime);
    }
    map['has_read'] = Variable<bool>(hasRead);
    map['has_read_local'] = Variable<bool>(hasReadLocal);
    map['marked_important'] = Variable<bool>(markedImportant);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || attachmentJson != null) {
      map['attachment_json'] = Variable<String>(attachmentJson);
    }
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      courseId: Value(courseId),
      title: Value(title),
      content: Value(content),
      publisher: Value(publisher),
      publishTime: Value(publishTime),
      expireTime: expireTime == null && nullToAbsent
          ? const Value.absent()
          : Value(expireTime),
      hasRead: Value(hasRead),
      hasReadLocal: Value(hasReadLocal),
      markedImportant: Value(markedImportant),
      isFavorite: Value(isFavorite),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      attachmentJson: attachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentJson),
    );
  }

  factory Notification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notification(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      publisher: serializer.fromJson<String>(json['publisher']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      expireTime: serializer.fromJson<String?>(json['expireTime']),
      hasRead: serializer.fromJson<bool>(json['hasRead']),
      hasReadLocal: serializer.fromJson<bool>(json['hasReadLocal']),
      markedImportant: serializer.fromJson<bool>(json['markedImportant']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      comment: serializer.fromJson<String?>(json['comment']),
      attachmentJson: serializer.fromJson<String?>(json['attachmentJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String>(courseId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'publisher': serializer.toJson<String>(publisher),
      'publishTime': serializer.toJson<String>(publishTime),
      'expireTime': serializer.toJson<String?>(expireTime),
      'hasRead': serializer.toJson<bool>(hasRead),
      'hasReadLocal': serializer.toJson<bool>(hasReadLocal),
      'markedImportant': serializer.toJson<bool>(markedImportant),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'comment': serializer.toJson<String?>(comment),
      'attachmentJson': serializer.toJson<String?>(attachmentJson),
    };
  }

  Notification copyWith({
    String? id,
    String? courseId,
    String? title,
    String? content,
    String? publisher,
    String? publishTime,
    Value<String?> expireTime = const Value.absent(),
    bool? hasRead,
    bool? hasReadLocal,
    bool? markedImportant,
    bool? isFavorite,
    Value<String?> comment = const Value.absent(),
    Value<String?> attachmentJson = const Value.absent(),
  }) => Notification(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    title: title ?? this.title,
    content: content ?? this.content,
    publisher: publisher ?? this.publisher,
    publishTime: publishTime ?? this.publishTime,
    expireTime: expireTime.present ? expireTime.value : this.expireTime,
    hasRead: hasRead ?? this.hasRead,
    hasReadLocal: hasReadLocal ?? this.hasReadLocal,
    markedImportant: markedImportant ?? this.markedImportant,
    isFavorite: isFavorite ?? this.isFavorite,
    comment: comment.present ? comment.value : this.comment,
    attachmentJson: attachmentJson.present
        ? attachmentJson.value
        : this.attachmentJson,
  );
  Notification copyWithCompanion(NotificationsCompanion data) {
    return Notification(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      publishTime: data.publishTime.present
          ? data.publishTime.value
          : this.publishTime,
      expireTime: data.expireTime.present
          ? data.expireTime.value
          : this.expireTime,
      hasRead: data.hasRead.present ? data.hasRead.value : this.hasRead,
      hasReadLocal: data.hasReadLocal.present
          ? data.hasReadLocal.value
          : this.hasReadLocal,
      markedImportant: data.markedImportant.present
          ? data.markedImportant.value
          : this.markedImportant,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      comment: data.comment.present ? data.comment.value : this.comment,
      attachmentJson: data.attachmentJson.present
          ? data.attachmentJson.value
          : this.attachmentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Notification(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('publisher: $publisher, ')
          ..write('publishTime: $publishTime, ')
          ..write('expireTime: $expireTime, ')
          ..write('hasRead: $hasRead, ')
          ..write('hasReadLocal: $hasReadLocal, ')
          ..write('markedImportant: $markedImportant, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('attachmentJson: $attachmentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    courseId,
    title,
    content,
    publisher,
    publishTime,
    expireTime,
    hasRead,
    hasReadLocal,
    markedImportant,
    isFavorite,
    comment,
    attachmentJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notification &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.title == this.title &&
          other.content == this.content &&
          other.publisher == this.publisher &&
          other.publishTime == this.publishTime &&
          other.expireTime == this.expireTime &&
          other.hasRead == this.hasRead &&
          other.hasReadLocal == this.hasReadLocal &&
          other.markedImportant == this.markedImportant &&
          other.isFavorite == this.isFavorite &&
          other.comment == this.comment &&
          other.attachmentJson == this.attachmentJson);
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<String> id;
  final Value<String> courseId;
  final Value<String> title;
  final Value<String> content;
  final Value<String> publisher;
  final Value<String> publishTime;
  final Value<String?> expireTime;
  final Value<bool> hasRead;
  final Value<bool> hasReadLocal;
  final Value<bool> markedImportant;
  final Value<bool> isFavorite;
  final Value<String?> comment;
  final Value<String?> attachmentJson;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.publisher = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.expireTime = const Value.absent(),
    this.hasRead = const Value.absent(),
    this.hasReadLocal = const Value.absent(),
    this.markedImportant = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.attachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required String courseId,
    required String title,
    this.content = const Value.absent(),
    this.publisher = const Value.absent(),
    required String publishTime,
    this.expireTime = const Value.absent(),
    this.hasRead = const Value.absent(),
    this.hasReadLocal = const Value.absent(),
    this.markedImportant = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.attachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       title = Value(title),
       publishTime = Value(publishTime);
  static Insertable<Notification> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? publisher,
    Expression<String>? publishTime,
    Expression<String>? expireTime,
    Expression<bool>? hasRead,
    Expression<bool>? hasReadLocal,
    Expression<bool>? markedImportant,
    Expression<bool>? isFavorite,
    Expression<String>? comment,
    Expression<String>? attachmentJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (publisher != null) 'publisher': publisher,
      if (publishTime != null) 'publish_time': publishTime,
      if (expireTime != null) 'expire_time': expireTime,
      if (hasRead != null) 'has_read': hasRead,
      if (hasReadLocal != null) 'has_read_local': hasReadLocal,
      if (markedImportant != null) 'marked_important': markedImportant,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (comment != null) 'comment': comment,
      if (attachmentJson != null) 'attachment_json': attachmentJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? courseId,
    Value<String>? title,
    Value<String>? content,
    Value<String>? publisher,
    Value<String>? publishTime,
    Value<String?>? expireTime,
    Value<bool>? hasRead,
    Value<bool>? hasReadLocal,
    Value<bool>? markedImportant,
    Value<bool>? isFavorite,
    Value<String?>? comment,
    Value<String?>? attachmentJson,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      content: content ?? this.content,
      publisher: publisher ?? this.publisher,
      publishTime: publishTime ?? this.publishTime,
      expireTime: expireTime ?? this.expireTime,
      hasRead: hasRead ?? this.hasRead,
      hasReadLocal: hasReadLocal ?? this.hasReadLocal,
      markedImportant: markedImportant ?? this.markedImportant,
      isFavorite: isFavorite ?? this.isFavorite,
      comment: comment ?? this.comment,
      attachmentJson: attachmentJson ?? this.attachmentJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (publishTime.present) {
      map['publish_time'] = Variable<String>(publishTime.value);
    }
    if (expireTime.present) {
      map['expire_time'] = Variable<String>(expireTime.value);
    }
    if (hasRead.present) {
      map['has_read'] = Variable<bool>(hasRead.value);
    }
    if (hasReadLocal.present) {
      map['has_read_local'] = Variable<bool>(hasReadLocal.value);
    }
    if (markedImportant.present) {
      map['marked_important'] = Variable<bool>(markedImportant.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (attachmentJson.present) {
      map['attachment_json'] = Variable<String>(attachmentJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('publisher: $publisher, ')
          ..write('publishTime: $publishTime, ')
          ..write('expireTime: $expireTime, ')
          ..write('hasRead: $hasRead, ')
          ..write('hasReadLocal: $hasReadLocal, ')
          ..write('markedImportant: $markedImportant, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('attachmentJson: $attachmentJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CourseFilesTable extends CourseFiles
    with TableInfo<$CourseFilesTable, CourseFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rawSizeMeta = const VerificationMeta(
    'rawSize',
  );
  @override
  late final GeneratedColumn<int> rawSize = GeneratedColumn<int>(
    'raw_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _uploadTimeMeta = const VerificationMeta(
    'uploadTime',
  );
  @override
  late final GeneratedColumn<String> uploadTime = GeneratedColumn<String>(
    'upload_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileTypeMeta = const VerificationMeta(
    'fileType',
  );
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
    'file_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewUrlMeta = const VerificationMeta(
    'previewUrl',
  );
  @override
  late final GeneratedColumn<String> previewUrl = GeneratedColumn<String>(
    'preview_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _markedImportantMeta = const VerificationMeta(
    'markedImportant',
  );
  @override
  late final GeneratedColumn<bool> markedImportant = GeneratedColumn<bool>(
    'marked_important',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("marked_important" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _visitCountMeta = const VerificationMeta(
    'visitCount',
  );
  @override
  late final GeneratedColumn<int> visitCount = GeneratedColumn<int>(
    'visit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadCountMeta = const VerificationMeta(
    'downloadCount',
  );
  @override
  late final GeneratedColumn<int> downloadCount = GeneratedColumn<int>(
    'download_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryTitleMeta = const VerificationMeta(
    'categoryTitle',
  );
  @override
  late final GeneratedColumn<String> categoryTitle = GeneratedColumn<String>(
    'category_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDownloadStateMeta =
      const VerificationMeta('localDownloadState');
  @override
  late final GeneratedColumn<String> localDownloadState =
      GeneratedColumn<String>(
        'local_download_state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    fileId,
    title,
    description,
    rawSize,
    size,
    uploadTime,
    fileType,
    downloadUrl,
    previewUrl,
    isNew,
    markedImportant,
    visitCount,
    downloadCount,
    categoryId,
    categoryTitle,
    isFavorite,
    comment,
    localDownloadState,
    localFilePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('raw_size')) {
      context.handle(
        _rawSizeMeta,
        rawSize.isAcceptableOrUnknown(data['raw_size']!, _rawSizeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('upload_time')) {
      context.handle(
        _uploadTimeMeta,
        uploadTime.isAcceptableOrUnknown(data['upload_time']!, _uploadTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_uploadTimeMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(
        _fileTypeMeta,
        fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta),
      );
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadUrlMeta);
    }
    if (data.containsKey('preview_url')) {
      context.handle(
        _previewUrlMeta,
        previewUrl.isAcceptableOrUnknown(data['preview_url']!, _previewUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_previewUrlMeta);
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('marked_important')) {
      context.handle(
        _markedImportantMeta,
        markedImportant.isAcceptableOrUnknown(
          data['marked_important']!,
          _markedImportantMeta,
        ),
      );
    }
    if (data.containsKey('visit_count')) {
      context.handle(
        _visitCountMeta,
        visitCount.isAcceptableOrUnknown(data['visit_count']!, _visitCountMeta),
      );
    }
    if (data.containsKey('download_count')) {
      context.handle(
        _downloadCountMeta,
        downloadCount.isAcceptableOrUnknown(
          data['download_count']!,
          _downloadCountMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('category_title')) {
      context.handle(
        _categoryTitleMeta,
        categoryTitle.isAcceptableOrUnknown(
          data['category_title']!,
          _categoryTitleMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('local_download_state')) {
      context.handle(
        _localDownloadStateMeta,
        localDownloadState.isAcceptableOrUnknown(
          data['local_download_state']!,
          _localDownloadStateMeta,
        ),
      );
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      rawSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}raw_size'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      )!,
      uploadTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_time'],
      )!,
      fileType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_type'],
      )!,
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      )!,
      previewUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_url'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      markedImportant: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}marked_important'],
      )!,
      visitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visit_count'],
      )!,
      downloadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_count'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      categoryTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_title'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      localDownloadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_download_state'],
      )!,
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      ),
    );
  }

  @override
  $CourseFilesTable createAlias(String alias) {
    return $CourseFilesTable(attachedDatabase, alias);
  }
}

class CourseFile extends DataClass implements Insertable<CourseFile> {
  final String id;
  final String courseId;
  final String fileId;
  final String title;
  final String description;
  final int rawSize;
  final String size;
  final String uploadTime;
  final String fileType;
  final String downloadUrl;
  final String previewUrl;
  final bool isNew;
  final bool markedImportant;
  final int visitCount;
  final int downloadCount;
  final String? categoryId;
  final String? categoryTitle;
  final bool? isFavorite;
  final String? comment;

  /// Local download state: 'none', 'downloading', 'downloaded', 'failed'
  final String localDownloadState;
  final String? localFilePath;
  const CourseFile({
    required this.id,
    required this.courseId,
    required this.fileId,
    required this.title,
    required this.description,
    required this.rawSize,
    required this.size,
    required this.uploadTime,
    required this.fileType,
    required this.downloadUrl,
    required this.previewUrl,
    required this.isNew,
    required this.markedImportant,
    required this.visitCount,
    required this.downloadCount,
    this.categoryId,
    this.categoryTitle,
    this.isFavorite,
    this.comment,
    required this.localDownloadState,
    this.localFilePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['course_id'] = Variable<String>(courseId);
    map['file_id'] = Variable<String>(fileId);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['raw_size'] = Variable<int>(rawSize);
    map['size'] = Variable<String>(size);
    map['upload_time'] = Variable<String>(uploadTime);
    map['file_type'] = Variable<String>(fileType);
    map['download_url'] = Variable<String>(downloadUrl);
    map['preview_url'] = Variable<String>(previewUrl);
    map['is_new'] = Variable<bool>(isNew);
    map['marked_important'] = Variable<bool>(markedImportant);
    map['visit_count'] = Variable<int>(visitCount);
    map['download_count'] = Variable<int>(downloadCount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || categoryTitle != null) {
      map['category_title'] = Variable<String>(categoryTitle);
    }
    if (!nullToAbsent || isFavorite != null) {
      map['is_favorite'] = Variable<bool>(isFavorite);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['local_download_state'] = Variable<String>(localDownloadState);
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    return map;
  }

  CourseFilesCompanion toCompanion(bool nullToAbsent) {
    return CourseFilesCompanion(
      id: Value(id),
      courseId: Value(courseId),
      fileId: Value(fileId),
      title: Value(title),
      description: Value(description),
      rawSize: Value(rawSize),
      size: Value(size),
      uploadTime: Value(uploadTime),
      fileType: Value(fileType),
      downloadUrl: Value(downloadUrl),
      previewUrl: Value(previewUrl),
      isNew: Value(isNew),
      markedImportant: Value(markedImportant),
      visitCount: Value(visitCount),
      downloadCount: Value(downloadCount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      categoryTitle: categoryTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryTitle),
      isFavorite: isFavorite == null && nullToAbsent
          ? const Value.absent()
          : Value(isFavorite),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      localDownloadState: Value(localDownloadState),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
    );
  }

  factory CourseFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseFile(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      fileId: serializer.fromJson<String>(json['fileId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      rawSize: serializer.fromJson<int>(json['rawSize']),
      size: serializer.fromJson<String>(json['size']),
      uploadTime: serializer.fromJson<String>(json['uploadTime']),
      fileType: serializer.fromJson<String>(json['fileType']),
      downloadUrl: serializer.fromJson<String>(json['downloadUrl']),
      previewUrl: serializer.fromJson<String>(json['previewUrl']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      markedImportant: serializer.fromJson<bool>(json['markedImportant']),
      visitCount: serializer.fromJson<int>(json['visitCount']),
      downloadCount: serializer.fromJson<int>(json['downloadCount']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      categoryTitle: serializer.fromJson<String?>(json['categoryTitle']),
      isFavorite: serializer.fromJson<bool?>(json['isFavorite']),
      comment: serializer.fromJson<String?>(json['comment']),
      localDownloadState: serializer.fromJson<String>(
        json['localDownloadState'],
      ),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String>(courseId),
      'fileId': serializer.toJson<String>(fileId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'rawSize': serializer.toJson<int>(rawSize),
      'size': serializer.toJson<String>(size),
      'uploadTime': serializer.toJson<String>(uploadTime),
      'fileType': serializer.toJson<String>(fileType),
      'downloadUrl': serializer.toJson<String>(downloadUrl),
      'previewUrl': serializer.toJson<String>(previewUrl),
      'isNew': serializer.toJson<bool>(isNew),
      'markedImportant': serializer.toJson<bool>(markedImportant),
      'visitCount': serializer.toJson<int>(visitCount),
      'downloadCount': serializer.toJson<int>(downloadCount),
      'categoryId': serializer.toJson<String?>(categoryId),
      'categoryTitle': serializer.toJson<String?>(categoryTitle),
      'isFavorite': serializer.toJson<bool?>(isFavorite),
      'comment': serializer.toJson<String?>(comment),
      'localDownloadState': serializer.toJson<String>(localDownloadState),
      'localFilePath': serializer.toJson<String?>(localFilePath),
    };
  }

  CourseFile copyWith({
    String? id,
    String? courseId,
    String? fileId,
    String? title,
    String? description,
    int? rawSize,
    String? size,
    String? uploadTime,
    String? fileType,
    String? downloadUrl,
    String? previewUrl,
    bool? isNew,
    bool? markedImportant,
    int? visitCount,
    int? downloadCount,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> categoryTitle = const Value.absent(),
    Value<bool?> isFavorite = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    String? localDownloadState,
    Value<String?> localFilePath = const Value.absent(),
  }) => CourseFile(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    fileId: fileId ?? this.fileId,
    title: title ?? this.title,
    description: description ?? this.description,
    rawSize: rawSize ?? this.rawSize,
    size: size ?? this.size,
    uploadTime: uploadTime ?? this.uploadTime,
    fileType: fileType ?? this.fileType,
    downloadUrl: downloadUrl ?? this.downloadUrl,
    previewUrl: previewUrl ?? this.previewUrl,
    isNew: isNew ?? this.isNew,
    markedImportant: markedImportant ?? this.markedImportant,
    visitCount: visitCount ?? this.visitCount,
    downloadCount: downloadCount ?? this.downloadCount,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    categoryTitle: categoryTitle.present
        ? categoryTitle.value
        : this.categoryTitle,
    isFavorite: isFavorite.present ? isFavorite.value : this.isFavorite,
    comment: comment.present ? comment.value : this.comment,
    localDownloadState: localDownloadState ?? this.localDownloadState,
    localFilePath: localFilePath.present
        ? localFilePath.value
        : this.localFilePath,
  );
  CourseFile copyWithCompanion(CourseFilesCompanion data) {
    return CourseFile(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      rawSize: data.rawSize.present ? data.rawSize.value : this.rawSize,
      size: data.size.present ? data.size.value : this.size,
      uploadTime: data.uploadTime.present
          ? data.uploadTime.value
          : this.uploadTime,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      downloadUrl: data.downloadUrl.present
          ? data.downloadUrl.value
          : this.downloadUrl,
      previewUrl: data.previewUrl.present
          ? data.previewUrl.value
          : this.previewUrl,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      markedImportant: data.markedImportant.present
          ? data.markedImportant.value
          : this.markedImportant,
      visitCount: data.visitCount.present
          ? data.visitCount.value
          : this.visitCount,
      downloadCount: data.downloadCount.present
          ? data.downloadCount.value
          : this.downloadCount,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      categoryTitle: data.categoryTitle.present
          ? data.categoryTitle.value
          : this.categoryTitle,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      comment: data.comment.present ? data.comment.value : this.comment,
      localDownloadState: data.localDownloadState.present
          ? data.localDownloadState.value
          : this.localDownloadState,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseFile(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('fileId: $fileId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('rawSize: $rawSize, ')
          ..write('size: $size, ')
          ..write('uploadTime: $uploadTime, ')
          ..write('fileType: $fileType, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('isNew: $isNew, ')
          ..write('markedImportant: $markedImportant, ')
          ..write('visitCount: $visitCount, ')
          ..write('downloadCount: $downloadCount, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryTitle: $categoryTitle, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('localDownloadState: $localDownloadState, ')
          ..write('localFilePath: $localFilePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    courseId,
    fileId,
    title,
    description,
    rawSize,
    size,
    uploadTime,
    fileType,
    downloadUrl,
    previewUrl,
    isNew,
    markedImportant,
    visitCount,
    downloadCount,
    categoryId,
    categoryTitle,
    isFavorite,
    comment,
    localDownloadState,
    localFilePath,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseFile &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.fileId == this.fileId &&
          other.title == this.title &&
          other.description == this.description &&
          other.rawSize == this.rawSize &&
          other.size == this.size &&
          other.uploadTime == this.uploadTime &&
          other.fileType == this.fileType &&
          other.downloadUrl == this.downloadUrl &&
          other.previewUrl == this.previewUrl &&
          other.isNew == this.isNew &&
          other.markedImportant == this.markedImportant &&
          other.visitCount == this.visitCount &&
          other.downloadCount == this.downloadCount &&
          other.categoryId == this.categoryId &&
          other.categoryTitle == this.categoryTitle &&
          other.isFavorite == this.isFavorite &&
          other.comment == this.comment &&
          other.localDownloadState == this.localDownloadState &&
          other.localFilePath == this.localFilePath);
}

class CourseFilesCompanion extends UpdateCompanion<CourseFile> {
  final Value<String> id;
  final Value<String> courseId;
  final Value<String> fileId;
  final Value<String> title;
  final Value<String> description;
  final Value<int> rawSize;
  final Value<String> size;
  final Value<String> uploadTime;
  final Value<String> fileType;
  final Value<String> downloadUrl;
  final Value<String> previewUrl;
  final Value<bool> isNew;
  final Value<bool> markedImportant;
  final Value<int> visitCount;
  final Value<int> downloadCount;
  final Value<String?> categoryId;
  final Value<String?> categoryTitle;
  final Value<bool?> isFavorite;
  final Value<String?> comment;
  final Value<String> localDownloadState;
  final Value<String?> localFilePath;
  final Value<int> rowid;
  const CourseFilesCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.rawSize = const Value.absent(),
    this.size = const Value.absent(),
    this.uploadTime = const Value.absent(),
    this.fileType = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.isNew = const Value.absent(),
    this.markedImportant = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.downloadCount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.categoryTitle = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.localDownloadState = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CourseFilesCompanion.insert({
    required String id,
    required String courseId,
    required String fileId,
    required String title,
    this.description = const Value.absent(),
    this.rawSize = const Value.absent(),
    this.size = const Value.absent(),
    required String uploadTime,
    this.fileType = const Value.absent(),
    required String downloadUrl,
    required String previewUrl,
    this.isNew = const Value.absent(),
    this.markedImportant = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.downloadCount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.categoryTitle = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.localDownloadState = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       fileId = Value(fileId),
       title = Value(title),
       uploadTime = Value(uploadTime),
       downloadUrl = Value(downloadUrl),
       previewUrl = Value(previewUrl);
  static Insertable<CourseFile> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? fileId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? rawSize,
    Expression<String>? size,
    Expression<String>? uploadTime,
    Expression<String>? fileType,
    Expression<String>? downloadUrl,
    Expression<String>? previewUrl,
    Expression<bool>? isNew,
    Expression<bool>? markedImportant,
    Expression<int>? visitCount,
    Expression<int>? downloadCount,
    Expression<String>? categoryId,
    Expression<String>? categoryTitle,
    Expression<bool>? isFavorite,
    Expression<String>? comment,
    Expression<String>? localDownloadState,
    Expression<String>? localFilePath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (fileId != null) 'file_id': fileId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (rawSize != null) 'raw_size': rawSize,
      if (size != null) 'size': size,
      if (uploadTime != null) 'upload_time': uploadTime,
      if (fileType != null) 'file_type': fileType,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (isNew != null) 'is_new': isNew,
      if (markedImportant != null) 'marked_important': markedImportant,
      if (visitCount != null) 'visit_count': visitCount,
      if (downloadCount != null) 'download_count': downloadCount,
      if (categoryId != null) 'category_id': categoryId,
      if (categoryTitle != null) 'category_title': categoryTitle,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (comment != null) 'comment': comment,
      if (localDownloadState != null)
        'local_download_state': localDownloadState,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CourseFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? courseId,
    Value<String>? fileId,
    Value<String>? title,
    Value<String>? description,
    Value<int>? rawSize,
    Value<String>? size,
    Value<String>? uploadTime,
    Value<String>? fileType,
    Value<String>? downloadUrl,
    Value<String>? previewUrl,
    Value<bool>? isNew,
    Value<bool>? markedImportant,
    Value<int>? visitCount,
    Value<int>? downloadCount,
    Value<String?>? categoryId,
    Value<String?>? categoryTitle,
    Value<bool?>? isFavorite,
    Value<String?>? comment,
    Value<String>? localDownloadState,
    Value<String?>? localFilePath,
    Value<int>? rowid,
  }) {
    return CourseFilesCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      fileId: fileId ?? this.fileId,
      title: title ?? this.title,
      description: description ?? this.description,
      rawSize: rawSize ?? this.rawSize,
      size: size ?? this.size,
      uploadTime: uploadTime ?? this.uploadTime,
      fileType: fileType ?? this.fileType,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      isNew: isNew ?? this.isNew,
      markedImportant: markedImportant ?? this.markedImportant,
      visitCount: visitCount ?? this.visitCount,
      downloadCount: downloadCount ?? this.downloadCount,
      categoryId: categoryId ?? this.categoryId,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      isFavorite: isFavorite ?? this.isFavorite,
      comment: comment ?? this.comment,
      localDownloadState: localDownloadState ?? this.localDownloadState,
      localFilePath: localFilePath ?? this.localFilePath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rawSize.present) {
      map['raw_size'] = Variable<int>(rawSize.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (uploadTime.present) {
      map['upload_time'] = Variable<String>(uploadTime.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (previewUrl.present) {
      map['preview_url'] = Variable<String>(previewUrl.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (markedImportant.present) {
      map['marked_important'] = Variable<bool>(markedImportant.value);
    }
    if (visitCount.present) {
      map['visit_count'] = Variable<int>(visitCount.value);
    }
    if (downloadCount.present) {
      map['download_count'] = Variable<int>(downloadCount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (categoryTitle.present) {
      map['category_title'] = Variable<String>(categoryTitle.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (localDownloadState.present) {
      map['local_download_state'] = Variable<String>(localDownloadState.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseFilesCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('fileId: $fileId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('rawSize: $rawSize, ')
          ..write('size: $size, ')
          ..write('uploadTime: $uploadTime, ')
          ..write('fileType: $fileType, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('isNew: $isNew, ')
          ..write('markedImportant: $markedImportant, ')
          ..write('visitCount: $visitCount, ')
          ..write('downloadCount: $downloadCount, ')
          ..write('categoryId: $categoryId, ')
          ..write('categoryTitle: $categoryTitle, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('localDownloadState: $localDownloadState, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedAssetsTable extends CachedAssets
    with TableInfo<$CachedAssetsTable, CachedAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetKeyMeta = const VerificationMeta(
    'assetKey',
  );
  @override
  late final GeneratedColumn<String> assetKey = GeneratedColumn<String>(
    'asset_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileTypeMeta = const VerificationMeta(
    'fileType',
  );
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
    'file_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<String> lastAccessedAt = GeneratedColumn<String>(
    'last_accessed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _persistedFileIdMeta = const VerificationMeta(
    'persistedFileId',
  );
  @override
  late final GeneratedColumn<String> persistedFileId = GeneratedColumn<String>(
    'persisted_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('generic'),
  );
  static const VerificationMeta _routeDataJsonMeta = const VerificationMeta(
    'routeDataJson',
  );
  @override
  late final GeneratedColumn<String> routeDataJson = GeneratedColumn<String>(
    'route_data_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetKey,
    courseId,
    title,
    fileType,
    localPath,
    fileSizeBytes,
    lastAccessedAt,
    updatedAt,
    persistedFileId,
    sourceKind,
    routeDataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_key')) {
      context.handle(
        _assetKeyMeta,
        assetKey.isAcceptableOrUnknown(data['asset_key']!, _assetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_assetKeyMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(
        _fileTypeMeta,
        fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('persisted_file_id')) {
      context.handle(
        _persistedFileIdMeta,
        persistedFileId.isAcceptableOrUnknown(
          data['persisted_file_id']!,
          _persistedFileIdMeta,
        ),
      );
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    }
    if (data.containsKey('route_data_json')) {
      context.handle(
        _routeDataJsonMeta,
        routeDataJson.isAcceptableOrUnknown(
          data['route_data_json']!,
          _routeDataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetKey};
  @override
  CachedAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAsset(
      assetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_key'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      fileType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_type'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_accessed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      persistedFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persisted_file_id'],
      ),
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      routeDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_data_json'],
      ),
    );
  }

  @override
  $CachedAssetsTable createAlias(String alias) {
    return $CachedAssetsTable(attachedDatabase, alias);
  }
}

class CachedAsset extends DataClass implements Insertable<CachedAsset> {
  final String assetKey;
  final String courseId;
  final String title;
  final String fileType;
  final String localPath;
  final int fileSizeBytes;
  final String? lastAccessedAt;
  final String updatedAt;
  final String? persistedFileId;
  final String sourceKind;
  final String? routeDataJson;
  const CachedAsset({
    required this.assetKey,
    required this.courseId,
    required this.title,
    required this.fileType,
    required this.localPath,
    required this.fileSizeBytes,
    this.lastAccessedAt,
    required this.updatedAt,
    this.persistedFileId,
    required this.sourceKind,
    this.routeDataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_key'] = Variable<String>(assetKey);
    map['course_id'] = Variable<String>(courseId);
    map['title'] = Variable<String>(title);
    map['file_type'] = Variable<String>(fileType);
    map['local_path'] = Variable<String>(localPath);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    if (!nullToAbsent || lastAccessedAt != null) {
      map['last_accessed_at'] = Variable<String>(lastAccessedAt);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || persistedFileId != null) {
      map['persisted_file_id'] = Variable<String>(persistedFileId);
    }
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || routeDataJson != null) {
      map['route_data_json'] = Variable<String>(routeDataJson);
    }
    return map;
  }

  CachedAssetsCompanion toCompanion(bool nullToAbsent) {
    return CachedAssetsCompanion(
      assetKey: Value(assetKey),
      courseId: Value(courseId),
      title: Value(title),
      fileType: Value(fileType),
      localPath: Value(localPath),
      fileSizeBytes: Value(fileSizeBytes),
      lastAccessedAt: lastAccessedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAccessedAt),
      updatedAt: Value(updatedAt),
      persistedFileId: persistedFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(persistedFileId),
      sourceKind: Value(sourceKind),
      routeDataJson: routeDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(routeDataJson),
    );
  }

  factory CachedAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAsset(
      assetKey: serializer.fromJson<String>(json['assetKey']),
      courseId: serializer.fromJson<String>(json['courseId']),
      title: serializer.fromJson<String>(json['title']),
      fileType: serializer.fromJson<String>(json['fileType']),
      localPath: serializer.fromJson<String>(json['localPath']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      lastAccessedAt: serializer.fromJson<String?>(json['lastAccessedAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      persistedFileId: serializer.fromJson<String?>(json['persistedFileId']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      routeDataJson: serializer.fromJson<String?>(json['routeDataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetKey': serializer.toJson<String>(assetKey),
      'courseId': serializer.toJson<String>(courseId),
      'title': serializer.toJson<String>(title),
      'fileType': serializer.toJson<String>(fileType),
      'localPath': serializer.toJson<String>(localPath),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'lastAccessedAt': serializer.toJson<String?>(lastAccessedAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'persistedFileId': serializer.toJson<String?>(persistedFileId),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'routeDataJson': serializer.toJson<String?>(routeDataJson),
    };
  }

  CachedAsset copyWith({
    String? assetKey,
    String? courseId,
    String? title,
    String? fileType,
    String? localPath,
    int? fileSizeBytes,
    Value<String?> lastAccessedAt = const Value.absent(),
    String? updatedAt,
    Value<String?> persistedFileId = const Value.absent(),
    String? sourceKind,
    Value<String?> routeDataJson = const Value.absent(),
  }) => CachedAsset(
    assetKey: assetKey ?? this.assetKey,
    courseId: courseId ?? this.courseId,
    title: title ?? this.title,
    fileType: fileType ?? this.fileType,
    localPath: localPath ?? this.localPath,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    lastAccessedAt: lastAccessedAt.present
        ? lastAccessedAt.value
        : this.lastAccessedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    persistedFileId: persistedFileId.present
        ? persistedFileId.value
        : this.persistedFileId,
    sourceKind: sourceKind ?? this.sourceKind,
    routeDataJson: routeDataJson.present
        ? routeDataJson.value
        : this.routeDataJson,
  );
  CachedAsset copyWithCompanion(CachedAssetsCompanion data) {
    return CachedAsset(
      assetKey: data.assetKey.present ? data.assetKey.value : this.assetKey,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      title: data.title.present ? data.title.value : this.title,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      persistedFileId: data.persistedFileId.present
          ? data.persistedFileId.value
          : this.persistedFileId,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      routeDataJson: data.routeDataJson.present
          ? data.routeDataJson.value
          : this.routeDataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAsset(')
          ..write('assetKey: $assetKey, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('fileType: $fileType, ')
          ..write('localPath: $localPath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('persistedFileId: $persistedFileId, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('routeDataJson: $routeDataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    assetKey,
    courseId,
    title,
    fileType,
    localPath,
    fileSizeBytes,
    lastAccessedAt,
    updatedAt,
    persistedFileId,
    sourceKind,
    routeDataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAsset &&
          other.assetKey == this.assetKey &&
          other.courseId == this.courseId &&
          other.title == this.title &&
          other.fileType == this.fileType &&
          other.localPath == this.localPath &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.updatedAt == this.updatedAt &&
          other.persistedFileId == this.persistedFileId &&
          other.sourceKind == this.sourceKind &&
          other.routeDataJson == this.routeDataJson);
}

class CachedAssetsCompanion extends UpdateCompanion<CachedAsset> {
  final Value<String> assetKey;
  final Value<String> courseId;
  final Value<String> title;
  final Value<String> fileType;
  final Value<String> localPath;
  final Value<int> fileSizeBytes;
  final Value<String?> lastAccessedAt;
  final Value<String> updatedAt;
  final Value<String?> persistedFileId;
  final Value<String> sourceKind;
  final Value<String?> routeDataJson;
  final Value<int> rowid;
  const CachedAssetsCompanion({
    this.assetKey = const Value.absent(),
    this.courseId = const Value.absent(),
    this.title = const Value.absent(),
    this.fileType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.persistedFileId = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.routeDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAssetsCompanion.insert({
    required String assetKey,
    required String courseId,
    required String title,
    this.fileType = const Value.absent(),
    required String localPath,
    this.fileSizeBytes = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    required String updatedAt,
    this.persistedFileId = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.routeDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : assetKey = Value(assetKey),
       courseId = Value(courseId),
       title = Value(title),
       localPath = Value(localPath),
       updatedAt = Value(updatedAt);
  static Insertable<CachedAsset> custom({
    Expression<String>? assetKey,
    Expression<String>? courseId,
    Expression<String>? title,
    Expression<String>? fileType,
    Expression<String>? localPath,
    Expression<int>? fileSizeBytes,
    Expression<String>? lastAccessedAt,
    Expression<String>? updatedAt,
    Expression<String>? persistedFileId,
    Expression<String>? sourceKind,
    Expression<String>? routeDataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetKey != null) 'asset_key': assetKey,
      if (courseId != null) 'course_id': courseId,
      if (title != null) 'title': title,
      if (fileType != null) 'file_type': fileType,
      if (localPath != null) 'local_path': localPath,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (persistedFileId != null) 'persisted_file_id': persistedFileId,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (routeDataJson != null) 'route_data_json': routeDataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAssetsCompanion copyWith({
    Value<String>? assetKey,
    Value<String>? courseId,
    Value<String>? title,
    Value<String>? fileType,
    Value<String>? localPath,
    Value<int>? fileSizeBytes,
    Value<String?>? lastAccessedAt,
    Value<String>? updatedAt,
    Value<String?>? persistedFileId,
    Value<String>? sourceKind,
    Value<String?>? routeDataJson,
    Value<int>? rowid,
  }) {
    return CachedAssetsCompanion(
      assetKey: assetKey ?? this.assetKey,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      fileType: fileType ?? this.fileType,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      persistedFileId: persistedFileId ?? this.persistedFileId,
      sourceKind: sourceKind ?? this.sourceKind,
      routeDataJson: routeDataJson ?? this.routeDataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetKey.present) {
      map['asset_key'] = Variable<String>(assetKey.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<String>(lastAccessedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (persistedFileId.present) {
      map['persisted_file_id'] = Variable<String>(persistedFileId.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (routeDataJson.present) {
      map['route_data_json'] = Variable<String>(routeDataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAssetsCompanion(')
          ..write('assetKey: $assetKey, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('fileType: $fileType, ')
          ..write('localPath: $localPath, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('persistedFileId: $persistedFileId, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('routeDataJson: $routeDataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileBookmarksTable extends FileBookmarks
    with TableInfo<$FileBookmarksTable, FileBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetKeyMeta = const VerificationMeta(
    'assetKey',
  );
  @override
  late final GeneratedColumn<String> assetKey = GeneratedColumn<String>(
    'asset_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseNameMeta = const VerificationMeta(
    'courseName',
  );
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
    'course_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetKey, courseName, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileBookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_key')) {
      context.handle(
        _assetKeyMeta,
        assetKey.isAcceptableOrUnknown(data['asset_key']!, _assetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_assetKeyMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
        _courseNameMeta,
        courseName.isAcceptableOrUnknown(data['course_name']!, _courseNameMeta),
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
  Set<GeneratedColumn> get $primaryKey => {assetKey};
  @override
  FileBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileBookmark(
      assetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_key'],
      )!,
      courseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FileBookmarksTable createAlias(String alias) {
    return $FileBookmarksTable(attachedDatabase, alias);
  }
}

class FileBookmark extends DataClass implements Insertable<FileBookmark> {
  final String assetKey;
  final String courseName;
  final String createdAt;
  const FileBookmark({
    required this.assetKey,
    required this.courseName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_key'] = Variable<String>(assetKey);
    map['course_name'] = Variable<String>(courseName);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  FileBookmarksCompanion toCompanion(bool nullToAbsent) {
    return FileBookmarksCompanion(
      assetKey: Value(assetKey),
      courseName: Value(courseName),
      createdAt: Value(createdAt),
    );
  }

  factory FileBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileBookmark(
      assetKey: serializer.fromJson<String>(json['assetKey']),
      courseName: serializer.fromJson<String>(json['courseName']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetKey': serializer.toJson<String>(assetKey),
      'courseName': serializer.toJson<String>(courseName),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  FileBookmark copyWith({
    String? assetKey,
    String? courseName,
    String? createdAt,
  }) => FileBookmark(
    assetKey: assetKey ?? this.assetKey,
    courseName: courseName ?? this.courseName,
    createdAt: createdAt ?? this.createdAt,
  );
  FileBookmark copyWithCompanion(FileBookmarksCompanion data) {
    return FileBookmark(
      assetKey: data.assetKey.present ? data.assetKey.value : this.assetKey,
      courseName: data.courseName.present
          ? data.courseName.value
          : this.courseName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileBookmark(')
          ..write('assetKey: $assetKey, ')
          ..write('courseName: $courseName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetKey, courseName, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileBookmark &&
          other.assetKey == this.assetKey &&
          other.courseName == this.courseName &&
          other.createdAt == this.createdAt);
}

class FileBookmarksCompanion extends UpdateCompanion<FileBookmark> {
  final Value<String> assetKey;
  final Value<String> courseName;
  final Value<String> createdAt;
  final Value<int> rowid;
  const FileBookmarksCompanion({
    this.assetKey = const Value.absent(),
    this.courseName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileBookmarksCompanion.insert({
    required String assetKey,
    this.courseName = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : assetKey = Value(assetKey),
       createdAt = Value(createdAt);
  static Insertable<FileBookmark> custom({
    Expression<String>? assetKey,
    Expression<String>? courseName,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetKey != null) 'asset_key': assetKey,
      if (courseName != null) 'course_name': courseName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileBookmarksCompanion copyWith({
    Value<String>? assetKey,
    Value<String>? courseName,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return FileBookmarksCompanion(
      assetKey: assetKey ?? this.assetKey,
      courseName: courseName ?? this.courseName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetKey.present) {
      map['asset_key'] = Variable<String>(assetKey.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileBookmarksCompanion(')
          ..write('assetKey: $assetKey, ')
          ..write('courseName: $courseName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HomeworksTable extends Homeworks
    with TableInfo<$HomeworksTable, Homework> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeworksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseIdMeta = const VerificationMeta('baseId');
  @override
  late final GeneratedColumn<String> baseId = GeneratedColumn<String>(
    'base_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<String> deadline = GeneratedColumn<String>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lateSubmissionDeadlineMeta =
      const VerificationMeta('lateSubmissionDeadline');
  @override
  late final GeneratedColumn<String> lateSubmissionDeadline =
      GeneratedColumn<String>(
        'late_submission_deadline',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _submitTimeMeta = const VerificationMeta(
    'submitTime',
  );
  @override
  late final GeneratedColumn<String> submitTime = GeneratedColumn<String>(
    'submit_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedMeta = const VerificationMeta(
    'submitted',
  );
  @override
  late final GeneratedColumn<bool> submitted = GeneratedColumn<bool>(
    'submitted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("submitted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gradedMeta = const VerificationMeta('graded');
  @override
  late final GeneratedColumn<bool> graded = GeneratedColumn<bool>(
    'graded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("graded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<double> grade = GeneratedColumn<double>(
    'grade',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeLevelMeta = const VerificationMeta(
    'gradeLevel',
  );
  @override
  late final GeneratedColumn<String> gradeLevel = GeneratedColumn<String>(
    'grade_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _graderNameMeta = const VerificationMeta(
    'graderName',
  );
  @override
  late final GeneratedColumn<String> graderName = GeneratedColumn<String>(
    'grader_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeContentMeta = const VerificationMeta(
    'gradeContent',
  );
  @override
  late final GeneratedColumn<String> gradeContent = GeneratedColumn<String>(
    'grade_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradeTimeMeta = const VerificationMeta(
    'gradeTime',
  );
  @override
  late final GeneratedColumn<String> gradeTime = GeneratedColumn<String>(
    'grade_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLateSubmissionMeta = const VerificationMeta(
    'isLateSubmission',
  );
  @override
  late final GeneratedColumn<bool> isLateSubmission = GeneratedColumn<bool>(
    'is_late_submission',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_late_submission" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completionTypeMeta = const VerificationMeta(
    'completionType',
  );
  @override
  late final GeneratedColumn<int> completionType = GeneratedColumn<int>(
    'completion_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submissionTypeMeta = const VerificationMeta(
    'submissionType',
  );
  @override
  late final GeneratedColumn<int> submissionType = GeneratedColumn<int>(
    'submission_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentJsonMeta = const VerificationMeta(
    'attachmentJson',
  );
  @override
  late final GeneratedColumn<String> attachmentJson = GeneratedColumn<String>(
    'attachment_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerContentMeta = const VerificationMeta(
    'answerContent',
  );
  @override
  late final GeneratedColumn<String> answerContent = GeneratedColumn<String>(
    'answer_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _answerAttachmentJsonMeta =
      const VerificationMeta('answerAttachmentJson');
  @override
  late final GeneratedColumn<String> answerAttachmentJson =
      GeneratedColumn<String>(
        'answer_attachment_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _submittedContentMeta = const VerificationMeta(
    'submittedContent',
  );
  @override
  late final GeneratedColumn<String> submittedContent = GeneratedColumn<String>(
    'submitted_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedAttachmentJsonMeta =
      const VerificationMeta('submittedAttachmentJson');
  @override
  late final GeneratedColumn<String> submittedAttachmentJson =
      GeneratedColumn<String>(
        'submitted_attachment_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _gradeAttachmentJsonMeta =
      const VerificationMeta('gradeAttachmentJson');
  @override
  late final GeneratedColumn<String> gradeAttachmentJson =
      GeneratedColumn<String>(
        'grade_attachment_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    baseId,
    title,
    description,
    deadline,
    lateSubmissionDeadline,
    submitTime,
    submitted,
    graded,
    grade,
    gradeLevel,
    graderName,
    gradeContent,
    gradeTime,
    isLateSubmission,
    completionType,
    submissionType,
    isFavorite,
    comment,
    attachmentJson,
    answerContent,
    answerAttachmentJson,
    submittedContent,
    submittedAttachmentJson,
    gradeAttachmentJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'homeworks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Homework> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('base_id')) {
      context.handle(
        _baseIdMeta,
        baseId.isAcceptableOrUnknown(data['base_id']!, _baseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_baseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    } else if (isInserting) {
      context.missing(_deadlineMeta);
    }
    if (data.containsKey('late_submission_deadline')) {
      context.handle(
        _lateSubmissionDeadlineMeta,
        lateSubmissionDeadline.isAcceptableOrUnknown(
          data['late_submission_deadline']!,
          _lateSubmissionDeadlineMeta,
        ),
      );
    }
    if (data.containsKey('submit_time')) {
      context.handle(
        _submitTimeMeta,
        submitTime.isAcceptableOrUnknown(data['submit_time']!, _submitTimeMeta),
      );
    }
    if (data.containsKey('submitted')) {
      context.handle(
        _submittedMeta,
        submitted.isAcceptableOrUnknown(data['submitted']!, _submittedMeta),
      );
    }
    if (data.containsKey('graded')) {
      context.handle(
        _gradedMeta,
        graded.isAcceptableOrUnknown(data['graded']!, _gradedMeta),
      );
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    }
    if (data.containsKey('grade_level')) {
      context.handle(
        _gradeLevelMeta,
        gradeLevel.isAcceptableOrUnknown(data['grade_level']!, _gradeLevelMeta),
      );
    }
    if (data.containsKey('grader_name')) {
      context.handle(
        _graderNameMeta,
        graderName.isAcceptableOrUnknown(data['grader_name']!, _graderNameMeta),
      );
    }
    if (data.containsKey('grade_content')) {
      context.handle(
        _gradeContentMeta,
        gradeContent.isAcceptableOrUnknown(
          data['grade_content']!,
          _gradeContentMeta,
        ),
      );
    }
    if (data.containsKey('grade_time')) {
      context.handle(
        _gradeTimeMeta,
        gradeTime.isAcceptableOrUnknown(data['grade_time']!, _gradeTimeMeta),
      );
    }
    if (data.containsKey('is_late_submission')) {
      context.handle(
        _isLateSubmissionMeta,
        isLateSubmission.isAcceptableOrUnknown(
          data['is_late_submission']!,
          _isLateSubmissionMeta,
        ),
      );
    }
    if (data.containsKey('completion_type')) {
      context.handle(
        _completionTypeMeta,
        completionType.isAcceptableOrUnknown(
          data['completion_type']!,
          _completionTypeMeta,
        ),
      );
    }
    if (data.containsKey('submission_type')) {
      context.handle(
        _submissionTypeMeta,
        submissionType.isAcceptableOrUnknown(
          data['submission_type']!,
          _submissionTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('attachment_json')) {
      context.handle(
        _attachmentJsonMeta,
        attachmentJson.isAcceptableOrUnknown(
          data['attachment_json']!,
          _attachmentJsonMeta,
        ),
      );
    }
    if (data.containsKey('answer_content')) {
      context.handle(
        _answerContentMeta,
        answerContent.isAcceptableOrUnknown(
          data['answer_content']!,
          _answerContentMeta,
        ),
      );
    }
    if (data.containsKey('answer_attachment_json')) {
      context.handle(
        _answerAttachmentJsonMeta,
        answerAttachmentJson.isAcceptableOrUnknown(
          data['answer_attachment_json']!,
          _answerAttachmentJsonMeta,
        ),
      );
    }
    if (data.containsKey('submitted_content')) {
      context.handle(
        _submittedContentMeta,
        submittedContent.isAcceptableOrUnknown(
          data['submitted_content']!,
          _submittedContentMeta,
        ),
      );
    }
    if (data.containsKey('submitted_attachment_json')) {
      context.handle(
        _submittedAttachmentJsonMeta,
        submittedAttachmentJson.isAcceptableOrUnknown(
          data['submitted_attachment_json']!,
          _submittedAttachmentJsonMeta,
        ),
      );
    }
    if (data.containsKey('grade_attachment_json')) {
      context.handle(
        _gradeAttachmentJsonMeta,
        gradeAttachmentJson.isAcceptableOrUnknown(
          data['grade_attachment_json']!,
          _gradeAttachmentJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Homework map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Homework(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      baseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deadline'],
      )!,
      lateSubmissionDeadline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}late_submission_deadline'],
      ),
      submitTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submit_time'],
      ),
      submitted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submitted'],
      )!,
      graded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}graded'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grade'],
      ),
      gradeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade_level'],
      ),
      graderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grader_name'],
      ),
      gradeContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade_content'],
      ),
      gradeTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade_time'],
      ),
      isLateSubmission: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_late_submission'],
      )!,
      completionType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completion_type'],
      ),
      submissionType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submission_type'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      attachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_json'],
      ),
      answerContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_content'],
      ),
      answerAttachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_attachment_json'],
      ),
      submittedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submitted_content'],
      ),
      submittedAttachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submitted_attachment_json'],
      ),
      gradeAttachmentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grade_attachment_json'],
      ),
    );
  }

  @override
  $HomeworksTable createAlias(String alias) {
    return $HomeworksTable(attachedDatabase, alias);
  }
}

class Homework extends DataClass implements Insertable<Homework> {
  final String id;
  final String courseId;
  final String baseId;
  final String title;
  final String? description;
  final String deadline;
  final String? lateSubmissionDeadline;
  final String? submitTime;
  final bool submitted;
  final bool graded;
  final double? grade;
  final String? gradeLevel;
  final String? graderName;
  final String? gradeContent;
  final String? gradeTime;
  final bool isLateSubmission;
  final int? completionType;
  final int? submissionType;
  final bool isFavorite;
  final String? comment;
  final String? attachmentJson;
  final String? answerContent;
  final String? answerAttachmentJson;
  final String? submittedContent;
  final String? submittedAttachmentJson;
  final String? gradeAttachmentJson;
  const Homework({
    required this.id,
    required this.courseId,
    required this.baseId,
    required this.title,
    this.description,
    required this.deadline,
    this.lateSubmissionDeadline,
    this.submitTime,
    required this.submitted,
    required this.graded,
    this.grade,
    this.gradeLevel,
    this.graderName,
    this.gradeContent,
    this.gradeTime,
    required this.isLateSubmission,
    this.completionType,
    this.submissionType,
    required this.isFavorite,
    this.comment,
    this.attachmentJson,
    this.answerContent,
    this.answerAttachmentJson,
    this.submittedContent,
    this.submittedAttachmentJson,
    this.gradeAttachmentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['course_id'] = Variable<String>(courseId);
    map['base_id'] = Variable<String>(baseId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['deadline'] = Variable<String>(deadline);
    if (!nullToAbsent || lateSubmissionDeadline != null) {
      map['late_submission_deadline'] = Variable<String>(
        lateSubmissionDeadline,
      );
    }
    if (!nullToAbsent || submitTime != null) {
      map['submit_time'] = Variable<String>(submitTime);
    }
    map['submitted'] = Variable<bool>(submitted);
    map['graded'] = Variable<bool>(graded);
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<double>(grade);
    }
    if (!nullToAbsent || gradeLevel != null) {
      map['grade_level'] = Variable<String>(gradeLevel);
    }
    if (!nullToAbsent || graderName != null) {
      map['grader_name'] = Variable<String>(graderName);
    }
    if (!nullToAbsent || gradeContent != null) {
      map['grade_content'] = Variable<String>(gradeContent);
    }
    if (!nullToAbsent || gradeTime != null) {
      map['grade_time'] = Variable<String>(gradeTime);
    }
    map['is_late_submission'] = Variable<bool>(isLateSubmission);
    if (!nullToAbsent || completionType != null) {
      map['completion_type'] = Variable<int>(completionType);
    }
    if (!nullToAbsent || submissionType != null) {
      map['submission_type'] = Variable<int>(submissionType);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    if (!nullToAbsent || attachmentJson != null) {
      map['attachment_json'] = Variable<String>(attachmentJson);
    }
    if (!nullToAbsent || answerContent != null) {
      map['answer_content'] = Variable<String>(answerContent);
    }
    if (!nullToAbsent || answerAttachmentJson != null) {
      map['answer_attachment_json'] = Variable<String>(answerAttachmentJson);
    }
    if (!nullToAbsent || submittedContent != null) {
      map['submitted_content'] = Variable<String>(submittedContent);
    }
    if (!nullToAbsent || submittedAttachmentJson != null) {
      map['submitted_attachment_json'] = Variable<String>(
        submittedAttachmentJson,
      );
    }
    if (!nullToAbsent || gradeAttachmentJson != null) {
      map['grade_attachment_json'] = Variable<String>(gradeAttachmentJson);
    }
    return map;
  }

  HomeworksCompanion toCompanion(bool nullToAbsent) {
    return HomeworksCompanion(
      id: Value(id),
      courseId: Value(courseId),
      baseId: Value(baseId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      deadline: Value(deadline),
      lateSubmissionDeadline: lateSubmissionDeadline == null && nullToAbsent
          ? const Value.absent()
          : Value(lateSubmissionDeadline),
      submitTime: submitTime == null && nullToAbsent
          ? const Value.absent()
          : Value(submitTime),
      submitted: Value(submitted),
      graded: Value(graded),
      grade: grade == null && nullToAbsent
          ? const Value.absent()
          : Value(grade),
      gradeLevel: gradeLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeLevel),
      graderName: graderName == null && nullToAbsent
          ? const Value.absent()
          : Value(graderName),
      gradeContent: gradeContent == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeContent),
      gradeTime: gradeTime == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeTime),
      isLateSubmission: Value(isLateSubmission),
      completionType: completionType == null && nullToAbsent
          ? const Value.absent()
          : Value(completionType),
      submissionType: submissionType == null && nullToAbsent
          ? const Value.absent()
          : Value(submissionType),
      isFavorite: Value(isFavorite),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      attachmentJson: attachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentJson),
      answerContent: answerContent == null && nullToAbsent
          ? const Value.absent()
          : Value(answerContent),
      answerAttachmentJson: answerAttachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(answerAttachmentJson),
      submittedContent: submittedContent == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedContent),
      submittedAttachmentJson: submittedAttachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAttachmentJson),
      gradeAttachmentJson: gradeAttachmentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeAttachmentJson),
    );
  }

  factory Homework.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Homework(
      id: serializer.fromJson<String>(json['id']),
      courseId: serializer.fromJson<String>(json['courseId']),
      baseId: serializer.fromJson<String>(json['baseId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      deadline: serializer.fromJson<String>(json['deadline']),
      lateSubmissionDeadline: serializer.fromJson<String?>(
        json['lateSubmissionDeadline'],
      ),
      submitTime: serializer.fromJson<String?>(json['submitTime']),
      submitted: serializer.fromJson<bool>(json['submitted']),
      graded: serializer.fromJson<bool>(json['graded']),
      grade: serializer.fromJson<double?>(json['grade']),
      gradeLevel: serializer.fromJson<String?>(json['gradeLevel']),
      graderName: serializer.fromJson<String?>(json['graderName']),
      gradeContent: serializer.fromJson<String?>(json['gradeContent']),
      gradeTime: serializer.fromJson<String?>(json['gradeTime']),
      isLateSubmission: serializer.fromJson<bool>(json['isLateSubmission']),
      completionType: serializer.fromJson<int?>(json['completionType']),
      submissionType: serializer.fromJson<int?>(json['submissionType']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      comment: serializer.fromJson<String?>(json['comment']),
      attachmentJson: serializer.fromJson<String?>(json['attachmentJson']),
      answerContent: serializer.fromJson<String?>(json['answerContent']),
      answerAttachmentJson: serializer.fromJson<String?>(
        json['answerAttachmentJson'],
      ),
      submittedContent: serializer.fromJson<String?>(json['submittedContent']),
      submittedAttachmentJson: serializer.fromJson<String?>(
        json['submittedAttachmentJson'],
      ),
      gradeAttachmentJson: serializer.fromJson<String?>(
        json['gradeAttachmentJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'courseId': serializer.toJson<String>(courseId),
      'baseId': serializer.toJson<String>(baseId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'deadline': serializer.toJson<String>(deadline),
      'lateSubmissionDeadline': serializer.toJson<String?>(
        lateSubmissionDeadline,
      ),
      'submitTime': serializer.toJson<String?>(submitTime),
      'submitted': serializer.toJson<bool>(submitted),
      'graded': serializer.toJson<bool>(graded),
      'grade': serializer.toJson<double?>(grade),
      'gradeLevel': serializer.toJson<String?>(gradeLevel),
      'graderName': serializer.toJson<String?>(graderName),
      'gradeContent': serializer.toJson<String?>(gradeContent),
      'gradeTime': serializer.toJson<String?>(gradeTime),
      'isLateSubmission': serializer.toJson<bool>(isLateSubmission),
      'completionType': serializer.toJson<int?>(completionType),
      'submissionType': serializer.toJson<int?>(submissionType),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'comment': serializer.toJson<String?>(comment),
      'attachmentJson': serializer.toJson<String?>(attachmentJson),
      'answerContent': serializer.toJson<String?>(answerContent),
      'answerAttachmentJson': serializer.toJson<String?>(answerAttachmentJson),
      'submittedContent': serializer.toJson<String?>(submittedContent),
      'submittedAttachmentJson': serializer.toJson<String?>(
        submittedAttachmentJson,
      ),
      'gradeAttachmentJson': serializer.toJson<String?>(gradeAttachmentJson),
    };
  }

  Homework copyWith({
    String? id,
    String? courseId,
    String? baseId,
    String? title,
    Value<String?> description = const Value.absent(),
    String? deadline,
    Value<String?> lateSubmissionDeadline = const Value.absent(),
    Value<String?> submitTime = const Value.absent(),
    bool? submitted,
    bool? graded,
    Value<double?> grade = const Value.absent(),
    Value<String?> gradeLevel = const Value.absent(),
    Value<String?> graderName = const Value.absent(),
    Value<String?> gradeContent = const Value.absent(),
    Value<String?> gradeTime = const Value.absent(),
    bool? isLateSubmission,
    Value<int?> completionType = const Value.absent(),
    Value<int?> submissionType = const Value.absent(),
    bool? isFavorite,
    Value<String?> comment = const Value.absent(),
    Value<String?> attachmentJson = const Value.absent(),
    Value<String?> answerContent = const Value.absent(),
    Value<String?> answerAttachmentJson = const Value.absent(),
    Value<String?> submittedContent = const Value.absent(),
    Value<String?> submittedAttachmentJson = const Value.absent(),
    Value<String?> gradeAttachmentJson = const Value.absent(),
  }) => Homework(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    baseId: baseId ?? this.baseId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    deadline: deadline ?? this.deadline,
    lateSubmissionDeadline: lateSubmissionDeadline.present
        ? lateSubmissionDeadline.value
        : this.lateSubmissionDeadline,
    submitTime: submitTime.present ? submitTime.value : this.submitTime,
    submitted: submitted ?? this.submitted,
    graded: graded ?? this.graded,
    grade: grade.present ? grade.value : this.grade,
    gradeLevel: gradeLevel.present ? gradeLevel.value : this.gradeLevel,
    graderName: graderName.present ? graderName.value : this.graderName,
    gradeContent: gradeContent.present ? gradeContent.value : this.gradeContent,
    gradeTime: gradeTime.present ? gradeTime.value : this.gradeTime,
    isLateSubmission: isLateSubmission ?? this.isLateSubmission,
    completionType: completionType.present
        ? completionType.value
        : this.completionType,
    submissionType: submissionType.present
        ? submissionType.value
        : this.submissionType,
    isFavorite: isFavorite ?? this.isFavorite,
    comment: comment.present ? comment.value : this.comment,
    attachmentJson: attachmentJson.present
        ? attachmentJson.value
        : this.attachmentJson,
    answerContent: answerContent.present
        ? answerContent.value
        : this.answerContent,
    answerAttachmentJson: answerAttachmentJson.present
        ? answerAttachmentJson.value
        : this.answerAttachmentJson,
    submittedContent: submittedContent.present
        ? submittedContent.value
        : this.submittedContent,
    submittedAttachmentJson: submittedAttachmentJson.present
        ? submittedAttachmentJson.value
        : this.submittedAttachmentJson,
    gradeAttachmentJson: gradeAttachmentJson.present
        ? gradeAttachmentJson.value
        : this.gradeAttachmentJson,
  );
  Homework copyWithCompanion(HomeworksCompanion data) {
    return Homework(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      baseId: data.baseId.present ? data.baseId.value : this.baseId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      lateSubmissionDeadline: data.lateSubmissionDeadline.present
          ? data.lateSubmissionDeadline.value
          : this.lateSubmissionDeadline,
      submitTime: data.submitTime.present
          ? data.submitTime.value
          : this.submitTime,
      submitted: data.submitted.present ? data.submitted.value : this.submitted,
      graded: data.graded.present ? data.graded.value : this.graded,
      grade: data.grade.present ? data.grade.value : this.grade,
      gradeLevel: data.gradeLevel.present
          ? data.gradeLevel.value
          : this.gradeLevel,
      graderName: data.graderName.present
          ? data.graderName.value
          : this.graderName,
      gradeContent: data.gradeContent.present
          ? data.gradeContent.value
          : this.gradeContent,
      gradeTime: data.gradeTime.present ? data.gradeTime.value : this.gradeTime,
      isLateSubmission: data.isLateSubmission.present
          ? data.isLateSubmission.value
          : this.isLateSubmission,
      completionType: data.completionType.present
          ? data.completionType.value
          : this.completionType,
      submissionType: data.submissionType.present
          ? data.submissionType.value
          : this.submissionType,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      comment: data.comment.present ? data.comment.value : this.comment,
      attachmentJson: data.attachmentJson.present
          ? data.attachmentJson.value
          : this.attachmentJson,
      answerContent: data.answerContent.present
          ? data.answerContent.value
          : this.answerContent,
      answerAttachmentJson: data.answerAttachmentJson.present
          ? data.answerAttachmentJson.value
          : this.answerAttachmentJson,
      submittedContent: data.submittedContent.present
          ? data.submittedContent.value
          : this.submittedContent,
      submittedAttachmentJson: data.submittedAttachmentJson.present
          ? data.submittedAttachmentJson.value
          : this.submittedAttachmentJson,
      gradeAttachmentJson: data.gradeAttachmentJson.present
          ? data.gradeAttachmentJson.value
          : this.gradeAttachmentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Homework(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('baseId: $baseId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('deadline: $deadline, ')
          ..write('lateSubmissionDeadline: $lateSubmissionDeadline, ')
          ..write('submitTime: $submitTime, ')
          ..write('submitted: $submitted, ')
          ..write('graded: $graded, ')
          ..write('grade: $grade, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('graderName: $graderName, ')
          ..write('gradeContent: $gradeContent, ')
          ..write('gradeTime: $gradeTime, ')
          ..write('isLateSubmission: $isLateSubmission, ')
          ..write('completionType: $completionType, ')
          ..write('submissionType: $submissionType, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('attachmentJson: $attachmentJson, ')
          ..write('answerContent: $answerContent, ')
          ..write('answerAttachmentJson: $answerAttachmentJson, ')
          ..write('submittedContent: $submittedContent, ')
          ..write('submittedAttachmentJson: $submittedAttachmentJson, ')
          ..write('gradeAttachmentJson: $gradeAttachmentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    courseId,
    baseId,
    title,
    description,
    deadline,
    lateSubmissionDeadline,
    submitTime,
    submitted,
    graded,
    grade,
    gradeLevel,
    graderName,
    gradeContent,
    gradeTime,
    isLateSubmission,
    completionType,
    submissionType,
    isFavorite,
    comment,
    attachmentJson,
    answerContent,
    answerAttachmentJson,
    submittedContent,
    submittedAttachmentJson,
    gradeAttachmentJson,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Homework &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.baseId == this.baseId &&
          other.title == this.title &&
          other.description == this.description &&
          other.deadline == this.deadline &&
          other.lateSubmissionDeadline == this.lateSubmissionDeadline &&
          other.submitTime == this.submitTime &&
          other.submitted == this.submitted &&
          other.graded == this.graded &&
          other.grade == this.grade &&
          other.gradeLevel == this.gradeLevel &&
          other.graderName == this.graderName &&
          other.gradeContent == this.gradeContent &&
          other.gradeTime == this.gradeTime &&
          other.isLateSubmission == this.isLateSubmission &&
          other.completionType == this.completionType &&
          other.submissionType == this.submissionType &&
          other.isFavorite == this.isFavorite &&
          other.comment == this.comment &&
          other.attachmentJson == this.attachmentJson &&
          other.answerContent == this.answerContent &&
          other.answerAttachmentJson == this.answerAttachmentJson &&
          other.submittedContent == this.submittedContent &&
          other.submittedAttachmentJson == this.submittedAttachmentJson &&
          other.gradeAttachmentJson == this.gradeAttachmentJson);
}

class HomeworksCompanion extends UpdateCompanion<Homework> {
  final Value<String> id;
  final Value<String> courseId;
  final Value<String> baseId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> deadline;
  final Value<String?> lateSubmissionDeadline;
  final Value<String?> submitTime;
  final Value<bool> submitted;
  final Value<bool> graded;
  final Value<double?> grade;
  final Value<String?> gradeLevel;
  final Value<String?> graderName;
  final Value<String?> gradeContent;
  final Value<String?> gradeTime;
  final Value<bool> isLateSubmission;
  final Value<int?> completionType;
  final Value<int?> submissionType;
  final Value<bool> isFavorite;
  final Value<String?> comment;
  final Value<String?> attachmentJson;
  final Value<String?> answerContent;
  final Value<String?> answerAttachmentJson;
  final Value<String?> submittedContent;
  final Value<String?> submittedAttachmentJson;
  final Value<String?> gradeAttachmentJson;
  final Value<int> rowid;
  const HomeworksCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.baseId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.deadline = const Value.absent(),
    this.lateSubmissionDeadline = const Value.absent(),
    this.submitTime = const Value.absent(),
    this.submitted = const Value.absent(),
    this.graded = const Value.absent(),
    this.grade = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.graderName = const Value.absent(),
    this.gradeContent = const Value.absent(),
    this.gradeTime = const Value.absent(),
    this.isLateSubmission = const Value.absent(),
    this.completionType = const Value.absent(),
    this.submissionType = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.attachmentJson = const Value.absent(),
    this.answerContent = const Value.absent(),
    this.answerAttachmentJson = const Value.absent(),
    this.submittedContent = const Value.absent(),
    this.submittedAttachmentJson = const Value.absent(),
    this.gradeAttachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HomeworksCompanion.insert({
    required String id,
    required String courseId,
    required String baseId,
    required String title,
    this.description = const Value.absent(),
    required String deadline,
    this.lateSubmissionDeadline = const Value.absent(),
    this.submitTime = const Value.absent(),
    this.submitted = const Value.absent(),
    this.graded = const Value.absent(),
    this.grade = const Value.absent(),
    this.gradeLevel = const Value.absent(),
    this.graderName = const Value.absent(),
    this.gradeContent = const Value.absent(),
    this.gradeTime = const Value.absent(),
    this.isLateSubmission = const Value.absent(),
    this.completionType = const Value.absent(),
    this.submissionType = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.comment = const Value.absent(),
    this.attachmentJson = const Value.absent(),
    this.answerContent = const Value.absent(),
    this.answerAttachmentJson = const Value.absent(),
    this.submittedContent = const Value.absent(),
    this.submittedAttachmentJson = const Value.absent(),
    this.gradeAttachmentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       courseId = Value(courseId),
       baseId = Value(baseId),
       title = Value(title),
       deadline = Value(deadline);
  static Insertable<Homework> custom({
    Expression<String>? id,
    Expression<String>? courseId,
    Expression<String>? baseId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? deadline,
    Expression<String>? lateSubmissionDeadline,
    Expression<String>? submitTime,
    Expression<bool>? submitted,
    Expression<bool>? graded,
    Expression<double>? grade,
    Expression<String>? gradeLevel,
    Expression<String>? graderName,
    Expression<String>? gradeContent,
    Expression<String>? gradeTime,
    Expression<bool>? isLateSubmission,
    Expression<int>? completionType,
    Expression<int>? submissionType,
    Expression<bool>? isFavorite,
    Expression<String>? comment,
    Expression<String>? attachmentJson,
    Expression<String>? answerContent,
    Expression<String>? answerAttachmentJson,
    Expression<String>? submittedContent,
    Expression<String>? submittedAttachmentJson,
    Expression<String>? gradeAttachmentJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (baseId != null) 'base_id': baseId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (deadline != null) 'deadline': deadline,
      if (lateSubmissionDeadline != null)
        'late_submission_deadline': lateSubmissionDeadline,
      if (submitTime != null) 'submit_time': submitTime,
      if (submitted != null) 'submitted': submitted,
      if (graded != null) 'graded': graded,
      if (grade != null) 'grade': grade,
      if (gradeLevel != null) 'grade_level': gradeLevel,
      if (graderName != null) 'grader_name': graderName,
      if (gradeContent != null) 'grade_content': gradeContent,
      if (gradeTime != null) 'grade_time': gradeTime,
      if (isLateSubmission != null) 'is_late_submission': isLateSubmission,
      if (completionType != null) 'completion_type': completionType,
      if (submissionType != null) 'submission_type': submissionType,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (comment != null) 'comment': comment,
      if (attachmentJson != null) 'attachment_json': attachmentJson,
      if (answerContent != null) 'answer_content': answerContent,
      if (answerAttachmentJson != null)
        'answer_attachment_json': answerAttachmentJson,
      if (submittedContent != null) 'submitted_content': submittedContent,
      if (submittedAttachmentJson != null)
        'submitted_attachment_json': submittedAttachmentJson,
      if (gradeAttachmentJson != null)
        'grade_attachment_json': gradeAttachmentJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HomeworksCompanion copyWith({
    Value<String>? id,
    Value<String>? courseId,
    Value<String>? baseId,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? deadline,
    Value<String?>? lateSubmissionDeadline,
    Value<String?>? submitTime,
    Value<bool>? submitted,
    Value<bool>? graded,
    Value<double?>? grade,
    Value<String?>? gradeLevel,
    Value<String?>? graderName,
    Value<String?>? gradeContent,
    Value<String?>? gradeTime,
    Value<bool>? isLateSubmission,
    Value<int?>? completionType,
    Value<int?>? submissionType,
    Value<bool>? isFavorite,
    Value<String?>? comment,
    Value<String?>? attachmentJson,
    Value<String?>? answerContent,
    Value<String?>? answerAttachmentJson,
    Value<String?>? submittedContent,
    Value<String?>? submittedAttachmentJson,
    Value<String?>? gradeAttachmentJson,
    Value<int>? rowid,
  }) {
    return HomeworksCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      baseId: baseId ?? this.baseId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      lateSubmissionDeadline:
          lateSubmissionDeadline ?? this.lateSubmissionDeadline,
      submitTime: submitTime ?? this.submitTime,
      submitted: submitted ?? this.submitted,
      graded: graded ?? this.graded,
      grade: grade ?? this.grade,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      graderName: graderName ?? this.graderName,
      gradeContent: gradeContent ?? this.gradeContent,
      gradeTime: gradeTime ?? this.gradeTime,
      isLateSubmission: isLateSubmission ?? this.isLateSubmission,
      completionType: completionType ?? this.completionType,
      submissionType: submissionType ?? this.submissionType,
      isFavorite: isFavorite ?? this.isFavorite,
      comment: comment ?? this.comment,
      attachmentJson: attachmentJson ?? this.attachmentJson,
      answerContent: answerContent ?? this.answerContent,
      answerAttachmentJson: answerAttachmentJson ?? this.answerAttachmentJson,
      submittedContent: submittedContent ?? this.submittedContent,
      submittedAttachmentJson:
          submittedAttachmentJson ?? this.submittedAttachmentJson,
      gradeAttachmentJson: gradeAttachmentJson ?? this.gradeAttachmentJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (baseId.present) {
      map['base_id'] = Variable<String>(baseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<String>(deadline.value);
    }
    if (lateSubmissionDeadline.present) {
      map['late_submission_deadline'] = Variable<String>(
        lateSubmissionDeadline.value,
      );
    }
    if (submitTime.present) {
      map['submit_time'] = Variable<String>(submitTime.value);
    }
    if (submitted.present) {
      map['submitted'] = Variable<bool>(submitted.value);
    }
    if (graded.present) {
      map['graded'] = Variable<bool>(graded.value);
    }
    if (grade.present) {
      map['grade'] = Variable<double>(grade.value);
    }
    if (gradeLevel.present) {
      map['grade_level'] = Variable<String>(gradeLevel.value);
    }
    if (graderName.present) {
      map['grader_name'] = Variable<String>(graderName.value);
    }
    if (gradeContent.present) {
      map['grade_content'] = Variable<String>(gradeContent.value);
    }
    if (gradeTime.present) {
      map['grade_time'] = Variable<String>(gradeTime.value);
    }
    if (isLateSubmission.present) {
      map['is_late_submission'] = Variable<bool>(isLateSubmission.value);
    }
    if (completionType.present) {
      map['completion_type'] = Variable<int>(completionType.value);
    }
    if (submissionType.present) {
      map['submission_type'] = Variable<int>(submissionType.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (attachmentJson.present) {
      map['attachment_json'] = Variable<String>(attachmentJson.value);
    }
    if (answerContent.present) {
      map['answer_content'] = Variable<String>(answerContent.value);
    }
    if (answerAttachmentJson.present) {
      map['answer_attachment_json'] = Variable<String>(
        answerAttachmentJson.value,
      );
    }
    if (submittedContent.present) {
      map['submitted_content'] = Variable<String>(submittedContent.value);
    }
    if (submittedAttachmentJson.present) {
      map['submitted_attachment_json'] = Variable<String>(
        submittedAttachmentJson.value,
      );
    }
    if (gradeAttachmentJson.present) {
      map['grade_attachment_json'] = Variable<String>(
        gradeAttachmentJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeworksCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('baseId: $baseId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('deadline: $deadline, ')
          ..write('lateSubmissionDeadline: $lateSubmissionDeadline, ')
          ..write('submitTime: $submitTime, ')
          ..write('submitted: $submitted, ')
          ..write('graded: $graded, ')
          ..write('grade: $grade, ')
          ..write('gradeLevel: $gradeLevel, ')
          ..write('graderName: $graderName, ')
          ..write('gradeContent: $gradeContent, ')
          ..write('gradeTime: $gradeTime, ')
          ..write('isLateSubmission: $isLateSubmission, ')
          ..write('completionType: $completionType, ')
          ..write('submissionType: $submissionType, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('comment: $comment, ')
          ..write('attachmentJson: $attachmentJson, ')
          ..write('answerContent: $answerContent, ')
          ..write('answerAttachmentJson: $answerAttachmentJson, ')
          ..write('submittedContent: $submittedContent, ')
          ..write('submittedAttachmentJson: $submittedAttachmentJson, ')
          ..write('gradeAttachmentJson: $gradeAttachmentJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStateTable extends AppState
    with TableInfo<$AppStateTable, AppStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppStateTable createAlias(String alias) {
    return $AppStateTable(attachedDatabase, alias);
  }
}

class AppStateData extends DataClass implements Insertable<AppStateData> {
  final String key;
  final String value;
  const AppStateData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppStateCompanion toCompanion(bool nullToAbsent) {
    return AppStateCompanion(key: Value(key), value: Value(value));
  }

  factory AppStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateData(
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

  AppStateData copyWith({String? key, String? value}) =>
      AppStateData(key: key ?? this.key, value: value ?? this.value);
  AppStateData copyWithCompanion(AppStateCompanion data) {
    return AppStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateData(')
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
      (other is AppStateData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppStateCompanion extends UpdateCompanion<AppStateData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppStateData> custom({
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

  AppStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppStateCompanion(
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
    return (StringBuffer('AppStateCompanion(')
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
  late final $SemestersTable semesters = $SemestersTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final $CourseFilesTable courseFiles = $CourseFilesTable(this);
  late final $CachedAssetsTable cachedAssets = $CachedAssetsTable(this);
  late final $FileBookmarksTable fileBookmarks = $FileBookmarksTable(this);
  late final $HomeworksTable homeworks = $HomeworksTable(this);
  late final $AppStateTable appState = $AppStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    semesters,
    courses,
    notifications,
    courseFiles,
    cachedAssets,
    fileBookmarks,
    homeworks,
    appState,
  ];
}

typedef $$SemestersTableCreateCompanionBuilder =
    SemestersCompanion Function({
      required String id,
      required String startDate,
      required String endDate,
      required int startYear,
      required int endYear,
      required String type,
      Value<int> rowid,
    });
typedef $$SemestersTableUpdateCompanionBuilder =
    SemestersCompanion Function({
      Value<String> id,
      Value<String> startDate,
      Value<String> endDate,
      Value<int> startYear,
      Value<int> endYear,
      Value<String> type,
      Value<int> rowid,
    });

class $$SemestersTableFilterComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableFilterComposer({
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

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startYear => $composableBuilder(
    column: $table.startYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endYear => $composableBuilder(
    column: $table.endYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SemestersTableOrderingComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableOrderingComposer({
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

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startYear => $composableBuilder(
    column: $table.startYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endYear => $composableBuilder(
    column: $table.endYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SemestersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SemestersTable> {
  $$SemestersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get startYear =>
      $composableBuilder(column: $table.startYear, builder: (column) => column);

  GeneratedColumn<int> get endYear =>
      $composableBuilder(column: $table.endYear, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$SemestersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SemestersTable,
          Semester,
          $$SemestersTableFilterComposer,
          $$SemestersTableOrderingComposer,
          $$SemestersTableAnnotationComposer,
          $$SemestersTableCreateCompanionBuilder,
          $$SemestersTableUpdateCompanionBuilder,
          (Semester, BaseReferences<_$AppDatabase, $SemestersTable, Semester>),
          Semester,
          PrefetchHooks Function()
        > {
  $$SemestersTableTableManager(_$AppDatabase db, $SemestersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SemestersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SemestersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SemestersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> endDate = const Value.absent(),
                Value<int> startYear = const Value.absent(),
                Value<int> endYear = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SemestersCompanion(
                id: id,
                startDate: startDate,
                endDate: endDate,
                startYear: startYear,
                endYear: endYear,
                type: type,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String startDate,
                required String endDate,
                required int startYear,
                required int endYear,
                required String type,
                Value<int> rowid = const Value.absent(),
              }) => SemestersCompanion.insert(
                id: id,
                startDate: startDate,
                endDate: endDate,
                startYear: startYear,
                endYear: endYear,
                type: type,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SemestersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SemestersTable,
      Semester,
      $$SemestersTableFilterComposer,
      $$SemestersTableOrderingComposer,
      $$SemestersTableAnnotationComposer,
      $$SemestersTableCreateCompanionBuilder,
      $$SemestersTableUpdateCompanionBuilder,
      (Semester, BaseReferences<_$AppDatabase, $SemestersTable, Semester>),
      Semester,
      PrefetchHooks Function()
    >;
typedef $$CoursesTableCreateCompanionBuilder =
    CoursesCompanion Function({
      required String id,
      required String name,
      required String chineseName,
      Value<String> englishName,
      Value<String> teacherName,
      Value<String> teacherNumber,
      Value<String> courseNumber,
      Value<int> courseIndex,
      required String courseType,
      required String semesterId,
      Value<String> timeAndLocationJson,
      Value<int> sortOrder,
      Value<DateTime?> lastSynced,
      Value<int> rowid,
    });
typedef $$CoursesTableUpdateCompanionBuilder =
    CoursesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> chineseName,
      Value<String> englishName,
      Value<String> teacherName,
      Value<String> teacherNumber,
      Value<String> courseNumber,
      Value<int> courseIndex,
      Value<String> courseType,
      Value<String> semesterId,
      Value<String> timeAndLocationJson,
      Value<int> sortOrder,
      Value<DateTime?> lastSynced,
      Value<int> rowid,
    });

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chineseName => $composableBuilder(
    column: $table.chineseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get englishName => $composableBuilder(
    column: $table.englishName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teacherNumber => $composableBuilder(
    column: $table.teacherNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseNumber => $composableBuilder(
    column: $table.courseNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get courseIndex => $composableBuilder(
    column: $table.courseIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseType => $composableBuilder(
    column: $table.courseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeAndLocationJson => $composableBuilder(
    column: $table.timeAndLocationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chineseName => $composableBuilder(
    column: $table.chineseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get englishName => $composableBuilder(
    column: $table.englishName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teacherNumber => $composableBuilder(
    column: $table.teacherNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseNumber => $composableBuilder(
    column: $table.courseNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get courseIndex => $composableBuilder(
    column: $table.courseIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseType => $composableBuilder(
    column: $table.courseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeAndLocationJson => $composableBuilder(
    column: $table.timeAndLocationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get chineseName => $composableBuilder(
    column: $table.chineseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get englishName => $composableBuilder(
    column: $table.englishName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get teacherName => $composableBuilder(
    column: $table.teacherName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get teacherNumber => $composableBuilder(
    column: $table.teacherNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseNumber => $composableBuilder(
    column: $table.courseNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get courseIndex => $composableBuilder(
    column: $table.courseIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get courseType => $composableBuilder(
    column: $table.courseType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semesterId => $composableBuilder(
    column: $table.semesterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeAndLocationJson => $composableBuilder(
    column: $table.timeAndLocationJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSynced => $composableBuilder(
    column: $table.lastSynced,
    builder: (column) => column,
  );
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoursesTable,
          Course,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
          Course,
          PrefetchHooks Function()
        > {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> chineseName = const Value.absent(),
                Value<String> englishName = const Value.absent(),
                Value<String> teacherName = const Value.absent(),
                Value<String> teacherNumber = const Value.absent(),
                Value<String> courseNumber = const Value.absent(),
                Value<int> courseIndex = const Value.absent(),
                Value<String> courseType = const Value.absent(),
                Value<String> semesterId = const Value.absent(),
                Value<String> timeAndLocationJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> lastSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion(
                id: id,
                name: name,
                chineseName: chineseName,
                englishName: englishName,
                teacherName: teacherName,
                teacherNumber: teacherNumber,
                courseNumber: courseNumber,
                courseIndex: courseIndex,
                courseType: courseType,
                semesterId: semesterId,
                timeAndLocationJson: timeAndLocationJson,
                sortOrder: sortOrder,
                lastSynced: lastSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String chineseName,
                Value<String> englishName = const Value.absent(),
                Value<String> teacherName = const Value.absent(),
                Value<String> teacherNumber = const Value.absent(),
                Value<String> courseNumber = const Value.absent(),
                Value<int> courseIndex = const Value.absent(),
                required String courseType,
                required String semesterId,
                Value<String> timeAndLocationJson = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> lastSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoursesCompanion.insert(
                id: id,
                name: name,
                chineseName: chineseName,
                englishName: englishName,
                teacherName: teacherName,
                teacherNumber: teacherNumber,
                courseNumber: courseNumber,
                courseIndex: courseIndex,
                courseType: courseType,
                semesterId: semesterId,
                timeAndLocationJson: timeAndLocationJson,
                sortOrder: sortOrder,
                lastSynced: lastSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoursesTable,
      Course,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (Course, BaseReferences<_$AppDatabase, $CoursesTable, Course>),
      Course,
      PrefetchHooks Function()
    >;
typedef $$NotificationsTableCreateCompanionBuilder =
    NotificationsCompanion Function({
      required String id,
      required String courseId,
      required String title,
      Value<String> content,
      Value<String> publisher,
      required String publishTime,
      Value<String?> expireTime,
      Value<bool> hasRead,
      Value<bool> hasReadLocal,
      Value<bool> markedImportant,
      Value<bool> isFavorite,
      Value<String?> comment,
      Value<String?> attachmentJson,
      Value<int> rowid,
    });
typedef $$NotificationsTableUpdateCompanionBuilder =
    NotificationsCompanion Function({
      Value<String> id,
      Value<String> courseId,
      Value<String> title,
      Value<String> content,
      Value<String> publisher,
      Value<String> publishTime,
      Value<String?> expireTime,
      Value<bool> hasRead,
      Value<bool> hasReadLocal,
      Value<bool> markedImportant,
      Value<bool> isFavorite,
      Value<String?> comment,
      Value<String?> attachmentJson,
      Value<int> rowid,
    });

class $$NotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableFilterComposer({
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

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expireTime => $composableBuilder(
    column: $table.expireTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasRead => $composableBuilder(
    column: $table.hasRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasReadLocal => $composableBuilder(
    column: $table.hasReadLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableOrderingComposer({
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

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expireTime => $composableBuilder(
    column: $table.expireTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasRead => $composableBuilder(
    column: $table.hasRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasReadLocal => $composableBuilder(
    column: $table.hasReadLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationsTable> {
  $$NotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<String> get publishTime => $composableBuilder(
    column: $table.publishTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expireTime => $composableBuilder(
    column: $table.expireTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasRead =>
      $composableBuilder(column: $table.hasRead, builder: (column) => column);

  GeneratedColumn<bool> get hasReadLocal => $composableBuilder(
    column: $table.hasReadLocal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => column,
  );
}

class $$NotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationsTable,
          Notification,
          $$NotificationsTableFilterComposer,
          $$NotificationsTableOrderingComposer,
          $$NotificationsTableAnnotationComposer,
          $$NotificationsTableCreateCompanionBuilder,
          $$NotificationsTableUpdateCompanionBuilder,
          (
            Notification,
            BaseReferences<_$AppDatabase, $NotificationsTable, Notification>,
          ),
          Notification,
          PrefetchHooks Function()
        > {
  $$NotificationsTableTableManager(_$AppDatabase db, $NotificationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> publisher = const Value.absent(),
                Value<String> publishTime = const Value.absent(),
                Value<String?> expireTime = const Value.absent(),
                Value<bool> hasRead = const Value.absent(),
                Value<bool> hasReadLocal = const Value.absent(),
                Value<bool> markedImportant = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> attachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion(
                id: id,
                courseId: courseId,
                title: title,
                content: content,
                publisher: publisher,
                publishTime: publishTime,
                expireTime: expireTime,
                hasRead: hasRead,
                hasReadLocal: hasReadLocal,
                markedImportant: markedImportant,
                isFavorite: isFavorite,
                comment: comment,
                attachmentJson: attachmentJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courseId,
                required String title,
                Value<String> content = const Value.absent(),
                Value<String> publisher = const Value.absent(),
                required String publishTime,
                Value<String?> expireTime = const Value.absent(),
                Value<bool> hasRead = const Value.absent(),
                Value<bool> hasReadLocal = const Value.absent(),
                Value<bool> markedImportant = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> attachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion.insert(
                id: id,
                courseId: courseId,
                title: title,
                content: content,
                publisher: publisher,
                publishTime: publishTime,
                expireTime: expireTime,
                hasRead: hasRead,
                hasReadLocal: hasReadLocal,
                markedImportant: markedImportant,
                isFavorite: isFavorite,
                comment: comment,
                attachmentJson: attachmentJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationsTable,
      Notification,
      $$NotificationsTableFilterComposer,
      $$NotificationsTableOrderingComposer,
      $$NotificationsTableAnnotationComposer,
      $$NotificationsTableCreateCompanionBuilder,
      $$NotificationsTableUpdateCompanionBuilder,
      (
        Notification,
        BaseReferences<_$AppDatabase, $NotificationsTable, Notification>,
      ),
      Notification,
      PrefetchHooks Function()
    >;
typedef $$CourseFilesTableCreateCompanionBuilder =
    CourseFilesCompanion Function({
      required String id,
      required String courseId,
      required String fileId,
      required String title,
      Value<String> description,
      Value<int> rawSize,
      Value<String> size,
      required String uploadTime,
      Value<String> fileType,
      required String downloadUrl,
      required String previewUrl,
      Value<bool> isNew,
      Value<bool> markedImportant,
      Value<int> visitCount,
      Value<int> downloadCount,
      Value<String?> categoryId,
      Value<String?> categoryTitle,
      Value<bool?> isFavorite,
      Value<String?> comment,
      Value<String> localDownloadState,
      Value<String?> localFilePath,
      Value<int> rowid,
    });
typedef $$CourseFilesTableUpdateCompanionBuilder =
    CourseFilesCompanion Function({
      Value<String> id,
      Value<String> courseId,
      Value<String> fileId,
      Value<String> title,
      Value<String> description,
      Value<int> rawSize,
      Value<String> size,
      Value<String> uploadTime,
      Value<String> fileType,
      Value<String> downloadUrl,
      Value<String> previewUrl,
      Value<bool> isNew,
      Value<bool> markedImportant,
      Value<int> visitCount,
      Value<int> downloadCount,
      Value<String?> categoryId,
      Value<String?> categoryTitle,
      Value<bool?> isFavorite,
      Value<String?> comment,
      Value<String> localDownloadState,
      Value<String?> localFilePath,
      Value<int> rowid,
    });

class $$CourseFilesTableFilterComposer
    extends Composer<_$AppDatabase, $CourseFilesTable> {
  $$CourseFilesTableFilterComposer({
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

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rawSize => $composableBuilder(
    column: $table.rawSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadTime => $composableBuilder(
    column: $table.uploadTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryTitle => $composableBuilder(
    column: $table.categoryTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDownloadState => $composableBuilder(
    column: $table.localDownloadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CourseFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CourseFilesTable> {
  $$CourseFilesTableOrderingComposer({
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

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rawSize => $composableBuilder(
    column: $table.rawSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadTime => $composableBuilder(
    column: $table.uploadTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryTitle => $composableBuilder(
    column: $table.categoryTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDownloadState => $composableBuilder(
    column: $table.localDownloadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CourseFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CourseFilesTable> {
  $$CourseFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rawSize =>
      $composableBuilder(column: $table.rawSize, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get uploadTime => $composableBuilder(
    column: $table.uploadTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<bool> get markedImportant => $composableBuilder(
    column: $table.markedImportant,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadCount => $composableBuilder(
    column: $table.downloadCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryTitle => $composableBuilder(
    column: $table.categoryTitle,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get localDownloadState => $composableBuilder(
    column: $table.localDownloadState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );
}

class $$CourseFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CourseFilesTable,
          CourseFile,
          $$CourseFilesTableFilterComposer,
          $$CourseFilesTableOrderingComposer,
          $$CourseFilesTableAnnotationComposer,
          $$CourseFilesTableCreateCompanionBuilder,
          $$CourseFilesTableUpdateCompanionBuilder,
          (
            CourseFile,
            BaseReferences<_$AppDatabase, $CourseFilesTable, CourseFile>,
          ),
          CourseFile,
          PrefetchHooks Function()
        > {
  $$CourseFilesTableTableManager(_$AppDatabase db, $CourseFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rawSize = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<String> uploadTime = const Value.absent(),
                Value<String> fileType = const Value.absent(),
                Value<String> downloadUrl = const Value.absent(),
                Value<String> previewUrl = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<bool> markedImportant = const Value.absent(),
                Value<int> visitCount = const Value.absent(),
                Value<int> downloadCount = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryTitle = const Value.absent(),
                Value<bool?> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String> localDownloadState = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourseFilesCompanion(
                id: id,
                courseId: courseId,
                fileId: fileId,
                title: title,
                description: description,
                rawSize: rawSize,
                size: size,
                uploadTime: uploadTime,
                fileType: fileType,
                downloadUrl: downloadUrl,
                previewUrl: previewUrl,
                isNew: isNew,
                markedImportant: markedImportant,
                visitCount: visitCount,
                downloadCount: downloadCount,
                categoryId: categoryId,
                categoryTitle: categoryTitle,
                isFavorite: isFavorite,
                comment: comment,
                localDownloadState: localDownloadState,
                localFilePath: localFilePath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courseId,
                required String fileId,
                required String title,
                Value<String> description = const Value.absent(),
                Value<int> rawSize = const Value.absent(),
                Value<String> size = const Value.absent(),
                required String uploadTime,
                Value<String> fileType = const Value.absent(),
                required String downloadUrl,
                required String previewUrl,
                Value<bool> isNew = const Value.absent(),
                Value<bool> markedImportant = const Value.absent(),
                Value<int> visitCount = const Value.absent(),
                Value<int> downloadCount = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> categoryTitle = const Value.absent(),
                Value<bool?> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String> localDownloadState = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CourseFilesCompanion.insert(
                id: id,
                courseId: courseId,
                fileId: fileId,
                title: title,
                description: description,
                rawSize: rawSize,
                size: size,
                uploadTime: uploadTime,
                fileType: fileType,
                downloadUrl: downloadUrl,
                previewUrl: previewUrl,
                isNew: isNew,
                markedImportant: markedImportant,
                visitCount: visitCount,
                downloadCount: downloadCount,
                categoryId: categoryId,
                categoryTitle: categoryTitle,
                isFavorite: isFavorite,
                comment: comment,
                localDownloadState: localDownloadState,
                localFilePath: localFilePath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CourseFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CourseFilesTable,
      CourseFile,
      $$CourseFilesTableFilterComposer,
      $$CourseFilesTableOrderingComposer,
      $$CourseFilesTableAnnotationComposer,
      $$CourseFilesTableCreateCompanionBuilder,
      $$CourseFilesTableUpdateCompanionBuilder,
      (
        CourseFile,
        BaseReferences<_$AppDatabase, $CourseFilesTable, CourseFile>,
      ),
      CourseFile,
      PrefetchHooks Function()
    >;
typedef $$CachedAssetsTableCreateCompanionBuilder =
    CachedAssetsCompanion Function({
      required String assetKey,
      required String courseId,
      required String title,
      Value<String> fileType,
      required String localPath,
      Value<int> fileSizeBytes,
      Value<String?> lastAccessedAt,
      required String updatedAt,
      Value<String?> persistedFileId,
      Value<String> sourceKind,
      Value<String?> routeDataJson,
      Value<int> rowid,
    });
typedef $$CachedAssetsTableUpdateCompanionBuilder =
    CachedAssetsCompanion Function({
      Value<String> assetKey,
      Value<String> courseId,
      Value<String> title,
      Value<String> fileType,
      Value<String> localPath,
      Value<int> fileSizeBytes,
      Value<String?> lastAccessedAt,
      Value<String> updatedAt,
      Value<String?> persistedFileId,
      Value<String> sourceKind,
      Value<String?> routeDataJson,
      Value<int> rowid,
    });

class $$CachedAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAssetsTable> {
  $$CachedAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetKey => $composableBuilder(
    column: $table.assetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get persistedFileId => $composableBuilder(
    column: $table.persistedFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeDataJson => $composableBuilder(
    column: $table.routeDataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAssetsTable> {
  $$CachedAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetKey => $composableBuilder(
    column: $table.assetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get persistedFileId => $composableBuilder(
    column: $table.persistedFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeDataJson => $composableBuilder(
    column: $table.routeDataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAssetsTable> {
  $$CachedAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetKey =>
      $composableBuilder(column: $table.assetKey, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get persistedFileId => $composableBuilder(
    column: $table.persistedFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get routeDataJson => $composableBuilder(
    column: $table.routeDataJson,
    builder: (column) => column,
  );
}

class $$CachedAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedAssetsTable,
          CachedAsset,
          $$CachedAssetsTableFilterComposer,
          $$CachedAssetsTableOrderingComposer,
          $$CachedAssetsTableAnnotationComposer,
          $$CachedAssetsTableCreateCompanionBuilder,
          $$CachedAssetsTableUpdateCompanionBuilder,
          (
            CachedAsset,
            BaseReferences<_$AppDatabase, $CachedAssetsTable, CachedAsset>,
          ),
          CachedAsset,
          PrefetchHooks Function()
        > {
  $$CachedAssetsTableTableManager(_$AppDatabase db, $CachedAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetKey = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> fileType = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<String?> lastAccessedAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> persistedFileId = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> routeDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAssetsCompanion(
                assetKey: assetKey,
                courseId: courseId,
                title: title,
                fileType: fileType,
                localPath: localPath,
                fileSizeBytes: fileSizeBytes,
                lastAccessedAt: lastAccessedAt,
                updatedAt: updatedAt,
                persistedFileId: persistedFileId,
                sourceKind: sourceKind,
                routeDataJson: routeDataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetKey,
                required String courseId,
                required String title,
                Value<String> fileType = const Value.absent(),
                required String localPath,
                Value<int> fileSizeBytes = const Value.absent(),
                Value<String?> lastAccessedAt = const Value.absent(),
                required String updatedAt,
                Value<String?> persistedFileId = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> routeDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAssetsCompanion.insert(
                assetKey: assetKey,
                courseId: courseId,
                title: title,
                fileType: fileType,
                localPath: localPath,
                fileSizeBytes: fileSizeBytes,
                lastAccessedAt: lastAccessedAt,
                updatedAt: updatedAt,
                persistedFileId: persistedFileId,
                sourceKind: sourceKind,
                routeDataJson: routeDataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedAssetsTable,
      CachedAsset,
      $$CachedAssetsTableFilterComposer,
      $$CachedAssetsTableOrderingComposer,
      $$CachedAssetsTableAnnotationComposer,
      $$CachedAssetsTableCreateCompanionBuilder,
      $$CachedAssetsTableUpdateCompanionBuilder,
      (
        CachedAsset,
        BaseReferences<_$AppDatabase, $CachedAssetsTable, CachedAsset>,
      ),
      CachedAsset,
      PrefetchHooks Function()
    >;
typedef $$FileBookmarksTableCreateCompanionBuilder =
    FileBookmarksCompanion Function({
      required String assetKey,
      Value<String> courseName,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$FileBookmarksTableUpdateCompanionBuilder =
    FileBookmarksCompanion Function({
      Value<String> assetKey,
      Value<String> courseName,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$FileBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $FileBookmarksTable> {
  $$FileBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetKey => $composableBuilder(
    column: $table.assetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $FileBookmarksTable> {
  $$FileBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetKey => $composableBuilder(
    column: $table.assetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileBookmarksTable> {
  $$FileBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetKey =>
      $composableBuilder(column: $table.assetKey, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
    column: $table.courseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FileBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileBookmarksTable,
          FileBookmark,
          $$FileBookmarksTableFilterComposer,
          $$FileBookmarksTableOrderingComposer,
          $$FileBookmarksTableAnnotationComposer,
          $$FileBookmarksTableCreateCompanionBuilder,
          $$FileBookmarksTableUpdateCompanionBuilder,
          (
            FileBookmark,
            BaseReferences<_$AppDatabase, $FileBookmarksTable, FileBookmark>,
          ),
          FileBookmark,
          PrefetchHooks Function()
        > {
  $$FileBookmarksTableTableManager(_$AppDatabase db, $FileBookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetKey = const Value.absent(),
                Value<String> courseName = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileBookmarksCompanion(
                assetKey: assetKey,
                courseName: courseName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetKey,
                Value<String> courseName = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FileBookmarksCompanion.insert(
                assetKey: assetKey,
                courseName: courseName,
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

typedef $$FileBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileBookmarksTable,
      FileBookmark,
      $$FileBookmarksTableFilterComposer,
      $$FileBookmarksTableOrderingComposer,
      $$FileBookmarksTableAnnotationComposer,
      $$FileBookmarksTableCreateCompanionBuilder,
      $$FileBookmarksTableUpdateCompanionBuilder,
      (
        FileBookmark,
        BaseReferences<_$AppDatabase, $FileBookmarksTable, FileBookmark>,
      ),
      FileBookmark,
      PrefetchHooks Function()
    >;
typedef $$HomeworksTableCreateCompanionBuilder =
    HomeworksCompanion Function({
      required String id,
      required String courseId,
      required String baseId,
      required String title,
      Value<String?> description,
      required String deadline,
      Value<String?> lateSubmissionDeadline,
      Value<String?> submitTime,
      Value<bool> submitted,
      Value<bool> graded,
      Value<double?> grade,
      Value<String?> gradeLevel,
      Value<String?> graderName,
      Value<String?> gradeContent,
      Value<String?> gradeTime,
      Value<bool> isLateSubmission,
      Value<int?> completionType,
      Value<int?> submissionType,
      Value<bool> isFavorite,
      Value<String?> comment,
      Value<String?> attachmentJson,
      Value<String?> answerContent,
      Value<String?> answerAttachmentJson,
      Value<String?> submittedContent,
      Value<String?> submittedAttachmentJson,
      Value<String?> gradeAttachmentJson,
      Value<int> rowid,
    });
typedef $$HomeworksTableUpdateCompanionBuilder =
    HomeworksCompanion Function({
      Value<String> id,
      Value<String> courseId,
      Value<String> baseId,
      Value<String> title,
      Value<String?> description,
      Value<String> deadline,
      Value<String?> lateSubmissionDeadline,
      Value<String?> submitTime,
      Value<bool> submitted,
      Value<bool> graded,
      Value<double?> grade,
      Value<String?> gradeLevel,
      Value<String?> graderName,
      Value<String?> gradeContent,
      Value<String?> gradeTime,
      Value<bool> isLateSubmission,
      Value<int?> completionType,
      Value<int?> submissionType,
      Value<bool> isFavorite,
      Value<String?> comment,
      Value<String?> attachmentJson,
      Value<String?> answerContent,
      Value<String?> answerAttachmentJson,
      Value<String?> submittedContent,
      Value<String?> submittedAttachmentJson,
      Value<String?> gradeAttachmentJson,
      Value<int> rowid,
    });

class $$HomeworksTableFilterComposer
    extends Composer<_$AppDatabase, $HomeworksTable> {
  $$HomeworksTableFilterComposer({
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

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseId => $composableBuilder(
    column: $table.baseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lateSubmissionDeadline => $composableBuilder(
    column: $table.lateSubmissionDeadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submitTime => $composableBuilder(
    column: $table.submitTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get graded => $composableBuilder(
    column: $table.graded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get graderName => $composableBuilder(
    column: $table.graderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradeContent => $composableBuilder(
    column: $table.gradeContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradeTime => $composableBuilder(
    column: $table.gradeTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLateSubmission => $composableBuilder(
    column: $table.isLateSubmission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completionType => $composableBuilder(
    column: $table.completionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submissionType => $composableBuilder(
    column: $table.submissionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerContent => $composableBuilder(
    column: $table.answerContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerAttachmentJson => $composableBuilder(
    column: $table.answerAttachmentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submittedContent => $composableBuilder(
    column: $table.submittedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submittedAttachmentJson => $composableBuilder(
    column: $table.submittedAttachmentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradeAttachmentJson => $composableBuilder(
    column: $table.gradeAttachmentJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HomeworksTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeworksTable> {
  $$HomeworksTableOrderingComposer({
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

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseId => $composableBuilder(
    column: $table.baseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lateSubmissionDeadline => $composableBuilder(
    column: $table.lateSubmissionDeadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submitTime => $composableBuilder(
    column: $table.submitTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get graded => $composableBuilder(
    column: $table.graded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get graderName => $composableBuilder(
    column: $table.graderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradeContent => $composableBuilder(
    column: $table.gradeContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradeTime => $composableBuilder(
    column: $table.gradeTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLateSubmission => $composableBuilder(
    column: $table.isLateSubmission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completionType => $composableBuilder(
    column: $table.completionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submissionType => $composableBuilder(
    column: $table.submissionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerContent => $composableBuilder(
    column: $table.answerContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerAttachmentJson => $composableBuilder(
    column: $table.answerAttachmentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submittedContent => $composableBuilder(
    column: $table.submittedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submittedAttachmentJson => $composableBuilder(
    column: $table.submittedAttachmentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradeAttachmentJson => $composableBuilder(
    column: $table.gradeAttachmentJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HomeworksTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeworksTable> {
  $$HomeworksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get baseId =>
      $composableBuilder(column: $table.baseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<String> get lateSubmissionDeadline => $composableBuilder(
    column: $table.lateSubmissionDeadline,
    builder: (column) => column,
  );

  GeneratedColumn<String> get submitTime => $composableBuilder(
    column: $table.submitTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get submitted =>
      $composableBuilder(column: $table.submitted, builder: (column) => column);

  GeneratedColumn<bool> get graded =>
      $composableBuilder(column: $table.graded, builder: (column) => column);

  GeneratedColumn<double> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<String> get gradeLevel => $composableBuilder(
    column: $table.gradeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get graderName => $composableBuilder(
    column: $table.graderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gradeContent => $composableBuilder(
    column: $table.gradeContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gradeTime =>
      $composableBuilder(column: $table.gradeTime, builder: (column) => column);

  GeneratedColumn<bool> get isLateSubmission => $composableBuilder(
    column: $table.isLateSubmission,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completionType => $composableBuilder(
    column: $table.completionType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get submissionType => $composableBuilder(
    column: $table.submissionType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get attachmentJson => $composableBuilder(
    column: $table.attachmentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerContent => $composableBuilder(
    column: $table.answerContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerAttachmentJson => $composableBuilder(
    column: $table.answerAttachmentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get submittedContent => $composableBuilder(
    column: $table.submittedContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get submittedAttachmentJson => $composableBuilder(
    column: $table.submittedAttachmentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gradeAttachmentJson => $composableBuilder(
    column: $table.gradeAttachmentJson,
    builder: (column) => column,
  );
}

class $$HomeworksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HomeworksTable,
          Homework,
          $$HomeworksTableFilterComposer,
          $$HomeworksTableOrderingComposer,
          $$HomeworksTableAnnotationComposer,
          $$HomeworksTableCreateCompanionBuilder,
          $$HomeworksTableUpdateCompanionBuilder,
          (Homework, BaseReferences<_$AppDatabase, $HomeworksTable, Homework>),
          Homework,
          PrefetchHooks Function()
        > {
  $$HomeworksTableTableManager(_$AppDatabase db, $HomeworksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeworksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeworksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeworksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> baseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> deadline = const Value.absent(),
                Value<String?> lateSubmissionDeadline = const Value.absent(),
                Value<String?> submitTime = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
                Value<bool> graded = const Value.absent(),
                Value<double?> grade = const Value.absent(),
                Value<String?> gradeLevel = const Value.absent(),
                Value<String?> graderName = const Value.absent(),
                Value<String?> gradeContent = const Value.absent(),
                Value<String?> gradeTime = const Value.absent(),
                Value<bool> isLateSubmission = const Value.absent(),
                Value<int?> completionType = const Value.absent(),
                Value<int?> submissionType = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> attachmentJson = const Value.absent(),
                Value<String?> answerContent = const Value.absent(),
                Value<String?> answerAttachmentJson = const Value.absent(),
                Value<String?> submittedContent = const Value.absent(),
                Value<String?> submittedAttachmentJson = const Value.absent(),
                Value<String?> gradeAttachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HomeworksCompanion(
                id: id,
                courseId: courseId,
                baseId: baseId,
                title: title,
                description: description,
                deadline: deadline,
                lateSubmissionDeadline: lateSubmissionDeadline,
                submitTime: submitTime,
                submitted: submitted,
                graded: graded,
                grade: grade,
                gradeLevel: gradeLevel,
                graderName: graderName,
                gradeContent: gradeContent,
                gradeTime: gradeTime,
                isLateSubmission: isLateSubmission,
                completionType: completionType,
                submissionType: submissionType,
                isFavorite: isFavorite,
                comment: comment,
                attachmentJson: attachmentJson,
                answerContent: answerContent,
                answerAttachmentJson: answerAttachmentJson,
                submittedContent: submittedContent,
                submittedAttachmentJson: submittedAttachmentJson,
                gradeAttachmentJson: gradeAttachmentJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String courseId,
                required String baseId,
                required String title,
                Value<String?> description = const Value.absent(),
                required String deadline,
                Value<String?> lateSubmissionDeadline = const Value.absent(),
                Value<String?> submitTime = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
                Value<bool> graded = const Value.absent(),
                Value<double?> grade = const Value.absent(),
                Value<String?> gradeLevel = const Value.absent(),
                Value<String?> graderName = const Value.absent(),
                Value<String?> gradeContent = const Value.absent(),
                Value<String?> gradeTime = const Value.absent(),
                Value<bool> isLateSubmission = const Value.absent(),
                Value<int?> completionType = const Value.absent(),
                Value<int?> submissionType = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String?> attachmentJson = const Value.absent(),
                Value<String?> answerContent = const Value.absent(),
                Value<String?> answerAttachmentJson = const Value.absent(),
                Value<String?> submittedContent = const Value.absent(),
                Value<String?> submittedAttachmentJson = const Value.absent(),
                Value<String?> gradeAttachmentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HomeworksCompanion.insert(
                id: id,
                courseId: courseId,
                baseId: baseId,
                title: title,
                description: description,
                deadline: deadline,
                lateSubmissionDeadline: lateSubmissionDeadline,
                submitTime: submitTime,
                submitted: submitted,
                graded: graded,
                grade: grade,
                gradeLevel: gradeLevel,
                graderName: graderName,
                gradeContent: gradeContent,
                gradeTime: gradeTime,
                isLateSubmission: isLateSubmission,
                completionType: completionType,
                submissionType: submissionType,
                isFavorite: isFavorite,
                comment: comment,
                attachmentJson: attachmentJson,
                answerContent: answerContent,
                answerAttachmentJson: answerAttachmentJson,
                submittedContent: submittedContent,
                submittedAttachmentJson: submittedAttachmentJson,
                gradeAttachmentJson: gradeAttachmentJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HomeworksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HomeworksTable,
      Homework,
      $$HomeworksTableFilterComposer,
      $$HomeworksTableOrderingComposer,
      $$HomeworksTableAnnotationComposer,
      $$HomeworksTableCreateCompanionBuilder,
      $$HomeworksTableUpdateCompanionBuilder,
      (Homework, BaseReferences<_$AppDatabase, $HomeworksTable, Homework>),
      Homework,
      PrefetchHooks Function()
    >;
typedef $$AppStateTableCreateCompanionBuilder =
    AppStateCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppStateTableUpdateCompanionBuilder =
    AppStateCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppStateTableFilterComposer
    extends Composer<_$AppDatabase, $AppStateTable> {
  $$AppStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStateTableOrderingComposer
    extends Composer<_$AppDatabase, $AppStateTable> {
  $$AppStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppStateTable> {
  $$AppStateTableAnnotationComposer({
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

class $$AppStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppStateTable,
          AppStateData,
          $$AppStateTableFilterComposer,
          $$AppStateTableOrderingComposer,
          $$AppStateTableAnnotationComposer,
          $$AppStateTableCreateCompanionBuilder,
          $$AppStateTableUpdateCompanionBuilder,
          (
            AppStateData,
            BaseReferences<_$AppDatabase, $AppStateTable, AppStateData>,
          ),
          AppStateData,
          PrefetchHooks Function()
        > {
  $$AppStateTableTableManager(_$AppDatabase db, $AppStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppStateTable,
      AppStateData,
      $$AppStateTableFilterComposer,
      $$AppStateTableOrderingComposer,
      $$AppStateTableAnnotationComposer,
      $$AppStateTableCreateCompanionBuilder,
      $$AppStateTableUpdateCompanionBuilder,
      (
        AppStateData,
        BaseReferences<_$AppDatabase, $AppStateTable, AppStateData>,
      ),
      AppStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SemestersTableTableManager get semesters =>
      $$SemestersTableTableManager(_db, _db.semesters);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db, _db.notifications);
  $$CourseFilesTableTableManager get courseFiles =>
      $$CourseFilesTableTableManager(_db, _db.courseFiles);
  $$CachedAssetsTableTableManager get cachedAssets =>
      $$CachedAssetsTableTableManager(_db, _db.cachedAssets);
  $$FileBookmarksTableTableManager get fileBookmarks =>
      $$FileBookmarksTableTableManager(_db, _db.fileBookmarks);
  $$HomeworksTableTableManager get homeworks =>
      $$HomeworksTableTableManager(_db, _db.homeworks);
  $$AppStateTableTableManager get appState =>
      $$AppStateTableTableManager(_db, _db.appState);
}
