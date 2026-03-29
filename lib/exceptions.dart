// App exceptions
class AppException implements Exception {
  final String message;
  final String? code;
  
  AppException(this.message, {this.code});
  
  @override
  String toString() => message;
}

class StorageException extends AppException {
  StorageException(super.message, {super.code});
}

class ValidationException extends AppException {
  ValidationException(super.message, {super.code});
}

// Result type for error handling (inspired by superpowers pattern)
class Result<T> {
  final T? data;
  final AppException? error;
  final bool isSuccess;
  
  Result.success(this.data) 
    : error = null, 
      isSuccess = true;
  
  Result.failure(this.error) 
    : data = null, 
      isSuccess = false;
  
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data as T);
    } else {
      return failure(error!);
    }
  }
}