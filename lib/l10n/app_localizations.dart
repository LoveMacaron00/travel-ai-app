import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GoThai'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileUpdateFailed;

  /// No description provided for @setYourName.
  ///
  /// In en, this message translates to:
  /// **'Please set your name'**
  String get setYourName;

  /// No description provided for @myInterests.
  ///
  /// In en, this message translates to:
  /// **'My Interests'**
  String get myInterests;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @noInterests.
  ///
  /// In en, this message translates to:
  /// **'No interests added yet. Tap edit to customize!'**
  String get noInterests;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @editInterests.
  ///
  /// In en, this message translates to:
  /// **'Edit Interests'**
  String get editInterests;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @logOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of GoThai?'**
  String get logOutConfirmation;

  /// No description provided for @interestFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get interestFood;

  /// No description provided for @interestCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get interestCafe;

  /// No description provided for @interestNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get interestNature;

  /// No description provided for @interestBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get interestBeach;

  /// No description provided for @interestTemple.
  ///
  /// In en, this message translates to:
  /// **'Temple'**
  String get interestTemple;

  /// No description provided for @interestAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get interestAdventure;

  /// No description provided for @interestShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get interestShopping;

  /// No description provided for @interestNightlife.
  ///
  /// In en, this message translates to:
  /// **'Nightlife'**
  String get interestNightlife;

  /// No description provided for @interestCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get interestCulture;

  /// No description provided for @readyToExplore.
  ///
  /// In en, this message translates to:
  /// **'Ready to explore Thailand?'**
  String get readyToExplore;

  /// No description provided for @aiTravelSuite.
  ///
  /// In en, this message translates to:
  /// **'AI Travel Suite'**
  String get aiTravelSuite;

  /// No description provided for @planTravel.
  ///
  /// In en, this message translates to:
  /// **'Plan Travel'**
  String get planTravel;

  /// No description provided for @chatbot.
  ///
  /// In en, this message translates to:
  /// **'Chatbot'**
  String get chatbot;

  /// No description provided for @scanWithAi.
  ///
  /// In en, this message translates to:
  /// **'Scan with AI'**
  String get scanWithAi;

  /// No description provided for @travelDiary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get travelDiary;

  /// No description provided for @smartTravelDiary.
  ///
  /// In en, this message translates to:
  /// **'Smart Travel Diary'**
  String get smartTravelDiary;

  /// No description provided for @travelDiarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep each day\'s photos, location, and memories'**
  String get travelDiarySubtitle;

  /// No description provided for @diaryAutoDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep GPS on to record nearby places automatically, or take a photo with AI Camera to create a diary entry with place insights.'**
  String get diaryAutoDescription;

  /// No description provided for @openAiCamera.
  ///
  /// In en, this message translates to:
  /// **'Open AI Camera'**
  String get openAiCamera;

  /// No description provided for @diarySavedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'The AI photo and insights were added to your diary automatically.'**
  String get diarySavedAutomatically;

  /// No description provided for @diaryDay.
  ///
  /// In en, this message translates to:
  /// **'Day {day} : {place}'**
  String diaryDay(int day, String place);

  /// No description provided for @culturalInsight.
  ///
  /// In en, this message translates to:
  /// **'Cultural Insight'**
  String get culturalInsight;

  /// No description provided for @writeDiaryHint.
  ///
  /// In en, this message translates to:
  /// **'You can write your diary.'**
  String get writeDiaryHint;

  /// No description provided for @diaryMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String diaryMinutes(int minutes);

  /// No description provided for @diaryHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String diaryHours(int hours);

  /// No description provided for @diaryHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String diaryHoursMinutes(int hours, int minutes);

  /// No description provided for @addMemory.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get addMemory;

  /// No description provided for @noDiaryEntries.
  ///
  /// In en, this message translates to:
  /// **'No travel memories yet'**
  String get noDiaryEntries;

  /// No description provided for @noDiaryEntriesDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and note from your trip. Your GPS location will be captured automatically.'**
  String get noDiaryEntriesDescription;

  /// No description provided for @memoryNote.
  ///
  /// In en, this message translates to:
  /// **'Today\'s story'**
  String get memoryNote;

  /// No description provided for @memoryNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write a highlight or something you want to remember'**
  String get memoryNoteHint;

  /// No description provided for @provinceVisited.
  ///
  /// In en, this message translates to:
  /// **'Province visited'**
  String get provinceVisited;

  /// No description provided for @provinceHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Chiang Mai'**
  String get provinceHint;

  /// No description provided for @capturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get capturePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @saveMemory.
  ///
  /// In en, this message translates to:
  /// **'Save memory'**
  String get saveMemory;

  /// No description provided for @editMemory.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get editMemory;

  /// No description provided for @deleteMemory.
  ///
  /// In en, this message translates to:
  /// **'Delete memory'**
  String get deleteMemory;

  /// No description provided for @deleteMemoryConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this diary entry?'**
  String get deleteMemoryConfirmation;

  /// No description provided for @memorySaved.
  ///
  /// In en, this message translates to:
  /// **'Memory saved'**
  String get memorySaved;

  /// No description provided for @travelFootprint.
  ///
  /// In en, this message translates to:
  /// **'Travel Footprint'**
  String get travelFootprint;

  /// No description provided for @travelFootprintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the provinces and places you have explored'**
  String get travelFootprintSubtitle;

  /// No description provided for @visitedProvinces.
  ///
  /// In en, this message translates to:
  /// **'Visited provinces'**
  String get visitedProvinces;

  /// No description provided for @visitedProvinceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} provinces visited'**
  String visitedProvinceCount(int count);

  /// No description provided for @noFootprint.
  ///
  /// In en, this message translates to:
  /// **'No travel footprint yet'**
  String get noFootprint;

  /// No description provided for @noFootprintDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a province and GPS location to your diary to start coloring your map.'**
  String get noFootprintDescription;

  /// No description provided for @memoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} memories'**
  String memoriesCount(int count);

  /// No description provided for @openTravelDiary.
  ///
  /// In en, this message translates to:
  /// **'Open diary'**
  String get openTravelDiary;

  /// No description provided for @destinations.
  ///
  /// In en, this message translates to:
  /// **'Destinations'**
  String get destinations;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @couldNotLoadTatDestinations.
  ///
  /// In en, this message translates to:
  /// **'Could not load TAT destinations'**
  String get couldNotLoadTatDestinations;

  /// No description provided for @pullDownTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Pull down to try again.'**
  String get pullDownTryAgain;

  /// No description provided for @noDestinationsYet.
  ///
  /// In en, this message translates to:
  /// **'No destinations yet'**
  String get noDestinationsYet;

  /// No description provided for @tatReturnedNoImages.
  ///
  /// In en, this message translates to:
  /// **'TAT API did not return places with images.'**
  String get tatReturnedNoImages;

  /// No description provided for @failedToLoadDestinations.
  ///
  /// In en, this message translates to:
  /// **'Failed to load destinations'**
  String get failedToLoadDestinations;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get changeProfilePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @enterImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter image URL'**
  String get enterImageUrl;

  /// No description provided for @editProfileImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Edit profile image URL'**
  String get editProfileImageUrl;

  /// No description provided for @imageUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the image URL'**
  String get imageUrlHint;

  /// No description provided for @editUsername.
  ///
  /// In en, this message translates to:
  /// **'Edit username'**
  String get editUsername;

  /// No description provided for @newUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new username'**
  String get newUsernameHint;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInformation;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully!'**
  String get savedSuccessfully;

  /// No description provided for @profilePhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile photo uploaded successfully!'**
  String get profilePhotoUploaded;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String errorOccurred(String error);

  /// No description provided for @allDestinations.
  ///
  /// In en, this message translates to:
  /// **'All destinations'**
  String get allDestinations;

  /// No description provided for @searchDestinationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search by place, province, or category'**
  String get searchDestinationsHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @couldNotLoadDestinations.
  ///
  /// In en, this message translates to:
  /// **'Could not load destinations'**
  String get couldNotLoadDestinations;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @noPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No places found for “{query}”'**
  String noPlacesFound(String query);

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @loginAccount.
  ///
  /// In en, this message translates to:
  /// **'Login to your\naccount'**
  String get loginAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an\naccount'**
  String get createAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Please enter your details.'**
  String get welcomeBack;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Email is invalid'**
  String get emailInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordHint;

  /// No description provided for @passwordRequirement.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least 8 characters.'**
  String get passwordRequirement;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful!'**
  String get registrationSuccessful;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @welcomeToApplication.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Application'**
  String get welcomeToApplication;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {error}'**
  String networkError(String error);

  /// No description provided for @registrationFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registrationFailedWithError(String error);

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get categoryAll;

  /// No description provided for @categoryAttraction.
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get categoryAttraction;

  /// No description provided for @categoryAccommodation.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get categoryAccommodation;

  /// No description provided for @categoryRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get categoryRestaurant;

  /// No description provided for @categoryShop.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get categoryShop;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @searchAttractionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search for tourist attractions'**
  String get searchAttractionsHint;

  /// No description provided for @unknownPlace.
  ///
  /// In en, this message translates to:
  /// **'Unknown place'**
  String get unknownPlace;

  /// No description provided for @beautifulThailandDestination.
  ///
  /// In en, this message translates to:
  /// **'Beautiful destination in Thailand.'**
  String get beautifulThailandDestination;

  /// No description provided for @gpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to get your GPS location. Check location settings and permission.'**
  String get gpsUnavailable;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @previousPhoto.
  ///
  /// In en, this message translates to:
  /// **'Previous photo'**
  String get previousPhoto;

  /// No description provided for @nextPhoto.
  ///
  /// In en, this message translates to:
  /// **'Next photo'**
  String get nextPhoto;

  /// No description provided for @atAGlance.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get atAGlance;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @checkBeforeVisiting.
  ///
  /// In en, this message translates to:
  /// **'Check before visiting'**
  String get checkBeforeVisiting;

  /// No description provided for @admission.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get admission;

  /// No description provided for @seeOnArrival.
  ///
  /// In en, this message translates to:
  /// **'See on arrival'**
  String get seeOnArrival;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @admissionFee.
  ///
  /// In en, this message translates to:
  /// **'Admission fee'**
  String get admissionFee;

  /// No description provided for @aboutThisPlace.
  ///
  /// In en, this message translates to:
  /// **'About this place'**
  String get aboutThisPlace;

  /// No description provided for @detailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some details are unavailable right now.'**
  String get detailsUnavailable;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @thaiAdult.
  ///
  /// In en, this message translates to:
  /// **'Thai adult'**
  String get thaiAdult;

  /// No description provided for @thaiChild.
  ///
  /// In en, this message translates to:
  /// **'Thai child'**
  String get thaiChild;

  /// No description provided for @foreignerAdult.
  ///
  /// In en, this message translates to:
  /// **'Foreigner adult'**
  String get foreignerAdult;

  /// No description provided for @foreignerChild.
  ///
  /// In en, this message translates to:
  /// **'Foreigner child'**
  String get foreignerChild;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @chatIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask me about Thai destinations, opening hours, entrance fees, directions, food, or nearby recommendations.'**
  String get chatIntro;

  /// No description provided for @chatEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatDeleteMessage;

  /// No description provided for @chatDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this message and its AI response?'**
  String get chatDeleteConfirmation;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get chatEdited;

  /// No description provided for @chatMessageOptions.
  ///
  /// In en, this message translates to:
  /// **'Message options'**
  String get chatMessageOptions;

  /// No description provided for @chatEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to edit this message.'**
  String get chatEditFailed;

  /// No description provided for @chatDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete this message.'**
  String get chatDeleteFailed;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @aiGuide.
  ///
  /// In en, this message translates to:
  /// **'AI Guide'**
  String get aiGuide;

  /// No description provided for @aiPreparingConversation.
  ///
  /// In en, this message translates to:
  /// **'AI Guide is still preparing your conversation.'**
  String get aiPreparingConversation;

  /// No description provided for @photoUnderTwoMb.
  ///
  /// In en, this message translates to:
  /// **'Please choose a photo under 2 MB.'**
  String get photoUnderTwoMb;

  /// No description provided for @photoAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'AI Guide could not analyze this photo. Please try again.'**
  String get photoAnalysisFailed;

  /// No description provided for @noConfirmedTravelData.
  ///
  /// In en, this message translates to:
  /// **'I could not find confirmed travel data yet.'**
  String get noConfirmedTravelData;

  /// No description provided for @travelAssistantUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The travel assistant is unavailable right now.'**
  String get travelAssistantUnavailable;

  /// No description provided for @chooseScanMode.
  ///
  /// In en, this message translates to:
  /// **'Choose what you want the guide to understand.'**
  String get chooseScanMode;

  /// No description provided for @photoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get photoLibrary;

  /// No description provided for @typingPlace.
  ///
  /// In en, this message translates to:
  /// **'AI Guide is checking the place and nearby context...'**
  String get typingPlace;

  /// No description provided for @typingSign.
  ///
  /// In en, this message translates to:
  /// **'AI Guide is reading and translating the sign...'**
  String get typingSign;

  /// No description provided for @typingFood.
  ///
  /// In en, this message translates to:
  /// **'AI Guide is identifying the Thai dish...'**
  String get typingFood;

  /// No description provided for @typingTat.
  ///
  /// In en, this message translates to:
  /// **'AI Guide is checking TAT details...'**
  String get typingTat;

  /// No description provided for @askThailandHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about Thailand...'**
  String get askThailandHint;

  /// No description provided for @originalThai.
  ///
  /// In en, this message translates to:
  /// **'Original Thai'**
  String get originalThai;

  /// No description provided for @englishTranslation.
  ///
  /// In en, this message translates to:
  /// **'English translation'**
  String get englishTranslation;

  /// No description provided for @otherPossibilities.
  ///
  /// In en, this message translates to:
  /// **'Other possibilities'**
  String get otherPossibilities;

  /// No description provided for @notFullyCertain.
  ///
  /// In en, this message translates to:
  /// **'Not fully certain — try a clearer, closer photo.'**
  String get notFullyCertain;

  /// No description provided for @tatPlace.
  ///
  /// In en, this message translates to:
  /// **'TAT place'**
  String get tatPlace;

  /// No description provided for @scanPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore a place'**
  String get scanPlaceTitle;

  /// No description provided for @scanSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Translate a sign'**
  String get scanSignTitle;

  /// No description provided for @scanFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Thai food'**
  String get scanFoodTitle;

  /// No description provided for @scanPlaceDescription.
  ///
  /// In en, this message translates to:
  /// **'History, culture, and visitor etiquette'**
  String get scanPlaceDescription;

  /// No description provided for @scanSignDescription.
  ///
  /// In en, this message translates to:
  /// **'Read Thai text and translate it to English'**
  String get scanSignDescription;

  /// No description provided for @scanFoodDescription.
  ///
  /// In en, this message translates to:
  /// **'Identify a dish and learn its cultural story'**
  String get scanFoodDescription;

  /// No description provided for @scanPlaceCaption.
  ///
  /// In en, this message translates to:
  /// **'Explore this place'**
  String get scanPlaceCaption;

  /// No description provided for @scanSignCaption.
  ///
  /// In en, this message translates to:
  /// **'Translate this Thai sign'**
  String get scanSignCaption;

  /// No description provided for @scanFoodCaption.
  ///
  /// In en, this message translates to:
  /// **'Tell me about this Thai dish'**
  String get scanFoodCaption;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @aiPlanTravel.
  ///
  /// In en, this message translates to:
  /// **'AI PLAN TRAVEL'**
  String get aiPlanTravel;

  /// No description provided for @buildYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Build your trip'**
  String get buildYourTrip;

  /// No description provided for @setTheBasics.
  ///
  /// In en, this message translates to:
  /// **'Set the basics'**
  String get setTheBasics;

  /// No description provided for @locationStartingPoint.
  ///
  /// In en, this message translates to:
  /// **'Your location is the starting point.'**
  String get locationStartingPoint;

  /// No description provided for @selectProvince.
  ///
  /// In en, this message translates to:
  /// **'Choose a province'**
  String get selectProvince;

  /// No description provided for @loadingProvinces.
  ///
  /// In en, this message translates to:
  /// **'Loading provinces…'**
  String get loadingProvinces;

  /// No description provided for @databaseProvinceOnly.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get databaseProvinceOnly;

  /// No description provided for @provinceRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a province before creating a travel plan.'**
  String get provinceRequired;

  /// No description provided for @couldNotLoadProvinces.
  ///
  /// In en, this message translates to:
  /// **'Could not load provinces'**
  String get couldNotLoadProvinces;

  /// No description provided for @travelDates.
  ///
  /// In en, this message translates to:
  /// **'Travel dates'**
  String get travelDates;

  /// No description provided for @chooseDates.
  ///
  /// In en, this message translates to:
  /// **'Choose travel dates'**
  String get chooseDates;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @estimatedBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get estimatedBudget;

  /// No description provided for @whatDoYouEnjoy.
  ///
  /// In en, this message translates to:
  /// **'What do you enjoy?'**
  String get whatDoYouEnjoy;

  /// No description provided for @aiFitsBudget.
  ///
  /// In en, this message translates to:
  /// **'AI will choose places that fit your budget.'**
  String get aiFitsBudget;

  /// No description provided for @howCanYouTravel.
  ///
  /// In en, this message translates to:
  /// **'How can you travel?'**
  String get howCanYouTravel;

  /// No description provided for @mustVisitPlaces.
  ///
  /// In en, this message translates to:
  /// **'Must-visit places'**
  String get mustVisitPlaces;

  /// No description provided for @mustVisitOptional.
  ///
  /// In en, this message translates to:
  /// **'Selected places are always included'**
  String get mustVisitOptional;

  /// No description provided for @addAPlace.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get addAPlace;

  /// No description provided for @mustVisitLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 5 must-visit places.'**
  String get mustVisitLimitReached;

  /// No description provided for @designingTrip.
  ///
  /// In en, this message translates to:
  /// **'Designing your trip…'**
  String get designingTrip;

  /// No description provided for @createTravelPlan.
  ///
  /// In en, this message translates to:
  /// **'Create my travel plan'**
  String get createTravelPlan;

  /// No description provided for @thailandNearYou.
  ///
  /// In en, this message translates to:
  /// **'THAILAND · NEAR YOU'**
  String get thailandNearYou;

  /// No description provided for @aiFindBudgetPlaces.
  ///
  /// In en, this message translates to:
  /// **'Let AI find the right\nplaces for your budget.'**
  String get aiFindBudgetPlaces;

  /// No description provided for @aiGeneratedPlan.
  ///
  /// In en, this message translates to:
  /// **'AI GENERATED PLAN'**
  String get aiGeneratedPlan;

  /// No description provided for @yourRoute.
  ///
  /// In en, this message translates to:
  /// **'Your route'**
  String get yourRoute;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'places'**
  String get places;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'estimated'**
  String get estimated;

  /// No description provided for @recommendedItinerary.
  ///
  /// In en, this message translates to:
  /// **'Recommended itinerary'**
  String get recommendedItinerary;

  /// No description provided for @aiPlanDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This itinerary is generated by AI. Place, route, time, cost, and schedule information may be inaccurate. Verify the details with service providers before travelling.'**
  String get aiPlanDisclaimer;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'DAY'**
  String get day;

  /// No description provided for @addAnotherPlace.
  ///
  /// In en, this message translates to:
  /// **'Add another place'**
  String get addAnotherPlace;

  /// No description provided for @removeFromPlan.
  ///
  /// In en, this message translates to:
  /// **'Remove from plan'**
  String get removeFromPlan;

  /// No description provided for @estimatedTripCost.
  ///
  /// In en, this message translates to:
  /// **'Estimated trip cost'**
  String get estimatedTripCost;

  /// No description provided for @estimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimates may change with availability, season, and traffic.'**
  String get estimateDisclaimer;

  /// No description provided for @currentGpsLocation.
  ///
  /// In en, this message translates to:
  /// **'Current GPS location'**
  String get currentGpsLocation;

  /// No description provided for @findingLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get findingLocation;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// No description provided for @searchPlacesThailand.
  ///
  /// In en, this message translates to:
  /// **'Search places in Thailand'**
  String get searchPlacesThailand;

  /// No description provided for @transportCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get transportCar;

  /// No description provided for @transportWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get transportWalking;

  /// No description provided for @transportBus.
  ///
  /// In en, this message translates to:
  /// **'Bus'**
  String get transportBus;

  /// No description provided for @transportTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get transportTrain;

  /// No description provided for @transportFerry.
  ///
  /// In en, this message translates to:
  /// **'Ferry'**
  String get transportFerry;

  /// No description provided for @transportFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get transportFlight;

  /// No description provided for @couldNotCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Could not create a plan.'**
  String get couldNotCreatePlan;

  /// No description provided for @estimatedStopCost.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost for this stop'**
  String get estimatedStopCost;

  /// No description provided for @admissionDetailsTat.
  ///
  /// In en, this message translates to:
  /// **'Admission details from TAT'**
  String get admissionDetailsTat;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @stopTotal.
  ///
  /// In en, this message translates to:
  /// **'Stop total'**
  String get stopTotal;

  /// No description provided for @journeyDetails.
  ///
  /// In en, this message translates to:
  /// **'Journey details'**
  String get journeyDetails;

  /// No description provided for @navigateToPlace.
  ///
  /// In en, this message translates to:
  /// **'Navigate to this place'**
  String get navigateToPlace;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @turnOnLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to navigate.'**
  String get turnOnLocationServices;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required for navigation.'**
  String get locationPermissionRequired;

  /// No description provided for @kilometersLeft.
  ///
  /// In en, this message translates to:
  /// **'{distance} km left'**
  String kilometersLeft(String distance);

  /// No description provided for @navigateTo.
  ///
  /// In en, this message translates to:
  /// **'Navigate to'**
  String get navigateTo;

  /// No description provided for @thailand.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get thailand;

  /// No description provided for @locationDetails.
  ///
  /// In en, this message translates to:
  /// **'Location details'**
  String get locationDetails;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @province.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get province;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @subDistrict.
  ///
  /// In en, this message translates to:
  /// **'Sub-district'**
  String get subDistrict;

  /// No description provided for @postcode.
  ///
  /// In en, this message translates to:
  /// **'Postcode'**
  String get postcode;

  /// No description provided for @viewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String viewsCount(String count);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
