library flutter_store;

import 'package:flutter/material.dart';
import 'package:store/store.dart';

export 'package:store/store.dart';

typedef OnData<T> = Widget Function(T data);
typedef OnError = Widget Function();
typedef OnLoading = Widget Function();

class StoreBuilder<K, T> extends StatelessWidget {
  final Store<K, T> store;
  final K storeKey;
  final T? initialValue;
  final OnData<T> onData;
  final OnError onError;
  final OnLoading onLoading;

  const StoreBuilder({
    super.key,
    required this.store,
    required this.storeKey,
    required this.onData,
    required this.onError,
    required this.onLoading,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      initialData: initialValue,
      stream: store.stream(
        request: StoreRequest.cached(key: storeKey),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return onData(snapshot.data as T);
        } else if (snapshot.hasError) {
          return onError();
        } else {
          return onLoading();
        }
      },
    );
  }
}
