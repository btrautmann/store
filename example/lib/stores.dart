import 'package:flutter_store/flutter_store.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

Store<String, String> stringStore(RxSharedPreferences prefs) {
  Stream<String> emitDigits() async* {
    await Future.delayed(const Duration(seconds: 5));
    yield 'response';
  }

  return Store.from(
    fetch: (key) => emitDigits(),
    sourceOfTruth: SourceOfTruth.of(
      read: () => prefs.getStringStream('value').map((event) => event ?? 'empty'),
      write: (value) async => prefs.setString('value', value),
    ),
  );
}
