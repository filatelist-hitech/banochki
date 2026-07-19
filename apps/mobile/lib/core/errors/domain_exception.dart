sealed class DomainException implements Exception {
  const DomainException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ValidationException extends DomainException {
  const ValidationException(super.message);
}

final class NotFoundException extends DomainException {
  const NotFoundException(super.message);
}

final class LocationCycleException extends DomainException {
  const LocationCycleException()
    : super('Место нельзя вложить само в себя или в дочернюю ветку.');
}

final class LocationDepthException extends DomainException {
  const LocationDepthException()
    : super('Место нельзя вложить глубже шести уровней.');
}

final class LocationNotEmptyException extends DomainException {
  const LocationNotEmptyException()
    : super('Сначала переместите активные партии из этого места.');
}

final class UnderflowConfirmationRequired extends DomainException {
  const UnderflowConfirmationRequired(this.computedQuantity)
    : super('После действия расчётный остаток станет отрицательным.');

  final int computedQuantity;
}
