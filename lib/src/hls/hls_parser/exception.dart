class ParserException implements Exception {
  new(this.message) : super();

  final String message;

  @override
  String toString() => 'SignalException: $message';
}

class UnrecognizedInputFormatException extends ParserException {
  new(super.message, this.uri);

  final Uri? uri;
}
