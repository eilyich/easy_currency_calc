import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'curlib.dart';

final logger = Logger(
  filter: null, // Вы можете использовать свой фильтр сообщений
  printer: PrettyPrinter(), // Вы можете использовать свой принтер сообщений
  output: null, // Вы можете использовать свой вывод сообщений
);

const String baseCurrency = 'EUR'; // Нужно для новой конвертации

Future<Map<String, dynamic>> getExchangeRates(
    String base, List<String> symbols) async {
  final apikey = dotenv.env['API_KEY']; // Переместите это сюда

  if (apikey == null) {
    throw Exception('API ключ не найден.');
  }

  final symbolsParam = symbols.join(',');
  final url =

      /// Fixer API (https://apilayer.com/marketplace/fixer-api#pricing)
      'https://api.apilayer.com/fixer/latest?symbols=$symbolsParam&base=$base';

  final headers = {'apikey': apikey};

  final response = await http.get(Uri.parse(url), headers: headers);

  final statusCode = response.statusCode;
  final result = response.body;

  if (statusCode == 200) {
    final json = jsonDecode(result);
    final rates = json['rates'];
    final timestamp = json['timestamp'];
    return {'rates': rates, 'timestamp': timestamp};
  } else {
    throw Exception('Не удалось получить обменный курс');
  }
}

Future<bool> checkInternetConnection() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    return false;
  } else {
    return true;
  }
}

// void main() {
//   runApp(MyApp());
// }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  // ignore: unused_field
  String _currentLocale = 'en';
  Locale _locale =
      const Locale('en'); // Используйте язык по умолчанию, например, английский

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<bool> _isDarkMode = ValueNotifier(false); // Добавьте это

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadLocale();
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void changeLocale(String locale) {
    setState(() {
      _currentLocale = locale;
    });
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _loadLocale() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String localeCode = prefs.getString('selectedLanguage') ?? 'en';
    setState(() {
      _locale = Locale(localeCode); // Инициализация _locale здесь
    });
  }

  void setNewLocale(String localeCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', localeCode);
    setState(() {
      _locale = Locale(localeCode);
    });
  }

  void changeLanguage() async {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      context: navigatorKey.currentState!.context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 200, // Укажите желаемую высоту
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('English'),
                onTap: () {
                  Navigator.pop(context);
                  setNewLocale('en');
                },
              ),
              ListTile(
                title: const Text('Русский'),
                onTap: () {
                  Navigator.pop(context);
                  setNewLocale('ru');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: _isDarkMode,
        builder: (context, isDarkMode, child) {
          return MaterialApp(
            // Добавьте return здесь
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // locale: Locale(_currentLocale),
            locale: _locale,
            home: MainScreen(
              isDarkMode: _isDarkMode,
              changeLocale: changeLocale,
            ),
            theme: ThemeData(
              brightness: _isDarkMode.value
                  ? Brightness.dark
                  : Brightness.light, // Используйте _isDarkMode здесь
              appBarTheme: AppBarTheme(
                backgroundColor: _isDarkMode.value
                    ? const Color.fromARGB(255, 21, 25, 32)
                    : const Color.fromARGB(255, 92, 145, 113),
              ),
            ),
          );
        });
  }
}

class CurrencySearchSheet extends StatefulWidget {
  final List<String> currencyList;
  final Map<String, String> currencyNames;
  final Function(String) onSelectCurrency;

  CurrencySearchSheet({
    Key? key,
    required this.currencyList,
    required this.currencyNames,
    required this.onSelectCurrency,
  }) : super(key: key);

  @override
  _CurrencySearchSheetState createState() => _CurrencySearchSheetState();
}

