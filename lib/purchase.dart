import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  // String _currency = '';

  @override
  void initState() {
    super.initState();
    _loadPriceAndCurrency();
  }

  Future<void> _loadPriceAndCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _price = prefs.getString('productPrice') ?? '';
      // _currency = prefs.getString('productCurrency') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;

    bool isAdFreeState = MyApp.of(context)!.isAdFreeState;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(t
            .drawerRemoveAds), // Предполагая, что у вас есть такой ключ в вашем файле локализации
      ),
      body: Column(children: [
        _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    CircularProgressIndicator()
                  ]) // Показываем индикатор загрузки, если _isLoading == true
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isAdFreeState
                      ? Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 50),
                              Center(
                                child: SvgPicture.asset(
                                  'assets/money-cash-purchased.svg', // Путь к SVG для состояния без рекламы
                                  width: 200.0,
                                  height: 200.0,
                                  colorFilter: const ColorFilter.mode(
                                      Color.fromARGB(255, 116, 177, 151),
                                      BlendMode.srcIn),
                                ),
                              ),
                              const SizedBox(height: 50),
                              Text(
                                t.purchaseScreenBuyTY1,
                                style: const TextStyle(
                                    color: Color.fromARGB(255, 116, 177, 151),
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 10),
                              Text(t.purchaseScreenBuyTY2,
                                  style: const TextStyle(fontSize: 16))
                            ],
                          ))
                      : Column(
                          children: [
                            const SizedBox(height: 50),
                            Center(
                              child: SvgPicture.asset(
                                'assets/money-cash-purchase.svg', // Исходный путь к SVG
                                width: 220.0,
                                height: 220.0,
                                colorFilter: const ColorFilter.mode(
                                    Color.fromARGB(255, 116, 177, 151),
                                    BlendMode.srcIn),
                              ),
                            ),
                            const SizedBox(
                              height: 50,
                            ),
                            Text(
                              t.purchaseScreenPayOnceUseForever,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            _price != ""
                                ? Text(
                                    _price,
                                    style: const TextStyle(
                                        color:
                                            Color.fromARGB(255, 116, 177, 151),
                                        fontSize: 50,
                                        fontStyle: FontStyle.italic),
                                  )
                                : LoadingAnimationWidget.staggeredDotsWave(
                                    color: const Color.fromARGB(
                                        255, 116, 177, 151),
                                    size: 70),
                            const SizedBox(
                              height: 20,
                            ),
                            Text(t.purchaseScreenProVersion),
                            Padding(
                              padding: const EdgeInsets.all(
                                  16.0), // Добавляем отступы вокруг кнопки для визуального комфорта
                              child: ConstrainedBox(
                                constraints: const BoxConstraints.tightFor(
                                    width: double
                                        .infinity), // Задаем максимальную ширину
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading =
                                          true; // Включаем индикатор загрузки
                                    });
                                    try {
                                      final onTapState = MyApp.of(context);
                                      isAdFreeState
                                          ? activateError(context, t.miscAds)
                                          : (onTapState?.productDetails != null)
                                              ? onTapState?.buyProduct()
                                              : activateError(context,
                                                  t.exceptionGooglePlayUnavailable);
                                    } catch (e) {
                                      // Обрабатываем любые ошибки, возникшие во время покупки
                                      activateError(context,
                                          t.purchaseScreenPurchaseError);
                                      // Возможно, показать диалоговое окно с ошибкой или Snackbar
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }, // Добавьте соответствующий текст для кнопки
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.all<Color>(
                                            const Color.fromARGB(255, 116, 177,
                                                151)), // Цвет фона кнопки
                                    padding:
                                        MaterialStateProperty.all<EdgeInsets>(
                                      const EdgeInsets.symmetric(
                                          vertical:
                                              5.0), // Внутренние отступы для высоты кнопки
                                    ),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            3.0), // Скругление углов
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    t.purchaseScreenBuyButton,
                                    style: const TextStyle(
                                        color: Colors.black, fontSize: 16),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                ],
              )
      ]),
    );
  }
}
