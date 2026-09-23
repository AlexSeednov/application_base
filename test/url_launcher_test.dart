import 'package:application_base/data/remote/utility/url_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every helper answers `false` on failure instead of throwing — the caller
/// shows a message, not a crash. A test run has no url_launcher plugin, which
/// is exactly such a failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an email that cannot be sent answers false', () async {
    final bool isSent = await UrlLauncher.sendEmail(
      to: 'user@example.com',
      title: 'Hello',
      body: 'A & B',
    );

    expect(isSent, isFalse);
  });

  test('an sms that cannot be sent answers false', () async {
    expect(await UrlLauncher.sendSms('50% off & #1'), isFalse);
  });

  /// Outside the web the download is a plain launch, so it fails the same way
  test('a download that cannot be launched answers false', () async {
    final bool isDownloaded = await UrlLauncher.downloadLink(
      'https://example.com/image.jpg',
    );

    expect(isDownloaded, isFalse);
  });

  test('a download of no link answers false', () async {
    expect(await UrlLauncher.downloadLink(null), isFalse);
    expect(await UrlLauncher.downloadLink(''), isFalse);
  });
}
