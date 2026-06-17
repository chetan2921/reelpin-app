import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/models/folder.dart';
import 'package:reelpin/models/reel.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/api_service.dart';
import 'package:reelpin/services/auth_service.dart';
import 'package:reelpin/services/profile_service.dart';
import 'package:reelpin/viewmodels/folders_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('createFolder stores returned folder summary', () async {
    final repository = _FakeReelRepository();
    final viewModel = FoldersViewModel(repository);

    final response = await viewModel.createFolder(
      name: 'Goa trip',
      note: 'Places',
      reelIds: const ['reel-a'],
    );

    expect(response.folder.id, 'folder-123');
    expect(viewModel.folders.single.name, 'Goa trip');
    expect(repository.createdReelIds, ['reel-a']);
  });

  test('addReelsToFolder stores returned folder summary', () async {
    final repository = _FakeReelRepository();
    final viewModel = FoldersViewModel(repository);

    final response = await viewModel.addReelsToFolder(
      folderId: 'folder-123',
      reelIds: const ['reel-b'],
    );

    expect(response.folder.id, 'folder-123');
    expect(response.folder.reelCount, 3);
    expect(viewModel.folders.single.reelCount, 3);
    expect(repository.addedFolderId, 'folder-123');
    expect(repository.addedReelIds, ['reel-b']);
  });

  test('removeReel drops stale reel from cached folder detail', () async {
    final repository = _FakeReelRepository();
    final viewModel = FoldersViewModel(repository);

    await viewModel.loadFolder('folder-123', forceRefresh: true);
    viewModel.removeReel('reel-a');

    final detail = viewModel.detailFor('folder-123');
    expect(detail?.reels.map((reel) => reel.id), ['reel-b']);
    expect(detail?.folder.reelCount, 1);
  });
}

class _FakeReelRepository extends ReelRepository {
  _FakeReelRepository()
    : super(ApiService(baseUrl: 'https://example.com'), _FakeAuthService());

  List<String> createdReelIds = [];
  String? addedFolderId;
  List<String> addedReelIds = [];

  @override
  Future<FolderMutationResponse> createFolder({
    required String name,
    String? note,
    List<String> reelIds = const [],
    bool moveExisting = false,
  }) async {
    createdReelIds = reelIds;
    return FolderMutationResponse(
      folder: FolderSummary(
        id: 'folder-123',
        name: name,
        note: note,
        reelCount: reelIds.length,
      ),
    );
  }

  @override
  Future<FolderMutationResponse> addReelsToFolder({
    required String folderId,
    required List<String> reelIds,
    bool moveExisting = false,
  }) async {
    addedFolderId = folderId;
    addedReelIds = reelIds;
    return const FolderMutationResponse(
      folder: FolderSummary(
        id: 'folder-123',
        name: 'Goa trip',
        note: 'Places',
        reelCount: 3,
      ),
    );
  }

  @override
  Future<FolderDetailResponse> getFolder(
    String folderId, {
    int? offset,
    String? cursor,
    int limit = 25,
  }) async {
    return const FolderDetailResponse(
      folder: FolderSummary(
        id: 'folder-123',
        name: 'Goa trip',
        note: 'Places',
        reelCount: 2,
      ),
      reels: [_reelA, _reelB],
      pagination: FolderPagination(hasMore: false, limit: 25, offset: 0),
    );
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> ensureProfile() async {}
}

const _reelA = Reel(
  id: 'reel-a',
  userId: 'user-123',
  url: 'https://example.com/a',
  title: 'A',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Food',
  subCategory: 'Meals',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
);

const _reelB = Reel(
  id: 'reel-b',
  userId: 'user-123',
  url: 'https://example.com/b',
  title: 'B',
  summary: '',
  caption: '',
  transcript: '',
  category: 'Travel',
  subCategory: 'Trips',
  keyFacts: [],
  locations: [],
  peopleMentioned: [],
  actionableItems: [],
);
