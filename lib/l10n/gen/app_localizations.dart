import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('ro')];

  /// No description provided for @appTitle.
  ///
  /// In ro, this message translates to:
  /// **'Tally'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In ro, this message translates to:
  /// **'Acasă'**
  String get navHome;

  /// No description provided for @navStats.
  ///
  /// In ro, this message translates to:
  /// **'Statistici'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In ro, this message translates to:
  /// **'Setări'**
  String get navSettings;

  /// No description provided for @periodDay.
  ///
  /// In ro, this message translates to:
  /// **'Azi'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In ro, this message translates to:
  /// **'Săptămâna'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In ro, this message translates to:
  /// **'Luna'**
  String get periodMonth;

  /// No description provided for @balance.
  ///
  /// In ro, this message translates to:
  /// **'Sold'**
  String get balance;

  /// No description provided for @income.
  ///
  /// In ro, this message translates to:
  /// **'Venituri'**
  String get income;

  /// No description provided for @expenses.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuieli'**
  String get expenses;

  /// No description provided for @lastSevenDays.
  ///
  /// In ro, this message translates to:
  /// **'Ultimele 7 zile'**
  String get lastSevenDays;

  /// No description provided for @recentTransactions.
  ///
  /// In ro, this message translates to:
  /// **'Tranzacții recente'**
  String get recentTransactions;

  /// No description provided for @seeAll.
  ///
  /// In ro, this message translates to:
  /// **'Vezi tot'**
  String get seeAll;

  /// No description provided for @addExpense.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuială'**
  String get addExpense;

  /// No description provided for @addIncome.
  ///
  /// In ro, this message translates to:
  /// **'Venit'**
  String get addIncome;

  /// No description provided for @amount.
  ///
  /// In ro, this message translates to:
  /// **'Sumă'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In ro, this message translates to:
  /// **'Categorie'**
  String get category;

  /// No description provided for @noteOptional.
  ///
  /// In ro, this message translates to:
  /// **'Notă (opțional)'**
  String get noteOptional;

  /// No description provided for @date.
  ///
  /// In ro, this message translates to:
  /// **'Data'**
  String get date;

  /// No description provided for @today.
  ///
  /// In ro, this message translates to:
  /// **'Azi'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ro, this message translates to:
  /// **'Ieri'**
  String get yesterday;

  /// No description provided for @save.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge'**
  String get delete;

  /// No description provided for @savedExpense.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuială salvată'**
  String get savedExpense;

  /// No description provided for @savedIncome.
  ///
  /// In ro, this message translates to:
  /// **'Venit salvat'**
  String get savedIncome;

  /// No description provided for @deleted.
  ///
  /// In ro, this message translates to:
  /// **'Tranzacție ștearsă'**
  String get deleted;

  /// No description provided for @undo.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get undo;

  /// No description provided for @errorAmountRequired.
  ///
  /// In ro, this message translates to:
  /// **'Introdu o sumă'**
  String get errorAmountRequired;

  /// No description provided for @errorAmountInvalid.
  ///
  /// In ro, this message translates to:
  /// **'Suma nu este validă'**
  String get errorAmountInvalid;

  /// No description provided for @errorCategoryRequired.
  ///
  /// In ro, this message translates to:
  /// **'Alege o categorie'**
  String get errorCategoryRequired;

  /// No description provided for @emptyTransactionsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Nicio tranzacție încă'**
  String get emptyTransactionsTitle;

  /// No description provided for @emptyTransactionsBody.
  ///
  /// In ro, this message translates to:
  /// **'Apasă butonul de mai jos ca să adaugi prima cheltuială.'**
  String get emptyTransactionsBody;

  /// No description provided for @emptyChartBody.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă câteva cheltuieli ca să vezi tendința.'**
  String get emptyChartBody;

  /// No description provided for @spentThisPeriod.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuit'**
  String get spentThisPeriod;

  /// No description provided for @dailyAverage.
  ///
  /// In ro, this message translates to:
  /// **'Medie pe zi'**
  String get dailyAverage;

  /// No description provided for @topCategory.
  ///
  /// In ro, this message translates to:
  /// **'Categoria principală'**
  String get topCategory;

  /// No description provided for @comparedToPrevious.
  ///
  /// In ro, this message translates to:
  /// **'{percent}% față de perioada anterioară'**
  String comparedToPrevious(String percent);

  /// No description provided for @quickAmounts.
  ///
  /// In ro, this message translates to:
  /// **'Sume folosite recent'**
  String get quickAmounts;

  /// No description provided for @periodNameDay.
  ///
  /// In ro, this message translates to:
  /// **'azi'**
  String get periodNameDay;

  /// No description provided for @periodNameWeek.
  ///
  /// In ro, this message translates to:
  /// **'săptămâna aceasta'**
  String get periodNameWeek;

  /// No description provided for @periodNameMonth.
  ///
  /// In ro, this message translates to:
  /// **'luna aceasta'**
  String get periodNameMonth;

  /// No description provided for @balanceIn.
  ///
  /// In ro, this message translates to:
  /// **'Sold {period}'**
  String balanceIn(String period);

  /// No description provided for @spentIn.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuit {period}'**
  String spentIn(String period);

  /// No description provided for @transactions.
  ///
  /// In ro, this message translates to:
  /// **'Tranzacții'**
  String get transactions;

  /// No description provided for @topCategoryShare.
  ///
  /// In ro, this message translates to:
  /// **'{percent}% din cheltuieli'**
  String topCategoryShare(String percent);

  /// No description provided for @dailyAverageValue.
  ///
  /// In ro, this message translates to:
  /// **'{amount} pe zi în medie'**
  String dailyAverageValue(String amount);

  /// No description provided for @editTransaction.
  ///
  /// In ro, this message translates to:
  /// **'Modifică'**
  String get editTransaction;

  /// No description provided for @savedChanges.
  ///
  /// In ro, this message translates to:
  /// **'Modificare salvată'**
  String get savedChanges;

  /// No description provided for @sectionData.
  ///
  /// In ro, this message translates to:
  /// **'Date'**
  String get sectionData;

  /// No description provided for @sectionApp.
  ///
  /// In ro, this message translates to:
  /// **'Aplicație'**
  String get sectionApp;

  /// No description provided for @sectionLook.
  ///
  /// In ro, this message translates to:
  /// **'Cum arată'**
  String get sectionLook;

  /// No description provided for @streakDays.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{O zi la rând} few{{count} zile la rând} other{{count} de zile la rând}}'**
  String streakDays(int count);

  /// No description provided for @themeTitle.
  ///
  /// In ro, this message translates to:
  /// **'Tema'**
  String get themeTitle;

  /// No description provided for @themeSub.
  ///
  /// In ro, this message translates to:
  /// **'Alege cum arată aplicația. Poți schimba oricând, nu se pierde nimic.'**
  String get themeSub;

  /// No description provided for @currency.
  ///
  /// In ro, this message translates to:
  /// **'Monedă'**
  String get currency;

  /// No description provided for @exportCsv.
  ///
  /// In ro, this message translates to:
  /// **'Exportă în CSV'**
  String get exportCsv;

  /// No description provided for @exportCsvSub.
  ///
  /// In ro, this message translates to:
  /// **'Pentru Excel sau Google Sheets'**
  String get exportCsvSub;

  /// No description provided for @exportBackup.
  ///
  /// In ro, this message translates to:
  /// **'Backup complet'**
  String get exportBackup;

  /// No description provided for @exportBackupSub.
  ///
  /// In ro, this message translates to:
  /// **'Un fișier din care poți reface tot'**
  String get exportBackupSub;

  /// No description provided for @restoreBackup.
  ///
  /// In ro, this message translates to:
  /// **'Restaurează dintr-un backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupSub.
  ///
  /// In ro, this message translates to:
  /// **'Înlocuiește toate datele de acum'**
  String get restoreBackupSub;

  /// No description provided for @nothingToExport.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nicio tranzacție de exportat.'**
  String get nothingToExport;

  /// No description provided for @shareExportTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cheltuielile mele'**
  String get shareExportTitle;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In ro, this message translates to:
  /// **'Înlocuiești toate datele?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In ro, this message translates to:
  /// **'Tot ce ai acum va fi șters și înlocuit cu ce se află în backup. Fă întâi un backup al datelor actuale dacă vrei să le păstrezi.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreAction.
  ///
  /// In ro, this message translates to:
  /// **'Restaurează'**
  String get restoreAction;

  /// No description provided for @wipeTitle.
  ///
  /// In ro, this message translates to:
  /// **'Șterge toate tranzacțiile'**
  String get wipeTitle;

  /// No description provided for @wipeSub.
  ///
  /// In ro, this message translates to:
  /// **'Categoriile rămân neschimbate'**
  String get wipeSub;

  /// No description provided for @wipeConfirmTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi toate tranzacțiile?'**
  String get wipeConfirmTitle;

  /// No description provided for @wipeConfirmBody.
  ///
  /// In ro, this message translates to:
  /// **'Toate veniturile și cheltuielile vor fi șterse definitiv. Această acțiune nu poate fi anulată.'**
  String get wipeConfirmBody;

  /// No description provided for @wipeDone.
  ///
  /// In ro, this message translates to:
  /// **'Toate tranzacțiile au fost șterse'**
  String get wipeDone;

  /// No description provided for @appVersion.
  ///
  /// In ro, this message translates to:
  /// **'Versiunea {version}'**
  String appVersion(String version);

  /// No description provided for @privacyNote.
  ///
  /// In ro, this message translates to:
  /// **'Datele tale rămân doar pe acest telefon. Nu există cont și nimic nu se trimite pe internet.'**
  String get privacyNote;

  /// No description provided for @restoreDone.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, =1{O tranzacție restaurată} other{{count} tranzacții restaurate}}'**
  String restoreDone(int count);

  /// No description provided for @recurring.
  ///
  /// In ro, this message translates to:
  /// **'Plăți recurente'**
  String get recurring;

  /// No description provided for @recurringSub.
  ///
  /// In ro, this message translates to:
  /// **'Salariu, abonamente, chirie'**
  String get recurringSub;

  /// No description provided for @recurringEmptyTitle.
  ///
  /// In ro, this message translates to:
  /// **'Nicio plată recurentă'**
  String get recurringEmptyTitle;

  /// No description provided for @recurringEmptyBody.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă salariul sau un abonament și aplicația te va întreba, în ziua respectivă, dacă a intrat.'**
  String get recurringEmptyBody;

  /// No description provided for @addRule.
  ///
  /// In ro, this message translates to:
  /// **'Adaugă'**
  String get addRule;

  /// No description provided for @newRule.
  ///
  /// In ro, this message translates to:
  /// **'Plată recurentă nouă'**
  String get newRule;

  /// No description provided for @ruleDay.
  ///
  /// In ro, this message translates to:
  /// **'În fiecare lună, în'**
  String get ruleDay;

  /// No description provided for @rulePaused.
  ///
  /// In ro, this message translates to:
  /// **'Pe pauză'**
  String get rulePaused;

  /// No description provided for @rulePauseAction.
  ///
  /// In ro, this message translates to:
  /// **'Pune pe pauză'**
  String get rulePauseAction;

  /// No description provided for @ruleResumeAction.
  ///
  /// In ro, this message translates to:
  /// **'Reia'**
  String get ruleResumeAction;

  /// No description provided for @ruleSaved.
  ///
  /// In ro, this message translates to:
  /// **'Plată recurentă salvată'**
  String get ruleSaved;

  /// No description provided for @ruleDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Plată recurentă ștearsă'**
  String get ruleDeleted;

  /// No description provided for @ruleDeleteTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi plata recurentă?'**
  String get ruleDeleteTitle;

  /// No description provided for @ruleDeleteBody.
  ///
  /// In ro, this message translates to:
  /// **'Nu vei mai fi întrebat despre ea. Tranzacțiile deja înregistrate rămân neatinse.'**
  String get ruleDeleteBody;

  /// No description provided for @errorDayRequired.
  ///
  /// In ro, this message translates to:
  /// **'Alege o zi din lună'**
  String get errorDayRequired;

  /// No description provided for @confirmYes.
  ///
  /// In ro, this message translates to:
  /// **'Da'**
  String get confirmYes;

  /// No description provided for @confirmNo.
  ///
  /// In ro, this message translates to:
  /// **'Nu'**
  String get confirmNo;

  /// No description provided for @occurrenceConfirmed.
  ///
  /// In ro, this message translates to:
  /// **'Adăugat'**
  String get occurrenceConfirmed;

  /// No description provided for @occurrenceSkipped.
  ///
  /// In ro, this message translates to:
  /// **'Sărit peste'**
  String get occurrenceSkipped;

  /// No description provided for @lastDayOfMonth.
  ///
  /// In ro, this message translates to:
  /// **'ultima zi'**
  String get lastDayOfMonth;

  /// No description provided for @dayOfMonth.
  ///
  /// In ro, this message translates to:
  /// **'ziua {day}'**
  String dayOfMonth(int day);

  /// No description provided for @pendingCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{O plată de confirmat} few{{count} plăți de confirmat} other{{count} de plăți de confirmat}}'**
  String pendingCount(int count);

  /// No description provided for @repeatsMonthly.
  ///
  /// In ro, this message translates to:
  /// **'Se repetă lunar'**
  String get repeatsMonthly;

  /// No description provided for @repeatsMonthlyHint.
  ///
  /// In ro, this message translates to:
  /// **'Vei fi întrebat în fiecare lună dacă a intrat'**
  String get repeatsMonthlyHint;

  /// No description provided for @repeatsFromNextMonth.
  ///
  /// In ro, this message translates to:
  /// **'Din luna viitoare, în fiecare {day}'**
  String repeatsFromNextMonth(String day);

  /// No description provided for @savedWithRule.
  ///
  /// In ro, this message translates to:
  /// **'Salvat și setat ca lunar'**
  String get savedWithRule;

  /// No description provided for @autoBackup.
  ///
  /// In ro, this message translates to:
  /// **'Backup automat'**
  String get autoBackup;

  /// No description provided for @autoBackupOn.
  ///
  /// In ro, this message translates to:
  /// **'Zilnic, pe telefon'**
  String get autoBackupOn;

  /// No description provided for @autoBackupNever.
  ///
  /// In ro, this message translates to:
  /// **'Încă niciunul'**
  String get autoBackupNever;

  /// No description provided for @autoBackupLast.
  ///
  /// In ro, this message translates to:
  /// **'Ultimul: {when}'**
  String autoBackupLast(String when);

  /// No description provided for @autoBackupEmptyTitle.
  ///
  /// In ro, this message translates to:
  /// **'Niciun backup automat încă'**
  String get autoBackupEmptyTitle;

  /// No description provided for @autoBackupEmptyBody.
  ///
  /// In ro, this message translates to:
  /// **'Se face unul pe zi, automat, prima dată când deschizi aplicația.'**
  String get autoBackupEmptyBody;

  /// No description provided for @autoBackupNow.
  ///
  /// In ro, this message translates to:
  /// **'Fă unul acum'**
  String get autoBackupNow;

  /// No description provided for @autoBackupDone.
  ///
  /// In ro, this message translates to:
  /// **'Backup făcut'**
  String get autoBackupDone;

  /// No description provided for @autoBackupCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{o tranzacție} few{{count} tranzacții} other{{count} de tranzacții}}'**
  String autoBackupCount(int count);

  /// No description provided for @autoBackupWarnTitle.
  ///
  /// In ro, this message translates to:
  /// **'Unde ajung datele tale'**
  String get autoBackupWarnTitle;

  /// No description provided for @autoBackupWarnBody.
  ///
  /// In ro, this message translates to:
  /// **'Snapshoturile zilnice de mai jos stau în aplicație și dispar odată cu ea dacă o dezinstalezi. Ca să rămână ceva pe telefon, alege un folder. Ca să se restaureze singur, pornește backupul Google.'**
  String get autoBackupWarnBody;

  /// No description provided for @restoreFrom.
  ///
  /// In ro, this message translates to:
  /// **'Restaurează din acesta'**
  String get restoreFrom;

  /// No description provided for @periodToday.
  ///
  /// In ro, this message translates to:
  /// **'Azi'**
  String get periodToday;

  /// No description provided for @periodYesterday.
  ///
  /// In ro, this message translates to:
  /// **'Ieri'**
  String get periodYesterday;

  /// No description provided for @periodThisWeek.
  ///
  /// In ro, this message translates to:
  /// **'Săptămâna aceasta'**
  String get periodThisWeek;

  /// No description provided for @periodLastWeek.
  ///
  /// In ro, this message translates to:
  /// **'Săptămâna trecută'**
  String get periodLastWeek;

  /// No description provided for @periodThisMonth.
  ///
  /// In ro, this message translates to:
  /// **'Luna aceasta'**
  String get periodThisMonth;

  /// No description provided for @periodLastMonth.
  ///
  /// In ro, this message translates to:
  /// **'Luna trecută'**
  String get periodLastMonth;

  /// No description provided for @backToNow.
  ///
  /// In ro, this message translates to:
  /// **'Revino la azi'**
  String get backToNow;

  /// No description provided for @twelveMonths.
  ///
  /// In ro, this message translates to:
  /// **'Ultimele 12 luni'**
  String get twelveMonths;

  /// No description provided for @twelveMonthsSub.
  ///
  /// In ro, this message translates to:
  /// **'Apasă pe o lună ca s-o deschizi'**
  String get twelveMonthsSub;

  /// No description provided for @monthlyAverage.
  ///
  /// In ro, this message translates to:
  /// **'Medie lunară'**
  String get monthlyAverage;

  /// No description provided for @noHistoryYet.
  ///
  /// In ro, this message translates to:
  /// **'Prea puțin istoric pentru o comparație pe luni.'**
  String get noHistoryYet;

  /// No description provided for @folderBackup.
  ///
  /// In ro, this message translates to:
  /// **'Folder pe telefon'**
  String get folderBackup;

  /// No description provided for @folderBackupNone.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai ales unul încă'**
  String get folderBackupNone;

  /// No description provided for @folderBackupPick.
  ///
  /// In ro, this message translates to:
  /// **'Alege un folder'**
  String get folderBackupPick;

  /// No description provided for @folderBackupChange.
  ///
  /// In ro, this message translates to:
  /// **'Schimbă folderul'**
  String get folderBackupChange;

  /// No description provided for @folderBackupWhy.
  ///
  /// In ro, this message translates to:
  /// **'Fișierele scrise aici rămân pe telefon chiar dacă dezinstalezi aplicația. Le vezi în Fișiere și le poți copia pe calculator sau trimite pe mail.'**
  String get folderBackupWhy;

  /// No description provided for @folderBackupLost.
  ///
  /// In ro, this message translates to:
  /// **'Nu mai am acces la folder'**
  String get folderBackupLost;

  /// No description provided for @folderBackupLostBody.
  ///
  /// In ro, this message translates to:
  /// **'L-ai mutat, l-ai șters, sau ai reinstalat aplicația. Alege-l din nou ca backupurile să continue.'**
  String get folderBackupLostBody;

  /// No description provided for @folderBackupEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Niciun backup scris în folder încă'**
  String get folderBackupEmpty;

  /// No description provided for @googleBackup.
  ///
  /// In ro, this message translates to:
  /// **'Backup în contul Google'**
  String get googleBackup;

  /// No description provided for @googleBackupBody.
  ///
  /// In ro, this message translates to:
  /// **'Singurul care se restaurează singur, fără niciun pas din partea ta, atunci când reinstalezi aplicația pe același cont Google. Se pornește din setările telefonului — aplicația nu poate face asta în locul tău.'**
  String get googleBackupBody;

  /// No description provided for @googleBackupOpen.
  ///
  /// In ro, this message translates to:
  /// **'Deschide setările telefonului'**
  String get googleBackupOpen;

  /// No description provided for @restoreFromFolder.
  ///
  /// In ro, this message translates to:
  /// **'Restaurează din folder'**
  String get restoreFromFolder;

  /// No description provided for @hadAppBefore.
  ///
  /// In ro, this message translates to:
  /// **'Ai mai folosit Tally?'**
  String get hadAppBefore;

  /// No description provided for @hadAppBeforeBody.
  ///
  /// In ro, this message translates to:
  /// **'Dacă ai un folder cu backupuri de la o instalare anterioară, arată-mi-l și îți aduc datele înapoi.'**
  String get hadAppBeforeBody;

  /// No description provided for @findMyBackup.
  ///
  /// In ro, this message translates to:
  /// **'Caută backupul meu'**
  String get findMyBackup;

  /// No description provided for @noBackupsInFolder.
  ///
  /// In ro, this message translates to:
  /// **'Nu am găsit niciun backup în folderul ales.'**
  String get noBackupsInFolder;

  /// No description provided for @restoreFoundBody.
  ///
  /// In ro, this message translates to:
  /// **'Îți aduc înapoi tranzacțiile, categoriile și plățile recurente din el. Nu ai nimic înregistrat acum, deci nu se pierde nimic.'**
  String get restoreFoundBody;

  /// No description provided for @foundBackups.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{Am găsit un backup} few{Am găsit {count} backupuri} other{Am găsit {count} de backupuri}}'**
  String foundBackups(int count);
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
      <String>['ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
