// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
// import 'dart:html';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:country_flags/country_flags.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'curlib.dart';
import 'help.dart';
import 'activateerror.dart';
import 'purchase.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await dotenv.load(fileName: ".env");
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

/// //////////////////////////////////////////////////////////////////////////
/// MYAPP ////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    final _MyAppState? result = context.findAncestorStateOfType<_MyAppState>();
    if (result != null) {
      return result;
    } else {
      throw Exception('Unable to find _MyAppState in context');
    }
  }
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<PurchaseDetails>>? subscription;
  ProductDetails? productDetails;
  // ignore: unused_field
  String _currentLocale = 'en';
  Locale _locale =
      const Locale('en'); // Используйте язык по умолчанию, например, английский
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<bool> _isDarkMode = ValueNotifier(false);
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  // Переменная используется для хранения состояния — отключена ли реклама в приложении.
  // Изначально устанавливается в false, указывая, что реклама включена.
  bool isAdFreeState = false;

  // Идентификатор продукта для отключения рекламы.
  final String _kAdFreeId = 'remove_ads_01';

  /// //////////////////////////////////////////////////////////////////////////
  /// INIT STATE ///////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////

  @override
  void initState() {
    InAppPurchase.instance.purchaseStream.listen((purchaseDetailsList) {
      isAdFreeChecker(purchaseDetailsList).then((isPurchased) {
        setState(() {
          isAdFreeState = isPurchased;
        });
        updatePurchaseStatus();
      });
    }, onDone: () {}, onError: (error) {});
    // updatePurchaseStatus();
    super.initState();
    _loadTheme();
    _loadLocale();
    _loadProducts(); // Загрузите доступные продукты для покупки
    InAppPurchase.instance.restorePurchases();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  // Асинхронно проверяет, не куплена ли уже опция без рекламы.
  // Если нет, и если доступны детали продукта, инициирует процесс покупки
  // с использованием метода InAppPurchase.instance.buyNonConsumable().
  void buyProduct() async {
    // final bool isAdFree = await isAdFreeChecker();
    final bool isAdFree = isAdFreeState;
    if (!isAdFree) {
      // Логика покупки продукта
      // Загрузите детали продукта, если они ещё не загружены
      if (productDetails != null) {
        final PurchaseParam purchaseParam =
            PurchaseParam(productDetails: productDetails!);
        InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // print("Детали продукта не доступны");
        activateError(navigatorKey.currentContext!, 'детали недоступны');
      }
    } else {
      // print('товар уже куплен');
      activateError(navigatorKey.currentContext!, 'товар уже куплен');
    }
  }

  // / Меняем возвращаемый тип метода на Future<bool> для асинхронного возвращения значения
  Future<bool> isAdFreeChecker(
      List<PurchaseDetails> purchaseDetailsList) async {
    // Проходим по списку деталей покупок асинхронно
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      // Проверяем статус покупки
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        return true; // Покупка найдена и подтверждена
      }
    }
    // Если ни одна покупка не соответствует критериям, возвращаем false
    return false;
  }

  int maxSelectedCurrencies = 4;
  bool isAdFreeScreenStatus = true;

  Future<void> updatePurchaseStatus() async {
    try {
      setState(() {
        maxSelectedCurrencies = isAdFreeState ? 30 : 6;
        print("Статус количества строк обновлен: $maxSelectedCurrencies");
      });
    } catch (e) {
      print("Ошибка обработки статуса покупки");
    }
  }

  Future<void> _saveMaxSelectedCurrencies(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxSelectedCurrencies', value);
  }

  Future<int> _loadMaxSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('maxSelectedCurrencies') ??
        4; // Возвращаем 4, если значение не найдено
  }

  // Обрабатывает обновления покупок.
  // Для каждой успешной покупки с идентификатором _kAdFreeId вызывает _disableAds(), чтобы отключить рекламу.
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased &&
          purchaseDetails.productID == _kAdFreeId) {
        // Покупка успешно завершена, отключаем рекламу
        _disableAds();
      }
    }
  }

  // Асинхронно проверяет доступность магазина
  // и запрашивает детали продукта для идентификатора _kAdFreeId.
  // При успешном получении данных обновляет productDetails для последующей покупки.
  Future<void> _loadProducts() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      // Магазин недоступен
      print('The store is not available');
      return;
    }

    Set<String> kIds = <String>{_kAdFreeId};
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      // Продукт не найден
      activateError(
          context, 'The product $_kAdFreeId was not found in the store');
      // print('The product $_kAdFreeId was not found in the store');
      return;
    }

    // Обрабатываем полученные данные о продукте
    if (response.productDetails.isNotEmpty) {
      setState(() {
        productDetails = response.productDetails.first;
        _savePriceAndCurrency(
            productDetails!.price, productDetails!.currencyCode);
      });
    }
  }

  Future<void> _savePriceAndCurrency(String price, String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('productPrice', price);
    await prefs.setString('productCurrency', currency);
  }

  // Асинхронно сохраняет в SharedPreferences значение true для ключа adFree,
  // указывая на то, что опция отключения рекламы куплена, и обновляет состояние isAdFreeState.
  void _disableAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adFree', true);
    setState(() {
      isAdFreeState = true; // Обновляем состояние
    });
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

  void changeLanguage() {
    // Определение текущего языка и смена на другой
    String newLocale = _locale.languageCode == 'en' ? 'ru' : 'en';

    setState(() {
      setNewLocale(newLocale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: _isDarkMode,
        builder: (context, isDarkMode, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: _locale,
            home: MainScreen(
              isDarkMode: _isDarkMode,
              changeLocale: changeLocale,
            ),
            theme: ThemeData(
              brightness:
                  _isDarkMode.value ? Brightness.dark : Brightness.light,
              appBarTheme: AppBarTheme(
                backgroundColor: _isDarkMode.value
                    ? const Color.fromARGB(255, 20, 25, 30)
                    : const Color.fromARGB(255, 180, 200, 190),
              ),
            ),
          );
        });
  }
}

