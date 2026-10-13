// Draws the app icons: dart run tool/make_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

img.Image icon(int size, {required bool maskable}) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  final bg = img.ColorRgba8(0xC4, 0x42, 0x0F, 255);
  final white = img.ColorRgba8(0xFF, 0xF6, 0xEE, 255); // the app's cream
  if (maskable) {
    img.fill(im, color: bg);
  } else {
    img.fillRect(
      im,
      x1: 0,
      y1: 0,
      x2: size,
      y2: size,
      color: img.ColorRgba8(0, 0, 0, 0),
    );
    img.fillRect(
      im,
      x1: 0,
      y1: 0,
      x2: size - 1,
      y2: size - 1,
      color: bg,
      radius: size * 0.22,
    );
  }
  final c = size ~/ 2;
  final u = size * (maskable ? 0.30 : 0.36);
  // camera body
  img.fillRect(
    im,
    x1: (c - u).round(),
    y1: (c - u * 0.62).round(),
    x2: (c + u).round(),
    y2: (c + u * 0.78).round(),
    color: white,
    radius: u * 0.22,
  );
  // viewfinder bump
  img.fillRect(
    im,
    x1: (c - u * 0.38).round(),
    y1: (c - u * 0.9).round(),
    x2: (c + u * 0.38).round(),
    y2: (c - u * 0.55).round(),
    color: white,
    radius: u * 0.1,
  );
  // lens
  img.fillCircle(
    im,
    x: c,
    y: (c + u * 0.08).round(),
    radius: (u * 0.46).round(),
    color: bg,
  );
  img.fillCircle(
    im,
    x: c,
    y: (c + u * 0.08).round(),
    radius: (u * 0.33).round(),
    color: white,
  );
  img.fillCircle(
    im,
    x: c,
    y: (c + u * 0.08).round(),
    radius: (u * 0.18).round(),
    color: bg,
  );
  return im;
}

void main() {
  for (final s in [192, 512]) {
    File('web/icons/Icon-$s.png')
        .writeAsBytesSync(img.encodePng(icon(s, maskable: false)));
    File('web/icons/Icon-maskable-$s.png')
        .writeAsBytesSync(img.encodePng(icon(s, maskable: true)));
  }
  File('web/favicon.png')
      .writeAsBytesSync(img.encodePng(icon(64, maskable: false)));
}
