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
