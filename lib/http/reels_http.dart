import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/data_models/reels/reel_filters.dart';
import 'package:reelpin/data_models/reels/reel_page.dart';

abstract interface class ReelsHttp {
  Future<Reel> processReel(
    String url, {
    String userId = 'default-user',
    void Function(ProcessingJob job)? onJobUpdate,
  });

  /// A link whose reel is already ready comes back as a completed job carrying
  /// the reel, with no id, because there is nothing to poll.
  Future<ProcessingJob> enqueueReelProcessing(
    String url, {
    String userId = 'default-user',
    List<String> collectionIds = const [],
  });

  /// Jobs the backend is still working on for the signed-in user. Used to show
  /// a placeholder card for a share that was queued while the app was closed.
  Future<List<ProcessingJob>> listProcessingJobs({
    bool activeOnly = true,
    int limit = 20,
  });

  Future<ReelPage> getReelsPage({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    String? cursor,
    int limit = 50,
  });

  Future<List<Reel>> getReels({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
    String? savedDate,
    int limit = 50,
  });

  Future<Reel> getReel(String reelId);

  Future<void> deleteReel(String reelId);

  /// Returns the whole platform → category → subcategory facet tree. The
  /// parameters do not prune the tree; they only resolve
  /// `selected_preview_count` for the combination the user is about to apply.
  Future<ReelFiltersResponse> getReelFilters({
    String? userId,
    String? platform,
    String? category,
    String? subcategory,
  });
}
