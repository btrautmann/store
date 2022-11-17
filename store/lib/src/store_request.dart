import 'package:equatable/equatable.dart';

/// A request for data at key [K] that can be issued to a [Store]
/// via the `stream` function.
class StoreRequest<K> extends Equatable {
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

  @override
  List<Object?> get props => [skipCache, refresh];
}
