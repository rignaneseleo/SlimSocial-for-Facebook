import '../main.dart';

class CustomCss {
  static List<MyCss> cssList = [
    centerTextPostsCss,
    addSpaceBetweenPostsCss,
    hideStoriesCss,
    fixedBarCss,
    //hideAdsAndPeopleYouMayKnowCss,
    darkThemeCss,
    hideMessengerSidebar,
  ];

  static MyCss centerTextPostsCss = MyCss(
    key: 'center_text',
    code: '._5rgt._5msi { text-align: center;}',
    description: 'Center text posts',
  );

  static MyCss hideMessengerSidebar = MyCss(
    key: 'hide_messenger_sidebar',
    code:
        '.x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.xu1343h.x26u7qi.xy80clv.x1yu6fn4.xs83m0k.x1dt7z5j.x2ixbly {display: none;}',
    description: 'Hide messenger sidebar',
    defaultEnabled: true,
  );

  static MyCss addSpaceBetweenPostsCss = MyCss(
    key: 'add_space',
    description: 'Add space between posts',
    code: 'article { margin-top: 50px !important; }',
  );

  static MyCss hideStoriesCss = MyCss(
    key: 'hide_stories',
    description: 'Hide stories',
    code: '#MStoriesTray { display: none !important; }',
  );

  static MyCss fixedBarCss = MyCss(
    key: 'fixed_bar',
    description: 'Fixed bar',
    defaultEnabled: true,
    code:
        '#header { position: fixed; z-index: 6; top: 0px; } #root { padding-top: 84px; } .flyout { max-height: \$spx; overflow-y: scroll; } .item.more { position: fixed; bottom: 0px; text-align: center !important; }',
  );

  static MyCss removeMessengerDownloadCss = MyCss(
    key: 'removeMessengerDownload',
    description: 'Remove messenger download',
    code:
        '._s15 { display: none; } input { -webkit-user-select: text; } [data-sigil*=m-promo-jewel-header] { display: none; }',
  );

  static MyCss removeBrowserNotSupportedCss = MyCss(
    key: 'removeBrowserNotSupported',
    description: 'Remove browser not supported notice',
    code: '#header-notices { display: none; }',
  );

  static MyCss hideAdsAndPeopleYouMayKnowCss = MyCss(
    key: 'hideAdsAndPeopleYouMayKnow',
    description: 'Hide ads and people you may know',
    code:
        '##[data-pagelet=RightRail]>div>div:has(>div>div>div>div>div> { display: none !important; } .ego { display: none !important; }',
  );

  static MyCss fabBtnCss = MyCss(
    key: 'fabBtn',
    description: 'Floating action button',
    code:
        '.my_fab_btn { position: fixed; z-index: 6; bottom: 10px; right: 10px; background-color: #3B5998; width: 60px; height: 60px; border-radius: 100%; background: #3B5998; border: none; outline: none; color: #FFF; font-size: 23px; box-shadow: 0 3px 6px rgba(0, 0, 0, 0.16), 0 3px 6px rgba(0, 0, 0, 0.23); transition: .3s; -webkit-tap-highlight-color: rgba(0, 0, 0, 0); }',
  );

