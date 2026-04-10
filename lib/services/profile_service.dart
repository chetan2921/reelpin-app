import 'supabase_client.dart';

class ProfileService {
  Future<void> upsertProfile({
    required String id,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{
      'id': id,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (fullName != null && fullName.trim().isNotEmpty)
        'full_name': fullName.trim(),
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        'avatar_url': avatarUrl.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await supabase.from('profiles').upsert(payload, onConflict: 'id');
  }
}
