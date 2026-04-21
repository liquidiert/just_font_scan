extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } on StateError {
      return null;
    }
  }
}
