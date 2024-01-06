import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
// import 'dart:math';
// import 'package:intl/number_symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  filter: null, // Вы можете использовать свой фильтр сообщений
  printer: PrettyPrinter(), // Вы можете использовать свой принтер сообщений
  output: null, // Вы можете использовать свой вывод сообщений
);

const String BASE_CURRENCY = 'EUR'; // Нужно для новой конвертации

Future<Map<String, dynamic>> getExchangeRates(
    String base, List<String> symbols) async {
  final symbolsParam = symbols.join(',');
  final url =
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
          home: MainScreen(isDarkMode: _isDarkMode),
          theme: ThemeData(
            brightness: isDarkMode ? Brightness.dark : Brightness.light,
            appBarTheme: AppBarTheme(
              backgroundColor: isDarkMode
                  ? Color.fromARGB(255, 21, 25, 32)
                  : Color.fromARGB(255, 92, 145, 113),
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

class ClearButton extends StatelessWidget {
  final List<TextEditingController> controllers;

  const ClearButton({Key? key, required this.controllers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        for (int i = 0; i < controllers.length; i++) {
          controllers[i].clear();
        }
      },
      child: Text('x'),
    );
  }
} // нужна ривизия - этот код нужен вообще?

class _MainScreenState extends State<MainScreen> {
  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      widget.isDarkMode.value = !widget.isDarkMode.value;
    });
    prefs.setBool('isDarkMode', widget.isDarkMode.value);
  } // для переключения светлая-темная тема

  final NumberFormat _formatter = NumberFormat("###,##0.##", "ru_RU");
  List<String> _currencies = [
    'RUB',
    'USD',
    'EUR',
    'GBP',
    'ILS',
    'KZT',
    'GEL',
    'BYR',
    'UAH',
    'AZN',
    'UZS ',
    'TJS',
    'KGS',
    'CNY',
    'AUD'
  ];

  List<String> _selectedCurrencies = ['RUB', 'USD', 'EUR', 'ILS', 'KZT', 'GEL'];
  Map<String, double> _rates = {
    'RUB': 1,
    'USD': 71,
    'EUR': 75,
    'ILS': 30,
    'KZT': 0.18,
    'GEL': 25
  };

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
  List<TextEditingController> _controllers =
      List.generate(6, (i) => TextEditingController());

  @override
  void dispose() {
    _controllers.forEach((controller) => controller.dispose());
    _focusNodes.forEach((node) => node.dispose());
    super.dispose();
  }

  List<FocusNode> _focusNodes = List.generate(6, (i) => FocusNode());

  Future<void> _getRates() async {
    String base = BASE_CURRENCY;
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

//---------------------------- время
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('EASY  CONVERTER')),
      body: Column(
        children: [
          SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _noInternetConnection
                    ? 'Проверьте соединение с Интернетом...'
                    : (_lastUpdateTimestamp != null
                        ? 'Курсы обновлены:    ${formatDate(_lastUpdateTimestamp!)}'
                        : 'Загрузка обменного курса...'),
                style: TextStyle(
                  fontSize: 10, // размер шрифта
                  color: Color.fromARGB(255, 113, 127, 116), // цвет шрифта
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    SizedBox(width: 30),
                    Expanded(
                      child: DropdownButton<String>(
                        elevation: 5,
                        underline: SizedBox(),
                        value: _selectedCurrencies[index],
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrencies[index] = value!;
                            _saveSelectedCurrencies();
                          });
                        },
                        items: _currencies
                            .map<DropdownMenuItem<String>>(
                              (currency) => DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          style: TextStyle(
                            fontSize: 26,
                          ),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          enabled: _rates[_selectedCurrencies[index]] !=
                              null, // rates loading control
                          keyboardType: TextInputType.numberWithOptions(
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
                          decoration: InputDecoration(
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
                            //------------------------------------▼
                            // попытка сделать форматирование для строки ввода
                            // for (int i = 0; i < 6; i++) {
                            //   if (i == index) {
                            //     String formattedValue =
                            //         _formatter.format(inputValue);
                            //     print(formattedValue);

                            //     _controllers[i].text = formattedValue;
                            //     final newCursorPosition = formattedValue.length;
                            //     _controllers[index].selection =
                            //         TextSelection.fromPosition(
                            //       TextPosition(
                            //           offset:
                            //               newCursorPosition), // когда включено - невозможно поставить точку
                            //     );
                            //   }
                            // }
                            //-----------------------------▲
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
                    SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        for (final controller in _controllers) {
                          controller.clear();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Icon(Icons.close, size: 14.0),
                      ),
                    ),
                    SizedBox(width: 20),
                  ],
                );
              },
            ),
          ),
          // SizedBox(height: 0),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 150),
        child: Container(
          height: 100,
          child: Row(
            // mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: Icon(Icons.info),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("О приложении"),
                          content: SingleChildScrollView(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        "Простой конвертер валют создан для вашего удобства.\n \nБуду рад любым пожеланиям, рекламациям и благодарностям, ",
                                  ),
                                  TextSpan(
                                    text: "пишите!",
                                    style: TextStyle(color: Colors.blue),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        const url =
                                            'mailto:ilyichstock@gmail.com';
                                        // ignore: deprecated_member_use
                                        await launch(url);
                                      },
                                  ),
                                  TextSpan(
                                    text: " \n \n \n v. 0.0.1 (Beta)",
                                  ),
                                ],
                              ),
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("ОК"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Text(
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
                  Text(
                    'Тема',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  IconButton(
                    icon: Icon(Icons.currency_exchange),
                    onPressed: () {
                      _getRates();
                    },
                  ),
                  Text(
                    'Курс',
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
