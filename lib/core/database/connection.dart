// Database connection factory — platform-specific.
//
// Uses `NativeDatabase` from sqlite3_flutter_libs for mobile,
// and can be extended for web (drift worker) if needed.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'database.dart';

/// Creates a database connection using the platform-specific storage.
AppDatabase createDatabase() {
  return AppDatabase(_openConnection());
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'learn_y.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
