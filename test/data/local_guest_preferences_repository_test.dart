import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xland_mobile/data/repositories/local_guest_preferences_repository.dart';
import 'package:xland_mobile/domain/xland_domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel=MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String,String> values;
  Completer<void>? firstWrite;
  bool failWrite=false;
  var writes=0;
  setUp(() {
    values={'xland.access_token.v1':'TOKEN_MUST_REMAIN'};
    firstWrite=null; failWrite=false; writes=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call) async {
      final args=Map<String,Object?>.from(call.arguments as Map);
      final key=args['key'] as String;
      switch(call.method) {
        case 'read': return values[key];
        case 'write':
          if(failWrite) throw PlatformException(code:'WRITE_FAILED',message:'native details must not leak');
          if(++writes==1 && firstWrite!=null) await firstWrite!.future;
          values[key]=args['value'] as String; return null;
        case 'delete': values.remove(key); return null;
        default: throw StateError('unexpected method');
      }
    });
  });
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  LocalGuestPreferencesRepository create()=>LocalGuestPreferencesRepository(const FlutterSecureStorage());
  test('new repository reads persisted values and clear preserves the account token',() async {
    final first=create();
    await first.update(const GuestPreferenceUpdate(feedAutoplay:false,feedMutedByDefault:true));
    final recreated=create();
    expect((await recreated.read()).feedAutoplay,false);
    expect((await recreated.read()).feedMutedByDefault,true);
    await recreated.clear();
    expect((await create().read()).feedAutoplay,true);
    expect(values['xland.access_token.v1'],'TOKEN_MUST_REMAIN');
  });
  test('concurrent patches serialize without losing the earlier field',() async {
    firstWrite=Completer<void>();
    final repository=create();
    final a=repository.update(const GuestPreferenceUpdate(feedAutoplay:false));
    final b=repository.update(const GuestPreferenceUpdate(feedMutedByDefault:true));
    await Future<void>.delayed(Duration.zero);
    expect(writes,1);
    firstWrite!.complete();
    await Future.wait([a,b]);
    final result=await create().read();
    expect(result.feedAutoplay,false);
    expect(result.feedMutedByDefault,true);
  });
  test('malformed or wrongly typed stored data falls back to defaults',() async {
    for(final raw in ['broken',jsonEncode({'version':1,'feedAutoplay':'false','feedMutedByDefault':true})]) {
      values[LocalGuestPreferencesRepository.storageKey]=raw;
      final result=await create().read();
      expect(result.feedAutoplay,true);
      expect(result.feedMutedByDefault,false);
    }
  });
  test('failed write is typed and does not poison a subsequent retry',() async {
    final repository=create();
    failWrite=true;
    await expectLater(repository.update(const GuestPreferenceUpdate(feedAutoplay:false)),throwsA(isA<XlandFailure>()));
    expect((await repository.read()).feedAutoplay,true);
    failWrite=false;
    await repository.update(const GuestPreferenceUpdate(feedAutoplay:false));
    expect((await create().read()).feedAutoplay,false);
  });
}
