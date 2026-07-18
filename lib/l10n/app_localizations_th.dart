// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'GoThai';

  @override
  String get home => 'หน้าหลัก';

  @override
  String get map => 'แผนที่';

  @override
  String get plan => 'วางแผน';

  @override
  String get profile => 'โปรไฟล์';

  @override
  String get profileUpdated => 'อัปเดตโปรไฟล์สำเร็จ';

  @override
  String get profileUpdateFailed => 'ไม่สามารถอัปเดตโปรไฟล์ได้';

  @override
  String get setYourName => 'กรุณาตั้งชื่อ';

  @override
  String get myInterests => 'ความสนใจของฉัน';

  @override
  String get edit => 'แก้ไข';

  @override
  String get noInterests => 'ยังไม่ได้เพิ่มความสนใจ แตะแก้ไขเพื่อปรับแต่ง';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get accountSettings => 'ตั้งค่าบัญชี';

  @override
  String get language => 'ภาษา';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'ไทย';

  @override
  String get selectLanguage => 'เลือกภาษา';

  @override
  String get editInterests => 'แก้ไขความสนใจ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get save => 'บันทึก';

  @override
  String get logOut => 'ออกจากระบบ';

  @override
  String get logOutConfirmation => 'คุณต้องการออกจากระบบ GoThai ใช่หรือไม่';

  @override
  String get interestFood => 'อาหาร';

  @override
  String get interestCafe => 'คาเฟ่';

  @override
  String get interestNature => 'ธรรมชาติ';

  @override
  String get interestBeach => 'ชายหาด';

  @override
  String get interestTemple => 'วัด';

  @override
  String get interestAdventure => 'ผจญภัย';

  @override
  String get interestShopping => 'ชอปปิง';

  @override
  String get interestNightlife => 'ชีวิตกลางคืน';

  @override
  String get interestCulture => 'วัฒนธรรม';

  @override
  String get readyToExplore => 'พร้อมสำรวจประเทศไทยแล้วหรือยัง';

  @override
  String get aiTravelSuite => 'ชุดเครื่องมือท่องเที่ยว AI';

  @override
  String get planTravel => 'วางแผนเที่ยว';

  @override
  String get chatbot => 'แชตบอต';

  @override
  String get scanWithAi => 'สแกนด้วย AI';

  @override
  String get destinations => 'สถานที่ท่องเที่ยว';

  @override
  String get seeAll => 'ดูทั้งหมด';

  @override
  String get couldNotLoadTatDestinations => 'ไม่สามารถโหลดสถานที่จาก TAT ได้';

  @override
  String get pullDownTryAgain => 'ดึงลงเพื่อลองอีกครั้ง';

  @override
  String get noDestinationsYet => 'ยังไม่มีสถานที่ท่องเที่ยว';

  @override
  String get tatReturnedNoImages => 'TAT API ไม่พบสถานที่ที่มีรูปภาพ';

  @override
  String get failedToLoadDestinations => 'ไม่สามารถโหลดสถานที่ท่องเที่ยวได้';

  @override
  String get changeProfilePhoto => 'เปลี่ยนรูปโปรไฟล์';

  @override
  String get chooseFromGallery => 'เลือกจากคลังภาพ';

  @override
  String get takePhoto => 'ถ่ายรูป';

  @override
  String get enterImageUrl => 'ใส่ URL รูปภาพ';

  @override
  String get editProfileImageUrl => 'แก้ไข URL รูปโปรไฟล์';

  @override
  String get imageUrlHint => 'กรอก URL ของรูปภาพ';

  @override
  String get editUsername => 'แก้ไขชื่อผู้ใช้';

  @override
  String get newUsernameHint => 'กรอกชื่อผู้ใช้ใหม่';

  @override
  String get accountInformation => 'ข้อมูลบัญชี';

  @override
  String get username => 'ชื่อผู้ใช้';

  @override
  String get email => 'อีเมล';

  @override
  String get notSet => 'ยังไม่ได้ตั้งค่า';

  @override
  String get savedSuccessfully => 'บันทึกข้อมูลสำเร็จ';

  @override
  String get profilePhotoUploaded => 'อัปโหลดรูปโปรไฟล์สำเร็จ';

  @override
  String get uploadFailed => 'อัปโหลดไม่สำเร็จ';

  @override
  String errorOccurred(String error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get allDestinations => 'สถานที่ท่องเที่ยวทั้งหมด';

  @override
  String get searchDestinationsHint => 'ค้นหาจากสถานที่ จังหวัด หรือหมวดหมู่';

  @override
  String get clearSearch => 'ล้างการค้นหา';

  @override
  String get couldNotLoadDestinations => 'ไม่สามารถโหลดสถานที่ท่องเที่ยวได้';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String noPlacesFound(String query) {
    return 'ไม่พบสถานที่สำหรับ “$query”';
  }

  @override
  String get destination => 'สถานที่ท่องเที่ยว';

  @override
  String get signIn => 'เข้าสู่ระบบ';

  @override
  String get signUp => 'สมัครสมาชิก';

  @override
  String get loginAccount => 'เข้าสู่ระบบ\nบัญชีผู้ใช้';

  @override
  String get createAccount => 'สร้าง\nบัญชีผู้ใช้';

  @override
  String get welcomeBack => 'ยินดีต้อนรับกลับ กรุณากรอกข้อมูลของคุณ';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get emailRequired => 'กรุณากรอกอีเมล';

  @override
  String get emailInvalid => 'รูปแบบอีเมลไม่ถูกต้อง';

  @override
  String get passwordRequired => 'กรุณากรอกรหัสผ่าน';

  @override
  String get passwordMinLength => 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';

  @override
  String get emailHint => 'กรอกอีเมลของคุณ';

  @override
  String get passwordHint => 'กรอกรหัสผ่านของคุณ';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get passwordRequirement => 'ต้องมีอย่างน้อย 8 ตัวอักษร';

  @override
  String get registrationSuccessful => 'สมัครสมาชิกสำเร็จ';

  @override
  String get registrationFailed => 'สมัครสมาชิกไม่สำเร็จ';

  @override
  String get loginFailed => 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองอีกครั้ง';

  @override
  String get welcomeToApplication => 'ยินดีต้อนรับสู่แอปพลิเคชัน';

  @override
  String get dontHaveAccount => 'ยังไม่มีบัญชี? ';

  @override
  String networkError(String error) {
    return 'เกิดข้อผิดพลาดของเครือข่าย: $error';
  }

  @override
  String registrationFailedWithError(String error) {
    return 'สมัครสมาชิกไม่สำเร็จ: $error';
  }

  @override
  String get categoryAll => 'ทุกหมวดหมู่';

  @override
  String get categoryAttraction => 'สถานที่ท่องเที่ยว';

  @override
  String get categoryAccommodation => 'ที่พัก';

  @override
  String get categoryRestaurant => 'ร้านอาหาร';

  @override
  String get categoryShop => 'ร้านค้า';

  @override
  String get categoryOther => 'อื่นๆ';

  @override
  String get searchAttractionsHint => 'ค้นหาสถานที่ท่องเที่ยว';

  @override
  String get unknownPlace => 'ไม่ทราบชื่อสถานที่';

  @override
  String get beautifulThailandDestination => 'สถานที่สวยงามในประเทศไทย';

  @override
  String get gpsUnavailable =>
      'ไม่สามารถรับตำแหน่ง GPS ได้ โปรดตรวจสอบการตั้งค่าตำแหน่งและสิทธิ์การเข้าถึง';

  @override
  String get navigate => 'นำทาง';

  @override
  String get previousPhoto => 'รูปก่อนหน้า';

  @override
  String get nextPhoto => 'รูปถัดไป';

  @override
  String get atAGlance => 'ข้อมูลโดยสรุป';

  @override
  String get hours => 'เวลาเปิดทำการ';

  @override
  String get checkBeforeVisiting => 'โปรดตรวจสอบก่อนเดินทาง';

  @override
  String get admission => 'ค่าเข้าชม';

  @override
  String get seeOnArrival => 'ตรวจสอบเมื่อเดินทางถึง';

  @override
  String get openingHours => 'เวลาเปิดทำการ';

  @override
  String get admissionFee => 'ค่าเข้าชม';

  @override
  String get aboutThisPlace => 'เกี่ยวกับสถานที่นี้';

  @override
  String get detailsUnavailable => 'ขณะนี้ข้อมูลบางส่วนไม่พร้อมใช้งาน';

  @override
  String get viewOnMap => 'ดูบนแผนที่';

  @override
  String get thaiAdult => 'ผู้ใหญ่ชาวไทย';

  @override
  String get thaiChild => 'เด็กชาวไทย';

  @override
  String get foreignerAdult => 'ผู้ใหญ่ชาวต่างชาติ';

  @override
  String get foreignerChild => 'เด็กชาวต่างชาติ';

  @override
  String get conditions => 'เงื่อนไข';

  @override
  String get chatIntro =>
      'ถามฉันเกี่ยวกับสถานที่ท่องเที่ยว เวลาเปิดทำการ ค่าเข้าชม เส้นทาง อาหาร หรือสถานที่แนะนำใกล้เคียงได้เลย';

  @override
  String get today => 'วันนี้';

  @override
  String get aiGuide => 'AI ไกด์';

  @override
  String get aiPreparingConversation => 'AI ไกด์กำลังเตรียมบทสนทนา';

  @override
  String get photoUnderTwoMb => 'กรุณาเลือกรูปภาพขนาดไม่เกิน 2 MB';

  @override
  String get photoAnalysisFailed =>
      'AI ไกด์ไม่สามารถวิเคราะห์รูปนี้ได้ กรุณาลองอีกครั้ง';

  @override
  String get noConfirmedTravelData => 'ยังไม่พบข้อมูลท่องเที่ยวที่ยืนยันได้';

  @override
  String get travelAssistantUnavailable =>
      'ขณะนี้ผู้ช่วยท่องเที่ยวไม่พร้อมใช้งาน';

  @override
  String get chooseScanMode => 'เลือกสิ่งที่คุณต้องการให้ไกด์ช่วยวิเคราะห์';

  @override
  String get photoLibrary => 'คลังภาพ';

  @override
  String get typingPlace => 'AI ไกด์กำลังตรวจสอบสถานที่และบริเวณใกล้เคียง...';

  @override
  String get typingSign => 'AI ไกด์กำลังอ่านข้อความและแปลป้าย...';

  @override
  String get typingFood => 'AI ไกด์กำลังระบุเมนูอาหารไทย...';

  @override
  String get typingTat => 'AI ไกด์กำลังตรวจสอบข้อมูล TAT...';

  @override
  String get askThailandHint => 'ถามเกี่ยวกับประเทศไทย...';

  @override
  String get originalThai => 'ข้อความภาษาไทย';

  @override
  String get englishTranslation => 'คำแปลภาษาอังกฤษ';

  @override
  String get otherPossibilities => 'ความเป็นไปได้อื่น';

  @override
  String get notFullyCertain =>
      'ผลลัพธ์ยังไม่แน่นอน ลองถ่ายรูปให้ชัดและใกล้ขึ้น';

  @override
  String get tatPlace => 'สถานที่จาก TAT';

  @override
  String get scanPlaceTitle => 'สำรวจสถานที่';

  @override
  String get scanSignTitle => 'แปลป้าย';

  @override
  String get scanFoodTitle => 'ค้นหาอาหารไทย';

  @override
  String get scanPlaceDescription =>
      'ประวัติศาสตร์ วัฒนธรรม และมารยาทสำหรับผู้เยี่ยมชม';

  @override
  String get scanSignDescription => 'อ่านข้อความภาษาไทยและแปลเป็นภาษาอังกฤษ';

  @override
  String get scanFoodDescription => 'ระบุเมนูและเรียนรู้เรื่องราวทางวัฒนธรรม';

  @override
  String get scanPlaceCaption => 'สำรวจสถานที่นี้';

  @override
  String get scanSignCaption => 'แปลป้ายภาษาไทยนี้';

  @override
  String get scanFoodCaption => 'เล่าเรื่องอาหารไทยจานนี้';

  @override
  String get reset => 'รีเซ็ต';

  @override
  String get aiPlanTravel => 'AI วางแผนเที่ยว';

  @override
  String get buildYourTrip => 'สร้างทริปของคุณ';

  @override
  String get setTheBasics => 'กำหนดข้อมูลเบื้องต้น';

  @override
  String get locationStartingPoint => 'ตำแหน่งของคุณคือจุดเริ่มต้น';

  @override
  String get travelDates => 'วันที่เดินทาง';

  @override
  String get chooseDates => 'เลือกวันที่';

  @override
  String get days => 'วัน';

  @override
  String get estimatedBudget => 'งบประมาณโดยประมาณ';

  @override
  String get whatDoYouEnjoy => 'คุณชอบอะไร';

  @override
  String get aiFitsBudget => 'AI จะเลือกสถานที่ที่เหมาะกับงบประมาณของคุณ';

  @override
  String get howCanYouTravel => 'คุณเดินทางแบบใดได้บ้าง';

  @override
  String get longTripsSegments => 'การเดินทางไกลจะแบ่งเป็นช่วงถนนและขนส่ง';

  @override
  String get mustVisitPlaces => 'สถานที่ที่ต้องไป';

  @override
  String get mustVisitOptional => 'ไม่บังคับ — AI จะรวมสถานที่ที่คุณเลือก';

  @override
  String get addAPlace => 'เพิ่มสถานที่';

  @override
  String get designingTrip => 'กำลังออกแบบทริป…';

  @override
  String get createTravelPlan => 'สร้างแผนการเดินทาง';

  @override
  String get thailandNearYou => 'ประเทศไทย · ใกล้คุณ';

  @override
  String get aiFindBudgetPlaces => 'ให้ AI ค้นหาสถานที่\nที่เหมาะกับงบของคุณ';

  @override
  String get aiGeneratedPlan => 'แผนที่สร้างโดย AI';

  @override
  String get yourRoute => 'เส้นทางของคุณ';

  @override
  String get places => 'สถานที่';

  @override
  String get estimated => 'โดยประมาณ';

  @override
  String get recommendedItinerary => 'แผนการเดินทางที่แนะนำ';

  @override
  String get day => 'วันที่';

  @override
  String get addAnotherPlace => 'เพิ่มสถานที่อีกแห่ง';

  @override
  String get removeFromPlan => 'นำออกจากแผน';

  @override
  String get estimatedTripCost => 'ค่าใช้จ่ายทริปโดยประมาณ';

  @override
  String get estimateDisclaimer =>
      'ราคาอาจเปลี่ยนตามจำนวนที่ว่าง ฤดูกาล และการจราจร';

  @override
  String get currentGpsLocation => 'ตำแหน่ง GPS ปัจจุบัน';

  @override
  String get findingLocation => 'กำลังค้นหาตำแหน่ง…';

  @override
  String get locationUnavailable => 'ไม่พบตำแหน่ง';

  @override
  String get searchPlacesThailand => 'ค้นหาสถานที่ในประเทศไทย';

  @override
  String get transportCar => 'รถยนต์';

  @override
  String get transportWalking => 'เดิน';

  @override
  String get couldNotCreatePlan => 'ไม่สามารถสร้างแผนได้';

  @override
  String get estimatedStopCost => 'ค่าใช้จ่ายโดยประมาณของจุดนี้';

  @override
  String get admissionDetailsTat => 'รายละเอียดค่าเข้าชมจาก TAT';

  @override
  String get food => 'อาหาร';

  @override
  String get transport => 'การเดินทาง';

  @override
  String get stopTotal => 'รวมจุดนี้';

  @override
  String get journeyDetails => 'รายละเอียดการเดินทาง';

  @override
  String get navigateToPlace => 'นำทางไปสถานที่นี้';

  @override
  String get minutesShort => 'นาที';

  @override
  String get turnOnLocationServices => 'เปิดบริการตำแหน่งเพื่อเริ่มนำทาง';

  @override
  String get locationPermissionRequired =>
      'ต้องอนุญาตการเข้าถึงตำแหน่งเพื่อนำทาง';

  @override
  String kilometersLeft(String distance) {
    return 'เหลืออีก $distance กม.';
  }

  @override
  String get navigateTo => 'นำทางไปยัง';

  @override
  String get thailand => 'ประเทศไทย';

  @override
  String viewsCount(String count) {
    return '$count ครั้ง';
  }
}
