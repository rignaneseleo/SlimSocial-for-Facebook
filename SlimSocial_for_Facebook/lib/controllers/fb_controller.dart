import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/main.dart';


part 'fb_controller.g.dart';

@riverpod
class PrefController extends _$PrefController {

  @override
  void build() {
    // Void build method only to inizialize the provider
  }


  String get homePageUrl {
    var initialURl = kTouchFacebookHomeUrl;

    if (sp.getBool("use_mbasic") ?? false) initialURl = kFacebookHomeBasicUrl;

    if (sp.getBool("recent_first") ?? false) {
      return initialURl + suffixRecentFirst;
    }
    return initialURl + suffixDefault;
  }


  String get userAgent {
    if (sp.getBool(spKeyUserAgentEnabled) ?? false) {
      final customUserAgent = sp.getString("custom_useragent");
      if (customUserAgent?.isNotEmpty ?? false) {
        print("Using custom user agent: $customUserAgent");
        return customUserAgent!;
      }
    }

    if (sp.getBool("use_mbasic") ?? false) return kOperaMiniUserAgent;

    return kFirefoxUserAgent;
  }



  String? get userCustomCss {
    if (sp.getBool(spKeyCustomCssEnabled) ?? false) {
      final customCss = sp.getString("custom_css");
      if (customCss?.isNotEmpty ?? false) {
        print("Using custom css: $customCss");
        return customCss!;
      }
    }

    return null;
  }


  String? get userCustomJs {
    if (sp.getBool(spKeyCustomJsEnabled) ?? false) {
      final customJs = sp.getString("custom_js");
      if (customJs?.isNotEmpty ?? false) {
        print("Using custom js: $customJs");
        return customJs!;
      }
    }

    return null;
  }
}

/* class webViewUriState extends StateNotifier<Uri> {
  webViewUriState(this.ref) : super(Uri.parse(kTouchFacebookHomeUrl));

  final Ref ref;

  void updateUrl(String _url) => state = Uri.parse(_url);
} */

@riverpod
class WebViewUriNotifier extends _$WebViewUriNotifier {
  @override
  Future<Uri> build() async {
    // Imposta un valore di default per il provider
    return Uri.parse(kTouchFacebookHomeUrl);
  }

  // Metodo per aggiornare lo stato
  Future<void> updateUrl(String newUriString) async {
    state = const AsyncLoading();
    try {
      state = AsyncData(Uri.parse(newUriString));
    } catch (error) {
      state = AsyncError(error, StackTrace.current);
    }
  }
}
