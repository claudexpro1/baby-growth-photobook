
import 'package:flutter/material.dart';
import '../common/photo_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import '../../ui/theme.dart';
import '../baby/baby_page.dart';
import '../onboarding/onboarding_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Top up the rolling reminder window every time the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(babiesProvider.future);
      ref.read(babiesProvider.notifier).reschedule();
    });
  }

  void _add() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OnboardingPage()));

  @override
  Widget build(BuildContext context) {
    final babies = ref.watch(babiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Baby Photobook')),
      floatingActionButton: babies.hasValue && babies.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add a baby'),
            )
          : null,
      body: babies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load your babies.')),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.child_care,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A few photos, kept with care',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One photo now and then, saved in your own Drive, '
                        'becomes a story you will treasure.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _add,
                        child: const Text('Start with your baby'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [for (final b in list) _BabyCard(b)],
              ),
      ),
    );
  }
}

class _BabyCard extends ConsumerWidget {
  const _BabyCard(this.baby);
  final Baby baby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider(baby.id)).value ?? [];
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final dueToday =
        baby.schedule.dueDates(todayUtc, todayUtc).isNotEmpty &&
        !photos.any((p) => p.date == todayUtc);
    final next = baby.schedule.nextDueAfter(todayUtc);
    final loc = MaterialLocalizations.of(context);
    final waiting = photos.where((p) => !p.synced).length;
    return Theme(
      data: buildTheme(baby.gender),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BabyPage(babyId: baby.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: photos.isEmpty
                            ? ColoredBox(
                                color: scheme.primaryContainer,
                                child: Icon(
                                  Icons.child_care,
                                  size: 40,
                                  color: scheme.primary,
                                ),
                              )
                            : PhotoImage(photos.last, cacheWidth: 250),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baby.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(ageLabel(baby.birth, DateTime.now())),
                          const SizedBox(height: 6),
                          if (dueToday)
                            Chip(
                              label: const Text("Today's photo"),
                              backgroundColor: scheme.primaryContainer,
                              visualDensity: VisualDensity.compact,
                            )
                          else
                            Text(
                              'Next photo: ${loc.formatMediumDate(next)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (baby.storage == StorageMode.appOnly)
                            Text(
                              'Only on this phone',
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 12,
                              ),
                            )
                          else if (waiting > 0)
                            Text(
                              '$waiting waiting to upload',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
