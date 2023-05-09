import 'package:easy_localization/easy_localization.dart';

class CustomJs {
  static String editCss(String css) {
    return '''
      javascript:function addStyle(css) {
        var node = document.createElement('style');
        node.innerHTML = css;
        document.body.appendChild(node);
      }
      addStyle('${css.replaceAll(RegExp(r'\s+'), '')}');
    ''';
  }

  static String exampleJs = """javascript:function foo() {
	     document.body.innerHTML = '';
		}
		foo();""";

  static String removeAds = """javascript:function removeAds() {
	      var adKeywords = [
            // French
            "Sponsorisé",
            // English
            "Sponsored",
            // Spanish
            "Patrocinado",
            "Publicidad",
            // German
            "Gesponsert",
            // Italian
            "Sponsorizzato",
            // Swedish
            "Sponsrad",
            // Vietnamese
            "Được tài trợ",
            // Chinese (Traditional and Simplified)
            "贊助內容",
            "赞助内容",
            // Japanese
            "スポンサーされた投稿",
            // Polish
            "Sponsorowane",
            // Russian
            "Реклама",
            // Croatian
            "Sponzorirano",
            // Hindi
            "प्रायोजित",
            // Bengali
            "স্পনসরড",
            // Tamil
            "பராமரிக்கப்பட்ட",
            // Telugu
            "ప్రచారం చేసిన",
            // Kannada
            "ಪ್ರಾಯೋಜಿತ",
            // Malayalam
            "സ്പോൺസർ ചെയ്യപ്പെട്ട",
            // Punjabi
            "ਸਰਪ੍ਰਸਤ",
            // Marathi
            "प्रायोजित",
            // Gujarati
            "સ્પોન્સર્ડ",
            // Urdu
            "سپانسرڈ",
            // Thai
            "โพสต์ที่ได้รับการสนับสนุน",
        ];
        
        var myDiv = '<div class="_52z5" style="z-index: 0; height: 135px; display: flex; justify-content: center; align-items: center;"> <div style="text-align: center;"><h1 style="color: white; font-size: 35px; height: 28px; margin: 0;">${"ad_removed".tr()}</h1><p style="color: white; font-size: 12px; margin: 0;">${"Thanks to SlimSocial".tr()}</p></div></div>';
        
        var spans = document.getElementsByTagName("span");
        
        var adsCount = 0;
        for (var i = 0; i < spans.length; i++) {
            if (adKeywords.includes(spans[i].textContent)) {
                var found = spans[i];
                var post = found.closest("article");
                post.innerHTML = (myDiv);
                adsCount++;
            }
        }
        (adsCount + " ads replaced");
		}
		removeAds();""";
}

String createFabFunc = """javascript:function createFab() {
		var button = document.createElement('button');
		button.type = 'button';
  		button.innerHTML = '▲';
  		button.className = 'my_fab_btn';

  		button.onclick = function() {
    		window.scrollTo(0,0);
  		};

  		var container = document.getElementById('root');
  		container.appendChild(button);
		}
		createFab();""";
