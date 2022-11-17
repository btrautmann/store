# Store (Dart)

[![codecov](https://codecov.io/github/btrautmann/store/branch/main/graph/badge.svg?token=2JC1RLHWH5)](https://codecov.io/github/btrautmann/store)
[![pub](https://img.shields.io/pub/v/gooder_store.svg)](https://pub.dev/packages/gooder_store)

A dart port of [Store](https://github.com/MobileNativeFoundation/Store), a library for loading data from remote and local sources.

## The goal

First and foremost, give the `README` over at the original [Store](https://github.com/MobileNativeFoundation/Store) repository a read. This library is an attempt at porting that library to dart, which admittedly [has been done before](https://pub.dev/packages/stored), but it would appear _that_ codebase is no longer maintained (or never was, heck it's at version `0.0.0`). With that said, this library aims to:

- Make the fetching, persisting and/or caching, and observation of your data super simple
- Limit data usage through the use of in-memory and disk (if provided) caching
- Expose a minimalistic API for reading or listening to data

## Some quick examples

**A fully configured `Store`**

```dart
return Store.from(
    fetch: (_) => fetchData(),
    sourceOfTruth: SourceOfTruth.of(
        read: (key) => prefs.getStringStream(key).map((v) => v),
        write: (key, value) async => prefs.setString(key, value),
        delete: (key) async => prefs.remove(key),
        deleteAll: () async => prefs.clear(),
    ),
);
```

This `Store` configures the `required` `Fetch<K, T>` parameter using `fetchData()` which could be an API call or whatever origin from which you choose to receive your data. It also provides a `SourceOfTruth` which acts as the disk cache (in this case, `RxSharedPreferences` is used). When data is fetched via the `Fetch` function, it will be persisted to the `SourceOfTruth` via `Write`. New emissions from `Read` will be streamed continuously when `stream` is invoked on the `Store`, assuming `skipCache` is not `true` (more on that later).

**Streaming data**

Streaming can be done by passing a `StoreRequest` to the `stream` function. A `StoreRequest` is one of `cached` or `fresh`, where the former can indicate whether a `refresh` should be done (via `Fetch`) after returning the cached data, if it exists.

```dart
store.stream(request: StoreRequest.cached(key: key, refresh: true)).listen((value) => ...);
```

On the other hand, if you need fresh data from `Fetch`, simply use `StoreRequest.fresh()`

```dart
store.stream(request: StoreRequest.fresh(key)).listen((value) => ...);
```

**Note:** Calling `stream` while another `Stream` is already being listened to for the same key is completely fine. The second subscription will be replayed the most recent emission from the existing `Stream`, and future events as well. This avoids redundant `Fetch` calls.

**Obtaining a single value**

A single value can be obtained using one of `cached()` or `fresh()`.

The former will return the first value from either the `Store`s in-memory cache _or_ the `SourceOfTruth`, if provided.

```dart
final value = await store.cached(key);
```

The latter will return the result of invoking `Fetch`.

```dart
final value = await store.fresh(key);
```

## On the roadmap

The following items are on the roadmap for `Store`:

- Currently, errors that result from reading from `SourceOfTruth` or fetching via `Fetch` are not handled. Soon, `Error` `StoreResponse<T>` types will be emitted on `stream()` or via `cached()` or `fresh()`.
- [flutter_store](../flutter_store/) needs thought and polishing (and publishing), and then this library will be more easily integrated into a Flutter application.
