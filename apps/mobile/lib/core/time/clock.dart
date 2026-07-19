abstract interface class AppClock {
  DateTime nowUtc();
}

final class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

final class FixedClock implements AppClock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();
}
