import 'package:myapp/core/network/api_client.dart';
import 'package:myapp/core/activity/activity_service.dart';
import 'package:myapp/features/auth/data/auth_service.dart';
import 'package:myapp/features/chat/data/chat_service.dart';
import 'package:myapp/features/destinations/data/destination_service.dart';
import 'package:myapp/features/feedback/data/feedback_service.dart';
import 'package:myapp/features/media/data/media_service.dart';
import 'package:myapp/core/locale/locale_controller.dart';
import 'package:myapp/core/navigation/navigation_service.dart';
import 'package:myapp/core/session/session_store.dart';
import 'package:myapp/features/plan/data/trip_service.dart';
import 'package:myapp/features/diary/data/travel_diary_automation_service.dart';
import 'package:myapp/features/diary/data/travel_diary_service.dart';
import 'package:myapp/features/plan/data/trip_generation_status_service.dart';

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
  static final TripGenerationStatusService tripGenerationStatus =
      TripGenerationStatusService();
}
