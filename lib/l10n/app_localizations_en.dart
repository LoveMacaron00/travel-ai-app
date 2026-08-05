// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GoThai';

  @override
  String get home => 'Home';

  @override
  String get map => 'Map';

  @override
  String get plan => 'Plan';

  @override
  String get profile => 'Profile';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get profileUpdateFailed => 'Failed to update profile';

  @override
  String get setYourName => 'Please set your name';

  @override
  String get myInterests => 'My Interests';

  @override
  String get edit => 'Edit';

  @override
  String get noInterests => 'No interests added yet. Tap edit to customize!';

  @override
  String get settings => 'Settings';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'Thai';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get editInterests => 'Edit Interests';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get logOut => 'Log Out';

  @override
  String get logOutConfirmation =>
      'Are you sure you want to log out of GoThai?';

  @override
  String get interestFood => 'Food';

  @override
  String get interestCafe => 'Cafe';

  @override
  String get interestNature => 'Nature';

  @override
  String get interestBeach => 'Beach';

  @override
  String get interestTemple => 'Temple';

  @override
  String get interestAdventure => 'Adventure';

  @override
  String get interestShopping => 'Shopping';

  @override
  String get interestNightlife => 'Nightlife';

  @override
  String get interestCulture => 'Culture';

  @override
  String get readyToExplore => 'Ready to explore Thailand?';

  @override
  String get aiTravelSuite => 'AI Travel Suite';

  @override
  String get planTravel => 'Plan Travel';

  @override
  String get chatbot => 'Chatbot';

  @override
  String get scanWithAi => 'Scan with AI';

  @override
  String get destinations => 'Destinations';

  @override
  String get seeAll => 'See all';

  @override
  String get couldNotLoadTatDestinations => 'Could not load TAT destinations';

  @override
  String get pullDownTryAgain => 'Pull down to try again.';

  @override
  String get noDestinationsYet => 'No destinations yet';

  @override
  String get tatReturnedNoImages =>
      'TAT API did not return places with images.';

  @override
  String get failedToLoadDestinations => 'Failed to load destinations';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get enterImageUrl => 'Enter image URL';

  @override
  String get editProfileImageUrl => 'Edit profile image URL';

  @override
  String get imageUrlHint => 'Enter the image URL';

  @override
  String get editUsername => 'Edit username';

  @override
  String get newUsernameHint => 'Enter a new username';

  @override
  String get accountInformation => 'Account information';

  @override
  String get username => 'Username';

  @override
  String get email => 'Email';

  @override
  String get notSet => 'Not set';

  @override
  String get savedSuccessfully => 'Saved successfully!';

  @override
  String get profilePhotoUploaded => 'Profile photo uploaded successfully!';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String errorOccurred(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get allDestinations => 'All destinations';

  @override
  String get searchDestinationsHint => 'Search by place, province, or category';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get couldNotLoadDestinations => 'Could not load destinations';

  @override
  String get tryAgain => 'Try again';

  @override
  String noPlacesFound(String query) {
    return 'No places found for “$query”';
  }

  @override
  String get destination => 'Destination';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get loginAccount => 'Login to your\naccount';

  @override
  String get createAccount => 'Create an\naccount';

  @override
  String get welcomeBack => 'Welcome back! Please enter your details.';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Email is invalid';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get emailHint => 'Enter your email.';

  @override
  String get passwordHint => 'Enter your password.';

  @override
  String get passwordRequirement => 'Must contain at least 8 characters.';

  @override
  String get registrationSuccessful => 'Registration successful!';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get loginFailed => 'Login failed. Please try again.';

  @override
  String get welcomeToApplication => 'Welcome to Application';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String networkError(String error) {
    return 'Network error: $error';
  }

  @override
  String registrationFailedWithError(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get categoryAll => 'All categories';

  @override
  String get categoryAttraction => 'Attractions';

  @override
  String get categoryAccommodation => 'Accommodation';

  @override
  String get categoryRestaurant => 'Restaurants';

  @override
  String get categoryShop => 'Shops';

  @override
  String get categoryOther => 'Other';

  @override
  String get searchAttractionsHint => 'Search for tourist attractions';

  @override
  String get unknownPlace => 'Unknown place';

  @override
  String get beautifulThailandDestination =>
      'Beautiful destination in Thailand.';

  @override
  String get gpsUnavailable =>
      'Unable to get your GPS location. Check location settings and permission.';

  @override
  String get navigate => 'Navigate';

  @override
  String get previousPhoto => 'Previous photo';

  @override
  String get nextPhoto => 'Next photo';

  @override
  String get atAGlance => 'At a glance';

  @override
  String get hours => 'Hours';

  @override
  String get checkBeforeVisiting => 'Check before visiting';

  @override
  String get admission => 'Admission';

  @override
  String get seeOnArrival => 'See on arrival';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get admissionFee => 'Admission fee';

  @override
  String get aboutThisPlace => 'About this place';

  @override
  String get detailsUnavailable => 'Some details are unavailable right now.';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get thaiAdult => 'Thai adult';

  @override
  String get thaiChild => 'Thai child';

  @override
  String get foreignerAdult => 'Foreigner adult';

  @override
  String get foreignerChild => 'Foreigner child';

  @override
  String get conditions => 'Conditions';

  @override
  String get chatIntro =>
      'Ask me about Thai destinations, opening hours, entrance fees, directions, food, or nearby recommendations.';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get chatDeleteConfirmation =>
      'Delete this message and its AI response?';

  @override
  String get chatEdited => 'Edited';

  @override
  String get chatMessageOptions => 'Message options';

  @override
  String get chatEditFailed => 'Unable to edit this message.';

  @override
  String get chatDeleteFailed => 'Unable to delete this message.';

  @override
  String get today => 'Today';

  @override
  String get aiGuide => 'AI Guide';

  @override
  String get aiPreparingConversation =>
      'AI Guide is still preparing your conversation.';

  @override
  String get photoUnderTwoMb => 'Please choose a photo under 2 MB.';

  @override
  String get photoAnalysisFailed =>
      'AI Guide could not analyze this photo. Please try again.';

  @override
  String get noConfirmedTravelData =>
      'I could not find confirmed travel data yet.';

  @override
  String get travelAssistantUnavailable =>
      'The travel assistant is unavailable right now.';

  @override
  String get chooseScanMode => 'Choose what you want the guide to understand.';

  @override
  String get photoLibrary => 'Photo library';

  @override
  String get typingPlace =>
      'AI Guide is checking the place and nearby context...';

  @override
  String get typingSign => 'AI Guide is reading and translating the sign...';

  @override
  String get typingFood => 'AI Guide is identifying the Thai dish...';

  @override
  String get typingTat => 'AI Guide is checking TAT details...';

  @override
  String get askThailandHint => 'Ask about Thailand...';

  @override
  String get originalThai => 'Original Thai';

  @override
  String get englishTranslation => 'English translation';

  @override
  String get otherPossibilities => 'Other possibilities';

  @override
  String get notFullyCertain =>
      'Not fully certain — try a clearer, closer photo.';

  @override
  String get tatPlace => 'TAT place';

  @override
  String get scanPlaceTitle => 'Explore a place';

  @override
  String get scanSignTitle => 'Translate a sign';

  @override
  String get scanFoodTitle => 'Discover Thai food';

  @override
  String get scanPlaceDescription => 'History, culture, and visitor etiquette';

  @override
  String get scanSignDescription =>
      'Read Thai text and translate it to English';

  @override
  String get scanFoodDescription =>
      'Identify a dish and learn its cultural story';

  @override
  String get scanPlaceCaption => 'Explore this place';

  @override
  String get scanSignCaption => 'Translate this Thai sign';

  @override
  String get scanFoodCaption => 'Tell me about this Thai dish';

  @override
  String get reset => 'Reset';

  @override
  String get aiPlanTravel => 'AI PLAN TRAVEL';

  @override
  String get buildYourTrip => 'Build your trip';

  @override
  String get setTheBasics => 'Set the basics';

  @override
  String get locationStartingPoint => 'Your location is the starting point.';

  @override
  String get selectProvince => 'Choose a province';

  @override
  String get loadingProvinces => 'Loading provinces…';

  @override
  String get databaseProvinceOnly =>
      'Optional — leave blank to search database destinations near your location.';

  @override
  String get provinceRequired =>
      'Choose a province before creating a travel plan.';

  @override
  String get couldNotLoadProvinces => 'Could not load provinces';

  @override
  String get travelDates => 'Travel dates';

  @override
  String get chooseDates => 'Choose dates';

  @override
  String get days => 'days';

  @override
  String get estimatedBudget => 'Budget';

  @override
  String get whatDoYouEnjoy => 'What do you enjoy?';

  @override
  String get aiFitsBudget => 'AI will choose places that fit your budget.';

  @override
  String get howCanYouTravel => 'How can you travel?';

  @override
  String get longTripsSegments =>
      'Long trips are split into road and transport segments.';

  @override
  String get mustVisitPlaces => 'Must-visit places';

  @override
  String get mustVisitOptional => 'Optional — AI will include your selections.';

  @override
  String get addAPlace => 'Add a place';

  @override
  String get designingTrip => 'Designing your trip…';

  @override
  String get createTravelPlan => 'Create my travel plan';

  @override
  String get thailandNearYou => 'THAILAND · NEAR YOU';

  @override
  String get aiFindBudgetPlaces =>
      'Let AI find the right\nplaces for your budget.';

  @override
  String get aiGeneratedPlan => 'AI GENERATED PLAN';

  @override
  String get yourRoute => 'Your route';

  @override
  String get places => 'places';

  @override
  String get estimated => 'estimated';

  @override
  String get recommendedItinerary => 'Recommended itinerary';

  @override
  String get day => 'DAY';

  @override
  String get addAnotherPlace => 'Add another place';

  @override
  String get removeFromPlan => 'Remove from plan';

  @override
  String get estimatedTripCost => 'Estimated trip cost';

  @override
  String get estimateDisclaimer =>
      'Estimates may change with availability, season, and traffic.';

  @override
  String get currentGpsLocation => 'Current GPS location';

  @override
  String get findingLocation => 'Finding your location…';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String get searchPlacesThailand => 'Search places in Thailand';

  @override
  String get transportCar => 'Car';

  @override
  String get transportWalking => 'Walking';

  @override
  String get couldNotCreatePlan => 'Could not create a plan.';

  @override
  String get estimatedStopCost => 'Estimated cost for this stop';

  @override
  String get admissionDetailsTat => 'Admission details from TAT';

  @override
  String get food => 'Food';

  @override
  String get transport => 'Transport';

  @override
  String get stopTotal => 'Stop total';

  @override
  String get journeyDetails => 'Journey details';

  @override
  String get navigateToPlace => 'Navigate to this place';

  @override
  String get minutesShort => 'min';

  @override
  String get turnOnLocationServices => 'Turn on location services to navigate.';

  @override
  String get locationPermissionRequired =>
      'Location permission is required for navigation.';

  @override
  String kilometersLeft(String distance) {
    return '$distance km left';
  }

  @override
  String get navigateTo => 'Navigate to';

  @override
  String get thailand => 'Thailand';

  @override
  String get locationDetails => 'Location details';

  @override
  String get address => 'Address';

  @override
  String get province => 'Province';

  @override
  String get district => 'District';

  @override
  String get subDistrict => 'Sub-district';

  @override
  String get postcode => 'Postcode';

  @override
  String viewsCount(String count) {
    return '$count views';
  }
}
