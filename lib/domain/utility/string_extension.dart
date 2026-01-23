///
extension StringExtension on String {
  ///
  Uri? get asUri => Uri.tryParse(this);

  ///
  String get capitalized {
    if (isEmpty) return this;
    if (length == 1) return toUpperCase();
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
