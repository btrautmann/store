import 'package:equatable/equatable.dart';

/// {@template store_response}
/// Represents the result of attempting to read data
/// from a [Store]
/// {@endtemplate}
abstract class StoreResponse<T> extends Equatable {
  /// The [Source] that produced the [StoreResponse].
  final Source source;

  /// {@macro store_response}
  const StoreResponse({required this.source});
}

/// {@template data_response}
/// Represents a successful read of data of type [T]
/// {@endtemplate}
class Data<T> extends StoreResponse<T> {
  /// The value of type [T] that was successfully
  /// read from storage
  final T value;

  /// {@macro data_response}
  Data({
    required this.value,
    required super.source,
  });

  @override
  List<Object?> get props => [value, source];
}

/// {@template loading_response}
/// Represents an in-flight request for data of type [T]
/// {@endtemplate}
class Loading<T> extends StoreResponse<T> {
  /// {@macro loading_response}
  Loading({required super.source});

  @override
  List<Object?> get props => [source];
}

/// {@template error_response}
/// Represents an error that occurred while reading
/// data
/// {@endtemplate}
class Error<T> extends StoreResponse<T> {
  /// The [Exception] that was raised when attempting
  /// to read from storage
  final Exception error;

  /// {@macro error_response}
  Error({
    required this.error,
    required super.source,
  });

  @override
  List<Object?> get props => [error, source];
}

/// The storage location from which a [StoreResponse]
/// was produced
enum Source {
  /// In-memory cache of the [Store]
  cache,

  /// The [SourceOfTruth] provided to a [Store]
  sourceOfTruth,

  /// The [Fetch] provided to a [Store]
  fetch,
}