  static MyCss adaptMessengerPageCss = MyCss(
    key: 'adaptMessenger',
    description: 'Adapt messenger',
    code: """
    /***** TOP BAR *****/
.x9f619.x1n2onr6.x1ja2u2z.xdt5ytf.x2lah0s.x193iq5w.xeuugli.x6s0dn4.x78zum5.xn3w4p2.xl56j7k.x1yrsyyn.xsyo7zv.x10b6aqq.x16hj40l.x187nhsf {
    display: none;
}

/* search bar */
.x9f619.x1n2onr6.x1ja2u2z.x1swvt13.x1pi30zi.xsag5q8.x1yrsyyn {
    padding-left: 2px;
    padding-right: 2px;
}

/***** LEFT BAR (groups,marketplace,etc) *****/
/* remove padding from icons on the left (groups, etc)*/
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.x2lah0s.x193iq5w.xurb0ha.x1sxyh0 {
    padding: 0;
}

/* reduce the width */
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.xdt5ytf.x2lah0s.x193iq5w.xeuugli.xycxndf.xkhd6sd.x4uap5.xexx8yu.x18d9i69 {
    width: 43px;
}

/***** CHAT BAR *****/
.x12nzpgo.x12nzpgo {
    width: 60px;
}

/* reduce chat bubbles */
a.x1i10hfl.x1qjc9v5.xjbqb8w.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1lq5wgf.xgqcy7u.x30kzoy.x9jhf4c.x1lliihq.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x889kno.x1iji9kk.x1a8lsjc.x1sln4lm {
    padding-top: 2px;
    padding-bottom: 6px;
    padding-left: 0px;
    padding-right: 0px;
}

/* selected chat */
a.x1i10hfl.x1qjc9v5.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1lq5wgf.xgqcy7u.x30kzoy.x9jhf4c.x1lliihq.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x889kno.x1iji9kk.x1a8lsjc.x1sln4lm.x1av1boa {
    padding: 7px;
}

/* hide badge downlad msg */
.x9f619.x1n2onr6.x1ja2u2z.x78zum5.x1r8uery.xs83m0k.xeuugli.x1qughib.x6s0dn4.xozqiw3.x1q0g3np.xb756pt.x1c4vz4f.xt55aet.xexx8yu.xc73u3c.x18d9i69.x5ib6vp.x1lku1pv.x12nzpgo {
    display: none;
}


/***** CHAT *****/

/* hide send gif */
.x6s0dn4.x1ey2m1c.x78zum5.xl56j7k.x10l6tqk.x1vjfegm.xat24cr.x3oybdh.x1g2r6go.x11xpdln.x5w5eug {
    display: none;
}

/* hide sticker */
.x6s0dn4.x1ey2m1c.x78zum5.xl56j7k.x10l6tqk.x1vjfegm.xat24cr.x3oybdh.x1g2r6go.x11xpdln.x5h36tt {
    display: none;
}

/* larger textbox */
.x78zum5.x1iyjqo2.x6q2ic0 {
    margin-left: 36px !important;
}

/* hide send audio */
.x1i10hfl.x1qjc9v5.xjbqb8w.xjqpnuy.xa49m3k.xqeqjp1.x2hbi6w.x13fuv20.xu3j5b3.x1q0q8m5.x26u7qi.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xdl72j9.x2lah0s.xe8uvvx.xdj266r.x11i5rnm.xat24cr.x2lwn1j.xeuugli.x1n2onr6.x16tdsg8.x1hl2dhg.xggy1nq.x1ja2u2z.x1t137rt.x1o1ewxj.x3x9cwd.x1e5q0jg.x13rtm0m.x3nfvp2.x1q0g3np.x87ps6o.x1lku1pv.x1a2a7pz.x1i64zmx.x1y1aw1k.x1sxyh0.xwib8y2.xurb0ha {
    display: none;
}

/***** OTHERS *****/
.wkznzc2l {
    display: none !important;
}

.kuivcneq {
    display: none !important;
}

.bafdgad4 {
    display: none !important;
}

.aov4n071.cxmmr5t8.bi6gxh9e.hcukyx3x.jb3vyjys.hv4rvrfc.qt6c0cv9.dati1w0a {
    display: none !important;
}

.rj1gh0hx {
    max-width: -webkit-fill-available;
}

.j83agx80 {
    max-width: -webkit-fill-available;
}
""",
  );

