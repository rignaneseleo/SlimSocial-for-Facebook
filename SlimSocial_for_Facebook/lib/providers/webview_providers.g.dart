// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fbWebViewHash() => r'3f2779166af13350fa3a9184850f803e71863880';

/// Provider for managing Facebook WebView URL state
///
/// Copied from [FbWebView].
@ProviderFor(FbWebView)
final fbWebViewProvider = AutoDisposeNotifierProvider<FbWebView, Uri>.internal(
  FbWebView.new,
  name: r'fbWebViewProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fbWebViewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FbWebView = AutoDisposeNotifier<Uri>;
String _$messengerWebViewHash() => r'ec576aa03ac8c01e48116f11d75fd4223bd39393';

/// Provider for managing Messenger WebView URL state
///
/// Copied from [MessengerWebView].
@ProviderFor(MessengerWebView)
final messengerWebViewProvider =
    AutoDisposeNotifierProvider<MessengerWebView, Uri>.internal(
      MessengerWebView.new,
      name: r'messengerWebViewProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$messengerWebViewHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MessengerWebView = AutoDisposeNotifier<Uri>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
