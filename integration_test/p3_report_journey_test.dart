// Full app navigation with real repositories, Android plugins and the owned
// Supabase mock API. Private credentials arrive after install, never in defines.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:xland_mobile/data/datasources/local/secure_session_store.dart';
import 'package:xland_mobile/data/datasources/remote/http_api_transport.dart';
import 'package:xland_mobile/data/demo/demo_media_repositories.dart';
import 'package:xland_mobile/data/repositories/local_guest_preferences_repository.dart';
import 'package:xland_mobile/data/repositories/remote_repositories.dart';
import 'package:xland_mobile/data/repositories/remaining_repositories.dart';
import 'package:xland_mobile/domain/xland_domain.dart';
import 'package:xland_mobile/presentation/app/xland_app.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_cubit.dart';
import 'package:xland_mobile/presentation/features/auth/cubit/auth_state.dart';
import 'package:xland_mobile/presentation/features/auth/pages/login_page.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_sheet.dart';
import 'package:xland_mobile/presentation/features/booking/pages/booking_detail_page.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/property_card.dart';
import 'package:xland_mobile/presentation/features/discovery/widgets/hero_carousel.dart';
import 'package:xland_mobile/presentation/features/clubs/pages/club_list_page.dart';
import 'package:xland_mobile/presentation/features/consultant/pages/consultant_profile_page.dart';
import 'package:xland_mobile/presentation/features/events/pages/event_detail_page.dart';
import 'package:xland_mobile/presentation/features/feed/widgets/comments_sheet.dart';
import 'package:xland_mobile/presentation/features/property_detail/pages/property_detail_page.dart';
import 'package:xland_mobile/presentation/features/shell/main_navigation_shell.dart';
import 'package:xland_mobile/presentation/shared/widgets/widgets.dart';
import 'support/private_input.dart';
import 'support/trace_client.dart';

/// Delays or drops a response AFTER the real server has processed it. Only
/// owned report actions are armed; no service/DB fault is injected remotely.
class _JourneyNetwork extends http.BaseClient {
  final http.Client delegate=http.Client();
  final Set<String> dropOnce={};
  final Set<String> dropped={};
  String? holdNextGet;
  Completer<void>? held;
  Completer<void>? release;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response=await delegate.send(request);
    if(request.method=='GET'&&request.url.path==holdNextGet){
      holdNextGet=null;held!.complete();await release!.future;
    }
    if(request.method=='POST'&&response.statusCode<300&&dropOnce.remove(request.url.path)){
      await response.stream.drain<void>();dropped.add(request.url.path);
      throw http.ClientException('Intentional local response loss after commit');
    }
    return response;
  }
  @override
  void close()=>delegate.close();
}

