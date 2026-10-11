import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_page.dart';

void main() {
  runApp(const ProviderScope(child: PhotobookApp()));
}

class PhotobookApp extends StatelessWidget {
  const PhotobookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Growth Photobook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
