import 'dart:convert';
import 'dart:math';

enum QrTargetType { batch, storageLocation, unlinked }

enum QrCodeState { unlinked, active, revoked, replaced }

enum QrResolutionKind {
  resolved,
  unknown,
  invalid,
  unsupported,
  unlinked,
  revoked,
  replaced,
}

final class QrCode {
  const QrCode({
    required this.id,
    required this.familyId,
    required this.publicToken,
    required this.shortCode,
    required this.checksum,
    required this.protocolVersion,
    required this.targetType,
    required this.state,
    required this.createdAt,
    required this.createdByMemberId,
    required this.deviceId,
    this.targetId,
    this.linkedAt,
    this.revokedAt,
    this.replacedByQrId,
  });

  final String id;
  final String familyId;
  final String publicToken;
  final String shortCode;
  final String checksum;
  final int protocolVersion;
  final QrTargetType targetType;
  final String? targetId;
  final QrCodeState state;
  final DateTime createdAt;
  final DateTime? linkedAt;
  final DateTime? revokedAt;
  final String? replacedByQrId;
  final String createdByMemberId;
  final String deviceId;

  String get payload => QrProtocol.payloadFor(publicToken, protocolVersion);
}

final class QrResolveResult {
  const QrResolveResult({required this.kind, this.qrCode});

  final QrResolutionKind kind;
  final QrCode? qrCode;
}

/// Versioned, PII-free local label protocol. Only opaque token travels in QR.
final class QrProtocol {
  static const scheme = 'banochki';
  static const currentVersion = 1;

  static String payloadFor(String token, [int version = currentVersion]) =>
      '$scheme://qr/v$version/$token';

  static ({int version, String token})? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host != 'qr') return null;
    final pieces = uri.pathSegments;
    if (pieces.length != 2 || !RegExp(r'^v[0-9]+$').hasMatch(pieces[0])) {
      return null;
    }
    final version = int.parse(pieces[0].substring(1));
    final token = pieces[1];
    if (!RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(token)) return null;
    return (version: version, token: token);
  }
}

final class QrTokenGenerator {
  QrTokenGenerator({Random? random}) : _random = random ?? Random.secure();
  final Random _random;

  String nextToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

/// Six decimal digits plus a Luhn check digit. Random base avoids local counters.
final class ShortCode {
  static String format(String digits) {
    final normalized = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length != 7) return normalized;
    return '${normalized.substring(0, 6)}-${normalized.substring(6)}';
  }

  static String create(String sixDigits) {
    if (!RegExp(r'^\d{6}$').hasMatch(sixDigits)) {
      throw ArgumentError.value(sixDigits, 'sixDigits');
    }
    return '$sixDigits-${_checkDigit(sixDigits)}';
  }

  static bool isValid(String value) {
    final compact = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (compact.length != 7) return false;
    return _checkDigit(compact.substring(0, 6)) == compact[6];
  }

  static String _checkDigit(String digits) {
    var sum = 0;
    for (var index = 0; index < digits.length; index++) {
      var value = int.parse(digits[digits.length - 1 - index]);
      if (index.isEven) {
        value *= 2;
        if (value > 9) value -= 9;
      }
      sum += value;
    }
    return '${(10 - sum % 10) % 10}';
  }
}
