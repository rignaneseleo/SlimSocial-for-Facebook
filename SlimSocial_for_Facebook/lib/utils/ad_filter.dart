/// Shortest label that may be matched as a *substring*.
///
/// A short substring appears all over Facebook's own chrome, so testing for one
/// inside a longer string produces false positives. Labels below this length are
/// not discarded: the filter script compares them against the candidate's whole
/// trimmed text instead, which cannot fire mid-sentence. CJK labels ("広告",
/// "광고") are genuinely two characters, so without that second path there would
/// be no ad detection at all in Chinese, Japanese or Korean.
const int kMinSponsoredLabelLength = 4;

/// Labels Facebook uses to mark a sponsored post, lowercase, one or more per
/// supported locale.
///
/// The label is rendered in the language of the *Facebook account*, which is
/// often not the language the app is running in, and a single feed can mix
/// several — so every known variant is bundled rather than just the active
/// locale's.
///
/// Values come from the `sponsored_keyword_fb` entries in `assets/lang/*.json`
/// plus the variants below. Matching is case-insensitive, and is a substring
/// test guarded by a length window for entries at or above
/// [kMinSponsoredLabelLength] and a whole-string comparison below it. A variant
/// that is wrong for some locale is inert rather than harmful. Still, prefer
/// deleting a doubtful label over guessing at one: every entry widens the
/// false-positive surface.
const List<String> kSponsoredLabels = [
  // Latin script
  'gesponsert',
  'gesponsord',
  'hirdetés',
  'patrocinado',
  'publicidad',
  'rėmėjas',
  'sponsede',
  'sponset',
  'sponsora',
  'sponsored',
  'sponsoreeritud',
  'sponsoreret',
  'sponsorisé',
  'sponsorisée',
  'sponsorizat',
  'sponsorizzato',
  'sponsorlu',
  'sponsoroidut',
  'sponsoroitu',
  'sponsorowane',
  'sponsrad',
  'sponsrat',
  'sponzorirano',
  'sponzorisano',
  'sponzorované',
  'sponzorováno',
  'szponzorált',
  'tài trợ',
  // Cyrillic
  'реклама',
  'спонсорирано',
  'спонсоровано',
  // Hebrew, Arabic, Persian, Urdu
  'ממומן',
  'تعاون',
  'حمایت شده',
  'رعاية',
  'ممول',
  // Indic
  'प्रायोजित',
  'স্পনসরড',
  'பரிந்துரைக்கப்பட்டது',
  'ప్రాయోజించబడిన',
  'പ്രവര്‍ത്തിച്ചിരിക്കുന്നത്',
  // Thai
  'โฆษณา',
  // CJK — two characters, so matched as whole strings, not substrings
  '広告',
  'スポンサー',
  '赞助',
  '贊助',
  '광고',
  '스폰서',
];
