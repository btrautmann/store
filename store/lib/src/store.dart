import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:stash/stash_api.dart';
import 'package:stash_memory/stash_memory.dart';

import 'fetch_manager.dart';
import 'source_of_truth.dart';
import 'store_request.dart';
import 'store_response.dart';

/// A [Store] orchestrates the fetching, observation, and
/// persistence of data of type [T] keyed by keys of type [K].
class Store<K extends Object, T extends Object?> {
  final SourceOfTruth<K, T>? _sourceOfTruth;
  final FetchManager<K, T> _fetchManager;

  final Completer<void> _cacheInitialization = Completer();
  late final Cache<T> _memoryCache;

  Store._({
    required Fetch<K, T> fetch,
    SourceOfTruth<K, T>? sourceOfTruth,
  })  : _fetchManager = FetchManager(fetch: fetch),
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
  /// If [request.fresh] is true, a fetch will be made
  /// via the provided [Fetch] provided during [Store] creation.
  ///
  /// Emissions following any cached value (based on the above
  /// logic) will always be from the provided [SourceOfTruth].
  Stream<StoreResponse<T>> stream({
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
      yield Data(value: memoryEntry, source: Source.cache);
    }

    Stream<StoreResponse<T>> mergeSourceOfTruthAndFetch() {
      final sourceOfTruthStream = _sourceOfTruth
          ?.read(request.key)
          .map(
            (v) => Data(
              value: v,
              source: Source.sourceOfTruth,
            ),
          )
          .doOnData((data) async {
        await _memoryCache.put(stringifiedKey, data.value);
      }).doOnDone(() {
        print('Store: sourceOfTruthStream finished.');
      });
      final fetchStream = _fetchManager.fetch(request.key).doOnData(
        (data) async {
          if (data is Data) {
            final value = (data as Data<T>).value;
            await _memoryCache.put(stringifiedKey, value);
            if (_sourceOfTruth != null) {
              _sourceOfTruth!.write(request.key, value);
            }
          }
        },
      ).doOnDone(() {
        print('Store: fetchStream finished.');
      });
      return Rx.merge([
        if (sourceOfTruthStream != null) sourceOfTruthStream,
        if (request.refresh) fetchStream,
      ]);
    }

    yield* mergeSourceOfTruthAndFetch().doOnDone(() {
      print('Store: sourceOfTruthAndFetchStream finished.');
    });
  }

  /// Attempts to return a cached value in the following
  /// order:
  /// - In-memory cache
  /// - Disk cache via [SourceOfTruth]
  ///
  /// If a value does not exist in either of those, null
  /// will be returned.
  Future<StoreResponse<T?>> cached(K key) async {
    return stream(request: StoreRequest.cached(key: key)).firstWhere(
      (element) =>
          element is Data<T> &&
          (element.source == Source.cache ||
              element.source == Source.sourceOfTruth),
    );
  }

  /// Invokes the [Fetch] provided during [Store] creation
  /// and writes the returned value to the [SourceOfTruth]
  /// if available. Lastly, it returns the fetched value.
  Future<StoreResponse<T>> fresh(K key) async {
    final value = await stream(request: StoreRequest.fresh(key)).firstWhere(
      (element) => element is Data<T> && element.source == Source.fetch,
    );
    return value;
  }

  /// Invalidates the in-memory cache at [K] and
  /// deletes data at [K] from the [SourceOfTruth]
  Future<void> clear(K key) async {
    await _memoryCache.remove(key.toString());
    await _sourceOfTruth?.delete(key);
  }

  /// Invalidates the entire in-memorty cache associated
  /// with this [Store] and deletes all data from the
  /// [SourceOfTruth]
  Future<void> clearAll() async {
    await _memoryCache.clear();
    await _sourceOfTruth?.deleteAll();
  }
}
