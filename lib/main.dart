import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/db/seed.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opening the database and seeding categories takes a few milliseconds. Doing
  // it before the first frame costs nothing visible and spares every screen a
  // loading branch that would only ever be true at startup.
  final database = AppDatabase();
  await seedDefaultCategories(database);

  final prefs = await SharedPreferences.getInstance();

  // Romanian month and weekday names, and the `1.250,50` grouping. Without this
  // `DateFormat` silently falls back to US formatting.
  await initializeDateFormatting('ro_RO', null);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        preferencesProvider.overrideWithValue(prefs),
      ],
      child: const TallyApp(),
    ),
  );
}
