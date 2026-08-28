import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/activity_service.dart';
import 'package:myapp/services/auth_service.dart';
import 'package:myapp/services/chat_service.dart';
import 'package:myapp/services/destination_service.dart';
import 'package:myapp/services/feedback_service.dart';
import 'package:myapp/services/media_service.dart';
import 'package:myapp/services/locale_controller.dart';
import 'package:myapp/services/navigation_service.dart';
import 'package:myapp/services/session_store.dart';
import 'package:myapp/services/trip_service.dart';
import 'package:myapp/services/travel_diary_automation_service.dart';
import 'package:myapp/services/travel_diary_service.dart';

/// Composition root: ประกอบ service จริงของแอปเพียงจุดเดียว
/// domain service แต่ละตัวรับ dependency ทาง constructor จึงสร้างชุด mock แยกใน test ได้
class AppServices {
  AppServices._();

  static final SessionState session = SessionState();
  static final LocaleController locale = LocaleController();
  static final ApiClient client = ApiClient(
    tokenProvider: () => session.token,
    languageProvider: () => locale.languageCode,
  );
  static final AuthService auth = AuthService(
    client: client,
    session: session,
    store: SharedPreferencesSessionStore(),
  );
  static final ActivityService activity = ActivityService(
    client: client,
    isAuthenticated: () => session.token?.isNotEmpty == true,
  );
  static final DestinationService destinations = DestinationService(
    client: client,
  );
  static final TripService trips = TripService(client: client);
  static final ChatService chat = ChatService(client: client);
  static final MediaService media = MediaService(client: client);
  static final TravelDiaryService diary = TravelDiaryService(client: client);
  static final TravelDiaryAutomationService diaryAutomation =
      TravelDiaryAutomationService(
        destinations: destinations,
        diary: diary,
        currentUser: () => session.currentUser,
      );
  static final FeedbackService feedback = FeedbackService(client: client);
  static final NavigationService navigator = NavigationService.instance;
}