void main(){
  final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled=bool.fromEnvironment('XLAND_P3_AFTER_T0');
  testWidgets('P3 report journey actual app navigation, login, booking and profile', (t) async {
    final input=await readW1Input();
    if(input['t0Authorized']!=true) throw StateError('A/T0 authorization required');
    String v(String key)=>input[key]! as String;
    final network=_JourneyNetwork();
    final client=TraceClient(network);
    const storage=FlutterSecureStorage(aOptions:AndroidOptions(storageNamespace:'xland-p3-report-journey'));
    final sessions=SecureSessionStore(storage);
    if(await sessions.readAccessToken()!=null) throw StateError('Preserve unexpected report canary session');
    final gateway=RemoteGateway(HttpApiTransport(baseUrl:Uri.parse(v('apiBaseUrl')),
      client:client,sessions:sessions,allowLocalHttp:true));
    final account=RemoteAccountRepository(gateway,sessions);
    final overlay=DemoMediaOverlay(Uri.parse(const String.fromEnvironment('XLAND_DEMO_MEDIA_BASE_URL')),reportMode:true);
    final dependencies=XlandDependencies(
      properties:RemotePropertyRepository(gateway),account:account,
      feed:DemoMediaFeedRepository(RemoteFeedRepository(gateway),overlay),
      consultants:DemoMediaConsultantRepository(RemoteConsultantRepository(gateway),overlay),
      events:RemoteEventRepository(gateway),bookings:RemoteBookingRepository(gateway),
      payments:RemotePaymentRepository(gateway),clubs:RemoteClubRepository(gateway),
      finance:RemoteFinanceRepository(gateway),support:RemoteSupportRepository(gateway),
      guestPreferences:LocalGuestPreferencesRepository(storage),
    );
    final checkpoints=<Map<String,Object?>>[];
    final screenshots=<Map<String,Object?>>[];
    String stage='startup';
    Future<void> tick([int count=4]) async {for(var i=0;i<count;i++){await t.pump(const Duration(milliseconds:100));}}
    Future<void> wait(bool Function() ready,String reason) async {
      final deadline=DateTime.now().add(const Duration(seconds:45));
      while(!ready()&&DateTime.now().isBefore(deadline)){await tick(1);}
      expect(ready(),true,reason:reason);
      await tick(2);
    }
    Future<void> tap(String text) async {
      final finder=find.text(text).first;
      await t.ensureVisible(finder);await t.tap(finder);await tick();
    }
    Future<void> nav(String text) async {
      final finder=find.descendant(of:find.byType(XLandBottomNavBar),matching:find.text(text));
      await t.tap(finder);await tick();
    }
    Future<void> back() async {await binding.handlePopRoute();await tick();}
    Future<void> shot(String id,String state,{String? resourceId}) async {
      await tick();
      final bytes=await binding.takeScreenshot(id);
      binding.reportData?.remove('screenshots');
      expect(bytes.take(4).toList(),[137,80,78,71]);
      final dir=Directory('/data/user/0/vn.xland.xland_mobile.cproof/files/p3-report-images');
      await dir.create(recursive:true);
      await File('${dir.path}/$id.png').writeAsBytes(bytes,flush:true);
      screenshots.add({'file':'$id.png','screenId':id,'state':state,'resourceId':resourceId,
        'physicalWidth':t.view.physicalSize.width,'physicalHeight':t.view.physicalSize.height,
        'dpr':t.view.devicePixelRatio,'textScale':MediaQuery.textScalerOf(t.element(find.byType(Scaffold).last)).scale(14)/14,
        'keyboardInset':MediaQuery.viewInsetsOf(t.element(find.byType(Scaffold).last)).bottom});
      debugPrint('P3_SCREEN_READY $id');
    }
    int bookingPosts()=>client.records.where((r)=>r['method']=='POST'&&r['path']=='/api/v1/bookings').length;
    late AuthCubit appAuth;
    AuthCubit auth()=>appAuth;
    try {
      await t.pumpWidget(XLandApp(dependencies:dependencies,showDeveloperTools:false));
      await wait(()=>find.byType(VideoPlayer).evaluate().isNotEmpty &&
        t.widget<VideoPlayer>(find.byType(VideoPlayer).first).controller.value.isInitialized,'Native feed initializes');
      appAuth=t.element(find.byType(MainNavigationShell)).read<AuthCubit>();
      final player=t.widget<VideoPlayer>(find.byType(VideoPlayer).first).controller;
      if(player.value.isPlaying) {
        final rect=t.getRect(find.byType(VideoPlayer).first);
        await t.tapAt(rect.topLeft+const Offset(24,140));await tick();
      }
      expect(player.value.isPlaying,false);
      await binding.convertFlutterSurfaceToImage();await tick();
      await shot('S00','guest feed initialized, paused');
      stage='discovery';await nav('Khám phá');
      await wait(()=>find.byType(PropertyCard).evaluate().isNotEmpty,'Catalog loads from API');
      await shot('S01','real property catalog');
      await t.tap(find.byIcon(Icons.tune_rounded));await tick();
      await wait(()=>find.textContaining('lô phù hợp').evaluate().isNotEmpty,'Filter result count completes');
      await shot('S09','filter form');await back();
      await t.scrollUntilVisible(find.text('Sự kiện XLand'),220,
        scrollable:find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first);
      await tap('Sự kiện XLand');
      await wait(()=>find.byType(EventDetailPage).evaluate().isNotEmpty&&find.text('Chi tiết sự kiện').evaluate().isNotEmpty&&
        find.textContaining('Thời lượng').evaluate().isNotEmpty,'Featured event loads');
      await shot('S07','real upcoming demo event');await back();
      await t.drag(find.byType(HeroCarousel),const Offset(-300,0));await tick();
      await tap('CLB Nhà đầu tư đất nền');
      await wait(()=>find.byType(ClubListPage).evaluate().isNotEmpty&&
        find.text('Cộng đồng nhà đầu tư XLand').evaluate().isNotEmpty,'Community information loads');
      await shot('S13','read-only community clubs');await back();
      // Return the carousel to its event page before leaving discovery.
      // Vertical scrolling cannot reveal a different horizontal page later.
      await t.drag(find.byType(HeroCarousel),const Offset(300,0));await tick();
      final card=find.byWidgetPredicate((w)=>w is PropertyCard&&w.property.id==v('propertyId'));
      await t.scrollUntilVisible(card,-220,scrollable:find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first);
      await t.tap(card);await tick();
      await wait(()=>find.byType(PropertyDetailPage).evaluate().isNotEmpty&&find.text('Thông số thửa đất').evaluate().isNotEmpty,'Property overview loads');
      await shot('S02','overview',resourceId:v('propertyId'));
      await tap('Pháp lý');await shot('S03','legal metadata; download deferred',resourceId:v('propertyId'));
      await tap('Khu vực');await shot('S04','area information; provider map deferred',resourceId:v('propertyId'));
      await tap('Tài chính');
      await wait(()=>find.textContaining('Khoản trả hàng tháng').evaluate().isNotEmpty,'Finance calculation returns');
      await shot('S05_FORM','finance form',resourceId:v('propertyId'));
      final resultCard=find.ancestor(of:find.textContaining('Khoản trả hàng tháng').first,matching:find.byType(Container)).first;
      await t.ensureVisible(resultCard);await tick();
      await shot('S05','equal installment result',resourceId:v('propertyId'));
      await tap('Tổng quan');
      await wait(()=>find.text('Liên hệ').evaluate().isNotEmpty,'Assigned consultant loads');
      await tap('Liên hệ');
      await wait(()=>find.byType(ConsultantProfilePage).evaluate().isNotEmpty&&find.text('Video thực địa').evaluate().isNotEmpty,'Consultant profile loads');
      await shot('S06','synthetic consultant profile');await back();
      stage='guest-booking';await tap('Xem thực địa');
      await wait(()=>find.textContaining(v('slotLabel')).evaluate().isNotEmpty,'Owned future slot available');
      final ownedSlot=find.textContaining(v('slotLabel'));
      await t.ensureVisible(ownedSlot);await t.tap(ownedSlot);await tick();
      final fields=find.descendant(of:find.byType(BookingSheet),matching:find.byType(TextField));
      await t.enterText(fields.at(0),'Minh An');await t.enterText(fields.at(1),v('contactPhone'));
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      await wait(()=>MediaQuery.viewInsetsOf(t.element(find.byType(Scaffold).last)).bottom>0,'Actual Android keyboard visible');
      await shot('S08_KEYBOARD','guest form with actual Android IME');
      FocusManager.instance.primaryFocus?.unfocus();await tick();
      await shot('S08_FORM','guest booking draft',resourceId:v('propertyId'));
      await tap('Xem lại thông tin đặt lịch');expect(bookingPosts(),0);
      await shot('S08_REVIEW','review, zero booking POST',resourceId:v('propertyId'));
      await tap('Xác nhận đặt lịch');await tap('Đăng nhập ngay');
      await wait(()=>find.byType(LoginPage).evaluate().isNotEmpty,'Login route opens');
      // Capture before entering credentials; never capture a filled login page.
      await shot('LOGIN','empty login form');
      final loginFields=find.byType(TextField);
      await t.enterText(loginFields.first,v('usernameA'));await t.enterText(loginFields.last,v('passwordA'));
      await t.tap(find.widgetWithText(PrimaryButton,'Đăng nhập'));
      await wait(()=>find.text('Xác nhận thông tin đặt lịch').evaluate().isNotEmpty,'Login returns to booking review');
      expect(bookingPosts(),0);
      checkpoints.add({'case':'E03','stage':'after_real_login','bookingPosts':0});
      await tap('Xác nhận đặt lịch');
      await wait(()=>find.text('Đặt lịch thực địa thành công!').evaluate().isNotEmpty,'Booking succeeds after reconfirm');
      expect(bookingPosts(),1);
      final history=await dependencies.bookings.getHistory(const PageQuery(limit:50));
      // Newest owned booking from this deliberate test run; earlier harness
      // failures preserve their records rather than resetting shared inventory.
      final booking=history.items.firstWhere((b)=>b.slotId==v('slotId')&&b.contactName=='Minh An');
      expect(booking.status,BookingStatus.awaitingDeposit);expect(booking.paymentStatus,PaymentStatus.unpaid);
      checkpoints.add({'case':'E03','bookingId':booking.id,'bookingPosts':1,'status':booking.status.name,'payment':booking.paymentStatus.name});
      await shot('S08_SUCCESS','awaiting deposit, unpaid',resourceId:booking.id);
      await tap('Đóng và xem lịch hẹn');
      await back();await nav('Giao dịch');
      await wait(()=>find.text('Chi tiết lịch').evaluate().isNotEmpty,'Owner history loads');
      await shot('S10','owner booking history');
      await tap('Chi tiết lịch');
      await wait(()=>find.byType(BookingDetailPage).evaluate().isNotEmpty&&find.text('Bất động sản khảo sát').evaluate().isNotEmpty,'Booking detail loads');
      await shot('S12','booking detail, payment deferred',resourceId:booking.id);await back();
      stage='profile';await nav('Tôi');
      final oldName=(await dependencies.account.getProfile()).displayName;
      final profileName=oldName=='Minh An • XLand'?'Minh An':'Minh An • XLand';
      await tap('Chỉnh sửa hồ sơ');
      await wait(()=>find.byType(TextField).evaluate().isNotEmpty,'Profile editor loads');
      await t.enterText(find.byType(TextField).first,profileName);await tap('Lưu thay đổi');
      await wait(()=>auth().state is AuthAuthenticated &&
        (auth().state as AuthAuthenticated).session.profile.displayName==profileName&&
        find.byType(MainNavigationShell).evaluate().isNotEmpty,'Same owner profile refresh reaches shell');
      expect(find.text(profileName),findsOneWidget);
      checkpoints.add({'case':'E06/P3-004','profileTileRefreshed':true});
      await shot('S11','updated synthetic owner profile');
      await tap('Cài đặt ứng dụng');
      await wait(()=>find.text('Tự động phát video').evaluate().isNotEmpty,'Owner settings loads');
      await shot('SETTINGS','owner settings');await back();

      stage='owner-actions';await nav('Trang chủ');
      await wait(()=>find.byType(VideoPlayer).evaluate().isNotEmpty,'Owner feed visible');
      final currentVideo=t.widget<VideoPlayer>(find.byType(VideoPlayer).first).controller;
      if(currentVideo.value.isPlaying){
        await t.tapAt(t.getRect(find.byType(VideoPlayer).first).topLeft+const Offset(24,140));await tick();
      }
      await t.tap(find.byIcon(Icons.mode_comment_outlined).first);await tick();
      await wait(()=>find.byType(CommentsSheet).evaluate().isNotEmpty&&find.byType(TextField).evaluate().isNotEmpty,'Comments load');
      final commentSheet=t.widget<CommentsSheet>(find.byType(CommentsSheet));
      final commentPath='/api/v1/videos/${commentSheet.videoId}/comments';
      final comment='XLand báo cáo • ${DateTime.now().millisecondsSinceEpoch}';
      network.dropOnce.add(commentPath);
      await t.enterText(find.byType(TextField).last,comment);
      FocusManager.instance.primaryFocus?.unfocus();await tick();
      await t.tap(find.byIcon(Icons.send_rounded));
      await wait(()=>network.dropped.contains(commentPath)&&find.byIcon(Icons.send_rounded).evaluate().isNotEmpty,'Response loss reaches comment retry UI');
      expect(t.widget<TextField>(find.byType(TextField).last).controller!.text,comment);
      await t.tap(find.byIcon(Icons.send_rounded));
      await wait(()=>t.widget<TextField>(find.byType(TextField).last).controller!.text.isEmpty&&
        find.text(comment).evaluate().isNotEmpty,'Same comment retry succeeds and clears composer');
      final commentPosts=client.records.where((r)=>r['method']=='POST'&&r['path']==commentPath).toList();
      expect(commentPosts.length,2);expect(commentPosts.first['keySha256'],commentPosts.last['keySha256']);
      expect(commentPosts.first['payloadSha256'],commentPosts.last['payloadSha256']);
      final comments=await dependencies.feed.getComments(commentSheet.videoId,const PageQuery(limit:50));
      expect(comments.items.where((c)=>c.text==comment).length,1);
      checkpoints.add({'case':'E05','responseLostAfterCommit':true,'sameKey':true,'persistedComments':1});
      await back();

      stage='finance-support';await nav('Khám phá');
      await t.scrollUntilVisible(card,-220,scrollable:find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first);
      await t.tap(card);await tick();
      await wait(()=>find.text('Thông số thửa đất').evaluate().isNotEmpty,'Owner property loads');
      await tap('Tài chính');
      await wait(()=>find.textContaining('Khoản trả hàng tháng').evaluate().isNotEmpty,'Initial owner estimate');
      network.dropOnce.add('/api/v1/finance/estimates');await tap('Dư nợ giảm dần');
      await wait(()=>network.dropped.contains('/api/v1/finance/estimates')&&find.text('Thử lại').evaluate().isNotEmpty,'Finance transport loss produces retry');
      expect(t.widget<PrimaryButton>(find.widgetWithText(PrimaryButton,'Lưu kế hoạch tài chính')).onPressed,isNull);
      await tap('Thử lại');
      await wait(()=>find.textContaining('Khoản trả tháng đầu').evaluate().isNotEmpty,'Declining estimate retry');
      await tap('Lưu kế hoạch tài chính');
      await wait(()=>find.byTooltip('Xóa kế hoạch').evaluate().isNotEmpty,'Saved plan appears in real history');
      final plans=await dependencies.finance.getPlans(const PageQuery(limit:50));
      final plan=plans.items.firstWhere((p)=>p.propertyId==v('propertyId')&&p.input.method==RepaymentMethod.decliningBalance);
      expect(plan.result!.monthlyPaymentVnd.wireValue,'14000000');
      await t.ensureVisible(find.byTooltip('Xóa kế hoạch').first);await t.tap(find.byTooltip('Xóa kế hoạch').first);
      await wait(()=>find.byTooltip('Xóa kế hoạch').evaluate().isEmpty,'Deleted plan removed from UI');
      expect((await dependencies.finance.getPlans(const PageQuery(limit:50))).items.any((p)=>p.id==plan.id),false);
      checkpoints.add({'case':'E07','staleSaveDisabled':true,'retry':true,'exactMonthlyVnd':'14000000','saveHistoryDeleteReload':true});
      await tap('Tổng quan');await tap('Liên hệ');
      await wait(()=>find.text('Đặt lịch tư vấn').evaluate().isNotEmpty,'Consultant owner page');
      await tap('Đặt lịch tư vấn');
      await wait(()=>find.text('Gửi phiếu yêu cầu').evaluate().isNotEmpty,'Support form opens');
      final beforeTicketIds=(await dependencies.support.getRequests(const PageQuery(limit:50))).items.map((s)=>s.id).toSet();
      expect(t.widget<PrimaryButton>(find.widgetWithText(PrimaryButton,'Gửi phiếu yêu cầu')).onPressed,isNull);
      final supportFields=find.byType(TextField);
      final message='Tìm hiểu XLand • ${DateTime.now().millisecondsSinceEpoch}';
      await t.enterText(supportFields.at(0),'Minh An');await t.enterText(supportFields.at(1),v('contactPhone'));await t.enterText(supportFields.at(2),message);
      FocusManager.instance.primaryFocus?.unfocus();await tick();await t.tap(find.byType(Checkbox));await tick();
      network.dropOnce.add('/api/v1/support-requests');await tap('Gửi phiếu yêu cầu');
      await wait(()=>network.dropped.contains('/api/v1/support-requests')&&find.text('Gửi phiếu yêu cầu').evaluate().isNotEmpty,'Support response loss allows retry');
      await tap('Gửi phiếu yêu cầu');
      await wait(()=>find.text('Gửi phiếu yêu cầu').evaluate().isEmpty,'Support retry returns to consultant');
      final tickets=await dependencies.support.getRequests(const PageQuery(limit:50));
      expect(tickets.items.where((s)=>!beforeTicketIds.contains(s.id)).length,1);
      final supportPosts=client.records.where((r)=>r['method']=='POST'&&r['path']=='/api/v1/support-requests').toList();
      expect(supportPosts.length,2);expect(supportPosts.first['keySha256'],supportPosts.last['keySha256']);
      checkpoints.add({'case':'E08','consentGate':true,'supportSameKey':true,'persistedTickets':1});
      await back();await back();

      // Real future report event; a lost response must not consume a second seat.
      await nav('Khám phá');
      await t.scrollUntilVisible(find.text('Sự kiện XLand'),220,
        scrollable:find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first);
      await tap('Sự kiện XLand');
      await wait(()=>find.textContaining('Đăng ký tham gia ngay').evaluate().isNotEmpty,'Open event loaded');
      final priorRegistrations=(await dependencies.events.getRegistrations(const PageQuery(limit:50))).items.where((r)=>r.eventId==v('eventId')).toList();
      if(priorRegistrations.isEmpty){
      final eventBefore=await dependencies.events.getEvent(v('eventId'));
      await t.tap(find.textContaining('Đăng ký tham gia ngay'));await tick();
      final registrationFields=find.byType(TextField);
      await t.enterText(registrationFields.first,'Minh An');await t.enterText(registrationFields.last,v('contactPhone'));
      FocusManager.instance.primaryFocus?.unfocus();await tick();
      final registrationPath='/api/v1/events/${v('eventId')}/registrations';
      network.dropOnce.add(registrationPath);await tap('Xác nhận đăng ký');
      await wait(()=>network.dropped.contains(registrationPath)&&find.text('Xác nhận đăng ký').evaluate().isNotEmpty,'Event response loss allows retry');
      await tap('Xác nhận đăng ký');
      await wait(()=>find.text('Đăng ký thành công').evaluate().isNotEmpty,'Event retry succeeds');
      final eventPosts=client.records.where((r)=>r['method']=='POST'&&r['path']==registrationPath).toList();
      expect(eventPosts.length,2);expect(eventPosts.first['keySha256'],eventPosts.last['keySha256']);
      final registrations=await dependencies.events.getRegistrations(const PageQuery(limit:50));
      expect(registrations.items.where((r)=>r.eventId==v('eventId')).length,1);
      expect((await dependencies.events.getEvent(v('eventId'))).remainingSlots,eventBefore.remainingSlots-1);
      checkpoints.add({'case':'E08','sameKey':true,'registrations':1,'capacityConsumed':1});
      await tap('Đóng');
      }else{
        expect(priorRegistrations.length,1);
        checkpoints.add({'case':'E08_RECHECK','existingOwnedRegistrationReload':true,
          'uiResponseLossRetryProof':'20261018T143755253Z; event UI/repositories unchanged; no second registration submitted'});
      }
      await back();

      // Hold an actual owner-A history response across logout and UI login as B.
      stage='owner-switch';await nav('Giao dịch');
      network.holdNextGet='/api/v1/me/bookings';network.held=Completer<void>();network.release=Completer<void>();
      final refresh=t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await wait(()=>network.held!.isCompleted,'Owner A response held');
      await nav('Tôi');
      await tap('Đăng xuất');
      await wait(()=>auth().state is AuthGuest,'Logout clears owner UI');
      await tap('Đăng nhập');
      await wait(()=>find.byType(LoginPage).evaluate().isNotEmpty,'B login route');
      await t.enterText(find.byType(TextField).first,v('usernameB'));await t.enterText(find.byType(TextField).last,v('passwordB'));
      await t.tap(find.widgetWithText(PrimaryButton,'Đăng nhập'));
      await wait(()=>find.byType(LoginPage).evaluate().isEmpty&&auth().state is AuthAuthenticated,'Owner B session');
      await nav('Giao dịch');
      await wait(()=>find.text('Bạn chưa có lịch hẹn thực địa nào.').evaluate().isNotEmpty,'B has no A history');
      network.release!.complete();await refresh;await tick();
      expect(find.text('Bạn chưa có lịch hẹn thực địa nào.'),findsOneWidget);
      expect(find.text('Chi tiết lịch'),findsNothing);
      expect((await dependencies.bookings.getHistory(const PageQuery(limit:50))).items,isEmpty);
      checkpoints.add({'case':'E04','actualDelayedOwnerResponse':true,'ownerBSawNoAHistory':true});
      // Revoke only this own B session remotely, leaving the local token until
      // an actual UI private read receives 401 and clears token + shell state.
      final token=await sessions.readAccessToken();expect(token,isNotNull);
      final revoked=await client.delete(Uri.parse('${v('apiBaseUrl')}/auth/sessions/current'),
        headers:{'Authorization':'Bearer $token'});
      expect(revoked.statusCode,200);expect(await sessions.readAccessToken(),token);
      await nav('Tôi');await tap('Chỉnh sửa hồ sơ');
      await wait(()=>auth().state is AuthGuest,'Real UI private GET 401 clears session and shell');
      expect(await sessions.readAccessToken(),isNull);await back();await nav('Giao dịch');
      expect(find.textContaining('Vui lòng đăng nhập'),findsWidgets);
      checkpoints.add({'case':'E04','actualUi401ClearsTokenAndShell':true,'ownSessionRevoked':true});
      final guestPlayback=await dependencies.guestPreferences!.read();
      expect(guestPlayback.feedAutoplay,true);expect(guestPlayback.feedMutedByDefault,false);
      checkpoints.add({'case':'E06/GP-1','guestPreferencesUnchangedByTwoOwners':true});
    } finally {
      if(network.release!=null&&!network.release!.isCompleted) network.release!.complete();
      if(await sessions.readAccessToken()!=null) await account.signOut();
      await writeW1Report({'stage':input['stage'],'lastStage':stage,'checkpoints':checkpoints,
        'screenshots':screenshots,'http':client.records},hold:const Duration(seconds:20));
      await t.pumpWidget(const SizedBox.shrink());client.close();
    }
  },skip:!enabled,timeout:const Timeout(Duration(minutes:15)));
}
