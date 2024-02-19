import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'activateerror.dart';
import 'main.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String _price = '';
  String _currency = '';

  @override
  void initState() {
    super.initState();
    _loadPriceAndCurrency();
  }

  Future<void> _loadPriceAndCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _price = prefs.getString('productPrice') ?? '';
      _currency = prefs.getString('productCurrency') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(t
            .drawerRemoveAds), // Предполагая, что у вас есть такой ключ в вашем файле локализации
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator() // Показываем индикатор загрузки, если _isLoading == true
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // ignore: unnecessary_null_comparison
                (_price != '')
                    ? Text("Price: $_price $_currency")
                    : LoadingAnimationWidget.staggeredDotsWave(
                        color: const Color.fromARGB(255, 116, 177, 151),
                        size: 50),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _isLoading = true; // Включаем индикатор загрузки
                    });

                    try {
                      final onTapState = MyApp.of(context);
                      if (await onTapState?.isAdFreeChecker() ?? false) {
                        // Реклама уже отключена, показываем сообщение
                        activateError(context, t.miscAds);
                      } else {
                        if (onTapState?.productDetails != null) {
                          onTapState?.buyProduct();
                        } else {
                          activateError(
                              context, t.exceptionGooglePlayUnavailable);
                        }
                      }
                    } catch (e) {
                      // Обрабатываем любые ошибки, возникшие во время покупки
                      print('Произошла ошибка при покупке: $e');
                      // Возможно, показать диалоговое окно с ошибкой или Snackbar
                    } finally {
                      setState(() {
                        _isLoading =
                            false; // Выключаем индикатор загрузки после завершения операции
                      });
                    }
                  },
                  child:
                      Text("buy"), // Добавьте соответствующий текст для кнопки
                ),
              ]),
      ),
    );
  }
}
