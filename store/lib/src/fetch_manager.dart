import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'store_response.dart';

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
  Stream<StoreResponse<T>> fetch(K key) {
    final existingSubject = _subjects[key];
    if (existingSubject != null) {
      return existingSubject.stream;
    }
    // The first emission when fetching will always be `Loading` with `Source.fetch`
    final subject = BehaviorSubject<StoreResponse<T>>.seeded(
        Loading<T>(source: Source.fetch));

    late StreamSubscription subscription;
    subscription = _fetch(key).listen(
      (data) => subject.add(Data(value: data, source: Source.fetch)),
    )..onDone(() async {
        // The Stream associated with _fetch has completed. Remove the BehaviorSubject
        // and StreamSubscription associated with the key.
        print(
            'Store: Cleaning up resources for Fetch associated with key: $key');
        await subscription.cancel();
        await subject.close();
        _subjects[key] = null;
        _subscriptions[key] = null;
      });
    _subjects[key] = subject;
    _subscriptions[key] = subscription;
    return subject.stream;
  }
}
