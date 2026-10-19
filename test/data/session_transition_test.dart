import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xland_mobile/data/datasources/local/session_store.dart';
import 'package:xland_mobile/data/datasources/remote/api_transport.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

class MemorySessionStore implements SessionStore {
  String? token='A'*43;
  @override Future<String?> readAccessToken() async=>token;
  @override Future<void> saveAccessToken({required String accessToken}) async { token=accessToken; }
  @override Future<void> clear() async { token=null; }
  @override Future<void> clearIfMatches({required String accessToken}) async {
    if(token==accessToken) token=null;
  }
}

void main(){
  test('late 401 for owner A does not erase the new owner B token',() async {
    final store=MemorySessionStore();
    final response=Completer<http.Response>();
    final client=MockClient((request) async {
      expect(request.headers['Authorization'],'Bearer ${'A'*43}');
      return response.future;
    });
    addTearDown(client.close);
    final transport=HttpApiTransport(baseUrl:Uri.parse('https://test.invalid/api/v1'),client:client,sessions:store);
    final pending=transport.send(const ApiRequest(method:'GET',path:'/me/bookings'));
    final expectation=expectLater(pending,throwsA(isA<XlandFailure>()));
    await Future<void>.delayed(Duration.zero);
    await store.saveAccessToken(accessToken:'B'*43);
    response.complete(http.Response('{"error":{"code":"UNAUTHENTICATED","message":"expired"}}',401));
    await expectation;
    expect(await store.readAccessToken(),'B'*43);
  });
}
