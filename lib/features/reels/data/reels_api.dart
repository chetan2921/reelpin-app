import 'dart:io';

import 'package:reelpin/features/reels/domain/processing_job.dart';
import 'package:reelpin/features/reels/domain/reel.dart';
import 'package:reelpin/features/reels/domain/reel_category_filters.dart';
import 'package:reelpin/features/reels/domain/reel_page.dart';

abstract interface class ReelsApi {
  Future<Reel> processReel(
    String url, {
    String userId = 'default-user',
    void Function(ProcessingJob job)? onJobUpdate,
  });

  Future<ProcessingJob> enqueueReelProcessing(
    String url, {
    String userId = 'default-user',
  });

  Future<Reel> processVideo(
    File videoFile, {
    String userId = 'default-user',
    String url = '',
  });

  Future<ReelPage> getReelsPage({
    String? userId,
    String? category,
    String? subcategory,
    String? savedDate,
    int? offset,
    String? cursor,
    int limit = 50,
    String? sort,
  });

  Future<List<Reel>> getReels({
    String? userId,
    String? category,
    String? subcategory,
    String? savedDate,
    int limit = 50,
  });

  Future<Reel> getReel(String reelId);

  Future<void> deleteReel(String reelId);

  Future<ReelCategoryFiltersResponse> getReelCategoryFilters({
    String? userId,
    String? category,
    String? subcategory,
  });
}
