package it.rignanese.leo.slim.rules

import it.rignanese.leo.slim.domain.InjectionRule

/**
 * Ports `removeAdsFunc` and `removeAdsObserver` from Flutter
 * `lib/utils/js.dart`. Combines the sponsor-keyword sweep with the
 * MutationObserver that re-runs it on new DOM sections.
 *
 * The Flutter source pulled an extra fallback keyword and replacement copy via
 * a localization runtime. The Kotlin port hard-codes the full 23-language
 * sponsor keyword list and the English replacement copy directly, so no such
 * runtime is needed.
 *
 * The keyword sweep walks up from a matching `<span>` to its enclosing post.
 * Flutter did that with `closest("article")`; measured on a live session
 * 2026-08-01, the `article` **tag** matches 0 elements on today's Facebook —
 * posts are `div[role="article"]` — so ad hiding had silently stopped working.
 * Both are matched now, keeping mbasic mode working.
 *
 * Applies to FB hosts (excluding messenger).
 */
class RemoveAdsRule : InjectionRule {
    override val id: String = "hide_ads"

    override fun jsFor(url: String): String? {
        if (!RuleGates.isFbHost(url) || RuleGates.isMessengerHost(url)) return null
        return JS
    }

    private companion object {
        val JS = """
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
  ];

  var myDiv = '<div class="_52z5" style="z-index: 0; height: 135px; display: flex; justify-content: center; align-items: center;"> <div style="text-align: center;"><h1 style="color: white; font-size: 35px; height: 28px; margin: 0;">Ad removed</h1><p style="color: white; font-size: 12px; margin: 0;">Thanks to SlimSocial</p></div></div>';

  var spans = document.getElementsByTagName("span");

  const adSpans = [...document.querySelectorAll('span')].filter(span =>
    adKeywords.some(keyword => span.textContent.includes(keyword))
  );
  let adsCount = 0;
  for (const span of adSpans) {
    const post = span.closest('[role="article"], article');
    if(post == null) continue;
    post.innerHTML = myDiv;
    adsCount++;
  }

  //console.log(adsCount + ` ads removed`);
  }

if (typeof newPostsObserver !== 'undefined') {
    // Select the node that will be observed for changes
    const bodyNode = document.body;

    // Create a new observer object
    const newPostsObserver = new MutationObserver(function (mutations) {
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
    newPostsObserver.observe(bodyNode, config);
}
""".trimStart()
    }
}
