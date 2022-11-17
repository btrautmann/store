import 'dart:async';

import 'package:reactive_store/reactive_store.dart';


void main() async {
  final inMemoryStorage = InMemoryStorage();
  final store = Store<String, String>.from(
    fetch: (key) => (StreamController<String>()..add('dummy')).stream,
    sourceOfTruth: SourceOfTruth<String, String>.of(
      read: (key) =>
          (StreamController<String>()..add(inMemoryStorage.value)).stream,
      write: (key, value) async => inMemoryStorage.value = value,
      delete: (key) async => inMemoryStorage.value = '',
      deleteAll: () async => inMemoryStorage.value = '',
    ),
  );
  store.stream(request: StoreRequest.cached(key: 'Brandon')).listen((value) {
    print(value);
  });
}

Future<String> fetchValue(String name) async {
  if (name == 'Brandon') {
    return 'Yes';
  } else {
    return 'No';
  }
}

class InMemoryStorage {
  String value = '';
}
