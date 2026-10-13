import 'package:flutter/material.dart';

import '../../data/photo_library.dart';
import '../../domain/age_label.dart';
import '../../domain/baby.dart';
import 'photo_image.dart';

/// The baby's picture: the latest photo, or a warm placeholder that invites
/// the first photo. Shared by the list and the baby page.
class BabyAvatar extends StatelessWidget {
  const BabyAvatar({super.key, required this.baby, this.photo, this.size = 84});
  final Baby baby;
  final PhotoEntry? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: SizedBox(
        width: size,
        height: size,
        child: photo != null
            ? PhotoImage(photo!, cacheWidth: (size * 3).round())
            : Semantics(
                label: 'No photo yet for ${baby.name}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primaryContainer,
                        Color.lerp(scheme.primaryContainer, Colors.white, 0.6)!,
                      ],
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: size * 0.08,
                          top: size * 0.06,
                          child: _doodle('⭐', size * 0.16),
                        ),
                        Positioned(
                          right: size * 0.08,
                          top: size * 0.12,
                          child: _doodle('🧸', size * 0.18),
                        ),
                        Positioned(
                          left: size * 0.1,
                          bottom: size * 0.22,
                          child: _doodle('💛', size * 0.14),
                        ),
                        Text('👶', style: TextStyle(fontSize: size * 0.46)),
                        Positioned(
                          right: size * 0.07,
                          bottom: size * 0.2,
                          child: Container(
                            padding: EdgeInsets.all(size * 0.05),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.photo_camera,
                              size: size * 0.15,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: size * 0.05,
                          child: Text(
                            'First photo',
                            style: TextStyle(
                              fontSize: size * 0.12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _doodle(String e, double s) => Opacity(
    opacity: 0.35,
    child: Text(e, style: TextStyle(fontSize: s)),
  );
}

/// "born Oct 12, 2026 at 14:05 in Athens" - only what the parent entered.
String bornText(BuildContext context, Baby baby) {
  final loc = MaterialLocalizations.of(context);
  final b = baby.birth;
  final sameYear = b.year == DateTime.now().year;
  final date = sameYear
      ? loc.formatShortMonthDay(b)
      : '${loc.formatShortMonthDay(b)}, ${b.year}';
  final time = (b.hour == 0 && b.minute == 0)
      ? ''
      : ' at ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(b))}';
  final place = baby.birthPlace.trim().isEmpty
      ? ''
      : ' in ${baby.birthPlace.trim()}';
  final verb = DateTime.now().isBefore(b) ? 'due' : 'born';
  return '$verb $date$time$place';
}

/// "born Oct 12 · 2 days old", for the list.
String birthSummary(BuildContext context, Baby baby) {
  final loc = MaterialLocalizations.of(context);
  final b = baby.birth;
  final date = b.year == DateTime.now().year
      ? loc.formatShortMonthDay(b)
      : '${loc.formatShortMonthDay(b)}, ${b.year}';
  final verb = DateTime.now().isBefore(b) ? 'due' : 'born';
  return '$verb $date · ${ageNowLabel(b, DateTime.now())}';
}
