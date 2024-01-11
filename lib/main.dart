import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';

import 'curlib.dart';

final logger = Logger(
  filter: null, // Вы можете использовать свой фильтр сообщений
  printer: PrettyPrinter(), // Вы можете использовать свой принтер сообщений
  output: null, // Вы можете использовать свой вывод сообщений
);

const String baseCurrency = 'EUR'; // Нужно для новой конвертации

Future<Map<String, dynamic>> getExchangeRates(
    String base, List<String> symbols) async {
  final symbolsParam = symbols.join(',');
  final url =

      /// Fixer API (https://apilayer.com/marketplace/fixer-api#pricing)
      'https://api.apilayer.com/fixer/latest?symbols=$symbolsParam&base=$base'; // API где 100 в мес

  // 'https://api.apilayer.com/exchangerates_data/latest?base=$base&symbols=$symbolsParam'; // API где 250 в мес
  final headers = {'apikey': 'Ce22Skfg1m7OrpKSV5LhnDL9wRhNhDHE'};
  // JBzY0tW3H76VayxaW2ylPfaL8nhLwGi3
  // Ce22Skfg1m7OrpKSV5LhnDL9wRhNhDHE 11.01.2024
  // UK4FkPA8DyY8PIORlLrHOEXpIr6T5Hnu     // это хз что за ключ

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String _currentLocale = 'en';
  final ValueNotifier<bool> _isDarkMode = ValueNotifier(false); // Добавьте это

  @override
  void initState() {
    super.initState();
    _loadTheme();
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
            locale: Locale(_currentLocale),
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

class MainScreen extends StatefulWidget {
  final ValueNotifier<bool> isDarkMode;
  final Function(String) changeLocale;

  MainScreen({required this.isDarkMode, required this.changeLocale});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool areRatesLoaded = false;

  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = !widget.isDarkMode.value;
    setState(() {
      widget.isDarkMode.value = isDark;
    });
    prefs.setBool('isDarkMode', isDark);
  }

  // String? _currentLocale;
  String _currentLocale = 'en'; // Начальная локаль

  // void onLocaleChange(String newLocale) {
  //   if (widget.onLocaleChange != null) {
  //     widget.onLocaleChange!(newLocale);
  //   }
  // }

  final NumberFormat _formatter = NumberFormat("###,##0.##", "ru_RU");
  final List<String> _currencies = currenciesOrder;

  Map<String, dynamic> getCurrencyNames(String locale) {
    if (locale == 'ru') {
      return aliasesRU;
    } else {
      return aliasesEN;
    }
  }

  List<String> _selectedCurrencies = ['RUB', 'USD', 'EUR', 'ILS', 'KZT', 'GEL'];

  Map<String, double> _rates = {};

  void _changeLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newLocale = _currentLocale == 'en' ? 'ru' : 'en';
    prefs.setString('selectedLanguage', newLocale);
    widget.changeLocale(newLocale);
  }

  Future<void> _saveSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedCurrencies', _selectedCurrencies);
  } // сохранение-загрузка состояния

  Future<void> _loadSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedCurrencies = prefs.getStringList('selectedCurrencies');
    if (loadedCurrencies != null && loadedCurrencies.isNotEmpty) {
      setState(() {
        _selectedCurrencies = loadedCurrencies;
      });
    }
  } // сохранение-загрузка состояния

  @override
  void initState() {
    super.initState();
    // _loadTheme();
    _loadSelectedCurrencies(); // сохранение-загрузка состояния
    checkInternetConnection().then((hasInternet) {
      setState(() {
        _noInternetConnection = !hasInternet;
      });
      if (hasInternet) {
        _getRates();
      }
    });
  }

  bool _noInternetConnection = false;

  String selectedCurrency = '';
  // bool _isLoading = false;
  final List<TextEditingController> _controllers =
      List.generate(6, (i) => TextEditingController());

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    _focusNodes.forEach((node) => node.dispose());
    super.dispose();
  }

  final List<FocusNode> _focusNodes = List.generate(6, (i) => FocusNode());

  Future<void> _getRates() async {
    String base = baseCurrency;
    final symbols = _currencies;

    try {
      final result = await getExchangeRates(base, symbols);
      setState(() {
        _rates = result['rates'].map<String, double>((key, value) {
          return MapEntry<String, double>(
              key, value is double ? value : double.parse(value.toString()));
        });
        _lastUpdateTimestamp = result['timestamp'];
        areRatesLoaded = true; // Обновление флага после загрузки курсов
      });
    } catch (e) {
      activateError(
          context, AppLocalizations.of(context)!.exceptionRateFailure);
    }
  }

  void activateError(BuildContext context, String message) {
    showToast(
      message, // Используем переданное сообщение
      context: context,
      animation: StyledToastAnimation.slideFromBottomFade,
      position: StyledToastPosition.center,
      duration: const Duration(seconds: 2),
      // backgroundColor: _isDarkMode.value
      //                 ? const Color.fromARGB(255, 21, 25, 32)
      //                 : const Color.fromARGB(255, 92, 145, 113),,
      textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      curve: Curves.elasticOut,
      reverseCurve: Curves.linear,
    );
  }

