import 'package:gooder_store/src/fetch_manager.dart';
import 'package:test/test.dart';

void main() {
  group('FetchManager', () {
    group('fetch', () {
      group('when invoked twice while fetch for key is in progress', () {
        test('it returns the existing fetch stream', () async {
          final subject = FetchManager<int, int>(fetch: (key) async* {
            await Future.delayed(Duration(seconds: 1));
            yield 1;
          });

          final stream1 = subject.fetch(0);
          final stream2 = subject.fetch(0);

          expect(stream1, stream2);
        });
      });

      group('when invoked twice while fetch for key is not in progress', () {
        test('it returns a new stream', () async {
          final subject = FetchManager<int, int>(fetch: (key) async* {
            await Future.delayed(Duration(seconds: 1));
            yield 1;
          });

          final stream1 = subject.fetch(0);
          // Ensure the previous `fetch` is complete
          await stream1.drain();
          final stream2 = subject.fetch(0);

          expect(stream1 != stream2, isTrue);
        });
      });
    });
  });
}
