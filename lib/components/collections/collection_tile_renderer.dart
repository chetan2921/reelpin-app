import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:reelpin/components/collections/collection_folder_tile.dart';
import 'package:reelpin/data_models/collections/collection_models.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Renders the real [CollectionFolderTile] to a PNG so the native share sheets
/// can show the exact artwork from the SAVED tab.
///
/// The share targets are native — an iOS Share Extension cannot host a Flutter
/// engine, and the Android relay activity must appear instantly — so the only
/// way to guarantee the tile looks identical is to draw it with Flutter and
/// hand over the pixels. Redrawing it natively produced a near-miss that
/// drifted from the app every time the design changed.
class CollectionTileRenderer {
  CollectionTileRenderer._();

  /// Logical size of one tile; the pixel ratio below decides the real output.
  static const Size tileSize = Size(150, 138);
  static const double _pixelRatio = 3;

  static Future<Uint8List?> renderTile({
    required CollectionSummary collection,
    required int index,
    Brightness brightness = Brightness.light,
  }) async {
    try {
      final boundary = RenderRepaintBoundary();
      final view = WidgetsBinding.instance.platformDispatcher.views.first;

      final renderView = RenderView(
        view: view,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: boundary,
        ),
        configuration: ViewConfiguration(
          physicalConstraints: BoxConstraints.tight(tileSize) * _pixelRatio,
          logicalConstraints: BoxConstraints.tight(tileSize),
          devicePixelRatio: _pixelRatio,
        ),
      );

      final pipelineOwner = PipelineOwner()..rootNode = renderView;
      final buildOwner = BuildOwner(focusManager: FocusManager());
      renderView.prepareInitialFrame();

      final element = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: _tileFrame(
          collection: collection,
          index: index,
          brightness: brightness,
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner
        ..buildScope(element)
        ..finalizeTree();
      pipelineOwner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();

      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      // A missing tile just means that collection shows as a plain chip.
      AppLogger.error('Collection tile render failed: $e');
      return null;
    }
  }

  /// Wraps the tile in the minimum the widget needs: a Directionality and the
  /// theme being rendered for. The background stays transparent so the sheet
  /// showing the tile provides its own surface.
  static Widget _tileFrame({
    required CollectionSummary collection,
    required int index,
    required Brightness brightness,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Theme(
          data: ThemeData(brightness: brightness),
          child: Builder(
            builder: (context) => Container(
              width: tileSize.width,
              height: tileSize.height,
              // Transparent, not the app background: an opaque fill is baked
              // into the PNG and shows as a box around every folder wherever
              // the sheet's own surface is even slightly different.
              color: Colors.transparent,
              padding: const EdgeInsets.all(6),
              child: CollectionFolderTile(
                collection: collection,
                index: index,
                onTap: null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Writes one PNG per collection into [directory] and returns the file name
  /// for each id. Stale files are cleared first so deleted collections do not
  /// leave artwork behind.
  static Future<Map<String, String>> writeTiles({
    required String directory,
    required List<CollectionSummary> collections,
  }) async {
    final dir = Directory(directory);
    try {
      if (dir.existsSync()) {
        for (final entry in dir.listSync()) {
          if (entry is File && entry.path.endsWith('.png')) entry.deleteSync();
        }
      } else {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Collection tile cache clear skipped: $e');
    }

    final names = <String, String>{};
    for (var index = 0; index < collections.length; index++) {
      final collection = collections[index];
      // Both themes: the native sheet picks by the device's mode, and it has
      // no Flutter engine to render one on demand.
      for (final brightness in Brightness.values) {
        final bytes = await renderTile(
          collection: collection,
          index: index,
          brightness: brightness,
        );
        if (bytes == null) continue;
        final suffix = brightness == Brightness.dark ? '_dark' : '';
        final fileName = 'collection_${collection.id}$suffix.png';
        try {
          await File('$directory/$fileName').writeAsBytes(bytes, flush: true);
          if (brightness == Brightness.light) names[collection.id] = fileName;
        } catch (e) {
          AppLogger.error('Collection tile write skipped: $e');
        }
      }
    }
    return names;
  }
}
