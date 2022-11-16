import 'dart:math';

import 'package:flutter_store/flutter_store.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
final _random = Random();

String getRandomString(int length) {
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _chars.codeUnitAt(
        _random.nextInt(
          _chars.length,
        ),
      ),
    ),
  );
}

/// An example [Store] that uses a [String] as a key and stores nullable
/// [String] values. The `fetchString` method simulates a network call
/// and returns a random 10 character [String].
Store<String, String?> stringStore(RxSharedPreferences prefs) {
  Stream<String> fetchString() async* {
    await Future.delayed(const Duration(seconds: 2));
    yield getRandomString(10);
  }

  return Store.from(
    fetch: (_) => fetchString(),
    sourceOfTruth: SourceOfTruth.of(
      read: (key) => prefs.getStringStream(key),
      write: (key, value) async => prefs.setString(key, value),
      delete: (key) async => prefs.remove(key),
      deleteAll: () async => prefs.clear(),
    ),
  );
}
