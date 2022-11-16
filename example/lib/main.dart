import 'package:example/stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_store/flutter_store.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

late RxSharedPreferences _preferences;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _preferences = (await SharedPreferences.getInstance()).rx;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FreshScreen(),
    );
  }
}

class FreshScreen extends StatelessWidget {
  FreshScreen({Key? key}) : super(key: key);

  final _store = stringStore(_preferences);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StringStoreBuilder(
              store: _store,
              storeRequest: StoreRequest.fresh('whatever'),
              onData: (value) {
                return Text(value ?? 'null');
              },
              onError: () => const Text('Error!'),
              onLoading: () => const CircularProgressIndicator(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  _store.refresh('whatever');
                },
                child: const Text('Refresh'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  _preferences.clear();
                  _store.refresh('whatever');
                },
                child: const Text('Clear RxPreferences'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (context) => CachedScreen(),
                  ));
                },
                child: const Text('Go to Cached Screen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CachedScreen extends StatelessWidget {
  CachedScreen({Key? key}) : super(key: key);

  final _store = stringStore(_preferences);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cached Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StringStoreBuilder(
              store: _store,
              storeRequest: StoreRequest.cached(key: 'whatever'),
              onData: (value) {
                return Text(value ?? 'null');
              },
              onError: () => const Text('Error!'),
              onLoading: () => const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

typedef StringStoreBuilder = StoreBuilder<String, String?>;
