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
  final headers = {'apikey': 'JBzY0tW3H76VayxaW2ylPfaL8nhLwGi3'};
  // JBzY0tW3H76VayxaW2ylPfaL8nhLwGi3
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
  WidgetsFlutterBinding.ensureInitialized(); // добавленная строка
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ValueNotifier<bool> _isDarkMode =
      ValueNotifier(false); // переключение тем

  MyApp() {
    _loadTheme();
  }

  void _loadTheme() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkMode,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // locale: Locale(_currentLocale), // Установка локали

          home: MainScreen(isDarkMode: _isDarkMode),
          theme: ThemeData(
            brightness: isDarkMode ? Brightness.dark : Brightness.light,
            appBarTheme: AppBarTheme(
              backgroundColor: isDarkMode
                  ? const Color.fromARGB(255, 21, 25, 32)
                  : const Color.fromARGB(255, 92, 145, 113),
            ),
          ),
        );
      },
    );
  }
} // новый метод с темой

class MainScreen extends StatefulWidget {
  final ValueNotifier<bool> isDarkMode; // для изменения темы
  MainScreen({required this.isDarkMode}); // для изменения темы

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      widget.isDarkMode.value = !widget.isDarkMode.value;
    });
    prefs.setBool('isDarkMode', widget.isDarkMode.value);
  } // для переключения светлая-темная тема

  // String? _currentLocale;
  String _currentLocale = 'en'; // Начальная локаль

  // void onLocaleChange(String newLocale) {
  //   if (widget.onLocaleChange != null) {
  //     widget.onLocaleChange!(newLocale);
  //   }
  // }

  final NumberFormat _formatter = NumberFormat("###,##0.##", "ru_RU");
  final List<String> _currencies = [
    'RUB',
    'USD',
    'EUR',
    'GBP',
    'ILS',
    'KZT',
    'GEL',
    'BYN',
    'UAH',
    'AZN',
    'UZS ',
    'TJS',
    'KGS',
    'CNY',
    'AUD',
    'THB',
    'VND',
    'KRW',
    'TRY',
    'TMT',
    'PLN',
    'SEK',
    'NOK',
    'LKR',
    'MYR',
    'IDR',
    'JPY',
    'SGD',
    'RSD',
    'CHF'
  ];

  Map<String, String> currencyNames = {
    'RUB': 'Российский рубль',
    'USD': 'Доллар США',
    'EUR': 'Евро',
    'ILS': 'Шекель',
    'KZT': 'Теньгушки',
    'GEL': 'Лари'
  };

  List<String> _selectedCurrencies = [
    'RUB',
    'USD',
    'EUR',
    'ILS',
    'KZT',
    'GEL',
    'EUR'
  ];

  Map<String, double> _rates = {
    'RUB': 1,
    'USD': 1,
    'EUR': 1,
    'ILS': 1,
    'KZT': 1,
    'GEL': 1
  };

  void _changeLanguage() {
    setState(() {
      _currentLocale = _currentLocale == 'en' ? 'ru' : 'en';
    });
  }

  // void _changeLanguage() {
  //   setState(() {
  //     _currentLocale = _currentLocale == 'en' ? 'ru' : 'en';
  //     onLocaleChange(_currentLocale);
  //   });
  // }

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
    _loadSelectedCurrencies(); // сохранение-загрузка состояния
    checkInternetConnection().then((hasInternet) {
      setState(() {
        _noInternetConnection = !hasInternet;
      });
      if (hasInternet) {
        _getRates();
      }
    });
    // _getRates();
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
      });
    } catch (e) {
      print('Error fetching exchange rates: $e');
    }
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
    _currentLocale = Localizations.localeOf(context).languageCode;

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
                          enabled: _rates[_selectedCurrencies[index]] !=
                              null, // rates loading control
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
                          title: const Text("О приложении"),
                          content: SingleChildScrollView(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text:
                                        "Простой конвертер валют создан для вашего удобства.\n \nБуду рад любым пожеланиям, рекламациям и благодарностям, ",
                                  ),
                                  TextSpan(
                                    text: "пишите!",
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
                  const Text(
                    'Инфо',
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
                  const Text(
                    'Тема',
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
                  const Text(
                    'Курс',
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
                  const Text(
                    'Язык',
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