  static MyCss darkThemeCss0 = MyCss(
      key: 'dark_theme',
      description: 'dark theme',
      code:
          "body, #root, .storyStream, ._2v9s, ._4nmh, ._4u3j, ._35aq, ._146a, ._4g34, ._5pxb, ._55wq, ._7om2, ._53_-, ._3iyw, ._6j_d, ._8ytl, ._4_d0, ._6beq, ._vi6, ._55ws, ._u42, ._13fn, .jx-result, .jx-typeahead-results, ._56bt, ._52x7, ._vqv, ._4g33, ._5rgt, .popover_flyout, .flyout, #m_newsfeed_stream, ._55wo, ._3iln, .mentions-suggest, #header, ._xy, ._bgx, .acb, .acg, .aclb, .touch._4g34, ._59e9, .nontouch._5ui0, input[type=text], .acw, ._5up8, ._5kgn, .tlLinkContainer, .aps, .jewel.flyout.header, .appCenterCategorySelectorButton, .tlBody, #timelineBody, .timelineX, .timeline.feed, .timeline.tlPrelude, .timeline.tlFeedPlaceholder, .touch._5c9u, .touch._5ca9, .innerLink, ._5dy4, ._52x3, #m_group_stories_container, .albums, .subpage, ._uwu, ._uww, .scrollAreaBody, .al, .apl, .structuredPublisher, .groupChromeView, ._djv, ._bjg, ._5kgn, ._3f50, ._55wm, ._58f0, ._55wr, ._22wy, ._1gkq, ._484w, ._1ih_, ._1p70, ._4e8n, ._15n_, ._1of-, ._5b6o, ._2rgt, ._u2c, ._5as1, ._3tl8, ._333v, ._5-lw, ._13e_, ._2rea._24e1._412_._bpa._vyy._5t8z, .touch._uoq, ._1t4h, .touch._45fu._18qg._1_ac, ._10c_._2jl2, ._4s0c, ._1h_j, .touch._3e18, .touch._533c{ background:#000!important; /*thebackground*/ } ._65wzO{ background:none!important; } ._51-g, ._2b06, ._5-lx, ._14v5._14v5._14v8{ background:#383a3e!important; } h3._391s{ color:#383a3e!important; } ._50cg._2ss{ background:#000!important; } .composerLinkText, .fcg, ._5c4t._1g06{ color:#d2d2d2!important; } /*whitetext*/ body, .touch._2ya3, .composerTextSelected, .composerInput, .mentions-input, input[type=text], ._5001, .timeline.cover.profileName, .appListTitle, ._52jd, ._52jb, ._52jg, ._5qc3, .tlActorText, .tlLinkTitle, ._5379, ._5cqn, ._592p, ._3c9l, ._4yrh, .name, .btn, .upText, .tlLinkTitleOnly, ._5rgt, ._52x2, ._52jh, ._52ja, ._56bz, ._2tbu, ._1mwn, ._55sr, ._5t6r, ._1_oe, ._52lz, ._2l5v, .inputtext, .inputpassword, .touch, .touchtr, .touchinput, .touchtextarea, .touch.mfsm, ._2b06span, ._59k{ color:#d2d2d2!important; } ._5s61._2pis { background-color:#dfeff0!important; border-radius:10px!important; } .touch._2ya3{ border-radius:5px; padding:5px; } /*bluelinktext*/ a, .actor, .mfsl, .fcw, .title, .blueName, ._5aw4, ._vqv, ._5yll, ._5qc3, ._52lz, ._4nwe, ._27vp, ._ir4, ._5wsv, ._46pa,header{ color:#DFEFF0!important; } /*darkimportant*/ .acy, .nontouch._55mb.actor-link, .nontoucha.btnD, .inlineMedia.storyAttachment{ background:#304702!important; } .statusBox, ._5whq, ._56bt, .composerInput, .mentions-input, ._1svy, ._bji{ background:#323232!important; } .ufiBorder, ._5as0, ._5ef_, ._35aq{ border-color:#555!important; } ._59te{ border-color:black!important; } /*buttons*/ .button>a.touchable, .btn, .touch._5c9u, ._2l5v, ._52x1, ._tn0, ._52ja{ background:#323232!important; } /*contextmenu*/ ._5c0e, ._5bn_{ background:#4e4e4e!important; } article, ._4o50, .acw, ._53_-, ._3wjp, ._usq, ._55wq, ._400s{ border:1pxdotted#383838!important; border-radius:4px; } ._1_oa, ._bmx, ._52x1{ border-bottom:1pxdotted#383838!important; } articleh3{ color:#999!important; } /*noborder*/ .aclb, ._53_-, ._52x6, ._52x1, ._2l5v, ._tn0, ._52ja, ._5lm6{ border-top:0px; border-bottom:0px; } ._59te.popoverOpen, ._59te.isActivem, ._59te{ background:#000; /*topbar*/ border-bottom:1pxsolid#444; border-right:1pxsolid#444; } /*#feed_jewel._59tf{ background-position:-22px-103px; } #requests_jewel._59tf{ background-position:-122px-148px; } #messages_jewel._59tf{ background-position:-268px-103px; } #notifications_jewel._2jdm._59tf{ background-position:-350px-103px; } #notifications_jewel._59tf{ background-position:0-149px; } #search_jewel._59tf{ background-position:-186px-103px; } #bookmarks_jewel._59tf{ background-position:-104px-103px; }*/ ._2lut{ border:1pxdotted#e9eaed!important; }");

