///
extension StringExtension on String {
  ///
  Uri? get asUri => Uri.tryParse(this);

  /// Lower-cases the rest as well: `hELLO` becomes `Hello`.
  String get capitalized {
    if (isEmpty) return this;
    if (length == 1) return toUpperCase();
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
