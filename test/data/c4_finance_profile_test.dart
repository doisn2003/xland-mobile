import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/mappers/domain_mappers.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class _Sessions implements SessionStore {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> saveAccessToken({required String accessToken}) async {}
  @override
  Future<void> clear() async {}
  @override Future<void> clearIfMatches({required String accessToken}) async {}
}

void main() {
  final samples = wireObject(
    wireObject(
      jsonDecode(File('test/data/fixtures/c4_samples.json').readAsStringSync()),
    )['samples'],
  );
  test('C-4 finance response exact strings, formula/rounding and nullable legacy result', () {
    final result = mapFinanceResult(samples['FinanceResult']);
    expect(result.monthlyPaymentVnd.wireValue, '10796711');
    expect(result.totalInterestVnd.wireValue, '1391210961');
    expect(result.totalRepaymentVnd.wireValue, '2591210961');
    expect(result.formulaVersion, 'xland-loan-v1');
    expect(result.roundingRule, 'VND_HALF_UP_MONTHLY_LAST_ADJUST');
    expect(
      mapSavedFinancePlan(samples['SavedFinancePlanLegacy']).result,
      isNull,
    );
    expect(
      mapSavedFinancePlan(samples['SavedFinancePlanCalculated']).result,
      isNotNull,
    );
    final invalid = Map<String, Object?>.from(
      wireObject(samples['FinanceResult']),
    )..['monthlyPaymentVnd'] = 10796711;
    expect(() => mapFinanceResult(invalid), throwsFormatException);
  });
  test('C-4 finance repository posts input only, preserves retry key and reads saved snapshot', () async {
    final input = mapFinanceResult(samples['FinanceResult']).input;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/finance/estimates')) {
        final body = wireObject(jsonDecode(request.body));
        expect(body['loanVnd'], '1200000000');
        expect(body.containsKey('result'), isFalse);
        return http.Response(
          jsonEncode({'data': samples['FinanceResult']}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'POST') {
        expect(request.headers['Idempotency-Key'], 'c4-finance-test-key01');
        final body = wireObject(jsonDecode(request.body));
        expect(body.keys.toSet(), {'label', 'input'});
        return http.Response(
          jsonEncode({'data': samples['SavedFinancePlanCalculated']}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'data': [
            samples['SavedFinancePlanLegacy'],
            samples['SavedFinancePlanCalculated'],
          ],
          'meta': {'hasMore': false, 'nextCursor': null, 'total': null},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final transport = HttpApiTransport(
      baseUrl: Uri.parse('https://example.invalid/api/v1'),
      client: client,
      sessions: _Sessions(),
    );
    final repository = RemoteFinanceRepository(RemoteGateway(transport));
    expect(
      (await repository.calculate(input)).monthlyPaymentVnd.wireValue,
      '10796711',
    );
    expect(
      (await repository.savePlan(
        'Minh họa',
        input,
        idempotencyKey: 'c4-finance-test-key01',
      )).result,
      isNotNull,
    );
    final plans = await repository.getPlans(const PageQuery());
    expect(plans.items.first.result, isNull);
    expect(plans.items.last.result?.formulaVersion, 'xland-loan-v1');
    client.close();
  });
}