  static MyCss darkThemeMessengerCss = MyCss(
    key: 'dark_theme_messenger',
    description: 'dark theme messenger',
    code: """
.__fb-light-mode {
    --surface-background: #000000;
    --messenger-card-background: #000000;
    --primary-text: #e5e5e5;
    --wash: #303030;
    --comment-background: rgba(38, 38, 38, 0.81);
    --secondary-button-background: rgba(38, 38, 38, 0.81);
    --primary-icon: #ffffff;
    --always-black: white;
    --divider: #181818;
    --media-inner-border: #181818;
    --disabled-icon: #65636c;
    --popover-background: #b79ab11a;
    --filter-primary-icon: invert(100%) sepia(10%) saturate(200%) saturate(200%) saturate(166%) hue-rotate(177deg) brightness(104%) contrast(91%);
    --hosted-view-selected-state: rgba(201, 201, 201, 0.11);
    --card-background: #000000;
    --fds-gray-20: #181818;
    --secondary-button-text: #dbdbdb;
    --web-wash: #000000;
}
::-webkit-scrollbar {
  width: 0;
}
::-webkit-scrollbar-thumb {
  background: #888;
  border-radius: 12px;
}
.xb756pt {
    box-shadow: 0 0 2px rgb(24, 24, 24);
}
""",
  );