/// //////////////////////////////////////////////////////////////////////////
/// SEARCH SHEET /////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////

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

/// //////////////////////////////////////////////////////////////////////////
/// MAIN SCREEN //////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////
/// //////////////////////////////////////////////////////////////////////////

class MainScreen extends StatefulWidget {
  final ValueNotifier<bool> isDarkMode;
  final Function(String) changeLocale;

  MainScreen({required this.isDarkMode, required this.changeLocale});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ignore: unused_field
  int? _lastUpdateTimestamp;
  // ignore: unused_field
  bool _noInternetConnection = false;

  bool areRatesLoaded = false;
  int _activeInputIndex = -1;
  final NumberFormat _formatter = NumberFormat("###,##0.##", "ru_RU");
  List<String> _selectedCurrencies = ['USD', 'EUR', 'RUB', 'CNY'];
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  Map<String, double> _rates = {};
  String selectedCurrency = '';
  TextEditingController searchController = TextEditingController();
  bool _isInitialized = false;
  bool _areFieldsEmpty = true;
  bool _isEditMode = false;
  Timer? _retryTimer;

  BannerAd? adaptiveBannerAd;
  late AdSize? adaptiveBannerAdSize;
  late BannerAd myBanner;
  late AdWidget adWidget;

  Map<String, String> getCurrencyNames(String locale) {
    Map<String, dynamic> selectedMap = (locale == 'ru') ? aliasesRU : aliasesEN;

    return selectedMap.map((key, value) {
      // Убедитесь, что значение является строкой, иначе верните пустую строку или любое другое подходящее значение
      return MapEntry(key, value.toString());
    });
  }

