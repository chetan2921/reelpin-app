import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/reels/processing_job.dart';
import 'package:reelpin/data_models/reels/reel.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/repositories/reel_repository.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/view_models/processing_jobs_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ProcessingJob _job(
  String id, {
  String status = 'processing',
  bool terminal = false,
  int? progress,
  Reel? reel,
  List<String> collectionIds = const [],
}) {
  return ProcessingJob(
    id: id,
    status: status,
    terminal: terminal,
    progressPercent: progress,
    collectionIds: collectionIds,
    reel: reel,
  );
}

Reel _reel(String id) => Reel(
  id: id,
  userId: 'user-1',
  url: 'https://example.com/$id',
  title: 'Saved $id',
  summary: '',
  caption: '',
  transcript: '',
  category: '',
  subCategory: '',
  keyFacts: const [],
  locations: const [],
  peopleMentioned: const [],
  actionableItems: const [],
);

void main() {
  late _FakeRepository repository;
  late ProcessingJobsViewModel vm;
  var completions = 0;
  late List<Reel> delivered;
  late Completer<void> reload;

  setUp(() {
    completions = 0;
    delivered = [];
    reload = Completer<void>()..complete();
    repository = _FakeRepository();
    vm = ProcessingJobsViewModel(
      repository,
      onJobsFinished: (readyReels) {
        completions += 1;
        delivered.addAll(readyReels);
        return reload.future;
      },
    );
  });

  tearDown(() => vm.dispose());

  test('an enqueued job becomes a card immediately', () {
    vm.trackEnqueued(_job('job-1'));

    expect(vm.jobs.map((j) => j.id), ['job-1']);
    expect(vm.hasJobs, isTrue);
  });

  test('a re-share that came back already done gets no card', () {
    vm.trackEnqueued(_job('job-1', status: 'completed', terminal: true));

    expect(vm.jobs, isEmpty);
  });

  test('the same job enqueued twice holds one card', () {
    vm.trackEnqueued(_job('job-1'));
    vm.trackEnqueued(_job('job-1', progress: 40));

    expect(vm.jobs.length, 1);
    expect(vm.jobs.single.progressPercent, 40);
  });

  test('a job that finishes leaves the grid and asks for a reload', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [_job('job-1', status: 'completed', terminal: true)];

    await vm.refresh();

    expect(vm.jobs, isEmpty);
    expect(completions, 1);
  });

  test('a job that failed leaves quietly, with no reload', () async {
    vm.trackEnqueued(_job('job-1'));
    // The card must not claim a reel arrived when the worker gave up on it.
    repository.jobs = [_job('job-1', status: 'failed', terminal: true)];

    await vm.refresh();

    expect(vm.jobs, isEmpty);
    expect(completions, 0);
  });

  test('a job aged out of the window is treated as finished', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = const [];

    await vm.refresh();

    expect(vm.jobs, isEmpty);
    expect(completions, 1);
  });

  test('refresh recovers jobs queued while the app was closed', () async {
    repository.jobs = [_job('job-9', progress: 30)];

    await vm.refresh();

    expect(vm.jobs.single.id, 'job-9');
  });

  test('terminal jobs from the server are never shown', () async {
    repository.jobs = [
      _job('done', status: 'completed', terminal: true),
      _job('live'),
    ];

    await vm.refresh();

    expect(vm.jobs.map((j) => j.id), ['live']);
  });

  test('a failed poll leaves the cards already on screen alone', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.shouldThrow = true;

    await vm.refresh();

    expect(vm.jobs.single.id, 'job-1');
    expect(completions, 0);
  });

  test('a job recovered from the backend knows its collection', () async {
    // Queued by the share extension with the app closed: this install never
    // saw the target, so the card can only be placed from what the API says.
    repository.jobs = [_job('job-9', collectionIds: ['col-a'])];

    await vm.refresh();

    expect(vm.jobsForCollection('col-a').map((j) => j.id), ['job-9']);
    expect(vm.jobsForCollection('col-b'), isEmpty);
  });

  test('a job with no collections belongs to none', () async {
    repository.jobs = [_job('job-9')];

    await vm.refresh();

    expect(vm.jobsForCollection('col-a'), isEmpty);
  });

  test('an API without collection_ids falls back to the enqueue targets', () {
    // Older deployment: the response carries no targets, so the only thing to
    // go on is what this install passed when it enqueued.
    vm.trackEnqueued(_job('job-1'), collectionIds: ['col-a']);
    vm.trackEnqueued(_job('job-2'));

    expect(vm.jobsForCollection('col-a').map((j) => j.id), ['job-1']);
    expect(vm.jobsForCollection('col-b'), isEmpty);
  });

  test('the card holds its place until the real reel is loaded', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [_job('job-1', status: 'completed', terminal: true)];
    // A reload that has not landed yet: this is the window where the card used
    // to vanish and leave a hole the user had to pull to fill.
    reload = Completer<void>();

    final pending = vm.refresh();
    await pumpEventQueue();

    expect(vm.jobs.single.id, 'job-1');
    expect(vm.isSettling('job-1'), isTrue);

    reload.complete();
    await pending;

    expect(vm.jobs, isEmpty);
    expect(vm.isSettling('job-1'), isFalse);
  });

  test('a card left settling stops the polling', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [_job('job-1', status: 'completed', terminal: true)];
    reload = Completer<void>();

    final pending = vm.refresh();
    await pumpEventQueue();
    repository.calls = 0;

    // Nothing left to ask about: the only card on screen is waiting on the
    // reload, not on the backend.
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(repository.calls, 0);

    reload.complete();
    await pending;
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('a failure still leaves without waiting on a reload', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [_job('job-1', status: 'failed', terminal: true)];
    reload = Completer<void>();

    await vm.refresh();

    expect(vm.jobs, isEmpty);
    expect(completions, 0);
  });

  test('a finished job hands over the reel it already carries', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [
      _job('job-1', status: 'completed', terminal: true, reel: _reel('reel-1')),
    ];

    await vm.refresh();

    // The whole point: no second request, the swap uses what the poll returned.
    expect(delivered.map((r) => r.id), ['reel-1']);
    expect(vm.jobs, isEmpty);
  });

  test('a finish with no reel attached asks for a reload instead', () async {
    vm.trackEnqueued(_job('job-1'));
    repository.jobs = [_job('job-1', status: 'completed', terminal: true)];

    await vm.refresh();

    expect(delivered, isEmpty);
    expect(completions, 1);
  });

  test('signing out clears the cards', () {
    vm.trackEnqueued(_job('job-1'), collectionIds: ['col-a']);

    vm.reset();

    expect(vm.jobs, isEmpty);
    expect(vm.jobsForCollection('col-a'), isEmpty);
  });
}

class _FakeRepository extends ReelRepository {
  _FakeRepository() : super(_FakeApiService(), _FakeAuthService());

  List<ProcessingJob> jobs = const [];
  bool shouldThrow = false;
  int calls = 0;

  @override
  Future<List<ProcessingJob>> listProcessingJobs({int limit = 20}) async {
    calls += 1;
    if (shouldThrow) throw Exception('offline');
    return jobs;
  }
}

class _FakeApiService extends ApiClient {
  _FakeApiService() : super(baseUrl: 'https://example.com');
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
