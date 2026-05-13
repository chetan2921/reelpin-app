import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelpin/services/api_service.dart';

void main() {
  test(
    'getAccountEntitlements falls back when the endpoint is missing',
    () async {
      final service = ApiService(
        baseUrl: 'https://example.com',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.com/account/entitlements?user_id=user-123',
          );
          return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
        }),
      );

      final entitlement = await service.getAccountEntitlements(
        userId: 'user-123',
      );

      expect(entitlement.userId, 'user-123');
      expect(entitlement.isPro, isTrue);
      expect(entitlement.features.conversationalRagSearch, isTrue);
      expect(entitlement.limits.reelsPerMonth, isNull);
    },
  );

  test('getAccountEntitlements still reports non-404 failures', () async {
    final service = ApiService(
      baseUrl: 'https://example.com',
      client: MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Server error'}), 500);
      }),
    );

    expect(
      () => service.getAccountEntitlements(userId: 'user-123'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });
}
