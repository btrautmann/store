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
  }) {
    final controller = StreamController<T>();
    return _updateStream(controller, request);
  }

  Stream<T> _updateStream(StreamController controller, StoreRequest request) async* {
    final cachedValue = _memoryValue;
    if (!request.skipCache && cachedValue != null) {
      yield cachedValue;
    } else {
      late StreamSubscription<T> sub;
      sub = _fetch(request.key).listen((value) {
        _sourceOfTruth?.write(value);
      }, onDone: () => sub.cancel());
    }
    final read = _sourceOfTruth?.read();
    if (read != null) {
      yield* read;
    }
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
