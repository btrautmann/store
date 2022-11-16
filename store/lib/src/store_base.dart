import 'dart:async';

import 'package:stash/stash_api.dart';
import 'package:stash_memory/stash_memory.dart';

/// A [Store] orchestrates the fetching, observation, and
/// persistence of data of type [T] keyed by keys of type [K].
class Store<K, T> {
  final Fetch<K, T> _fetch;
  final SourceOfTruth<K, T>? _sourceOfTruth;

  final Completer<void> _cacheInitialization = Completer();
  late final Cache<T> _memoryCache;

  Store._({
    required Fetch<K, T> fetch,
    SourceOfTruth<K, T>? sourceOfTruth,
  })  : _fetch = fetch,
        _sourceOfTruth = sourceOfTruth;

  /// Creates a [Store] that will use [fetch] for fetching
  /// data from the network and an optional [sourceOfTruth]
  /// for disk caching.
  factory Store.from({
    required Fetch<K, T> fetch,
    SourceOfTruth<K, T>? sourceOfTruth,
  }) {
    return Store._(
      fetch: fetch,
      sourceOfTruth: sourceOfTruth,
    );
  }

  /// Returns a [Stream] of data of type [T] based on
  /// the provided [StoreRequest].
  ///
  /// If [request.skipCache] is false and an in-memory
  /// value exists, it will be the first value emitted.
  /// If [request.refresh] is true, a fetch will be made
  /// via the provided [Fetch] provided during [Store] creation.
  ///
  /// Emissions following any cached value (based on the above
  /// logic) will always be from the provided [SourceOfTruth].
  Stream<T> stream({
    required StoreRequest<K> request,
  }) async* {
    final stringifiedKey = request.key.toString();
    if (!_cacheInitialization.isCompleted) {
      final store = await newMemoryCacheStore();
      _memoryCache = await store.cache<T>();
      _cacheInitialization.complete();
    }
    final memoryEntry = await _memoryCache.get(stringifiedKey);
    if (!request.skipCache && memoryEntry != null) {
      yield memoryEntry;
    } else if (request.refresh) {
      late StreamSubscription<T> fetchSubscription;
      fetchSubscription = _fetch(request.key).listen(
        (value) async {
          await _memoryCache.put(stringifiedKey, value);
          _sourceOfTruth?.write(request.key, value);
        },
        onDone: () => fetchSubscription.cancel(),
      );
    }
    final read = _sourceOfTruth?.read(request.key);
    if (read != null) {
      yield* read;
    }
  }

  /// Attempts to return a cached value in the following
  /// order:
  /// - In-memory cache
  /// - Disk cache via [SourceOfTruth]
  ///
  /// If a value does not exist in either of those, null
  /// will be returned.
  Future<T?> cached(K key) async {
    final value = await _memoryCache.get(key.toString());
    if (value != null) {
      return value;
    } else if (_sourceOfTruth != null) {
      return _sourceOfTruth!.read(key).first;
    }
    return null;
  }

  /// Invokes the [Fetch] provided during [Store] creation
  /// and writes the returned value to the [SourceOfTruth]
  /// if available. Lastly, it returns the fetched value.
  Future<T> refresh(K key) async {
    final value = await _fetch(key).first;
    _sourceOfTruth?.write(key, value);
    return value;
  }
}

/// Function describing a network fetch of type [T] by key [K]
typedef Fetch<K, T> = Stream<T> Function(K key);

/// The source of truth for data of type [T] keyed by [K]. This
/// defines the CRUD operations that can be performed on the underlying
/// data. Ideally, the storage mechanism that backs this should support
/// stream-based reads, which will allow [Store] to always serve the
/// latest data.
class SourceOfTruth<K, T> {
  final Read<K, T> _read;
  final Write<K, T> _write;
  final Delete<K> _delete;
  final DeleteAll _deleteAll;

  SourceOfTruth._({
    required Read<K, T> read,
    required Write<K, T> write,
    required Delete<K> delete,
    required DeleteAll deleteAll,
  })  : _read = read,
        _write = write,
        _delete = delete,
        _deleteAll = deleteAll;

  /// Creates a [SourceOfTruth] that handles CRUD
  /// operations via the provided [Read], [Write],
  /// [Delete], and [DeleteAll] functions.
  factory SourceOfTruth.of({
    required Read<K, T> read,
    required Write<K, T> write,
    required Delete<K> delete,
    required DeleteAll deleteAll,
  }) {
    return SourceOfTruth._(
      read: read,
      write: write,
      delete: delete,
      deleteAll: deleteAll,
    );
  }

  /// Returns a [Stream] of type [T] at key [K] via
  /// the [Read] function provided during [SourceOfTruth]
  /// creation.
  Stream<T> read(K key) {
    return _read(key);
  }

  /// Persists [value] at key [K] via the [Write] function
  /// provided during [SourceOfTruth] creation.
  Future<void> write(K key, T value) {
    return _write(key, value);
  }

  /// Deletes the value at key [K] via the [Delete] function
  /// provided during [SourceOfTruth] creation.
  Future<void> delete(K key) {
    return _delete(key);
  }

  /// Deletes all data associated with this [SourceOfTruth]
  Future<void> deleteAll() {
    return _deleteAll();
  }
}

/// Function describing the observation of data of type [T] at key [K]
typedef Read<K, T> = Stream<T> Function(K key);

/// Function describing the persistence of data of type [T] at key [K]
typedef Write<K, T> = Future<void> Function(K key, T value);

/// Function describing the deletion of data of type [T] at key [K]
typedef Delete<K> = Future<void> Function(K key);

/// Function describing the deletion of all data of type [T]
typedef DeleteAll = Future<void> Function();

/// A request for data at key [K] that can be issues to a [Store]
/// via the `stream` function.
class StoreRequest<K> {
  /// The key at which the data being requested resides
  final K key;

  /// Whether any cached value should be emitted on the
  /// [Store]s stream
  final bool skipCache;

  /// Whether the [Store] should attempt to refresh the
  /// data in the [SourceOfTruth] by invoking [Fetch]
  final bool refresh;

  StoreRequest._({
    required this.key,
    required this.skipCache,
    required this.refresh,
  });

  /// Creates a [StoreRequest] that indicates the desire
  /// for a fresh value at key [K], skipping any cached
  /// values.
  factory StoreRequest.fresh(K key) {
    return StoreRequest._(
      key: key,
      skipCache: true,
      refresh: true,
    );
  }

  /// Creates a [StoreRequest] that indicates the desire
  /// for a cached value at key [K]. Optionally, [refresh]
  /// can be set to true indicating that [Fetch] should be
  /// invoked to update the [SourceOfTruth].
  factory StoreRequest.cached({
    required K key,
    bool? refresh,
  }) {
    return StoreRequest._(
      key: key,
      skipCache: false,
      refresh: refresh ?? false,
    );
  }
}
