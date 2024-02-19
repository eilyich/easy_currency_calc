import 'package:flutter/material.dart';
import 'package:flutter_animated_icons/icons8.dart';
import 'package:flutter_animated_icons/lottiefiles.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// import 'main.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({
    Key? key,
    required this.title,
    required this.isDarkMode,
  }) : super(key: key);

  final String title;
  final bool isDarkMode;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  late AnimationController _refreshController;
  BannerAd? adaptiveBannerAd;
  late AdSize? adaptiveBannerAdSize;
  late final VoidCallback? loadAdaptiveBannerAd;
  late final VoidCallback? isAdFree;

  Color lightGreenColor = const Color.fromARGB(255, 180, 200, 190);

  @override
  void initState() {
    super.initState();

    _refreshController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: SingleChildScrollView(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Flexible(child: Text(t.helpScreenRefresh)),
                const SizedBox(
                  width: 5,
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(
                          LottieFiles.$60895_line_refresh_icon_animations,
                          controller: _refreshController,
                          height: 30,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.all(20), child: (Divider())),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(Icons8.expensive,
                          controller: _refreshController,
                          height: 30,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(child: Text(t.helpScreenAllCurrencys)),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.all(20), child: (Divider())),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Flexible(child: Text(t.helpScreenIsActive)),
                const SizedBox(
                  width: 5,
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(Icons8.activity,
                          controller: _refreshController,
                          height: 30,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.all(20), child: (Divider())),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(Icons8.icons8_settings_2_,
                          controller: _refreshController,
                          height: 30,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(child: Text(t.helpScreenSettingsIntro))
              ],
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                const SizedBox(
                  width: 5,
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(Icons8.trash_bin,
                          controller: _refreshController,
                          height: 15,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Flexible(child: Text(t.helpScreenSettingsDelete)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              children: [
                const SizedBox(
                  width: 10,
                ),
                Padding(
                  padding: const EdgeInsets.all(0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        widget.isDarkMode ? Colors.white : lightGreenColor,
                    child: SizedBox(
                      child: Lottie.asset(Icons8.drag_left,
                          controller: _refreshController,
                          height: 15,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Flexible(child: Text(t.helpScreenSettingsReorder)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(t.helpScreenComment,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
        ])),
      ),
    );
  }
}
