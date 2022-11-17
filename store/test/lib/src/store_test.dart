import 'package:gooder_store/gooder_store.dart';
import 'package:test/test.dart';

void main() {
  group('Store', () {
    Stream<String> fetchString() {
      return Stream.value('test');
    }

    SourceOfTruth<String, String?> produceSourceOfTruth({Map<String, String?>? storage}) {
      final s = storage ?? {};
      return SourceOfTruth.of(
        read: (key) => Stream.value(s[key]),
        write: (key, value) async => s[key] = value,
        delete: (key) async => s[key] = null,
        deleteAll: () async => s.clear(),
      );
    }

    group('stream', () {
      group('cached', () {
        group('when refresh is false', () {
          group('and no source of truth is provided', () {
            group('and no value exists in memory cache', () {
              test('it emits nothing ', () async {
                final subject = Store<String, String>.from(
                  fetch: (_) => fetchString(),
                );

                final responses = <StoreResponse<String>>[];
                await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                  responses.add(response);
                }

                expect(responses, []);
              });
            });

            group('and a value exists in memory cache', () {
              test('it emits the result of memory cache ', () async {
                final subject = Store<String, String>.from(
                  fetch: (_) => fetchString(),
                );

                // ignore: unused_local_variable
                await for (final response in subject.stream(request: StoreRequest.fresh('dummy'))) {
                  // Do nothing
                }

                // Memory cache is populated now
                final responses = <StoreResponse<String>>[];
                await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                  responses.add(response);
                }

                expect(
                  responses,
                  [
                    Data<String>(value: 'test', source: Source.cache),
                  ],
                );
              });
            });
          });

          group('and source of truth is provided', () {
            group('and no value exists in memory cache', () {
              group('and no value exists in source of truth', () {
                test('it emits data with null value', () async {
                  final subject = Store<String, String?>.from(
                    fetch: (_) => fetchString(),
                    sourceOfTruth: produceSourceOfTruth(),
                  );

                  final responses = <StoreResponse<String?>>[];
                  await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                    responses.add(response);
                  }

                  expect(responses, [Data<String?>(value: null, source: Source.sourceOfTruth)]);
                });
              });

              group('and a value exists in source of truth', () {
                test('it emits the result of source of truth and persists the value in memory', () async {
                  final subject = Store<String, String?>.from(
                    fetch: (_) => fetchString(),
                    sourceOfTruth: produceSourceOfTruth(storage: {'dummy': 'existingValue'}),
                  );

                  final firstResponses = <StoreResponse<String?>>[];
                  await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                    firstResponses.add(response);
                  }

                  expect(firstResponses, [Data<String?>(value: 'existingValue', source: Source.sourceOfTruth)]);

                  final secondResponses = <StoreResponse<String?>>[];
                  await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                    secondResponses.add(response);
                  }

                  expect(
                    secondResponses,
                    [
                      Data<String?>(value: 'existingValue', source: Source.cache),
                      Data<String?>(value: 'existingValue', source: Source.sourceOfTruth),
                    ],
                  );
                });
              });
            });

            group('and a value exists in memory cache', () {
              test('it emits the result of memory cache followed by source of truth', () async {
                final subject =
                    Store<String, String?>.from(fetch: (_) => fetchString(), sourceOfTruth: produceSourceOfTruth());

                // ignore: unused_local_variable
                await for (final response in subject.stream(request: StoreRequest.fresh('dummy'))) {
                  // Do nothing
                }

                // Memory cache is populated now
                final responses = <StoreResponse<String?>>[];
                await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
                  responses.add(response);
                }

                expect(
                  responses,
                  [
                    Data<String?>(value: 'test', source: Source.cache),
                    Data<String?>(value: 'test', source: Source.sourceOfTruth),
                  ],
                );
              });
            });
          });
        });

        group('when refresh is true', () {
          group('and no source of truth is provided', () {
            group('and no value exists in memory cache', () {
              test('it emits the result of fetch ', () async {
                final subject = Store<String, String>.from(
                  fetch: (_) => fetchString(),
                );

                final responses = <StoreResponse<String>>[];
                await for (final response in subject.stream(
                  request: StoreRequest.cached(
                    key: 'dummy',
                    refresh: true,
                  ),
                )) {
                  responses.add(response);
                }

                expect(responses, [
                  Loading<String>(source: Source.fetch),
                  Data<String>(value: 'test', source: Source.fetch),
                ]);
              });
            });

            group('and a value exists in memory cache', () {
              test('it emits the result of memory cache followed by the result of fetch', () async {
                final subject = Store<String, String>.from(
                  fetch: (_) => fetchString(),
                );

                // ignore: unused_local_variable
                await for (final response in subject.stream(request: StoreRequest.fresh('dummy'))) {
                  // Do nothing
                }

                // Memory cache is populated now
                final responses = <StoreResponse<String>>[];
                await for (final response in subject.stream(
                  request: StoreRequest.cached(
                    key: 'dummy',
                    refresh: true,
                  ),
                )) {
                  responses.add(response);
                }

                expect(
                  responses,
                  [
                    Data<String>(value: 'test', source: Source.cache),
                    Loading<String>(source: Source.fetch),
                    Data<String>(value: 'test', source: Source.fetch),
                  ],
                );
              });
            });
          });

          group('and a source of truth is provided', () {
            group('and no value exists in memory cache', () {
              group('and no value exists in source of truth', () {
                test('it emits data with null value followed by the result of fetch ', () async {
                  final subject = Store<String, String?>.from(
                    fetch: (_) => fetchString(),
                    sourceOfTruth: produceSourceOfTruth(),
                  );

                  final responses = <StoreResponse<String?>>[];
                  await for (final response in subject.stream(
                    request: StoreRequest.cached(
                      key: 'dummy',
                      refresh: true,
                    ),
                  )) {
                    responses.add(response);
                  }

                  expect(responses, [
                    Data<String?>(value: null, source: Source.sourceOfTruth),
                    Loading<String?>(source: Source.fetch),
                    Data<String?>(value: 'test', source: Source.fetch),
                  ]);
                });
              });
              group('and a value exists in source of truth', () {
                test('it emits the result of source of truth followed by the result of fetch ', () async {
                  final subject = Store<String, String?>.from(
                    fetch: (_) => fetchString(),
                    sourceOfTruth: produceSourceOfTruth(storage: {'dummy': 'existingValue'}),
                  );

                  final responses = <StoreResponse<String?>>[];
                  await for (final response in subject.stream(
                    request: StoreRequest.cached(
                      key: 'dummy',
                      refresh: true,
                    ),
                  )) {
                    responses.add(response);
                  }

                  expect(responses, [
                    Data<String?>(value: 'existingValue', source: Source.sourceOfTruth),
                    Loading<String?>(source: Source.fetch),
                    Data<String?>(value: 'test', source: Source.fetch),
                  ]);
                });
              });
            });

            group('and a value exists in memory cache', () {
              test(
                  'it emits the result of memory cache '
                  'followed by the result of source of truth '
                  'followed by the result of fetch', () async {
                final subject = Store<String, String?>.from(
                  fetch: (_) => fetchString(),
                  sourceOfTruth: produceSourceOfTruth(),
                );

                // ignore: unused_local_variable
                await for (final response in subject.stream(request: StoreRequest.fresh('dummy'))) {
                  // Do nothing
                }

                // Memory cache is populated now
                final responses = <StoreResponse<String?>>[];
                await for (final response in subject.stream(
                  request: StoreRequest.cached(
                    key: 'dummy',
                    refresh: true,
                  ),
                )) {
                  responses.add(response);
                }

                expect(
                  responses,
                  [
                    Data<String?>(value: 'test', source: Source.cache),
                    Data<String?>(value: 'test', source: Source.sourceOfTruth),
                    Loading<String?>(source: Source.fetch),
                    Data<String?>(value: 'test', source: Source.fetch),
                  ],
                );
              });
            });
          });
        });
      });

      group('fresh', () {
        group('when no source of truth is provided', () {
          test('it emits the result of fetch', () async {
            final subject = Store<String, String>.from(
              fetch: (_) => fetchString(),
            );

            final responses = <StoreResponse<String>>[];
            await for (final response in subject.stream(
              request: StoreRequest.fresh('dummy'),
            )) {
              responses.add(response);
            }

            expect(responses, [
              Loading<String>(source: Source.fetch),
              Data<String>(value: 'test', source: Source.fetch),
            ]);
          });
        });
        group('when source of truth is provided', () {
          test('it emits the result of source of truth followed by the result of fetch', () async {
            final subject = Store<String, String?>.from(
              fetch: (_) => fetchString(),
              sourceOfTruth: produceSourceOfTruth(),
            );

            final responses = <StoreResponse<String?>>[];
            await for (final response in subject.stream(
              request: StoreRequest.fresh('dummy'),
            )) {
              responses.add(response);
            }

            expect(responses, [
              // TODO(brandon): We probably don't want to emit source of truth for `fresh` requests,
              // especially if they're null!
              Data<String?>(value: null, source: Source.sourceOfTruth),
              Loading<String?>(source: Source.fetch),
              Data<String?>(value: 'test', source: Source.fetch),
              // In a reactive data storage mechanism, we'd see another emission of `sourceOfTruth`:
              // Data<String?>(value: 'test', source: Source.sourceOfTruth),
            ]);
          });
        });
      });
    });

    group('cached', () {
      group('when no memory cache value exists', () {
        group('and no source of truth value exists', () {
          test('it returns null from source of truth', () async {
            final subject = Store.from(
              fetch: (key) => fetchString(),
              sourceOfTruth: produceSourceOfTruth(),
            );

            final value = await subject.cached('dummy');

            expect(value, Data<String?>(value: null, source: Source.sourceOfTruth));
          });
        });

        group('and a source of truth value exists', () {
          test('it returns the result of source of truth', () async {
            final subject = Store.from(
              fetch: (key) => fetchString(),
              sourceOfTruth: produceSourceOfTruth(storage: {'dummy': 'existingValue'}),
            );

            final value = await subject.cached('dummy');

            expect(value, Data<String?>(value: 'existingValue', source: Source.sourceOfTruth));
          });
        });
      });
      group('when a memory cache value exists', () {
        test('it returns the result of memory cache', () async {
          final subject = Store.from(
            fetch: (key) => fetchString(),
            sourceOfTruth: produceSourceOfTruth(),
          );

          // ignore: unused_local_variable
          await for (final response in subject.stream(request: StoreRequest.fresh('dummy'))) {
            // Do nothing
          }

          final source = await subject.cached('dummy');

          expect(source, Data<String?>(value: 'test', source: Source.cache));
        });
      });
    });

    group('refresh', () {
      test('it returns the result of fetch', () async {
        final subject = Store.from(
          fetch: (key) => fetchString(),
          sourceOfTruth: produceSourceOfTruth(),
        );
        final response = await subject.refresh('dummy');
        expect(response, Data<String?>(value: 'test', source: Source.fetch));
      });
    });

    group('clear', () {
      test('it clear memory cache and source of truth for key', () async {
        final sourceOfTruth = produceSourceOfTruth(storage: {'dummy': 'existingValue'});
        final subject = Store.from(
          fetch: (key) => fetchString(),
          sourceOfTruth: sourceOfTruth,
        );

        // ignore: unused_local_variable
        await for (final response in subject.stream(request: StoreRequest.cached(key: 'dummy'))) {
          // Do nothing
        }

        // Memory cache is populated now
        final responsesBefore = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'dummy',
          ),
        )) {
          responsesBefore.add(response);
        }

        expect(
          responsesBefore,
          [
            Data<String?>(value: 'existingValue', source: Source.cache),
            Data<String?>(value: 'existingValue', source: Source.sourceOfTruth),
          ],
        );

        await subject.clear('dummy');

        final responsesAfter = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'dummy',
          ),
        )) {
          responsesAfter.add(response);
        }

        expect(
          responsesAfter,
          [
            Data<String?>(value: null, source: Source.sourceOfTruth),
          ],
        );
      });
    });

    group('clearAll', () {
      test('it clear memory cache and source of truth entirely', () async {
        final sourceOfTruth = produceSourceOfTruth(
          storage: {'dummy': 'existingValue', 'rummy': 'existingValue2'},
        );
        final subject = Store.from(
          fetch: (key) => fetchString(),
          sourceOfTruth: sourceOfTruth,
        );

        for (final key in ['dummy', 'rummy']) {
          // ignore: unused_local_variable
          await for (final response in subject.stream(request: StoreRequest.cached(key: key))) {
            // Do nothing
          }
        }

        // Memory cache is populated now
        final dummyResponses = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'dummy',
          ),
        )) {
          dummyResponses.add(response);
        }
        final rummyResponses = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'rummy',
          ),
        )) {
          rummyResponses.add(response);
        }

        expect(
          dummyResponses,
          [
            Data<String?>(value: 'existingValue', source: Source.cache),
            Data<String?>(value: 'existingValue', source: Source.sourceOfTruth),
          ],
        );
        expect(
          rummyResponses,
          [
            Data<String?>(value: 'existingValue2', source: Source.cache),
            Data<String?>(value: 'existingValue2', source: Source.sourceOfTruth),
          ],
        );

        await subject.clearAll();

        final dummyResponsesAfter = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'dummy',
          ),
        )) {
          dummyResponsesAfter.add(response);
        }
        final rummyResponsesAfter = <StoreResponse<String?>>[];
        await for (final response in subject.stream(
          request: StoreRequest.cached(
            key: 'rummy',
          ),
        )) {
          rummyResponsesAfter.add(response);
        }

        expect(
          dummyResponsesAfter,
          [
            Data<String?>(value: null, source: Source.sourceOfTruth),
          ],
        );
        expect(
          rummyResponsesAfter,
          [
            Data<String?>(value: null, source: Source.sourceOfTruth),
          ],
        );
      });
    });
  });
}
