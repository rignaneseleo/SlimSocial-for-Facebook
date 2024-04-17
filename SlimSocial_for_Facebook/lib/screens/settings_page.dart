import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:restart_app/restart_app.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slimsocial_for_facebook/controllers/fb_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../consts.dart';
import '../main.dart';
import '../utils/css.dart';
import '../utils/js.dart';
import '../utils/utils.dart';

class SettingsPage extends ConsumerStatefulWidget {
  //this is used to make a shortcut for donations
  String? productId;

  SettingsPage({this.productId, Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  StreamSubscription<List<PurchaseDetails>>? _paymentSubscription;
  bool isDev = false;

  final Map<String, Permission> permissions = const {
    "gps_permission": Permission.locationWhenInUse,
    "camera_permission": Permission.camera,
    "photos_permission": Permission.photos,
  };

  @override
  void initState() {
    _updatePermissionsToggle();

    if (!widget.productId.isNullOrEmpty()) {
      Future.delayed(Duration(milliseconds: 1), () {
        buildPaymentWidget(widget.productId!);
      });
    }

    _checkDev();

    super.initState();
  }

  _checkDev() async {
    var _isDev = (await FlutterJailbreakDetection.developerMode);
    setState(() {
      isDev = _isDev;
    });
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr().capitalize())),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('SlimSocial'.tr()),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: Icon(Icons.privacy_tip),
                title: Text('privacy'.tr().capitalize()),
                description: Text("disclaimer_privacy".tr()),
              ),
            ],
          ),
          SettingsSection(
            title: Text('Facebook'.tr()),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool("enable_messenger", value);
                  });
                },
                initialValue: sp.getBool("enable_messenger") ?? true,
                leading: Icon(Icons.messenger),
                title: Text('enable_messenger'.tr()),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool("hide_ads", value);
                  });
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: sp.getBool("hide_ads") ?? true,
                leading: Icon(Icons.hide_source),
                title: Text('hide_all_ads'.tr()),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool("recent_first", value);
                  });
                  ref
                      .read(fbWebViewProvider.notifier)
                      .updateUrl(PrefController.getHomePage());
                },
                initialValue: sp.getBool("recent_first"),
                leading: Icon(Icons.rss_feed),
                title: Text('recent_first'.tr()),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool("use_mbasic", value);
                  });
                  ref
                      .read(fbWebViewProvider.notifier)
                      .updateUrl(PrefController.getHomePage());
                  Restart.restartApp();
                },
                initialValue: sp.getBool("use_mbasic") ?? false,
                leading: Icon(Icons.abc),
                title: Text('use_mbasic'.tr()),
                description: Text('use_mbasic_desc'.tr()),
              ),
            ],
          ),
          SettingsSection(
              title: Text('permissions'.tr().capitalize()),
              tiles: <SettingsTile>[
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    Permission permission = Permission.locationWhenInUse;

                    //for gps I don't care about updating value, because the webview can block it anyway
                    await handlePermission(value, permission);

                    setState(() {
                      sp.setBool("gps_permission", value);
                    });
                    if (value == false) {
                      //restart so the weview is blocked
                      showToast("rebooting".tr());
                      Restart.restartApp();
                    }
                  },
                  //fixme bug on sp, I shoudl use the permission handler .isgranted
                  initialValue: sp.getBool("gps_permission") ?? false,
                  leading: Icon(Icons.gps_fixed),
                  title: Text('gps_permission'.tr()),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    var oldVal = value == true;
                    Permission permission = Permission.camera;

                    //value is set based on the new value of granted
                    value = await handlePermission(value, permission);

                    if (oldVal != value) {
                      setState(() {
                        sp.setBool("camera_permission", value);
                      });
                      ref.refresh(fbWebViewProvider);
                    }
                  },
                  //fixme bug on sp, I shoudl use the permission handler .isgranted
                  initialValue: sp.getBool("camera_permission") ?? false,
                  leading: Icon(Icons.camera_alt),
                  title: Text('camera_permission'.tr()),
                ),
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    var oldVal = value == true;
                    Permission permission = Permission.photos;

                    //value is set based on the new value of granted
                    value = await handlePermission(value, permission);

                    if (oldVal != value) {
                      setState(() {
                        sp.setBool("photo_permission", value);
                      });
                      ref.refresh(fbWebViewProvider);
                    }
                  },
                  //fixme bug on sp, I shoudl use the permission handler .isgranted
                  initialValue: sp.getBool("photo_permission") ?? false,
                  leading: Icon(Icons.photo_camera_back_outlined),
                  title: Text('photo_permission'.tr()),
                ),
              ]),
          SettingsSection(
            title: Text('style'.tr().capitalize()),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.darkThemeCss.key, value);
                  });
                  //set dark theme

                  var newTheme = value ? ThemeMode.dark : ThemeMode.light;
                  SlimSocialApp.of(context).changeTheme(newTheme);
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: CustomCss.darkThemeCss.isEnabled(),
                title: Text(CustomCss.darkThemeCss.key.tr()),
                leading: Icon(Icons.format_paint),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.fixedBarCss.key, value);
                  });
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: CustomCss.fixedBarCss.isEnabled(),
                leading: Icon(Icons.vertical_align_top),
                title: Text(CustomCss.fixedBarCss.key.tr()),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.hideStoriesCss.key, value);
                  });
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: CustomCss.hideStoriesCss.isEnabled(),
                title: Text(CustomCss.hideStoriesCss.key.tr()),
                leading: Icon(Icons.hide_image),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.centerTextPostsCss.key, value);
                  });
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: CustomCss.centerTextPostsCss.isEnabled(),
                title: Text(CustomCss.centerTextPostsCss.key.tr()),
                leading: Icon(Icons.format_align_center),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() {
                    sp.setBool(CustomCss.addSpaceBetweenPostsCss.key, value);
                  });
                  ref.refresh(fbWebViewProvider);
                },
                initialValue: CustomCss.addSpaceBetweenPostsCss.isEnabled(),
                title: Text(CustomCss.addSpaceBetweenPostsCss.key.tr()),
                leading: Icon(Icons.format_line_spacing),
              ),
            ],
          ),
          SettingsSection(
            title: Text('advanced'.tr().capitalize()),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: Icon(Icons.person),
                title: Text('custom_useragent'.tr()),
                trailing: Visibility(
                    visible: sp.getBool("custom_useragent_enabled") ?? false,
                    child: Icon(Icons.check_circle)),
                onPressed: (context) async {
                  await showTextInputDialog(
                      spKey: "custom_useragent",
                      hint: PrefController.getUserAgent());
                  setState(() {});
                },
              ),
              SettingsTile.navigation(
                leading: Icon(Icons.css),
                title: Text('custom_js'.tr()),
                trailing: Visibility(
                    visible: sp.getBool("custom_js_enabled") ?? false,
                    child: Icon(Icons.check_circle)),
                onPressed: (context) async {
                  await showTextInputDialog(
                    spKey: "custom_js",
                    hint: CustomJs.exampleJs,
                  );
                  setState(() {});
                },
              ),
              SettingsTile.navigation(
                leading: Icon(Icons.javascript_sharp),
                title: Text('custom_css'.tr()),
                trailing: Visibility(
                    visible: sp.getBool("custom_css_enabled") ?? false,
                    child: Icon(Icons.check_circle)),
                onPressed: (context) async {
                  await showTextInputDialog(
                      spKey: "custom_css",
                      hint: '._5rgt._5msi { text-align: center;}');
                  setState(() {});
                },
              ),
              if (isDev)
                SettingsTile.navigation(
                  enabled: !sp.getString("custom_css").isNullOrEmpty() ||
                      !sp.getString("custom_js").isNullOrEmpty() ||
                      !sp.getString("custom_useragent").isNullOrEmpty(),
                  leading: Icon(Icons.send_time_extension),
                  title: Text('send_to_dev'.tr()),
                  description: Text('send_to_dev_desc'.tr()),
                  onPressed: (context) => showSendCodeToDev(),
                ),
              SettingsTile.navigation(
                leading: Icon(Icons.private_connectivity_outlined),
                title: Text('custom_proxy'.tr()),
                trailing: Visibility(
                    visible: sp.getBool("custom_proxy_enabled") ?? false,
                    child: Icon(Icons.check_circle)),
                onPressed: (context) async {
                  var spKey = "custom_proxy";
                  String spKeyEnabled = spKey + "_enabled";
                  String spKeyIp = spKey + "_ip";
                  String spKeyPort = spKey + "_port";

                  var ip = sp.getString(spKeyIp);
                  var port = sp.getString(spKeyPort);

                  await showProxyDialog();

                  var newIp = sp.getString(spKeyIp);
                  var newPort = sp.getString(spKeyPort);
                  var enabled = sp.getBool(spKeyEnabled) ?? false;

                  if ((ip != newIp || port != newPort) && enabled) {
                    Restart.restartApp();
                  }

                  setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
              title: Text('contribute'.tr().capitalize()),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: Icon(Icons.share),
                  title: Text('shareapp'.tr()),
                  onPressed: (BuildContext context) async {
                    Share.share(kPlayStoreUrl);
                  },
                ),
                SettingsTile.navigation(
                  leading: Icon(Icons.star),
                  title: Text('review5stars_v1'.tr()),
                  onPressed: (BuildContext context) async {
                    final InAppReview inAppReview = InAppReview.instance;

                    if (await inAppReview.isAvailable()) {
                      inAppReview.requestReview();
                    }
                  },
                ),
                SettingsTile.navigation(
                    leading: Icon(Icons.coffee),
                    title: Text('buy_coffee'.tr()),
                    onPressed: (BuildContext context) async {
                      buildPaymentWidget("donation_2".tr());
                    }),
                /*SettingsTile.navigation(
                    leading: Icon(Icons.local_pizza_outlined),
                    title: Text('buy_pizza'.tr()),
                    onPressed: (BuildContext context) async {
                      buildPaymentWidget("donation_3".tr());
                    }),*/
                SettingsTile.navigation(
                    leading: Icon(Icons.stars),
                    title: Text('become_hero'.tr()),
                    description: Text('become_hero_desc_v1'.tr()),
                    onPressed: (BuildContext context) async {
                      buildPaymentWidget("donation_4");
                    }),
              ]),
          SettingsSection(
            title: Text('the_project'.tr().capitalize()),
            tiles: <SettingsTile>[
              SettingsTile.navigation(
                leading: Icon(Icons.email),
                title: Text('contactdev'.tr()),
                onPressed: (BuildContext context) =>
                    launchInAppUrl(context, kTwitterProfileUrl),
              ),
              SettingsTile.navigation(
                leading: Icon(Icons.bug_report),
                title: Text('report_issue'.tr()),
                onPressed: (BuildContext context) =>
                    launchUrl(Uri.parse(kGithubIssuesUrl)),
              ),
              SettingsTile.navigation(
                leading: Icon(Icons.code),
                title: Text('GitHub'),
                onPressed: (BuildContext context) =>
                    launchInAppUrl(context, kGithubProjectUrl),
              ),
              SettingsTile.navigation(
                leading: Icon(Icons.perm_device_info),
                title: Text('version'.tr().capitalize()),
                description: Text(packageInfo.version),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> handlePermission(bool isTurningOn, Permission permission) async {
    var status = await permission.status;
    if (isTurningOn) {
      //going from off to on
      switch (status) {
        case PermissionStatus.restricted:
        case PermissionStatus.limited:
        case PermissionStatus.denied:
          await permission.request();
          break;
        case PermissionStatus.granted:
          break;
        case PermissionStatus.permanentlyDenied:
          await openAppSettings();
          break;
      }
    } else {
      //going from on to off
      switch (status) {
        case PermissionStatus.permanentlyDenied:
        case PermissionStatus.restricted:
        case PermissionStatus.limited:
        case PermissionStatus.denied:
          break;
        case PermissionStatus.granted:
          await openAppSettings();
          print("revoke_permission".tr());
          break;
      }
    }
    return await permission.status.isGranted;
  }

  Future buildPaymentWidget(String idItem) async {
    //get the product
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({idItem});
    if (response.notFoundIDs.isNotEmpty) {
      print("Product not found");
      showToast("error_trylater".tr());
      return;
    }

    //set the listener
    Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;

    _paymentSubscription ??=
        purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      // handle  purchaseDetailsList
      purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
        if (purchaseDetails.status == PurchaseStatus.pending) {
        } else {
          if (purchaseDetails.status == PurchaseStatus.error) {
            showToast("error_trylater".tr());
          } else if (purchaseDetails.status == PurchaseStatus.purchased ||
              purchaseDetails.status == PurchaseStatus.restored) {
            showToast("thankyou".tr() + " ❤️");
          }
          if (purchaseDetails.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchaseDetails);
          }
        }
      });
    }, onDone: () {
      showToast("thankyou".tr() + " ❤️");
      print("Close subscription");
    }, onError: (error) {
      print("Payment error: " + error.toString());
      showToast("error_trylater".tr());
    });

    //show the dialog
    List<ProductDetails> products = response.productDetails;
    var product = products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);

    return;
  }

  Future showTextInputDialog({required String spKey, String? hint}) async {
    String spKeyEnabled = spKey + "_enabled";

    var _textEditingController = TextEditingController();
    _textEditingController.text = sp.getString(spKey) ?? "";

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: StatefulBuilder(
            builder: (context, StateSetter _setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('enabled'.tr().capitalize()),
                    value: sp.getBool(spKeyEnabled) ?? false,
                    onChanged: (value) {
                      _setState(() {
                        sp.setBool(spKeyEnabled, value);
                      });
                      if (value)
                        showToast("default value will be overwritten".tr());
                    },
                  ),
                  TextField(
                    minLines: 4,
                    maxLines: 10,
                    controller: _textEditingController,
                    decoration: InputDecoration(hintText: hint),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('delete'.tr().capitalize()),
              onPressed: () {
                sp.remove(spKey);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('cancel'.tr().capitalize()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('save'.tr().capitalize()),
              onPressed: () {
                setState(() {
                  sp.setString(spKey, _textEditingController.text.trim());
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showSendCodeToDev() {
    bool sendCss = true;
    bool sendJs = true;
    bool sendUserAgent = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: StatefulBuilder(
            builder: (context, StateSetter _setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('send_useragent'.tr()),
                    value: sendUserAgent,
                    onChanged: (value) {
                      _setState(() => sendUserAgent = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('send_css'.tr()),
                    value: sendCss,
                    onChanged: (value) {
                      _setState(() => sendCss = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('send_js'.tr()),
                    value: sendJs,
                    onChanged: (value) {
                      _setState(() => sendJs = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('cancel'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('compose email'.tr()),
              onPressed: () {
                String myCss, myJs, myUserAgent;
                myCss = myJs = myUserAgent = "";

                if (sendCss)
                  myCss = (Uri.encodeFull(sp.getString("custom_css") ?? ""));

                if (sendJs)
                  myJs = (Uri.encodeFull(sp.getString("custom_js") ?? ""));

                if (sendUserAgent)
                  myUserAgent =
                      (Uri.encodeFull(sp.getString("custom_useragent") ?? ""));

                var link =
                    "mailto:$kDevEmail?subject=SlimSocial%3A%20new%20code%20suggestion&body=Hi%20Leo%2C%0A%0Athis%20code%20is%20good%20for%20these%20reasons%3A%0A-%20...%0A-%20...%0A%0AMy%20CSS%3A%20%0A$myCss%0A%0A-----%0A%0AMy%20js%3A%20%0A$myJs%0A%0A---%0A%0AMy%20user%20agent%3A%20%0A$myUserAgent%0A";

                launchUrl(Uri.parse(link));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePermissionsToggle() async {
    for (var entry in permissions.entries) {
      Permission permission = entry.value;
      String spKey = entry.key;

      bool permissionValue = await permission.isGranted;
      setState(() {
        sp.setBool(spKey, permissionValue);
      });
    }
  }

  Future showProxyDialog() async {
    var spKey = "custom_proxy";
    String spKeyEnabled = spKey + "_enabled";
    String spKeyIp = spKey + "_ip";
    String spKeyPort = spKey + "_port";

    var _ipController = TextEditingController();
    _ipController.text = sp.getString(spKeyIp) ?? "";
    var _portController = TextEditingController();
    _portController.text = sp.getString(spKeyPort) ?? "";

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: StatefulBuilder(
            builder: (context, StateSetter _setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('enabled'.tr().capitalize()),
                    value: sp.getBool(spKeyEnabled) ?? false,
                    onChanged: (value) {
                      _setState(() {
                        sp.setBool(spKeyEnabled, value);
                      });
                      if (value)
                        showToast("default value will be overwritten".tr());
                    },
                  ),
                  Row(
                    children: [
                      Flexible(
                        flex: 4,
                        child: TextField(
                          minLines: 1,
                          maxLines: 1,
                          controller: _ipController,
                          decoration: InputDecoration(hintText: "localhost"),
                        ),
                      ),
                      Text(" : "),
                      Flexible(
                        flex: 2,
                        child: TextField(
                          minLines: 1,
                          maxLines: 1,
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: "8888"),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('delete'.tr().capitalize()),
              onPressed: () {
                sp.remove(spKey);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('cancel'.tr().capitalize()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('save'.tr().capitalize()!),
              onPressed: () {
                var port = _portController.text.trim();
                var ip = _ipController.text.trim();

                if (port.isNullOrEmpty() || port.isNullOrEmpty()) {
                  Navigator.of(context).pop();
                  return;
                }

                setState(() {
                  sp.setString(spKeyPort, port);
                  sp.setString(spKeyIp, ip);
                });

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
