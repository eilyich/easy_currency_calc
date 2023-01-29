import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, double>> getExchangeRates(String baseCurrency) async {
  var response = await http.get(
      Uri.parse('https://api.exchangerate-api.com/v4/latest/$baseCurrency'));
  if (response.statusCode == 200) {
    Map<String, dynamic> data = jsonDecode(response.body);
    Map<String, double> rates = {};
    data['rates'].forEach((key, value) {
      rates[key] = value.toDouble();
    });
    return rates;
  } else {
    throw Exception('Failed to load exchange rates');
  }
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<double> _inputValues = List.generate(6, (i) => 0);
  List<String> _currencies = ['USD', 'RUB', 'EUR', 'GEL', 'KZT', 'ILS'];
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  late Map<String, double> _exchangeRates;
  int _baseCurrencyIndex = 0;

  @override
  void initState() {
    super.initState();
    getExchangeRates(_currencies[_baseCurrencyIndex]).then((value) {
      setState(() {
        _exchangeRates = value;
      });
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          for (var i = 0; i < 6; i++)
            Row(
              children: [
                DropdownButton<String>(
                  value: _currencies[i],
                  onChanged: (value) {
                    setState(() {
                      _currencies[i] = value!;
                      if (i == _baseCurrencyIndex) {
                        getExchangeRates(value!).then((value) {
                          setState(() {
                            _exchangeRates = value;
                          });
                        });
                      }
                      _baseCurrencyIndex = i;
                    });
                  },
                  items: _currencies
                      .map((currency) => DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(),
                ),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      if (value == null || value.isEmpty) {
                        setState(() {
                          _inputValues[i] = 0;
                        });
                        return;
                      }
                      double enteredValue = double.parse(value);
                      setState(() {
                        _inputValues[i] = enteredValue;
                        for (var j = 0; j < 6; j++) {
                          if (j != i) {
                            _inputValues[j] = enteredValue *
                                (_exchangeRates[_currencies[j]] ?? 1);
                            _controllers[j].text = _inputValues[j].toString();
                            _controllers[j].selection =
                                TextSelection.fromPosition(TextPosition(
                                    offset: _controllers[j].text.length));
                          }
                        }
                      });
                      // extract the baseCurrency value here
                      String baseCurrency = _currencies[i];
                      getExchangeRates(baseCurrency).then((value) {
                        setState(() {
                          _exchangeRates = value;
                        });
                      });
                    },
                    // show input value multiplied by selected currency rate
                    controller: _controllers[i],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
