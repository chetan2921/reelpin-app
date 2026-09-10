import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:reelpin/constants/app_colors.dart';

/// Brutalist map pin: flat colored square with thick black border.
///
/// Shared by the Map tab and the chat places block so a category is drawn
/// identically — same shape, same `AppColors.getCategoryColor` fill — in
/// both places.
Future<BitmapDescriptor> createCategoryMarkerIcon(String category) async {
  return BitmapDescriptor.bytes(await createCategoryMarkerPng(category));
}

/// The pin's raw PNG bytes, for a caller that wants to paint it as a plain
/// `Image.memory` widget rather than hand it to a native `Marker` — a lite
/// mode map draws its own "directions" / "open in Maps" icons around any
/// real marker, baked into the static tile itself, regardless of the
/// marker's own icon. Drawing the pin as a plain overlay widget instead
/// keeps the map underneath marker-free, so that chrome never appears.
Future<Uint8List> createCategoryMarkerPng(String category) async {
  final catColor = AppColors.getCategoryColor(category);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(40, 52);

  // Hard shadow (offset, no blur)
  final shadowPaint = Paint()..color = Colors.black;
  canvas.drawRect(
    Rect.fromLTWH(3, 3, size.width - 3, size.height * 0.7),
    shadowPaint,
  );
  // Add shadow specifically for the pointer to make it unified
  final shadowPath = Path();
  shadowPath.moveTo((size.width - 3) * 0.35 + 3, size.height * 0.7 + 3);
  shadowPath.lineTo((size.width - 3) * 0.5 + 3, size.height);
  shadowPath.lineTo((size.width - 3) * 0.65 + 3, size.height * 0.7 + 3);
  shadowPath.close();
  canvas.drawPath(shadowPath, shadowPaint);

  // Pin body (sharp square with pointer)
  final path = Path();
  // Square body
  path.addRect(Rect.fromLTWH(0, 0, size.width - 3, size.height * 0.7));
  // Triangle pointer
  path.moveTo((size.width - 3) * 0.35, size.height * 0.7);
  path.lineTo((size.width - 3) * 0.5, size.height - 3);
  path.lineTo((size.width - 3) * 0.65, size.height * 0.7);
  path.close();

  // Fill
  canvas.drawPath(path, Paint()..color = catColor);
  // Border
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = 2.5,
  );

  // Letter (centered in square body)
  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  final letterColor = catColor.computeLuminance() > 0.5
      ? AppColors.black
      : AppColors.white;
  textPainter.text = TextSpan(
    text: category.isNotEmpty ? category[0].toUpperCase() : '?',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      color: letterColor,
      fontFamily: 'monospace',
    ),
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      ((size.width - 3) - textPainter.width) / 2,
      (size.height * 0.7 - textPainter.height) / 2,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  return bytes!.buffer.asUint8List();
}