//---------------------------- время
  int? _lastUpdateTimestamp;

  String formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    // final formattedDate = DateFormat.yMMMMd().add_jm().format(dt);
    final formattedDate = DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    return formattedDate;
  }

  void _recalculateCurrencies() {
    int baseIndex =
        _controllers.indexWhere((controller) => controller.text.isNotEmpty);
    if (baseIndex == -1) return; // Не выполняем перерасчёт, если все поля пусты

    double baseInputValue =
        double.tryParse(_controllers[baseIndex].text) ?? 0.0;
    String baseCurrency = _selectedCurrencies[baseIndex];
    double baseRate = _rates[baseCurrency] ?? 1.0;
    double toBaseValue = baseInputValue / baseRate;

    for (int i = 0; i < _controllers.length; i++) {
      if (i != baseIndex) {
        String currencyCode = _selectedCurrencies[i];
        double targetRate = _rates[currencyCode] ?? 1.0;
        double multipliedValue = toBaseValue * targetRate;
        _controllers[i].text = _formatter.format(multipliedValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // _currentLocale = Localizations.localeOf(context).languageCode;
    String locale = Localizations.localeOf(context).languageCode;
    Map<String, dynamic> currencyNames = getCurrencyNames(locale);

    var t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('EASY  CONVERTER')),
      body: Column(
        children: [
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _noInternetConnection
                    ? t.exceptionCheckConn
                    : (_lastUpdateTimestamp != null
                        ? '${t.mainCurUpdated}:    ${formatDate(_lastUpdateTimestamp!)}'
                        : t.mainRatesLoading),
                style: const TextStyle(
                  fontSize: 10, // размер шрифта
                  color: Color.fromARGB(255, 116, 177, 151), // цвет шрифта
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    const SizedBox(width: 20),
                    // Expanded(
                    // child:
                    SizedBox(
                      width: 80,
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              return ListView(
                                children: _currencies.map((String currency) {
                                  return ListTile(
                                    title: Text(
                                        '${currencyNames[currency]} ($currency)'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      setState(() {
                                        _selectedCurrencies[index] = currency;
                                        _saveSelectedCurrencies();
                                      });
                                      await _getRates(); // Обновляем курсы валют
                                      _recalculateCurrencies(); // Пересчитываем значения в полях ввода
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            // border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(5.0),
                          ),
                          child: Text(
                            _selectedCurrencies[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    // ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          style: const TextStyle(
                            fontSize: 26,
                          ),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          // enabled: _rates[_selectedCurrencies[index]] !=
                          //     null, // rates loading control
                          enabled: areRatesLoaded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                            TextInputFormatter.withFunction(
                                (oldValue, newValue) {
                              if (newValue.text.startsWith('0') &&
                                  newValue.text.length > 1 &&
                                  newValue.text[1] != '.') {
                                return TextEditingValue(
                                  text: newValue.text.substring(1),
                                  selection: newValue.selection.copyWith(
                                      baseOffset:
                                          newValue.selection.baseOffset - 1,
                                      extentOffset:
                                          newValue.selection.extentOffset - 1),
                                );
                              }
                              return newValue;
                            }),
                          ],
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            String numericValue =
                                value.replaceAll(RegExp(r'[^\d\s?\.?]'), '');
                            double inputValue =
                                double.tryParse(numericValue) ?? 0.0;
                            String selectedCurrency =
                                _selectedCurrencies[index];
                            for (int i = 0; i < 6; i++) {
                              if (i != index) {
                                String currencyCode = _selectedCurrencies[i];
                                double baseRate = _rates[selectedCurrency] ?? 1;
                                double toBaseValue = inputValue / baseRate;
                                double targetRate = _rates[currencyCode] ?? 1;
                                double multipliedValue =
                                    toBaseValue * targetRate;
                                String formattedValue =
                                    _formatter.format(multipliedValue);
                                _controllers[i].text = formattedValue;
                              }
                            }
                            setState(() {
                              _selectedCurrencies[index] = selectedCurrency;
                            });
                          },
                          onTap: () {
                            _focusNodes[index].addListener(() {
                              if (_focusNodes[index].hasFocus) {}
                            });
                          }),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        for (final controller in _controllers) {
                          controller.clear();
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Icon(Icons.close, size: 18.0),
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                );
              },
            ),
          ),
          // SizedBox(height: 0),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 150),
        child: SizedBox(
          height: 100,
          child: Row(
            // mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(t.mainAbout),
                          content: SingleChildScrollView(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: t.mainDisclamer1,
                                  ),
                                  TextSpan(
                                    text: t.mainDiclamer2,
                                    style: const TextStyle(color: Colors.blue),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        const url =
                                            'mailto:evgenyprudovsky@gmail.com';
                                        // ignore: deprecated_member_use
                                        await launch(url);
                                      },
                                  ),
                                  const TextSpan(
                                    text: " \n \n \n v. 0.2.0 (Beta)",
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("ОК"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Text(
                    t.mainInfo,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: Icon(widget.isDarkMode.value
                        ? Icons.nights_stay
                        : Icons.wb_sunny),
                    onPressed: _toggleTheme,
                  ),
                  Text(
                    t.mainTheme,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: const Icon(Icons.currency_exchange),
                    onPressed: () {
                      _getRates();
                    },
                  ),
                  Text(
                    t.mainUpdate,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: const Icon(Icons.language),
                    onPressed: _changeLanguage,
                  ),
                  Text(
                    t.mainLang,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
