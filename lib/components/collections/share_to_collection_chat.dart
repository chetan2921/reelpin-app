import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reelpin/components/collections/pick_collection_sheet.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/utils/error_message.dart';

/// What "+ COLLECTION" on an answer does: puts the answer at [index], exactly
/// as it stands, into the chat of a collection the user picks.
///
/// Shared by the private chat and a collection's own chat, which is how an
/// answer moves on from one collection to another. No re-ask: everyone sees
/// the answer the sharer saw. It travels with the question that produced it,
/// so the thread it lands in reads as a conversation rather than loose
/// answers.
Future<void> shareToCollectionChat(
  BuildContext context,
  WidgetRef ref, {
  required List<ChatMessage> messages,
  required int index,
  String? excludeCollectionId,
}) async {
  final collection = await showPickCollectionSheet(
    context,
    excludeCollectionId: excludeCollectionId,
  );
  if (collection == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  var question = '';
  for (var i = index - 1; i >= 0; i--) {
    if (messages[i].role == MessageRole.user) {
      question = messages[i].text;
      break;
    }
  }

  try {
    // Straight to the seam rather than through a collection's view model:
    // that one lives and dies with the collection screen, and nothing is
    // watching it from here.
    await ref
        .read(collectionChatHttpProvider)
        .shareAnswer(
          collectionId: collection.id,
          questionText: question,
          blocks: messages[index].blocks,
        );
    messenger.showSnackBar(
      SnackBar(content: Text('Added to ${collection.name}.')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          userFacingErrorMessage(
            e,
            fallbackMessage: 'Could not add it to that collection.',
          ),
        ),
      ),
    );
  }
}
