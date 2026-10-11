import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/photo_library.dart';
import '../domain/age_label.dart';
import '../domain/baby.dart';

/// Builds a simple photobook: a cover, then 6 photos per page with ages.
Future<Uint8List> buildPhotobookPdf(Baby baby, List<PhotoEntry> photos) async {
  final shrunk = <Uint8List>[];
  for (final p in photos) {
    shrunk.add(await compute(_shrinkBytes, await p.bytes()));
  }
  // Noto Sans covers Latin, Greek and Cyrillic names (the default PDF font does not).
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  final doc = pw.Document(
    title: "${baby.name}'s photobook",
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  String d(DateTime x) => '${x.day}.${x.month}.${x.year}';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              baby.name,
              style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Born ${d(baby.birth)}${baby.birthPlace.isEmpty ? '' : ' in ${baby.birthPlace}'}',
              style: const pw.TextStyle(fontSize: 18),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '${photos.length} photos',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );

  for (var i = 0; i < photos.length; i += 6) {
    final chunk = [for (var j = i; j < i + 6 && j < photos.length; j++) j];
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final j in chunk)
              pw.SizedBox(
                width: 245,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      height: 220,
                      alignment: pw.Alignment.center,
                      child: shrunk[j].isEmpty
                          ? pw.SizedBox()
                          : pw.Image(
                              pw.MemoryImage(shrunk[j]),
                              fit: pw.BoxFit.contain,
                            ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      ageLabel(baby.birth, photos[j].date),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      d(photos[j].date),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

Uint8List _shrinkBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return Uint8List(0);
  final landscape = decoded.width >= decoded.height;
  final small = img.copyResize(
    decoded,
    width: landscape ? 1000 : null,
    height: landscape ? null : 1000,
  );
  return Uint8List.fromList(img.encodeJpg(small, quality: 80));
}