  static MyCss darkThemeCss = MyCss(
      key: 'dark_theme',
      description: 'dark theme messenger',
      defaultEnabled: false,
      code: """
/* ===========================
Credits: Bean Verified Bean Terified
https://userstyles.org/styles/160729/violet-nebula
============================*/
body,
body ._li {
	background:black !important
}

._53jh {
    background: transparent;
}

.loggedout_menubar_container {
    background: none !important;
}

.fbIndex #globalContainer #dropmenu_container,
.fbIndex #globalContainer #content,
.fbIndex #globalContainer #pageFooter {
    display: none !important
}


.fbIndex .loggedout_menubar_container {
    position: fixed !important;
    width: 0px !important;
    height: 0px !important;
    min-width: 0px !important;
    bottom: 70% !important;
    left: 1% !important;
    margin-bottom: -290px !important;
    margin-left: -15px !important;
    z-index: -1000 !important;
}


.loggedout_menubar {
    background: rgba(0, 0, 0, .6) !important;
    padding: 0 0px 0px 0px;
    -webkit-border-radius: 0px;
    border-radius: 0px;
    -webkit-box-shadow: rgba(0, 0, 0, .4);
    box-shadow: rgba(0, 0, 0, .4);
    border: 1px solid #333 !important;
}

.fbIndex .loggedout_menubar {
    width: auto !important
}

.fbIndex .loggedout_menubar_container .lfloat,
.fbIndex .loggedout_menubar_container .rfloat {
    float: none !important
}

.fbIndex .loggedout_menubar_container .lfloat img,
.fbIndex .loggedout_menubar_container .rfloat #login_form table {
    display: block !important;
    margin: 0 auto !important
}

.menu_login_container {
    margin-top: 1.2em !important;
}

td .inputtext {
    background: rgba(0, 0, 0, 0.4) !important;
    border-radius: 0px !important;
}

* {
    border-color: transparent !important;
    font-family: Arial !important;
    color: #FFFFFF !important;
    background-color: transparent !important;
}

a:hover {
    text-decoration: none;
    font-weight: bold;
}

#BuddylistPagelet {
    display: none !important;
}

/*left panel */
._3m75 .sideNavItem ._5afe::after {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

._3m75 .sideNavItem ._5afe:active {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

/*group sidebar*/
._2yau::after {
    background-color: rgba(0, 0, 0, 0.8) !important;
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}

._2yau:active {
    background-color: rgba(0, 0, 0, 0.8);
    border: 1px solid #dddfe2;
    border-radius: 2px;
    bottom: -1px;
    content: '';
    display: block;
    left: -1px;
    opacity: 0;
    position: absolute;
    right: -1px;
    top: -1px;
    transition: 400ms cubic-bezier(.08, .52, .52, 1) background-color, 400ms cubic-bezier(.08, .52, .52, 1) border-color, 400ms cubic-bezier(.08, .52, .52, 1) opacity;
    z-index: -1
}


/*leave box */
._1yv {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

/*global notification */
._50d1 {
    background-color: rgba(0, 0, 0, 0.8) !important;
}


/*#contentCol,#left_column,#right_column{
	background-color: rgba(0,0,0,0.6) !important; 
	border: none !important;
}*/
._4-u2 {
    background-color: rgba(0, 0, 0, 0.5) !important;
}

.u_yqurkg_f8,
._26z1 {
    display: none;
}

.__tw,
._54ng,
._5tlx,
.fbNubFlyoutOuter {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

/*Chat box */
.fbNubFlyoutTitlebar {
    background-color: rgba(0, 0, 0, 0.8) !important;
    border-radius: 0px !important;
}

._2nlt,
._3olsv,
._2nlst {
    background: rgba(255, 255, 255, 0.8) !important;
}

/*header */
#pagelet_bluebar {
    background-color: rgba(0, 0, 0, 0.4) !important;
}

/*search icon */
._585- ._42ft {
    display: none;
}

/*unread notification*/
.jewelItemNew {
    background-color: rgba(255, 255, 255, 0.2) !important;
}

/*tool tip chat like time etc*/
.uiTooltipX {
    background-color: rgba(0, 0, 0, 0.8) !important;
}

._59s7 {
    background-color: rgba(0, 0, 0, 0.8) !important;
}


/*messenger*/
._1enh {
    border-right: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._4_j5 {
    border-left: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._5742 {
    border-bottom: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

._36ic {
    border-bottom: 0.2em solid rgba(255, 255, 255, 0.2) !important;
}

#u_jsonp_6_7,
.stickyHeaderWrap,
.uiMenuInner {
    background-color: rgba(0, 0, 0, 0.5) !important;
}

/*friend request*/
._n3 {
    background-color: rgba(0, 0, 0, 0.9) !important;
}

/*personal profil*/
._6_7 {
    background-color: rgba(0, 0, 0, 0.6) !important;
}

._513x {
    display: none !important;
}

/*pointer*/

/*messenger read notification*/
._9ah {
    background-color: rgba(255, 255, 255, 0.7) !important;
}

/*delivered*/
._3zzf {
    border: 1px solid rgba(255, 255, 255, 0.7) !important;
    color: blue !important
}

/*sent*/

/*profile*/
._53ij {
    background-color: rgba(0, 0, 0, 0.8) !important;
}
""" +
          """
/*badge*/
span._59tg {
    background-color: #3141ac !important;
}

#header { 
background-color: #080618 !important; 
}
""");
}

class MyCss {
  String key;
  String description;
  String code;
  bool defaultEnabled;

  MyCss({
    required this.key,
    required this.description,
    required this.code,
    this.defaultEnabled = false,
  }) {
    this.code = this
        .code
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll("'", "\\'")
        .replaceAll("\n", " ");
  }

  bool isEnabled() {
    return sp.getBool(key) ?? defaultEnabled;
  }

  void setEnabled(bool enabled) async {
    sp.setBool(key, enabled);
  }
}
