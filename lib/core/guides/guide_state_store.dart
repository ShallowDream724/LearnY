import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../providers/app_providers.dart';
import 'guide_registry.dart';

class GuideStateRecord {
  const GuideStateRecord({this.presentedVersion, this.dismissedVersion});

  final String? presentedVersion;
  final String? dismissedVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'presentedVersion': presentedVersion,
    'dismissedVersion': dismissedVersion,
  };

  static GuideStateRecord fromJson(Map<String, dynamic> json) {
    return GuideStateRecord(
      presentedVersion: json['presentedVersion'] as String?,
      dismissedVersion: json['dismissedVersion'] as String?,
    );
  }

  GuideStateRecord copyWith({
    String? presentedVersion,
    String? dismissedVersion,
  }) {
    return GuideStateRecord(
      presentedVersion: presentedVersion ?? this.presentedVersion,
      dismissedVersion: dismissedVersion ?? this.dismissedVersion,
    );
  }
}

class GuideStateStore {
  const GuideStateStore(this._db);

  final AppDatabase _db;

  Future<GuideStateRecord> read(GuideDefinition guide) async {
    final all = await _readAll();
    return all[guide.id] ?? const GuideStateRecord();
  }

  Future<bool> shouldShow(GuideDefinition guide) async {
    final record = await read(guide);
    return record.dismissedVersion != guide.version;
  }

  Future<void> markPresented(GuideDefinition guide) async {
    final all = await _readAll();
    final current = all[guide.id] ?? const GuideStateRecord();
    if (current.presentedVersion == guide.version) {
      return;
    }
    all[guide.id] = current.copyWith(presentedVersion: guide.version);
    await _writeAll(all);
  }

  Future<void> dismiss(GuideDefinition guide) async {
    final all = await _readAll();
    final current = all[guide.id] ?? const GuideStateRecord();
    all[guide.id] = current.copyWith(
      presentedVersion: guide.version,
      dismissedVersion: guide.version,
    );
    await _writeAll(all);
  }

  Future<Map<String, GuideStateRecord>> _readAll() async {
    try {
      final raw = await _db.getState(AppStateKeys.guideState);
      if (raw == null || raw.trim().isEmpty) {
        return <String, GuideStateRecord>{};
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, GuideStateRecord>{};
      }

      return decoded.map<String, GuideStateRecord>((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key.toString(), GuideStateRecord.fromJson(value));
        }
        if (value is Map) {
          return MapEntry(
            key.toString(),
            GuideStateRecord.fromJson(
              value.map<String, dynamic>(
                (dynamic childKey, dynamic childValue) =>
                    MapEntry(childKey.toString(), childValue),
              ),
            ),
          );
        }
        return MapEntry(key.toString(), const GuideStateRecord());
      });
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Failed to read guide state: $error');
      debugPrint('$stackTrace');
      return <String, GuideStateRecord>{};
    }
  }

  Future<void> _writeAll(Map<String, GuideStateRecord> all) {
    final encoded = jsonEncode(
      all.map((key, value) => MapEntry(key, value.toJson())),
    );
    return _db.setState(AppStateKeys.guideState, encoded);
  }
}

final guideStateStoreProvider = Provider<GuideStateStore>((ref) {
  return GuideStateStore(ref.watch(databaseProvider));
});
