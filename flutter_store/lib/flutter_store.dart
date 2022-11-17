library flutter_store;

import 'package:flutter/material.dart';
import 'package:dart_store/dart_store.dart';

export 'package:dart_store/dart_store.dart';

typedef OnData<T> = Widget Function(T value, Source source);
typedef OnError = Widget Function(Exception error);
typedef OnLoading = Widget Function(Source source);

class StoreBuilder<K extends Object, T extends Object?> extends StatelessWidget {
  final Store<K, T> store;
  final StoreRequest<K> storeRequest;
  final T? initialValue;
  final OnData<T> onData;
  final OnError onError;
  final OnLoading onLoading;

  const StoreBuilder({
    super.key,
    required this.store,
    required this.storeRequest,
    required this.onData,
    required this.onError,
    required this.onLoading,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      initialData: initialValue,
      stream: store.stream(request: storeRequest),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final response = snapshot.data as StoreResponse<T>;
          if (response is Data<T>) {
            return onData(response.value, response.source);
          } else if (response is Error) {
            return onError((response as Error).error);
          } else if (response is Loading) {
            return onLoading(response.source);
          }
        } else if (snapshot.hasError) {
          return onError(Exception(snapshot.error?.toString()));
        }
        // There may exist a moment in which snapshot does not have
        // data from the Store, but rather than clutter the public API,
        // simply return a shrink for now.
        return const SizedBox.shrink();
      },
    );
  }
}
