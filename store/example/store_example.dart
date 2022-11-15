import 'dart:async';

import 'package:store/store.dart';

void main() async {
  final inMemoryStorage = InMemoryStorage();
  final store = Store<String, String>.from(
    fetch: (key) => (StreamController<String>()..add('dummy')).stream,
    sourceOfTruth: SourceOfTruth<String>.of(
      read: () => (StreamController<String>()..add(inMemoryStorage.value)).stream,
      write: (value) async => inMemoryStorage.value = value,
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
