/// Structural equality used by values ported from Kotlin data classes.
mixin MailValueEquality {
  List<Object?> get equalityProps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is MailValueEquality &&
          _sequenceEquals(equalityProps, other.equalityProps);

  @override
  int get hashCode => Object.hash(runtimeType, _sequenceHash(equalityProps));
}

bool _sequenceEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_valueEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _valueEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) return _sequenceEquals(a, b);
  if (a is Set && b is Set) {
    return a.length == b.length &&
        a.every((value) => b.any((other) => _valueEquals(value, other)));
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.entries.every(
          (entry) =>
              b.containsKey(entry.key) &&
              _valueEquals(entry.value, b[entry.key]),
        );
  }
  return a == b;
}

int _sequenceHash(Iterable<Object?> values) =>
    Object.hashAll(values.map(_valueHash));

int _valueHash(Object? value) {
  if (value is List) return _sequenceHash(value);
  if (value is Set) return Object.hashAllUnordered(value.map(_valueHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (entry) => Object.hash(_valueHash(entry.key), _valueHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}