class _CurrencySearchSheetState extends State<CurrencySearchSheet> {
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.mainSearch,

              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                        });
                      },
                    )
                  : null,

              // suffixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide:
                    BorderSide.lerp(const BorderSide(), const BorderSide(), 1),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: ListView(
            children: widget.currencyList
                .where((currency) => widget.currencyNames[currency]!
                    .toLowerCase()
                    .contains(searchController.text.toLowerCase()))
                .map((String currency) {
              return ListTile(
                title: Text('${widget.currencyNames[currency]} ($currency)'),
                onTap: () {
                  widget.onSelectCurrency(currency);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class MainScreen extends StatefulWidget {
  final ValueNotifier<bool> isDarkMode;
  final Function(String) changeLocale;

  MainScreen({required this.isDarkMode, required this.changeLocale});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late List<Widget> _rows;
  bool areRatesLoaded = false;
  // bool _isInEditMode = false;
  int? _lastUpdateTimestamp;
  int _activeInputIndex = -1;
  final NumberFormat _formatter = NumberFormat("###,##0.##", "ru_RU");
  List<String> _selectedCurrencies = ['USD', 'EUR', 'RUB', 'CNY'];
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  Map<String, double> _rates = {};
  bool _noInternetConnection = false;
  String selectedCurrency = '';
  TextEditingController searchController = TextEditingController();
  bool _isInitialized = false;
  Timer? _retryTimer;

  //////
  /// ПОЛУЧЕНИЕ АЛИАСОВ -
  Map<String, String> getCurrencyNames(String locale) {
    Map<String, dynamic> selectedMap = (locale == 'ru') ? aliasesRU : aliasesEN;

    return selectedMap.map((key, value) {
      return MapEntry(key, value.toString());
    });
  }

  //////
  /// ПОЛУЧЕНИЕ ПОРЯДКОВОГО СПИСКА ВАЛЮТ
  List<String> getCurrencyList(String locale) {
    if (locale == 'ru') {
      return currenciesOrderRU;
    } else {
      return currenciesOrderEN;
    }
  }

  //////
  /// СМЕНА ЦВЕТОВОЙ ТЕМЫ
  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = !widget.isDarkMode.value;
    setState(() {
      widget.isDarkMode.value = isDark;
    });
    prefs.setBool('isDarkMode', isDark);
  }

  //////
  /// СОХРАНЕНИЕ СОСТОЯНИЯ ВЫБРАННЫХ ВАЛЮТ
  Future<void> _saveSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedCurrencies', _selectedCurrencies);
  }

  //////
  /// ЗАГРУЗКА СОСТОЯНИЯ ВЫБРАННЫХ ВАЛЮТ
  Future<void> _loadSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedCurrencies = prefs.getStringList('selectedCurrencies');
    if (loadedCurrencies != null && loadedCurrencies.isNotEmpty) {
      setState(() {
        _selectedCurrencies = loadedCurrencies;
      });
    }
  }

  //////
  /// СОХРАНЕНИЕ КУРСА В SHARED PREFERENCES
  Future<void> _saveRatesToSharedPreferences(Map<String, dynamic> rates) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('rates', jsonEncode(rates));
  }

  //////
  /// ЗАГРУЗКА КУРСОВ ИЗ SHARED PREFERENCES
  Future<void> _loadRatesFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesString = prefs.getString('rates');
    if (ratesString != null) {
      final ratesMap = jsonDecode(ratesString) as Map<String, dynamic>;
      setState(() {
        _rates = ratesMap.map<String, double>(
            (key, value) => MapEntry(key, (value as num).toDouble()));
        areRatesLoaded = true;
      });
    }
  }

  //////
  /// ОБНОВЛЕНИЕ СОСТОЯНИЯ ТЕКСТОВЫХ ПОЛЕЙ
  void _updateCurrencyFields() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('numFields', _selectedCurrencies.length);
      _controllers = List.generate(
          _selectedCurrencies.length, (_) => TextEditingController());
      _focusNodes =
          List.generate(_selectedCurrencies.length, (_) => FocusNode());
    });
  }

  //////////////////////////////////////////////////////////////////////////////
  /// ДОБАВЛЕНИЕ ПОЛЯ ДЛЯ РАССЧЁТА КУРСОВ
  void _addCurrencyField() {
    if (_selectedCurrencies.length >= 20) {
      return;
    }

    String locale = Localizations.localeOf(context).languageCode;
    Map<String, String> currencyNames = getCurrencyNames(locale);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (BuildContext context) {
        return CurrencySearchSheet(
          currencyList: getCurrencyList(locale),
          currencyNames: currencyNames,
          onSelectCurrency: (currency) {
            setState(() {
              _selectedCurrencies.add(currency); // Добавляем выбранную валюту
              _controllers.add(TextEditingController());
              _focusNodes.add(FocusNode());
            });
            _updateCurrencyFields();
            _saveSelectedCurrencies(); // Сохраняем изменения в SharedPreferences
          },
        );
      },
    );
  }

  /// ДОБАВЛЕНИЕ НОВОЙ СТРОКИ-ВИДЖЕТА
  void _addNewRow() {
    setState(() {
      int newIndex = _rows.length - 1; // Индекс перед кнопкой добавления
      _rows.insert(newIndex, _buildItem(newIndex));
      // Обновление индексов элементов после нового
      for (int i = newIndex + 1; i < _rows.length - 1; i++) {
        _rows[i] = _buildItem(i);
      }
    });
  }
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  /// УДАЛЕНИЕ ПОЛЯ ВАЛЮТЫ
  void _removeCurrencyField(int index) {
    setState(() {
      _selectedCurrencies.removeAt(index);
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _focusNodes[index].dispose();
      _focusNodes.removeAt(index);
    });
    _updateCurrencyFields(); // Обновляем после удаления поля
    _saveSelectedCurrencies(); // Сохраняем изменения в SharedPreferences
  }

  /// УДАЛЕНИЕ СТРОКИ-ВИДЖЕТА
  void _removeItem(int index) {
    setState(() {
      _rows.removeAt(index);
      // Обновление индексов оставшихся элементов
      for (int i = index; i < _rows.length - 1; i++) {
        _rows[i] = _buildItem(i);
      }
    });
  }
  //////////////////////////////////////////////////////////////////////////////

  //////
  /// ПОЛУЧЕНИЕ КУРСОВ ВАЛЮТ ПО API
  Future<void> _getRates() async {
    try {
      // final result = await getExchangeRates(baseCurrency, _currencies);
      final result = await getExchangeRates(baseCurrency,
          getCurrencyList(Localizations.localeOf(context).languageCode));
      setState(() {
        _rates = result['rates'].map<String, double>((key, value) =>
            MapEntry<String, double>(
                key, value is double ? value : double.parse(value.toString())));
        _lastUpdateTimestamp = result['timestamp'];
        areRatesLoaded = true;

        // Перерасчет валют и сохранение курсов в SharedPreferences
        if (areRatesLoaded) {
          _recalculateCurrencies();
        }
        _saveRatesToSharedPreferences(result['rates']);
      });
    } catch (e) {
      activateError(
          context, AppLocalizations.of(context)!.exceptionRateFailure);

      // Установка таймера для повторного запроса
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 10), () {
        if (!areRatesLoaded) {
          _getRates();
        }
      });
    }
  }

  //////
  /// ПОКАЗ ВСПЛЫВАЮЩЕГО УВЕДОМЛЕНИЯ
  void activateError(BuildContext context, String message) {
    showToast(
      message, // Используем переданное сообщение
      context: context,
      animation: StyledToastAnimation.slideFromBottomFade,
      position: StyledToastPosition.center,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.grey,
      textStyle: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white),
      curve: Curves.elasticOut,
      reverseCurve: Curves.linear,
    );
  }

  /// ФОРМАТИРВОВАНИЕ ДАТЫ И ВРЕМЕНИ
  String formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final formattedDate = DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    return formattedDate;
  }

  //////
  /// ПЕРЕРАСЧЁТ ВАЛЮТ ПРИ СМЕНЕ ВАЛЮТЫ
  void _recalculateCurrencies() {
    if (_activeInputIndex == -1) return; // Если нет активного ввода, выходим

    double baseInputValue =
        double.tryParse(_controllers[_activeInputIndex].text) ?? 0.0;
    String baseCurrency = _selectedCurrencies[_activeInputIndex];
    double baseRate = _rates[baseCurrency] ?? 1.0;

    int minSize = min(_controllers.length, _selectedCurrencies.length);
    for (int i = 0; i < minSize; i++) {
      if (i != _activeInputIndex) {
        String currencyCode = _selectedCurrencies[i];
        double targetRate = _rates[currencyCode] ?? 1.0;
        double convertedValue = (baseInputValue / baseRate) * targetRate;
        _controllers[i].text = _formatter.format(convertedValue);
      }
    }

    _activeInputIndex = -1; // Сброс активного индекса после пересчёта
  }

  //////
  /// НОВЫЙ INIT STATE
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      // Загружаем сохраненный список валют
      List<String> loadedCurrencies =
          prefs.getStringList('selectedCurrencies') ??
              ['USD', 'EUR', 'RUB', 'CNY'];

      // Инициализируем _selectedCurrencies сохраненными данными
      _selectedCurrencies = loadedCurrencies;

      // Инициализируем контроллеры и фокусы для каждой валюты
      _controllers = List.generate(
          _selectedCurrencies.length, (_) => TextEditingController());
      _focusNodes =
          List.generate(_selectedCurrencies.length, (_) => FocusNode());

      setState(() {
        _isInitialized = true;
      });
    });

    _loadRatesFromSharedPreferences();
    checkInternetConnection().then((hasInternet) {
      setState(() {
        _noInternetConnection = !hasInternet;
      });
      if (hasInternet) {
        _getRates();
      }
    });
  }

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    _focusNodes.forEach((node) => node.dispose());
    _retryTimer?.cancel();
    super.dispose();
  }

  //////
  /// СТАРЫЙ  INIT STATE
  // @override
  // void initState() {
  //   super.initState();
  //   _rows = [];
  //   _addAddButton();
  // }

  void _addAddButton() {
    _rows.add(
      ListTile(
        key: ValueKey('add_button'), // Уникальный ключ для кнопки добавления
        title: Text('Добавить строку'),
        onTap: _addNewRow,
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > _rows.length - 1) {
        newIndex = _rows.length - 1;
      }
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final Widget row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
    });
  }

  Widget _buildItem(int index) {
    return ReorderableDragStartListener(
      key: ValueKey('item $index'),
      index: index,
      child: ListTile(
        title: Text('Text $index'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.info),
              onPressed: () {
                // --
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Info'),
                      content: Text('Button $index pressed'),
                      actions: [
                        InkWell(
                          child: Text('OK'),
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
                // ---------- showDialog
              },
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeItem(index),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reorderable List'),
      ),
      body: ReorderableColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _rows,
        onReorder: _onReorder,
      ),
    );
  }
}
