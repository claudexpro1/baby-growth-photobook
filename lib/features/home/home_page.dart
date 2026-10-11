import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/baby.dart';
import '../onboarding/onboarding_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _add(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OnboardingPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final babies = ref.watch(babiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Baby Growth Photobook')),
      floatingActionButton: babies.hasValue && babies.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('Add baby'),
            )
          : null,
      body: babies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profiles: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'A few photos, kept with care.',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      const Text("Add your baby to set up a photo schedule."),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _add(context),
                        child: const Text('Add your baby'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(children: [for (final b in list) _BabyTile(b)]),
      ),
    );
  }
}

class _BabyTile extends StatelessWidget {
  const _BabyTile(this.baby);
  final Baby baby;

  @override
  Widget build(BuildContext context) {
    final next = baby.schedule.nextDueAfter(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.child_care)),
      title: Text(baby.name),
      subtitle: Text(
        'Next photo: ${MaterialLocalizations.of(context).formatMediumDate(next)}'
        '${baby.storage == StorageMode.appOnly ? '\nPhotos kept only in this app' : ''}',
      ),
      isThreeLine: baby.storage == StorageMode.appOnly,
    );
  }
}