  List<String> getCurrencyList(String locale) {
    if (locale == 'ru') {
      return currenciesOrderRU;
    } else {
      return currenciesOrderEN;
    }
  }

  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = !widget.isDarkMode.value;
    setState(() {
      widget.isDarkMode.value = isDark;
    });
    prefs.setBool('isDarkMode', isDark);
  }

  Future<void> _saveSelectedCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('selectedCurrencies', _selectedCurrencies);
  } // сохранение-загрузка состояния

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

  void _updateCurrencyFields() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('numFields', _selectedCurrencies.length);
      _controllers = List.generate(
          _selectedCurrencies.length, (_) => TextEditingController());
      _focusNodes =
          List.generate(_selectedCurrencies.length, (_) => FocusNode());
    });
  }

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

  void _onChanged(String value) {
    bool areAllEmpty =
        _controllers.every((controller) => controller.text.isEmpty);
    for (var controller in _controllers) {
      if (controller.text.isNotEmpty) {
        areAllEmpty = false;
        break;
      }
    }
    setState(() {
      _areFieldsEmpty = areAllEmpty;
    });
  }

  void loadAdaptiveBannerAd(String adaptiveAdId) async {
    double width = MediaQuery.of(context).size.width;
    AdSize? size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait, width.toInt());

    if (size != null) {
      setState(() {
        adaptiveBannerAdSize = size;
      });
      adaptiveBannerAd = BannerAd(
        adUnitId: adaptiveAdId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            print('Адаптивный баннер загружен успешно');
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            print('Адаптивный баннер не загрузился: $error');
            ad.dispose();
          },
        ),
      );
      adaptiveBannerAd!.load();
    }
  }

  /// //////////////////////////////////////////////////////////////////////////
  /// INIT STATE ///////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////

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

    WidgetsBinding.instance.addPostFrameCallback((_) => loadAdaptiveBannerAd(
          dotenv.env['GOOGLE_AD_BOTTOM_BANNER']!,
        ));

    myBanner = BannerAd(
      adUnitId: dotenv.env['GOOGLE_AD_BANNER']!,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );

    // Загрузите рекламу
    myBanner.load();

    // Создайте AdWidget из баннера
    adWidget = AdWidget(ad: myBanner);

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
    myBanner.dispose();
    super.dispose();
  }

  Future<void> _saveRatesToSharedPreferences(Map<String, dynamic> rates) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('rates', jsonEncode(rates));
  }

  Future<void> _getRates() async {
    try {
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
      // activateError(
      //     context, AppLocalizations.of(context)!.exceptionRateFailure);

      // Установка таймера для повторного запроса
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 10), () {
        if (!areRatesLoaded) {
          _getRates();
        }
      });
    }
  }

  void _clearAllFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    // Проверяем, пусты ли все поля после очистки
    _checkIfFieldsAreEmpty();
  }

  void _checkIfFieldsAreEmpty() {
    bool areAllEmpty =
        _controllers.every((controller) => controller.text.isEmpty);
    setState(() {
      _areFieldsEmpty = areAllEmpty;
    });
  }

  String formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final formattedDate = DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    return formattedDate;
  }

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

  void _recalculateCurrenciesAfterReorder() {
    if (_selectedCurrencies.isEmpty ||
        _controllers.isEmpty ||
        _activeInputIndex < 0 ||
        _activeInputIndex >= _controllers.length) return;

    double baseInputValue =
        double.tryParse(_controllers[_activeInputIndex].text) ?? 0.0;
    String baseCurrency = _selectedCurrencies[_activeInputIndex];

    for (int i = 0; i < _selectedCurrencies.length; i++) {
      if (i != _activeInputIndex) {
        String currencyCode = _selectedCurrencies[i];
        double targetRate = _rates[currencyCode] ?? 1.0;
        double baseRate = _rates[baseCurrency] ?? 1.0;
        double convertedValue = (baseInputValue / baseRate) * targetRate;

        setState(() {
          if (baseInputValue != 0.0) {
            _controllers[i].text = _formatter.format(convertedValue);
          } else {
            _controllers[i]
                .clear(); // Очищаем текстовое поле, если базовое значение равно 0
          }
        });
      }
    }
  }

  void handleReorder(int oldIndex, int newIndex) {
    if (!_isEditMode) {
      return;
    }

    // Проверка на перемещение элемента добавления валюты
    if (oldIndex == _selectedCurrencies.length ||
        newIndex > _selectedCurrencies.length) {
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _selectedCurrencies.removeAt(oldIndex);
      _selectedCurrencies.insert(newIndex, item);
    });

    _recalculateCurrenciesAfterReorder();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw 'Could not launch $urlString';
    }
  }

  /// //////////////////////////////////////////////////////////////////////////
  /// MAIN WIDGET //////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////

  Widget _buildListItem(BuildContext context, int index) {
    String locale = Localizations.localeOf(context).languageCode;
    Map<String, String> currencyNames = getCurrencyNames(locale);
    var t = AppLocalizations.of(context)!;
    int maxSelectedCurrencies = MyApp.of(context)!.maxSelectedCurrencies;
    bool isAdFreeScreenStatus = MyApp.of(context)!.isAdFreeState;
    final key = ValueKey('currency_$index');

    if (index == _selectedCurrencies.length) {
      if (_selectedCurrencies.length >= maxSelectedCurrencies) {
        if (isAdFreeScreenStatus) {
          return Center(
              key: const ValueKey('maxRowsMessage'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(t.exceptionMaximumRows),
              ));
        } else {
          return Center(
              key: const ValueKey('maxRowsMessage'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(t.exceptionMaximumRowsGetPro),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PurchaseScreen()),
                      ).then((result) {
                        if (result == true) {
                          MyApp.of(context)!.updatePurchaseStatus();
                          InAppPurchase.instance.purchaseStream.listen(
                              (purchaseDetailsList) {
                            MyApp.of(context)!
                                .isAdFreeChecker(purchaseDetailsList)
                                .then((isPurchased) {
                              setState(() {
                                isAdFreeScreenStatus = isPurchased;
                              });
                              MyApp.of(context)!.updatePurchaseStatus();
                              ;
                            });
                          }, onDone: () {}, onError: (error) {});
                        }
                      });
                    },
                    child: Text(t.exceptionMaximumRowsGetProLink,
                        style: const TextStyle(
                            color: Color.fromARGB(255, 116, 177, 151))),
                  )
                ]),
              ));
        }
      } else {
        return Center(
          key: const ValueKey('addCurrencyButton'),
          child: IconButton(
            icon: const Icon(
              Icons.add_rounded,
              size: 32,
            ),
            onPressed: _addCurrencyField,
          ),
        );
      }
    } else if (index < _controllers.length) {
      String currencyCode = _selectedCurrencies[index];
      String currencyName = currencyNames[currencyCode] ?? currencyCode;
      return Row(
        key: key,
        children: <Widget>[
          SizedBox(
            width: 65,
            child: InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10.0)),
                  ),
                  builder: (BuildContext context) {
                    return CurrencySearchSheet(
                      currencyList: getCurrencyList(locale),
                      currencyNames: currencyNames,
                      onSelectCurrency: (currency) {
                        setState(() {
                          _selectedCurrencies[index] = currency;
                          _saveSelectedCurrencies();
                        });
                        _recalculateCurrencies();
                      },
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: Text(
                  _selectedCurrencies[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
                style: const TextStyle(
                  fontSize: 26,
                ),
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: areRatesLoaded && !_isEditMode,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.startsWith('0') &&
                        newValue.text.length > 1 &&
                        newValue.text[1] != '.') {
                      return TextEditingValue(
                        text: newValue.text.substring(1),
                        selection: newValue.selection.copyWith(
                            baseOffset: newValue.selection.baseOffset - 1,
                            extentOffset: newValue.selection.extentOffset - 1),
                      );
                    }
                    return newValue;
                  }),
                ],
                decoration: InputDecoration(
                  labelText: currencyName,
                  border: InputBorder.none,
                  labelStyle: TextStyle(
                      fontSize: 14,
                      color: widget.isDarkMode.value
                          ? _isEditMode
                              ? Colors.white10
                              : Colors.white38
                          : _isEditMode
                              ? Colors.black12
                              : Colors.black38),
                ),
                onChanged: (value) {
                  _onChanged(value);
                  bool areAllEmpty = true;

                  for (var controller in _controllers) {
                    if (controller.text.isNotEmpty) {
                      areAllEmpty = false;
                      break;
                    }
                  }
                  setState(() {
                    _areFieldsEmpty = areAllEmpty;
                  });
                  _activeInputIndex =
                      index; // Установка индекса активного поля ввода
                  String numericValue =
                      value.replaceAll(RegExp(r'[^\d\s?\.?]'), '');
                  double inputValue = double.tryParse(numericValue) ?? 0.0;
                  String selectedCurrency = _selectedCurrencies[index];
                  for (int i = 0; i < _selectedCurrencies.length; i++) {
                    if (i != index) {
                      String currencyCode = _selectedCurrencies[i];
                      double baseRate = _rates[selectedCurrency] ?? 1;
                      double toBaseValue = inputValue / baseRate;
                      double targetRate = _rates[currencyCode] ?? 1;
                      double multipliedValue = toBaseValue * targetRate;
                      String formattedValue =
                          _formatter.format(multipliedValue);
                      _controllers[i].text = formattedValue;
                    }
                  }
                  setState(() {
                    _selectedCurrencies[index] = selectedCurrency;
                  });
                  _checkIfFieldsAreEmpty();
                },
                onTap: () {
                  _focusNodes[index].addListener(() {
                    if (_focusNodes[index].hasFocus) {}
                  });
                }),
          ),
          _isEditMode
              ? GestureDetector(
                  onTap: () => _removeCurrencyField(index),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Icon(Icons.delete_outline_rounded, size: 26.0),
                  ),
                )
              : !_areFieldsEmpty // Проверяем, не пусты ли поля
                  ? GestureDetector(
                      onTap: _clearAllFields,
                      child: const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Icon(Icons.close_rounded, size: 26.0),
                      ),
                    )
                  : const SizedBox(), // Если поля пусты и не в режиме редактирования, не показываем иконку

          _isEditMode
              ? const SizedBox(
                  width: 10,
                )
              : Container(),
          _isEditMode
              ? const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Icon(Icons.drag_indicator_outlined))
              : Container(),
          PopScope(
            canPop:
                _areFieldsEmpty, //When false, blocks the current route from being popped.
            onPopInvoked: (didPop) async {
              setState(() {
                _clearAllFields();
              });
            },
            child: Container(),
          )
        ],
      );
    } else {
      return Container(
        key: const ValueKey('EmergencyContainer'),
      );
    }
  }

  /// //////////////////////////////////////////////////////////////////////////
  /// BUILD ////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////
  /// //////////////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    String locale = Localizations.localeOf(context).languageCode;
    var t = AppLocalizations.of(context)!;
    bool isAdFreeScreenStatus = MyApp.of(context)!.isAdFreeState;

    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          centerTitle: true,
          title: const Text('EASY  CONVERTER'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HelpScreen(
                            title: t.miscHelp,
                            isDarkMode: widget.isDarkMode.value,
                          )),
                );
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: widget.isDarkMode.value
                            ? const Color.fromARGB(255, 20, 25, 30)
                            : const Color.fromARGB(255, 180, 200, 190),
                      ),
                      child: const Text(
                        '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(widget.isDarkMode.value
                          ? Icons.nights_stay_outlined
                          : Icons.wb_sunny_outlined),
                      title: Text(t.drawerChangeTheme),
                      onTap: () {
                        _toggleTheme();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.wallet_giftcard_outlined),
                      title: Text(t.drawerRemoveAds),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // ignore: prefer_const_constructors
                            builder: (context) => PurchaseScreen(),
                          ),
                        ).then((result) {
                          if (result == true) {
                            MyApp.of(context)!.updatePurchaseStatus();
                            InAppPurchase.instance.purchaseStream.listen(
                                (purchaseDetailsList) {
                              MyApp.of(context)!
                                  .isAdFreeChecker(purchaseDetailsList)
                                  .then((isPurchased) {
                                setState(() {
                                  isAdFreeScreenStatus = isPurchased;
                                });
                                MyApp.of(context)!.updatePurchaseStatus();
                                ;
                              });
                            }, onDone: () {}, onError: (error) {});
                          }
                        });
                      },
                    ),
                    ListTile(
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: CountryFlag.fromCountryCode(
                          locale == 'en' ? 'gb' : 'ru',
                          height: 20,
                          width: 24,
                          borderRadius: 100,
                        ),
                      ),
                      title: Text(t.drawerLanguage),
                      onTap: () {
                        MyApp.of(context)?.changeLanguage();
                      },
                    ),
                  ],
                ),
              ),
              const Text(
                "v 0.4.7 (Beta)",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 15),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _launchUrl(dotenv.env['POLICY']!),
                    child: Text(
                      t.drawerPrivacy,
                      style: const TextStyle(
                          decoration: TextDecoration.underline, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => _launchUrl(dotenv.env['TERMS']!),
                    child: Text(
                      t.drawerTerms,
                      style: const TextStyle(
                          decoration: TextDecoration.underline, fontSize: 12),
                    ),
                  )
                ],
              ),
              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),

        /// ////////////////////////////////////////////////////////////////////
        /// COLUMN /////////////////////////////////////////////////////////////
        /// ////////////////////////////////////////////////////////////////////
        /// ////////////////////////////////////////////////////////////////////

        body: Column(
          children: <Widget>[
            const SizedBox(height: 4),
            isAdFreeScreenStatus
                ? const SizedBox.shrink()
                : Container(
                    alignment: Alignment.center,
                    height: myBanner.size.height.toDouble(),
                    width: myBanner.size.width.toDouble(),
                    child: adWidget),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  //////////////////////////////////////////////////////////////
                  // Иконка обновления курсов и
                  // Сообщения об успешной загрузке / не загрузке курсов
                  //////////////////////////////////////////////////////////////

                  IconButton(
                    icon: const Icon(
                      Icons.currency_exchange,
                      size: 20,
                    ),
                    onPressed: () {
                      _getRates();
                    },
                  ),
                  _noInternetConnection
                      ? Text(
                          t.exceptionCheckConn,
                          style: const TextStyle(
                            fontSize: 10, // размер шрифта
                            color:
                                Color.fromARGB(255, 173, 63, 53), // цвет шрифта
                          ),
                        )
                      : (_lastUpdateTimestamp != null)
                          ? Text(
                              '${t.mainCurUpdated}:    ${formatDate(_lastUpdateTimestamp!)}',
                              style: const TextStyle(
                                fontSize: 10, // размер шрифта
                                color: Color.fromARGB(
                                    255, 116, 177, 151), // цвет шрифта
                              ),
                            )
                          : Row(children: [
                              Text(
                                t.mainRatesLoading,
                                style: const TextStyle(
                                  fontSize: 10, // размер шрифта
                                  color: Color.fromARGB(
                                      255, 116, 177, 151), // цвет шрифта
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              LoadingAnimationWidget.staggeredDotsWave(
                                  color:
                                      const Color.fromARGB(255, 116, 177, 151),
                                  size: 20),
                            ]),
                  IconButton(
                    icon: Icon(Icons.settings_outlined,
                        size: 22,
                        color: widget.isDarkMode.value
                            ? _areFieldsEmpty
                                ? Colors.white
                                : Colors.white12
                            : _areFieldsEmpty
                                ? Colors.black
                                : Colors.black12),
                    onPressed: _areFieldsEmpty
                        ? () {
                            setState(() {
                              _isEditMode = !_isEditMode;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isInitialized
                  ? _isEditMode
                      ? ReorderableListView.builder(
                          itemCount: _selectedCurrencies.length + 1,
                          itemBuilder: _buildListItem,
                          dragStartBehavior: DragStartBehavior.down,
                          onReorder: handleReorder,
                        )
                      : ListView.builder(
                          itemCount: _selectedCurrencies.length + 1,
                          itemBuilder: _buildListItem,
                        )
                  : const CircularProgressIndicator(),
            ),
            PopScope(
              canPop:
                  !_isEditMode, //When false, blocks the current route from being popped.
              onPopInvoked: (didPop) async {
                if (_isEditMode) {
                  setState(() {
                    _isEditMode =
                        !_isEditMode; // Выход из режима редактирования
                  });
                }
              },
              child: Container(),
            )
          ],
        ),
        bottomNavigationBar: adaptiveBannerAd == null
            ? const SizedBox.shrink()
            : isAdFreeScreenStatus
                ? const SizedBox.shrink()
                : SizedBox(
                    height: adaptiveBannerAdSize?.height.toDouble(),
                    width: MediaQuery.of(context).size.width,
                    child: AdWidget(ad: adaptiveBannerAd!),
                  ));
  }
}
