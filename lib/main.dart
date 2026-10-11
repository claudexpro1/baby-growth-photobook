import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/baby.dart';
import 'features/home/home_page.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: PhotobookApp()));
}

class PhotobookApp extends StatelessWidget {
  const PhotobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Photobook',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Gender.neutral),
      darkTheme: buildTheme(Gender.neutral, brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}
