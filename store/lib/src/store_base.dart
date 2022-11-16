import 'dart:async';

class Store<K, T> {
  final Fetch<K, T> _fetch;
  final SourceOfTruth<T>? _sourceOfTruth;
  T? _memoryValue;

  Store._({
    required Fetch<K, T> fetch,
    SourceOfTruth<T>? sourceOfTruth,
  })  : _fetch = fetch,
        _sourceOfTruth = sourceOfTruth;

  factory Store.from({
    required Fetch<K, T> fetch,
    SourceOfTruth<T>? sourceOfTruth,
  }) {
    return Store._(
      fetch: fetch,
      sourceOfTruth: sourceOfTruth,
    );
  }

  Stream<T> stream({
    required StoreRequest request,
  }) async* {
    final cachedValue = _memoryValue;
    if (!request.skipCache && cachedValue != null) {
      yield cachedValue;
    } else if (request.refresh) {
      late StreamSubscription<T> fetchSubscription;
      fetchSubscription = _fetch(request.key).listen(
        (value) {
          _sourceOfTruth?.write(value);
        },
        onDone: () => fetchSubscription.cancel(),
      );
    }
    final read = _sourceOfTruth?.read();
    if (read != null) {
      yield* read;
    }
  }

  Future<T?> cached(K key) async {
    if (_memoryValue != null) {
      return _memoryValue;
    } else if (_sourceOfTruth != null) {
      return _sourceOfTruth!.read().first;
    }
    return null;
  }

  Future<T> refresh(K key) async {
    final value = await _fetch(key).first;
    _sourceOfTruth?.write(value);
    return value;
  }
}

typedef Fetch<K, T> = Stream<T> Function(K key);

class SourceOfTruth<T> {
  final Read<T> _read;
  final Write<T> _write;

  SourceOfTruth._({
    required Read<T> read,
    required Write<T> write,
  })  : _read = read,
        _write = write;

  factory SourceOfTruth.of({
    required Read<T> read,
    required Write<T> write,
  }) {
    return SourceOfTruth._(
      read: read,
      write: write,
    );
  }

  Stream<T> read() {
    return _read();
  }

  Future<void> write(T value) {
    return _write(value);
  }
}

typedef Read<T> = Stream<T> Function();

typedef Write<T> = Future<void> Function(T value);

class StoreRequest<K> {
  final K key;
  final bool skipCache;
  final bool refresh;

  StoreRequest._({
    required this.key,
    required this.skipCache,
    required this.refresh,
  });

  factory StoreRequest.fresh(K key) {
    return StoreRequest._(
      key: key,
      skipCache: true,
      refresh: false,
    );
  }

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
