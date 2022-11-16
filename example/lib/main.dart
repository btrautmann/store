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
      home: const HomeScreen(title: 'Flutter Demo Home Page'),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Store<String, String> _store;

  Stream<String> emitDigits() async* {
    for (int x = 0; x < 10; x++) {
      await Future.delayed(const Duration(seconds: 1));
      yield x.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _store = stringStore(_preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StringStoreBuilder(
              store: _store,
              storeKey: 'ok',
              onData: (value) {
                return Text(value);
              },
              onError: () => const Text('Error!'),
              onLoading: () => const CircularProgressIndicator(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (context) => RefreshScreen(),
                  ));
                },
                child: const Text('Next'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  _preferences.clear();
                },
                child: const Text('Clear RxPreferences'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class RefreshScreen extends StatelessWidget {
  RefreshScreen({Key? key}) : super(key: key);

  final _store = stringStore(_preferences);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Two'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StringStoreBuilder(
              store: _store,
              storeKey: 'ok',
              onData: (value) {
                return Text(value);
              },
              onError: () => const Text('Error!'),
              onLoading: () => const CircularProgressIndicator(),
              refresh: true,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (context) => RefreshScreen(),
                  ));
                },
                child: const Text('Next'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

typedef StringStoreBuilder = StoreBuilder<String, String>;
