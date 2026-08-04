import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

class CustomJs {
  static String injectCssFunc(String css) {
    //jsonEncode gives us a valid JS string literal: it escapes quotes,
    //backslashes and newlines, so user-provided CSS can't break out of the
    //call and turn the whole injection into a syntax error
    final str = '''
      (function (css) {
        var node = document.createElement('style');
        node.innerHTML = css;
        document.body.appendChild(node);
      }) (${jsonEncode(css)});
    ''';
    return str;
  }

  static String exampleJs = """
javascript:function foo() {
	     document.body.innerHTML = '';
		}
		foo();""";

  static String removeAdsFunc = """
  javascript: function removeAds() {
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
    "${"sponsored_keyword_fb".tr()}",
  ];

  var myDiv = '<div class="_52z5" style="z-index: 0; height: 135px; display: flex; justify-content: center; align-items: center;"> <div style="text-align: center;"><h1 style="color: white; font-size: 35px; height: 28px; margin: 0;">${"ad_removed".tr()}</h1><p style="color: white; font-size: 12px; margin: 0;">${"Thanks to SlimSocial".tr()}</p></div></div>';

  var spans = document.getElementsByTagName("span");

  const adSpans = [...document.querySelectorAll('span')].filter(span =>
    adKeywords.some(keyword => span.textContent.includes(keyword))
  );
  let adsCount = 0;
  for (const span of adSpans) {
    const post = span.closest("article");
    if(post == null) continue;
    post.innerHTML = myDiv;
    adsCount++;
  }

  //console.log(adsCount + ` ads removed`);
  }
""";

  static String removeAdsObserver = """
// The observer is stored on `window` so it survives being re-injected on every
// page load: without a global we cannot tell whether one is already running.
// (The guard used to read `typeof newPostsObserver !== 'undefined'` against a
// block-scoped `const` declared inside the branch, so it was always false and
// the observer was never installed -- ads came back as soon as you scrolled.)
if (typeof window.newPostsObserver === 'undefined') {
    // Select the node that will be observed for changes
    const bodyNode = document.body;

    // Create a new observer object
    window.newPostsObserver = new MutationObserver(function (mutations) {
        mutations.forEach(function (mutation) {
            // Filter out added nodes that are not <section> elements
            const addedSections = Array.from(mutation.addedNodes).filter(node => node.nodeName === 'SECTION');

            // Check if any new <section> elements were added
            if (addedSections.length) {
                removeAds();
            }
        });
    });

    // Options for the observer (which mutations to observe)
    const config = { childList: true, subtree: true };

    // Start observing the target node for configured mutations
    window.newPostsObserver.observe(bodyNode, config);
}
  """;
}

String createFabFunc = """
javascript:function createFab() {
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
