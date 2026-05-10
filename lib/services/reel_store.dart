import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/reel.dart';
import 'supabase_client.dart';

class ReelPage {
  const ReelPage({
    required this.reels,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<Reel> reels;
  final int nextOffset;
  final bool hasMore;
}

class ReelCacheSnapshot {
  const ReelCacheSnapshot({
    required this.reels,
    required this.nextOffset,
    required this.hasMore,
    required this.lastFetchedAt,
  });

  final List<Reel> reels;
  final int nextOffset;
  final bool hasMore;
  final DateTime? lastFetchedAt;
}

class ReelStore {
  static const _cacheLimit = 1000;
  static const _databaseName = 'reelpin_cache.db';
  static const _databaseVersion = 3;
  static const _cacheMetadataTable = 'reel_cache_metadata';
  static const _cacheEntriesTable = 'reel_cache_entries';
  static const _cacheSearchTable = 'reel_cache_search';
  static const _offlineSearchCandidateLimit = 48;
  static const _optimizeEveryWrites = 8;
  static const _checkpointEveryWrites = 24;

  static bool _sqliteFactoryConfigured = false;

  Future<Database>? _databaseFuture;
  Future<void>? _maintenanceFuture;
  bool _maintenanceQueued = false;
  int _writesSinceOptimize = 0;
  int _writesSinceCheckpoint = 0;

  static Future<void> configureDatabaseFactory() async {
    if (_sqliteFactoryConfigured || kIsWeb) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _sqliteFactoryConfigured = true;
  }

  bool get _supportsSqliteCache =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  Future<ReelPage> fetchReelsPage({
    required String userId,
    String? category,
    int limit = 25,
    int offset = 0,
  }) async {
    dynamic query = supabase.from('reels').select().eq('user_id', userId);

    if (category != null && category.trim().isNotEmpty) {
      query = query.eq('category', category.trim());
    }

    final rows = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit)
        as List<dynamic>;
    final hasMore = rows.length > limit;
    final visibleRows = hasMore ? rows.take(limit) : rows;
    final reels = visibleRows
        .map((row) => Reel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);

    return ReelPage(
      reels: reels,
      nextOffset: offset + reels.length,
      hasMore: hasMore,
    );
  }

  Future<ReelCacheSnapshot?> loadCachedReels({
    required String userId,
  }) async {
    if (!_supportsSqliteCache) {
      return _loadLegacySharedPreferencesCache(userId);
    }

    final db = await _database;
    final sqliteSnapshot = await _readSnapshot(db, userId);
    if (sqliteSnapshot != null) {
      return sqliteSnapshot;
    }

    return _migrateLegacySharedPreferencesCache(db, userId);
  }

  Future<void> saveCachedReels({
    required String userId,
    required List<Reel> reels,
    required int nextOffset,
    required bool hasMore,
    required DateTime lastFetchedAt,
  }) async {
    if (!_supportsSqliteCache) {
      return _saveLegacySharedPreferencesCache(
        userId: userId,
        reels: reels,
        nextOffset: nextOffset,
        hasMore: hasMore,
        lastFetchedAt: lastFetchedAt,
      );
    }

    final db = await _database;
    final boundedReels = reels.take(_cacheLimit).toList(growable: false);
    await db.transaction((txn) async {
      await txn.delete(
        _cacheEntriesTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        _cacheSearchTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final batch = txn.batch();
      batch.insert(_cacheMetadataTable, {
        'user_id': userId,
        'next_offset': nextOffset,
        'has_more': hasMore ? 1 : 0,
        'last_fetched_at': lastFetchedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var index = 0; index < boundedReels.length; index++) {
        batch.insert(_cacheEntriesTable, {
          'user_id': userId,
          'reel_id': boundedReels[index].id,
          'sort_index': index,
          'category': boundedReels[index].category,
          'subcategory': boundedReels[index].subCategory,
          'created_at': boundedReels[index].createdAt,
          'payload': jsonEncode(boundedReels[index].toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        batch.insert(
          _cacheSearchTable,
          _searchRowFor(userId, boundedReels[index]),
        );
      }

      await batch.commit(noResult: true);
    });
    _registerSqliteWrite();
    await _clearLegacySharedPreferencesCache(userId);
  }

  Future<void> cacheReel({
    required String userId,
    required Reel reel,
  }) async {
    final snapshot = await loadCachedReels(userId: userId);
    final next = <Reel>[
      reel,
      ...(snapshot?.reels ?? const <Reel>[]).where(
        (existing) => existing.id != reel.id,
      ),
    ];
    await saveCachedReels(
      userId: userId,
      reels: next,
      nextOffset: snapshot == null ? 1 : snapshot.nextOffset,
      hasMore: snapshot?.hasMore ?? false,
      lastFetchedAt: snapshot?.lastFetchedAt ?? DateTime.now(),
    );
  }

  Future<void> removeCachedReel({
    required String userId,
    required String reelId,
  }) async {
    final snapshot = await loadCachedReels(userId: userId);
    if (snapshot == null) return;

    await saveCachedReels(
      userId: userId,
      reels: snapshot.reels.where((reel) => reel.id != reelId).toList(),
      nextOffset: snapshot.nextOffset > 0 ? snapshot.nextOffset - 1 : 0,
      hasMore: snapshot.hasMore,
      lastFetchedAt: snapshot.lastFetchedAt ?? DateTime.now(),
    );
  }

  Future<void> clearCachedReels({required String userId}) async {
    if (!_supportsSqliteCache) {
      return _clearLegacySharedPreferencesCache(userId);
    }

    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        _cacheEntriesTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        _cacheSearchTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        _cacheMetadataTable,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
    _registerSqliteWrite();
    await _clearLegacySharedPreferencesCache(userId);
  }

  Future<Database> get _database {
    final future = _databaseFuture;
    if (future != null) {
      return future;
    }

    final createdFuture = _openDatabase();
    _databaseFuture = createdFuture;
    return createdFuture;
  }

  Future<Database> _openDatabase() async {
    await configureDatabaseFactory();
    final databasesDirectory = await getDatabasesPath();
    final databasePath = '$databasesDirectory/$_databaseName';
    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeSchemaToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeSchemaToV3(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cacheMetadataTable (
        user_id TEXT PRIMARY KEY,
        next_offset INTEGER NOT NULL,
        has_more INTEGER NOT NULL,
        last_fetched_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cacheEntriesTable (
        user_id TEXT NOT NULL,
        reel_id TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        category TEXT,
        subcategory TEXT,
        created_at TEXT,
        payload TEXT NOT NULL,
        PRIMARY KEY (user_id, reel_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reel_cache_entries_user_sort
      ON $_cacheEntriesTable(user_id, sort_index)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reel_cache_entries_filters
      ON $_cacheEntriesTable(user_id, category, subcategory, sort_index)
    ''');
    await _createSearchTable(db);
  }

  Future<void> _upgradeSchemaToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cacheMetadataTable (
        user_id TEXT PRIMARY KEY,
        next_offset INTEGER NOT NULL,
        has_more INTEGER NOT NULL,
        last_fetched_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_cacheEntriesTable (
        user_id TEXT NOT NULL,
        reel_id TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        category TEXT,
        subcategory TEXT,
        created_at TEXT,
        payload TEXT NOT NULL,
        PRIMARY KEY (user_id, reel_id)
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info($_cacheEntriesTable)');
    final columnNames = columns
        .map((column) => column['name'] as String? ?? '')
        .toSet();
    if (!columnNames.contains('category')) {
      await db.execute(
        'ALTER TABLE $_cacheEntriesTable ADD COLUMN category TEXT',
      );
    }
    if (!columnNames.contains('subcategory')) {
      await db.execute(
        'ALTER TABLE $_cacheEntriesTable ADD COLUMN subcategory TEXT',
      );
    }
    if (!columnNames.contains('created_at')) {
      await db.execute(
        'ALTER TABLE $_cacheEntriesTable ADD COLUMN created_at TEXT',
      );
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reel_cache_entries_user_sort
      ON $_cacheEntriesTable(user_id, sort_index)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reel_cache_entries_filters
      ON $_cacheEntriesTable(user_id, category, subcategory, sort_index)
    ''');
    await _createSearchTable(db);
    await _reindexSearchTable(db);
  }

  Future<void> _upgradeSchemaToV3(Database db) async {
    await db.execute('DROP TABLE IF EXISTS $_cacheSearchTable');
    await _createSearchTable(db);
    await _reindexSearchTable(db);
  }

  Future<ReelCacheSnapshot?> _readSnapshot(
    DatabaseExecutor db,
    String userId,
  ) async {
    final metadataRows = await db.query(
      _cacheMetadataTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (metadataRows.isEmpty) {
      return null;
    }

    try {
      final metadata = metadataRows.first;
      final entryRows = await db.query(
        _cacheEntriesTable,
        columns: ['payload'],
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'sort_index ASC',
      );
      final reels = entryRows
          .map(
            (row) => Reel.fromJson(
              jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);

      return ReelCacheSnapshot(
        reels: reels,
        nextOffset: (metadata['next_offset'] as num?)?.toInt() ?? reels.length,
        hasMore: (metadata['has_more'] as num?)?.toInt() == 1,
        lastFetchedAt: (metadata['last_fetched_at'] as String?) == null
            ? null
            : DateTime.tryParse(metadata['last_fetched_at'] as String),
      );
    } catch (_) {
      await clearCachedReels(userId: userId);
      return null;
    }
  }

  Future<List<Reel>> searchCachedReels({
    required String userId,
    required String query,
    String? category,
    String? subcategory,
    int limit = _offlineSearchCandidateLimit,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    if (!_supportsSqliteCache) {
      final snapshot = await loadCachedReels(userId: userId);
      if (snapshot == null) {
        return const [];
      }
      return _filterReels(
        snapshot.reels,
        category: category,
        subcategory: subcategory,
      ).take(limit).toList(growable: false);
    }

    final tokens = _ftsTokens(normalizedQuery);
    if (tokens.isEmpty) {
      return const [];
    }

    final db = await _database;
    final args = <Object?>[_ftsMatchQuery(tokens), userId];
    final filters = <String>['$_cacheSearchTable MATCH ?', 'e.user_id = ?'];
    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      filters.add('e.category = ?');
      args.add(normalizedCategory);
    }
    final normalizedSubcategory = subcategory?.trim();
    if (normalizedSubcategory != null && normalizedSubcategory.isNotEmpty) {
      filters.add('e.subcategory = ?');
      args.add(normalizedSubcategory);
    }
    args.add(limit);

    final rows = await db.rawQuery(
      '''
      SELECT e.payload
      FROM $_cacheSearchTable
      INNER JOIN $_cacheEntriesTable e
        ON e.user_id = $_cacheSearchTable.user_id
       AND e.reel_id = $_cacheSearchTable.reel_id
      WHERE ${filters.join(' AND ')}
      ORDER BY e.sort_index ASC
      LIMIT ?
      ''',
      args,
    );

    return rows
        .map(
          (row) => Reel.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<ReelCacheSnapshot?> _migrateLegacySharedPreferencesCache(
    DatabaseExecutor db,
    String userId,
  ) async {
    final legacySnapshot = await _loadLegacySharedPreferencesCache(userId);
    if (legacySnapshot == null) {
      return null;
    }

    final boundedReels = legacySnapshot.reels
        .take(_cacheLimit)
        .toList(growable: false);
    final batch = db.batch();
    batch.insert(_cacheMetadataTable, {
      'user_id': userId,
      'next_offset': legacySnapshot.nextOffset,
      'has_more': legacySnapshot.hasMore ? 1 : 0,
      'last_fetched_at': legacySnapshot.lastFetchedAt?.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (var index = 0; index < boundedReels.length; index++) {
      batch.insert(_cacheEntriesTable, {
        'user_id': userId,
        'reel_id': boundedReels[index].id,
        'sort_index': index,
        'category': boundedReels[index].category,
        'subcategory': boundedReels[index].subCategory,
        'created_at': boundedReels[index].createdAt,
        'payload': jsonEncode(boundedReels[index].toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      batch.insert(
        _cacheSearchTable,
        _searchRowFor(userId, boundedReels[index]),
      );
    }
    await batch.commit(noResult: true);
    await _clearLegacySharedPreferencesCache(userId);
    return legacySnapshot;
  }

  Future<ReelCacheSnapshot?> _loadLegacySharedPreferencesCache(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cachePayload = prefs.getString(_legacyCachePayloadKey(userId));
    if (cachePayload == null || cachePayload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(cachePayload) as Map<String, dynamic>;
      final rawReels = decoded['reels'];
      final reels = rawReels is List
          ? rawReels
                .map(
                  (row) => Reel.fromJson(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList(growable: false)
          : const <Reel>[];
      final nextOffset =
          (decoded['next_offset'] as num?)?.toInt() ?? reels.length;
      final hasMore = decoded['has_more'] as bool? ?? false;
      final lastFetchedAtRaw = decoded['last_fetched_at'] as String?;

      return ReelCacheSnapshot(
        reels: reels,
        nextOffset: nextOffset,
        hasMore: hasMore,
        lastFetchedAt: lastFetchedAtRaw == null || lastFetchedAtRaw.isEmpty
            ? null
            : DateTime.tryParse(lastFetchedAtRaw),
      );
    } catch (_) {
      await prefs.remove(_legacyCachePayloadKey(userId));
      return null;
    }
  }

  Future<void> _saveLegacySharedPreferencesCache({
    required String userId,
    required List<Reel> reels,
    required int nextOffset,
    required bool hasMore,
    required DateTime lastFetchedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final boundedReels = reels.take(_cacheLimit).map((reel) => reel.toJson()).toList();
    final payload = jsonEncode({
      'reels': boundedReels,
      'next_offset': nextOffset,
      'has_more': hasMore,
      'last_fetched_at': lastFetchedAt.toUtc().toIso8601String(),
    });
    await prefs.setString(_legacyCachePayloadKey(userId), payload);
  }

  Future<void> _clearLegacySharedPreferencesCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyCachePayloadKey(userId));
  }

  List<Reel> _filterReels(
    List<Reel> reels, {
    String? category,
    String? subcategory,
  }) {
    final normalizedCategory = category?.trim().toLowerCase();
    final normalizedSubcategory = subcategory?.trim().toLowerCase();
    return reels.where((reel) {
      if (normalizedCategory != null &&
          normalizedCategory.isNotEmpty &&
          reel.category.trim().toLowerCase() != normalizedCategory) {
        return false;
      }
      if (normalizedSubcategory != null &&
          normalizedSubcategory.isNotEmpty &&
          reel.subCategory.trim().toLowerCase() != normalizedSubcategory) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Map<String, Object?> _searchRowFor(String userId, Reel reel) {
    return {
      'user_id': userId,
      'reel_id': reel.id,
      'title': reel.title,
      'summary': reel.summary,
      'caption': reel.caption,
      'transcript': reel.transcript,
      'category': reel.category,
      'subcategory': reel.subCategory,
      'key_facts': reel.keyFacts.join(' '),
      'people': reel.peopleMentioned.join(' '),
      'actions': reel.actionableItems.join(' '),
      'locations': reel.locations
          .expand((location) => [location.name, location.address ?? ''])
          .where((part) => part.trim().isNotEmpty)
          .join(' '),
    };
  }

  List<String> _ftsTokens(String query) {
    return RegExp(r'[a-z0-9]+')
        .allMatches(query.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }

  String _ftsMatchQuery(List<String> tokens) {
    return tokens.map((token) => '$token*').join(' AND ');
  }

  void _registerSqliteWrite() {
    _writesSinceOptimize += 1;
    _writesSinceCheckpoint += 1;
    _scheduleMaintenance();
  }

  void _scheduleMaintenance() {
    if (!_supportsSqliteCache) {
      return;
    }
    if (_maintenanceFuture != null) {
      _maintenanceQueued = true;
      return;
    }

    final future = _runMaintenance();
    _maintenanceFuture = future;
    unawaited(
      future.whenComplete(() {
        _maintenanceFuture = null;
        if (_maintenanceQueued) {
          _maintenanceQueued = false;
          _scheduleMaintenance();
        }
      }),
    );
  }

  Future<void> _runMaintenance() async {
    final shouldOptimize = _writesSinceOptimize >= _optimizeEveryWrites;
    final shouldCheckpoint = _writesSinceCheckpoint >= _checkpointEveryWrites;
    if (!shouldOptimize && !shouldCheckpoint) {
      return;
    }

    final db = await _database;
    if (shouldOptimize) {
      _writesSinceOptimize = 0;
      await _optimizeSearchIndex(db);
    }
    if (shouldCheckpoint) {
      _writesSinceCheckpoint = 0;
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    }
  }

  Future<void> _optimizeSearchIndex(Database db) async {
    await db.transaction((txn) async {
      final userRows = await txn.query(
        _cacheMetadataTable,
        columns: ['user_id'],
      );
      for (final row in userRows) {
        final userId = row['user_id'] as String? ?? '';
        if (userId.isEmpty) {
          continue;
        }

        final retainedRows = await txn.query(
          _cacheEntriesTable,
          columns: ['reel_id'],
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'sort_index ASC',
          limit: _cacheLimit,
        );
        if (retainedRows.isEmpty) {
          await txn.delete(
            _cacheSearchTable,
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          continue;
        }

        final retainedIds = retainedRows
            .map((entry) => entry['reel_id'] as String? ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        final placeholderCount = math.max(retainedIds.length, 1);
        final placeholders = List.filled(placeholderCount, '?').join(', ');
        final whereClause =
            'user_id = ? AND reel_id NOT IN ($placeholders)';
        final whereArgs = <Object?>[userId, ...retainedIds];

        await txn.delete(
          _cacheEntriesTable,
          where: whereClause,
          whereArgs: whereArgs,
        );
        await txn.delete(
          _cacheSearchTable,
          where: whereClause,
          whereArgs: whereArgs,
        );
      }
    });

    await db.execute(
      "INSERT INTO $_cacheSearchTable($_cacheSearchTable) VALUES('optimize')",
    );
  }

  Future<void> _createSearchTable(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS $_cacheSearchTable
      USING fts4(
        user_id,
        reel_id,
        title,
        summary,
        caption,
        transcript,
        category,
        subcategory,
        key_facts,
        people,
        actions,
        locations
      )
    ''');
  }

  Future<void> _reindexSearchTable(Database db) async {
    final rows = await db.query(
      _cacheEntriesTable,
      columns: ['user_id', 'reel_id', 'payload'],
    );
    await db.delete(_cacheSearchTable);

    final batch = db.batch();
    for (final row in rows) {
      try {
        final reel = Reel.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        );
        final userId = row['user_id'] as String? ?? '';
        final reelId = row['reel_id'] as String? ?? '';
        if (userId.isEmpty || reelId.isEmpty) {
          continue;
        }

        batch.update(
          _cacheEntriesTable,
          {
            'category': reel.category,
            'subcategory': reel.subCategory,
            'created_at': reel.createdAt,
          },
          where: 'user_id = ? AND reel_id = ?',
          whereArgs: [userId, reelId],
        );
        batch.insert(_cacheSearchTable, _searchRowFor(userId, reel));
      } catch (_) {
        // Invalid cached rows are dropped on the next fetch.
      }
    }
    await batch.commit(noResult: true);
  }

  String _legacyCachePayloadKey(String userId) => 'reel_store_cache_$userId';

  @Deprecated('Use fetchReelsPage instead.')
  Future<List<Reel>> fetchReels({
    required String userId,
    String? category,
    int limit = 50,
  }) async {
    final page = await fetchReelsPage(
      userId: userId,
      category: category,
      limit: limit,
      offset: 0,
    );

    return page.reels;
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
