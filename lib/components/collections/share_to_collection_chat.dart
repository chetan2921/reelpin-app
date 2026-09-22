import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/components/collections/pick_collection_sheet.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/providers.dart';

/// What "+ COLLECTION" on an answer does: puts the answer, exactly as it
/// stands, into the chat of one or more collections the user picks.
///
/// Shared by the private chat and a collection's own chat, which is how an
/// answer moves on from one collection to another. No re-ask: everyone sees
/// the answer the sharer saw. The private question that produced it is never
/// sent — only the answer is shared, and only who shared it is shown.
Future<void> shareToCollectionChat(
  BuildContext context,
  WidgetRef ref, {
  required List<AnswerBlock> blocks,
  String? excludeCollectionId,
}) async {
  final collections = await showPickCollectionSheet(
    context,
    excludeCollectionId: excludeCollectionId,
  );
  if (collections == null || collections.isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final http = ref.read(collectionChatHttpProvider);
  final collectionsVm = ref.read(collectionsViewModelProvider);

  // Each share starts its own conversation in the collection, titled by the
  // answer, so it shows in the ASK screen's sidebar rather than landing in
  // the middle of someone else's thread.
  final threadId = 'shared-${DateTime.now().microsecondsSinceEpoch}';
  final succeeded = <String>[];
  final failed = <String>[];
  for (final collection in collections) {
    try {
      // Straight to the seam rather than through a collection's view model:
      // that one lives and dies with the collection screen, and nothing is
      // watching it from here. Empty question text: the private question
      // that produced this answer was never asked here and stays private.
      await http.shareAnswer(
        collectionId: collection.id,
        threadId: threadId,
        questionText: '',
        blocks: blocks,
      );
      // Same jump to the top of the list an added reel gets, since sharing
      // into a collection's chat doesn't otherwise refetch it.
      collectionsVm.bumpToFront(collection.id);
      succeeded.add(collection.name);
    } catch (_) {
      failed.add(collection.name);
    }
  }

  if (succeeded.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          succeeded.length == 1
              ? 'Added to ${succeeded.single}.'
              : 'Added to ${succeeded.length} collections.',
        ),
      ),
    );
  }
  if (failed.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not add to ${failed.join(', ')}.')),
    );
  }
}
