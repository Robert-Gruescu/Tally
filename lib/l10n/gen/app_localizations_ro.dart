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
}
