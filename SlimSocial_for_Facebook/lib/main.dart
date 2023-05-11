import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:native_flutter_proxy/custom_proxy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/screens/home_page.dart';
import 'package:slimsocial_for_facebook/screens/settings_page.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

import 'controllers/fb_controller.dart';

late SharedPreferences sp;

//riverpod state
final fbWebViewProvider =
    StateNotifierProvider<webViewUriState, Uri>((ref) => webViewUriState(ref));
final messengerWebViewProvider =
    StateNotifierProvider<webViewUriState, Uri>((ref) => webViewUriState(ref));

late PackageInfo packageInfo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  packageInfo = await PackageInfo.fromPlatform();
  sp = await SharedPreferences.getInstance();
  final container = ProviderContainer();

  if (sp.getBool("custom_proxy_enabled") ?? false) _setupProxy();

  //library to handle app links (link that open the app)
  final _appLinks = AppLinks();

  // Subscribe to all events when app is started.
  _appLinks.allUriLinkStream.listen((uri) {
    print("Received uri: $uri");
    // Do something (navigation, ...)
    //run the app with the uri
    container.read(fbWebViewProvider.notifier).updateUrl(uri.toString());
  });

  runApp(
    ProviderScope(
      parent: container,
      child: EasyLocalization(
        supportedLocales: [
          Locale('it', 'IT'),
          Locale('en', 'US'),
          Locale('fr', 'FR'),
          Locale('es', 'ES'),
          Locale('de', 'DE'),
          Locale('pt', 'PT'),
          Locale('nl', 'NL'),
          Locale('ru', 'RU'),
          Locale('pl', 'PL'),
          Locale('tr', 'TR'),
          Locale('zh', 'CN'),
          Locale('ja', 'JP'),
          Locale('ko', 'KR'),
          Locale('ar', 'AR'),
          Locale('hi', 'IN'),
          Locale('sv', 'SE'),
          Locale('no', 'NO'),
          Locale('fi', 'FI'),
          Locale('da', 'DK'),
          Locale('cs', 'CZ'),
          Locale('sk', 'SK'),
          Locale('hu', 'HU'),
          Locale('ro', 'RO'),
          Locale('uk', 'UA'),
          Locale('bg', 'BG'),
          Locale('hr', 'HR'),
          Locale('sr', 'SP'),
          Locale('sl', 'SI'),
          Locale('et', 'EE'),
          Locale('lv', 'LV'),
          Locale('lt', 'LT'),
          Locale('he', 'IL'),
          Locale('fa', 'IR'),
          Locale('ur', 'PK'),
          Locale('bn', 'IN'),
          Locale('ta', 'IN'),
          Locale('te', 'IN'),
          Locale('mr', 'IN'),
          Locale('ml', 'IN'),
          Locale('th', 'TH'),
          Locale('vi', 'VN'),
        ],
        path: 'assets/lang',
        fallbackLocale: Locale('en', 'US'),
        child: SlimSocialApp(),
      ),
    ),
  );
}

void _setupProxy() {
  var ip = sp.getString("custom_proxy_ip");
  var port = sp.getString("custom_proxy_port");
  if (ip == null || port == null) {
    showToast("error_proxy".tr());
    return;
  }

  try {
    final proxy = CustomProxy(ipAddress: ip, port: int.parse(port));
    proxy.enable();
    showToast("proxy_is_active".tr());
  } catch (e) {
    showToast("error_proxy with {}:{}".tr(args: [ip, port]));
  }
}

class SlimSocialApp extends StatefulWidget {
  SlimSocialApp({super.key});

  @override
  State<SlimSocialApp> createState() => _SlimSocialAppState();

  /// InheritedWidget style accessor to our State object.
  static _SlimSocialAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_SlimSocialAppState>()!;
}

class _SlimSocialAppState extends State<SlimSocialApp> {
  late ThemeMode _themeMode;

  _SlimSocialAppState() {
    _themeMode =
        CustomCss.darkThemeCss.isEnabled() ? ThemeMode.dark : ThemeMode.light;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    //TODO change app title dynamically

    return MaterialApp(
      title: 'SlimSocial for Facebook',
      theme: ThemeData(
        useMaterial3: false,
        colorScheme: lightColorScheme,
        textTheme: GoogleFonts.robotoTextTheme(
            ThemeData(brightness: Brightness.light).textTheme),
      ),
      darkTheme: ThemeData(
        useMaterial3: false,
        colorScheme: darkColorScheme,
        textTheme: GoogleFonts.robotoTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme),
      ),
      themeMode: _themeMode,
      home: HomePage(),
      routes: {
        "/settings": (context) => SettingsPage(),
      },
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }
}
