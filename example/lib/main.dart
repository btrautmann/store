import 'package:flutter/material.dart';
import 'package:flutter_store/flutter_store.dart';
import 'package:rx_shared_preferences/rx_shared_preferences.dart';

late SharedPreferences _preferences;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _preferences = await SharedPreferences.getInstance();
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
    _store = Store.from(
      fetch: (key) => emitDigits(),
      sourceOfTruth: SourceOfTruth.of(
        read: () => _preferences.rx.getStringStream('value').map((event) => event ?? ''),
        write: (value) async => _preferences.rx.setString('value', value),
      ),
    );
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
                  _preferences.rx.setString('value', '-x-');  
                },
                child: const Text('Clear'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

typedef StringStoreBuilder = StoreBuilder<String, String>;
