// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Tally';

  @override
  String get navHome => 'Acasă';

  @override
  String get navStats => 'Statistici';

  @override
  String get navSettings => 'Setări';

  @override
  String get periodDay => 'Azi';

  @override
  String get periodWeek => 'Săptămâna';

  @override
  String get periodMonth => 'Luna';

  @override
  String get balance => 'Sold';

  @override
  String get income => 'Venituri';

  @override
  String get expenses => 'Cheltuieli';

  @override
  String get lastSevenDays => 'Ultimele 7 zile';

  @override
  String get recentTransactions => 'Tranzacții recente';

  @override
  String get seeAll => 'Vezi tot';

  @override
  String get addExpense => 'Cheltuială';

  @override
  String get addIncome => 'Venit';

  @override
  String get amount => 'Sumă';

  @override
  String get category => 'Categorie';

  @override
  String get noteOptional => 'Notă (opțional)';

  @override
  String get date => 'Data';

  @override
  String get today => 'Azi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get save => 'Salvează';

  @override
  String get cancel => 'Anulează';

  @override
  String get delete => 'Șterge';

  @override
  String get savedExpense => 'Cheltuială salvată';

  @override
  String get savedIncome => 'Venit salvat';

  @override
  String get deleted => 'Tranzacție ștearsă';

  @override
  String get undo => 'Anulează';

  @override
  String get errorAmountRequired => 'Introdu o sumă';

  @override
  String get errorAmountInvalid => 'Suma nu este validă';

  @override
  String get errorCategoryRequired => 'Alege o categorie';

  @override
  String get emptyTransactionsTitle => 'Nicio tranzacție încă';

  @override
  String get emptyTransactionsBody =>
      'Apasă butonul de mai jos ca să adaugi prima cheltuială.';

  @override
  String get emptyChartBody => 'Adaugă câteva cheltuieli ca să vezi tendința.';

  @override
  String get spentThisPeriod => 'Cheltuit';

  @override
  String get dailyAverage => 'Medie pe zi';

  @override
  String get topCategory => 'Categoria principală';

  @override
  String comparedToPrevious(String percent) {
    return '$percent% față de perioada anterioară';
  }

  @override
  String get quickAmounts => 'Sume folosite recent';

  @override
  String get periodNameDay => 'azi';

  @override
  String get periodNameWeek => 'săptămâna aceasta';

  @override
  String get periodNameMonth => 'luna aceasta';

  @override
  String balanceIn(String period) {
    return 'Sold $period';
  }

  @override
  String spentIn(String period) {
    return 'Cheltuit $period';
  }

  @override
  String get transactions => 'Tranzacții';

  @override
  String topCategoryShare(String percent) {
    return '$percent% din cheltuieli';
  }

  @override
  String dailyAverageValue(String amount) {
    return '$amount pe zi în medie';
  }

  @override
  String get editTransaction => 'Modifică';

  @override
  String get savedChanges => 'Modificare salvată';

  @override
  String get sectionData => 'Date';

  @override
  String get sectionApp => 'Aplicație';

  @override
  String get sectionLook => 'Cum arată';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de zile la rând',
      few: '$count zile la rând',
      one: 'O zi la rând',
    );
    return '$_temp0';
  }

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSub =>
      'Alege cum arată aplicația. Poți schimba oricând, nu se pierde nimic.';

  @override
  String get currency => 'Monedă';

  @override
  String get exportCsv => 'Exportă în CSV';

  @override
  String get exportCsvSub => 'Pentru Excel sau Google Sheets';

  @override
  String get exportBackup => 'Backup complet';

  @override
  String get exportBackupSub => 'Un fișier din care poți reface tot';

  @override
  String get restoreBackup => 'Restaurează dintr-un backup';

  @override
  String get restoreBackupSub => 'Înlocuiește toate datele de acum';

  @override
  String get nothingToExport => 'Nu ai nicio tranzacție de exportat.';

  @override
  String get shareExportTitle => 'Cheltuielile mele';

  @override
  String get restoreConfirmTitle => 'Înlocuiești toate datele?';

  @override
  String get restoreConfirmBody =>
      'Tot ce ai acum va fi șters și înlocuit cu ce se află în backup. Fă întâi un backup al datelor actuale dacă vrei să le păstrezi.';

  @override
  String get restoreAction => 'Restaurează';

  @override
  String get wipeTitle => 'Șterge toate tranzacțiile';

  @override
  String get wipeSub => 'Categoriile rămân neschimbate';

  @override
  String get wipeConfirmTitle => 'Ștergi toate tranzacțiile?';

  @override
  String get wipeConfirmBody =>
      'Toate veniturile și cheltuielile vor fi șterse definitiv. Această acțiune nu poate fi anulată.';

  @override
  String get wipeDone => 'Toate tranzacțiile au fost șterse';

  @override
  String appVersion(String version) {
    return 'Versiunea $version';
  }

  @override
  String get privacyNote =>
      'Datele tale rămân doar pe acest telefon. Nu există cont și nimic nu se trimite pe internet.';

  @override
  String restoreDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tranzacții restaurate',
      one: 'O tranzacție restaurată',
    );
    return '$_temp0';
  }

  @override
  String get recurring => 'Plăți recurente';

  @override
  String get recurringSub => 'Salariu, abonamente, chirie';

  @override
  String get recurringEmptyTitle => 'Nicio plată recurentă';

  @override
  String get recurringEmptyBody =>
      'Adaugă salariul sau un abonament și aplicația te va întreba, în ziua respectivă, dacă a intrat.';

  @override
  String get addRule => 'Adaugă';

  @override
  String get newRule => 'Plată recurentă nouă';

  @override
  String get ruleDay => 'În fiecare lună, în';

  @override
  String get rulePaused => 'Pe pauză';

  @override
  String get rulePauseAction => 'Pune pe pauză';

  @override
  String get ruleResumeAction => 'Reia';

  @override
  String get ruleSaved => 'Plată recurentă salvată';

  @override
  String get ruleDeleted => 'Plată recurentă ștearsă';

  @override
  String get ruleDeleteTitle => 'Ștergi plata recurentă?';

  @override
  String get ruleDeleteBody =>
      'Nu vei mai fi întrebat despre ea. Tranzacțiile deja înregistrate rămân neatinse.';

  @override
  String get errorDayRequired => 'Alege o zi din lună';

  @override
  String get confirmYes => 'Da';

  @override
  String get confirmNo => 'Nu';

  @override
  String get occurrenceConfirmed => 'Adăugat';

  @override
  String get occurrenceSkipped => 'Sărit peste';

  @override
  String get lastDayOfMonth => 'ultima zi';

  @override
  String dayOfMonth(int day) {
    return 'ziua $day';
  }

  @override
  String pendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plăți de confirmat',
      few: '$count plăți de confirmat',
      one: 'O plată de confirmat',
    );
    return '$_temp0';
  }

  @override
  String get repeatsMonthly => 'Se repetă lunar';

  @override
  String get repeatsMonthlyHint =>
      'Vei fi întrebat în fiecare lună dacă a intrat';

  @override
  String repeatsFromNextMonth(String day) {
    return 'Din luna viitoare, în fiecare $day';
  }

  @override
  String get savedWithRule => 'Salvat și setat ca lunar';

  @override
  String get autoBackup => 'Backup automat';

  @override
  String get autoBackupOn => 'Zilnic, pe telefon';

  @override
  String get autoBackupNever => 'Încă niciunul';

  @override
  String autoBackupLast(String when) {
    return 'Ultimul: $when';
  }

  @override
  String get autoBackupEmptyTitle => 'Niciun backup automat încă';

  @override
  String get autoBackupEmptyBody =>
      'Se face unul pe zi, automat, prima dată când deschizi aplicația.';

  @override
  String get autoBackupNow => 'Fă unul acum';

  @override
  String get autoBackupDone => 'Backup făcut';

  @override
  String autoBackupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de tranzacții',
      few: '$count tranzacții',
      one: 'o tranzacție',
    );
    return '$_temp0';
  }

  @override
  String get autoBackupWarnTitle => 'Unde ajung datele tale';

  @override
  String get autoBackupWarnBody =>
      'Snapshoturile zilnice de mai jos stau în aplicație și dispar odată cu ea dacă o dezinstalezi. Ca să rămână ceva pe telefon, alege un folder. Ca să se restaureze singur, pornește backupul Google.';

  @override
  String get restoreFrom => 'Restaurează din acesta';

  @override
  String get periodToday => 'Azi';

  @override
  String get periodYesterday => 'Ieri';

  @override
  String get periodThisWeek => 'Săptămâna aceasta';

  @override
  String get periodLastWeek => 'Săptămâna trecută';

  @override
  String get periodThisMonth => 'Luna aceasta';

  @override
  String get periodLastMonth => 'Luna trecută';

  @override
  String get backToNow => 'Revino la azi';

  @override
  String get twelveMonths => 'Ultimele 12 luni';

  @override
  String get twelveMonthsSub => 'Apasă pe o lună ca s-o deschizi';

  @override
  String get monthlyAverage => 'Medie lunară';

  @override
  String get noHistoryYet => 'Prea puțin istoric pentru o comparație pe luni.';

  @override
  String get folderBackup => 'Folder pe telefon';

  @override
  String get folderBackupNone => 'Nu ai ales unul încă';

  @override
  String get folderBackupPick => 'Alege un folder';

  @override
  String get folderBackupChange => 'Schimbă folderul';

  @override
  String get folderBackupWhy =>
      'Fișierele scrise aici rămân pe telefon chiar dacă dezinstalezi aplicația. Le vezi în Fișiere și le poți copia pe calculator sau trimite pe mail.';

  @override
  String get folderBackupLost => 'Nu mai am acces la folder';

  @override
  String get folderBackupLostBody =>
      'L-ai mutat, l-ai șters, sau ai reinstalat aplicația. Alege-l din nou ca backupurile să continue.';

  @override
  String get folderBackupEmpty => 'Niciun backup scris în folder încă';

  @override
  String get googleBackup => 'Backup în contul Google';

  @override
  String get googleBackupBody =>
      'Singurul care se restaurează singur, fără niciun pas din partea ta, atunci când reinstalezi aplicația pe același cont Google. Se pornește din setările telefonului — aplicația nu poate face asta în locul tău.';

  @override
  String get googleBackupOpen => 'Deschide setările telefonului';

  @override
  String get restoreFromFolder => 'Restaurează din folder';

  @override
  String get hadAppBefore => 'Ai mai folosit Tally?';

  @override
  String get hadAppBeforeBody =>
      'Dacă ai un folder cu backupuri de la o instalare anterioară, arată-mi-l și îți aduc datele înapoi.';

  @override
  String get findMyBackup => 'Caută backupul meu';

  @override
  String get noBackupsInFolder => 'Nu am găsit niciun backup în folderul ales.';

  @override
  String get restoreFoundBody =>
      'Îți aduc înapoi tranzacțiile, categoriile și plățile recurente din el. Nu ai nimic înregistrat acum, deci nu se pierde nimic.';

  @override
  String foundBackups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Am găsit $count de backupuri',
      few: 'Am găsit $count backupuri',
      one: 'Am găsit un backup',
    );
    return '$_temp0';
  }
}
