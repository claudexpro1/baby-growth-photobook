import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/google_auth.dart';
import 'domain/baby.dart';
import 'features/home/home_page.dart';
import 'ui/theme.dart';

void main() {
  // Load Google's sign-in script now, so a later tap can open its window at
  // once (browsers block a pop-up that opens after a network wait).
  if (kIsWeb) unawaited(GoogleAuth.ensureInit().catchError((_) {}));
  runApp(const ProviderScope(child: PhotobookApp()));
}

class PhotobookApp extends StatelessWidget {
  const PhotobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Photobook',
      debugShowCheckedModeBanner: false,
      // Always the light, cream-and-orange look, whatever the phone's setting.
      theme: buildTheme(
        Gender.neutral,
        wide: MediaQuery.sizeOf(context).width >= 700,
      ),
      themeMode: ThemeMode.light,
      home: const HomePage(),
    );
  }
}
