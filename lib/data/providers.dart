import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/baby.dart';
import 'baby_repository.dart';

final babyRepositoryProvider = FutureProvider<BabyRepository>((ref) async {
  return BabyRepository(await getApplicationSupportDirectory());
});

class BabiesNotifier extends AsyncNotifier<List<Baby>> {
  @override
  Future<List<Baby>> build() async =>
      (await ref.watch(babyRepositoryProvider.future)).load();

  Future<void> add(Baby baby) async {
    final repo = await ref.read(babyRepositoryProvider.future);
    final next = [...?state.value, baby];
    await repo.save(next);
    state = AsyncData(next);
  }
}

final babiesProvider = AsyncNotifierProvider<BabiesNotifier, List<Baby>>(
  BabiesNotifier.new,
);
