class HttpFailure implements Exception {
  const HttpFailure(this.description);

  static const HttpFailure notFound = HttpFailure('404 not found');

  final String description;

  @override
  String toString() => description;
}
