import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:native_flutter_proxy/custom_proxy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:slimsocial_for_facebook/screens/home_page.dart';
import 'package:slimsocial_for_facebook/screens/settings_page.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/css.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

late SharedPreferences sp;

//riverpod state
/* final fbWebViewProvider =
    StateNotifierProvider<webViewUriState, Uri>(webViewUriState.new);
final messegerWebViewProvider =
    StateNotifierProvider<webViewUriState, Uri>(webViewUriState.new); */

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
  _appLinks.uriLinkStream.listen((uri) {
    print("Received uri: $uri");
    //run the app with the uri
    container
        .read(webViewUriNotifierProvider.notifier)
        .updateUrl(uri.toString());
  });

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [
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
        fallbackLocale: const Locale('en', 'US'),
        child: const SlimSocialApp(),
      ),
    ),
  );
}

void _setupProxy() {
  final ip = sp.getString("custom_proxy_ip");
  final port = sp.getString("custom_proxy_port");
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
  const SlimSocialApp({super.key});

  @override
  State<SlimSocialApp> createState() => _SlimSocialAppState();

  /// InheritedWidget style accessor to our State object.
  static _SlimSocialAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_SlimSocialAppState>()!;
}

class _SlimSocialAppState extends State<SlimSocialApp> {
  _SlimSocialAppState() {
    _themeMode =
        CustomCss.darkThemeCss.isEnabled() ? ThemeMode.dark : ThemeMode.light;
  }
  late ThemeMode _themeMode;

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
          ThemeData(brightness: Brightness.light).textTheme,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          textStyle: TextStyle(
            color: FacebookColors.blue,
          ),
          iconColor: FacebookColors.blue,
        ), 
        listTileTheme: const ListTileThemeData(
          tileColor: FacebookColors.white,
          selectedTileColor: FacebookColors.lightBlue,
          iconColor: FacebookColors.blue,
          textColor: FacebookColors.darkBlue,
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(FacebookColors.blue),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: false,
        colorScheme: darkColorScheme,
        textTheme: GoogleFonts.robotoTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          textStyle: TextStyle(
            color: FacebookColors.white,
          ),
          iconColor: FacebookColors.white,
        ), 
        listTileTheme: const ListTileThemeData(
          //tileColor: FacebookColors.white,
          selectedTileColor: FacebookColors.lightBlue,
          iconColor: FacebookColors.white,
          textColor: FacebookColors.white,
        ),

      ),
      themeMode: _themeMode,
      home: const HomePage(),
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
