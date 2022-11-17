import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stash/stash_api.dart';
import 'package:stash_memory/stash_memory.dart';

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
  /// If [request.refresh] is true, a fetch will be made
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
      (element) => element is Data<T> && (element.source == Source.cache || element.source == Source.sourceOfTruth),
    );
  }

  /// Invokes the [Fetch] provided during [Store] creation
  /// and writes the returned value to the [SourceOfTruth]
  /// if available. Lastly, it returns the fetched value.
  Future<StoreResponse<T>> refresh(K key) async {
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

/// Function describing a network fetch of type [T] by key [K]
typedef Fetch<K, T> = Stream<T> Function(K key);

/// {@template fetch_manager}
/// Manages a given [Fetch] by maintaining a mapping of its
/// key to its [StreamController] and subsequent [Stream]. This
/// guarantees that multiple requests made to the same [Store]
/// for the same key will share the same broadcast [Stream].
/// {@endtemplate}
class FetchManager<K, T> {
  final Fetch<K, T> _fetch;

  final _subjects = <K, BehaviorSubject<StoreResponse<T>>?>{};
  final _subscriptions = <K, StreamSubscription?>{};

  /// {@macro fetch_manager}
  FetchManager({
    required Fetch<K, T> fetch,
  }) : _fetch = fetch;

  /// Returns the [Stream] associated with the provided [key]
  ///
  /// If one does not exist yet, creates and stores
  /// the [BehaviorSubject] to be associated with the [key].
  Stream<StoreResponse<T>> fetch(K key) async* {
    final existingSubject = _subjects[key];
    if (existingSubject != null) {
      yield* existingSubject.stream;
      return;
    }
    final subject = BehaviorSubject<StoreResponse<T>>.seeded(Loading<T>(source: Source.fetch));
    late StreamSubscription subscription;
    subscription = _fetch(key).listen((data) => subject.add(Data(value: data, source: Source.fetch)))
      ..onDone(() async {
        // The Stream associated with _fetch has completed. Remove the BehaviorSubject
        // and StreamSubscription associated with the key.
        print('Store: Cleaning up resources for Fetch associated with key: $key');
        await subscription.cancel();
        await subject.close();
        _subjects[key] = null;
        _subscriptions[key] = null;
      });
    _subjects[key] = subject;
    _subscriptions[key] = subscription;
    yield* subject.stream.doOnDone(() {
      print('Store: FetchManager#fetch stream complete for $key');
    });
  }
}

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

/// A request for data at key [K] that can be issued to a [Store]
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

/// {@template store_response}
/// Represents the result of attempting to read data
/// from a [Store]
/// {@endtemplate}
abstract class StoreResponse<T> extends Equatable {
  /// The [Source] that produced the [StoreResponse].
  final Source source;

  /// {@macro store_response}
  const StoreResponse({required this.source});
}

/// {@template data_response}
/// Represents a successful read of data of type [T]
/// {@endtemplate}
class Data<T> extends StoreResponse<T> {
  /// The value of type [T] that was successfully
  /// read from storage
  final T value;

  /// {@macro data_response}
  Data({
    required this.value,
    required super.source,
  });

  @override
  List<Object?> get props => [value, source];
}

/// {@template loading_response}
/// Represents an in-flight request for data of type [T]
/// {@endtemplate}
class Loading<T> extends StoreResponse<T> {
  /// {@macro loading_response}
  Loading({required super.source});

  @override
  List<Object?> get props => [source];
}

/// {@template error_response}
/// Represents an error that occurred while reading
/// data
/// {@endtemplate}
class Error<T> extends StoreResponse<T> {
  /// The [Exception] that was raised when attempting
  /// to read from storage
  final Exception error;

  /// {@macro error_response}
  Error({
    required this.error,
    required super.source,
  });

  @override
  List<Object?> get props => [error, source];
}

/// The storage location from which a [StoreResponse]
/// was produced
enum Source {
  /// In-memory cache of the [Store]
  cache,

  /// The [SourceOfTruth] provided to a [Store]
  sourceOfTruth,

  /// The [Fetch] provided to a [Store]
  fetch,
}
