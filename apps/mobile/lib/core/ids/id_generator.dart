import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String next();
}

final class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  static const _uuid = Uuid();

  @override
  String next() => _uuid.v4();
}

final class SequenceIdGenerator implements IdGenerator {
  SequenceIdGenerator([this._value = 0]);

  int _value;

  @override
  String next() =>
      '00000000-0000-4000-8000-${(++_value).toString().padLeft(12, '0')}';
}
