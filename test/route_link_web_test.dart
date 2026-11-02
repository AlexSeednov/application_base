@TestOn('browser')
library;

import 'dart:ui_web' as ui_web;

import 'package:application_base/presentation/utility/browser_link_uri_web.dart';
import 'package:application_base/presentation/view/route_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/src/navigation/url_strategy.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_web/src/link.dart' as browser;
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:web/web.dart' as web;

/// Replays both orders of Flutter's tap and the DOM click through the real
/// link controller. In semantics mode the DOM click can be cancelled before
/// Flutter receives the tap; that fallback must never push an in-tab route.
void main() {
  ///
  late UrlLauncherPlatform originalPlatform;

  ///
  late ui_web.UrlStrategy? originalStrategy;

  ///
  late Future<ByteData> Function(String) originalPushRoute;

  ///
  late _LinkPlatform platform;

  ///
  final List<String> pushedRoutes = [];

  ///
  int clicks = 0;

  ///
  const String path = '/catalog/product/1?q=one%20two&value=%26';

  ///
  Widget harness({Widget? child}) => MaterialApp(
    home: Scaffold(
      body: RouteLink(
        path: path,
        onClick: () => clicks++,
        child: child ?? const SizedBox(width: 100, height: 40),
      ),
    ),
  );

  /// The DOM event reaches the plugin's capture listener independently of
  /// the framework gesture. It is not dispatched to avoid real navigation.
  web.MouseEvent domClick(
    WidgetTester tester, {
    bool meta = false,
    bool control = false,
  }) {
    final web.MouseEvent event = web.MouseEvent(
      'click',
      web.MouseEventInit(cancelable: true, metaKey: meta, ctrlKey: control),
    );
    browser.LinkViewController.handleGlobalClick(
      event: event,
      target: browser.linkViewFactory(
        tester
            .widget<PlatformViewSurface>(find.byType(PlatformViewSurface))
            .controller
            .viewId,
      ),
    );
    return event;
  }

  /// Clear the plugin's stale-signal timer before the test checks for leaks.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUpAll(() {
    ui_web.platformViewRegistry.registerViewFactory(
      browser.linkViewType,
      browser.linkViewFactory,
      isVisible: false,
    );
  });

  setUp(() {
    originalPlatform = UrlLauncherPlatform.instance;
    originalStrategy = ui_web.urlStrategy;
    originalPushRoute = browser.pushRouteToFrameworkFunction;
    platform = _LinkPlatform();
    UrlLauncherPlatform.instance = platform;
    browser.pushRouteToFrameworkFunction = (route) async {
      pushedRoutes.add(route);
      return ByteData(0);
    };
    pushedRoutes.clear();
    clicks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalPlatform;
    browser.pushRouteToFrameworkFunction = originalPushRoute;
    ui_web.debugResetCustomUrlStrategy();
    ui_web.urlStrategy = originalStrategy;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  for (final LogicalKeyboardKey modifier in [
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.controlLeft,
  ]) {
    testWidgets('delayed ${modifier.keyLabel} click opens a separate URL', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      final web.MouseEvent event = domClick(
        tester,
        meta: modifier == LogicalKeyboardKey.metaLeft,
        control: modifier == LogicalKeyboardKey.controlLeft,
      );
      await tester.pump();
      expect(event.defaultPrevented, isTrue);

      await tester.sendKeyDownEvent(modifier);
      await tester.tap(find.byType(RouteLink));
      await tester.sendKeyUpEvent(modifier);

      expect(platform.launched, [browserLinkUri(Uri.parse(path)).toString()]);
      expect(pushedRoutes, isEmpty);
      expect(clicks, 0);
      await finish(tester);
    });
  }

  testWidgets(
    'an immediate modified click stays with native browser handling',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tap(find.byType(RouteLink));
      final web.MouseEvent event = domClick(tester, meta: true);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

      expect(event.defaultPrevented, isFalse);
      expect(platform.launched, isEmpty);
      expect(pushedRoutes, isEmpty);
      expect(clicks, 0);
      await finish(tester);
    },
  );

  testWidgets('a plain click keeps the application action', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    final web.MouseEvent event = domClick(tester);
    await tester.pump();
    await tester.tap(find.byType(RouteLink));

    expect(event.defaultPrevented, isTrue);
    expect(platform.launched, isEmpty);
    expect(pushedRoutes, isEmpty);
    expect(clicks, 1);
    await finish(tester);
  });

  testWidgets('a nested button keeps its action on a modified click', (
    tester,
  ) async {
    int nestedClicks = 0;
    await tester.pumpWidget(
      harness(
        child: TextButton(
          onPressed: () => nestedClicks++,
          child: const Text('Action'),
        ),
      ),
    );
    await tester.pump();
    final web.MouseEvent event = domClick(tester, meta: true);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.tap(find.text('Action'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    expect(event.defaultPrevented, isTrue);
    expect(nestedClicks, 1);
    expect(platform.launched, isEmpty);
    expect(pushedRoutes, isEmpty);
    expect(clicks, 0);
    await finish(tester);
  });

  test('hash URLs preserve the hosting path and encoded query', () {
    ui_web.debugResetCustomUrlStrategy();
    ui_web.urlStrategy = const ui_web.HashUrlStrategy(_SubpathLocation());

    expect(
      browserLinkUri(Uri.parse(path)).toString(),
      '${web.window.location.origin}/learning/#$path',
    );
  });

  test('path URLs preserve the hosting path and encoded query', () {
    ui_web.debugResetCustomUrlStrategy();
    ui_web.urlStrategy = PathUrlStrategy(const _SubpathLocation());

    expect(
      browserLinkUri(Uri.parse(path)).toString(),
      '${web.window.location.origin}/learning$path',
    );
  });

  test('external URLs keep their scheme, query and fragment', () {
    final Uri uri = Uri.parse('https://example.com/file?q=one%20two#section');

    expect(browserLinkUri(uri), uri);
  });
}

/// The plugin's real controller, with only the actual window opening replaced.
final class _LinkPlatform extends UrlLauncherPlatform {
  ///
  final List<String> launched = [];

  ///
  @override
  LinkDelegate get linkDelegate => UrlLauncherPlugin().linkDelegate;

  ///
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

/// A site hosted below the origin root, for both supported URL strategies.
final class _SubpathLocation extends ui_web.BrowserPlatformLocation {
  ///
  const _SubpathLocation();

  ///
  @override
  String get pathname => '/learning/';

  ///
  @override
  String get search => '';

  ///
  @override
  String getBaseHref() => '/learning/';
}
