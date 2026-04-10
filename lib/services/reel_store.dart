import '../models/reel.dart';
import 'supabase_client.dart';

class ReelStore {
  Future<List<Reel>> fetchReels({
    required String userId,
    String? category,
    int limit = 50,
  }) async {
    dynamic query = supabase.from('reels').select().eq('user_id', userId);

    if (category != null && category.trim().isNotEmpty) {
      query = query.eq('category', category.trim());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit)
        as List<dynamic>;

    return rows
        .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Reel> fetchReel({
    required String reelId,
    required String userId,
  }) async {
    final row = await supabase
        .from('reels')
        .select()
        .eq('id', reelId)
        .eq('user_id', userId)
        .single();

    return Reel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteReel({
    required String reelId,
    required String userId,
  }) async {
    await supabase
        .from('reels')
        .delete()
        .eq('id', reelId)
        .eq('user_id', userId);
  }
}
