import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/updater/updater.dart';
import 'package:rythem_app/features/settings/widgets/software_update_card.dart';
import 'package:rythem_app/features/settings/widgets/update_modal_sheet.dart';

void main() {
  group('SoftwareUpdateCard Widget Tests', () {
    testWidgets('renders initial state with Check for Updates button', (tester) async {
      bool checkCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SoftwareUpdateCard(
              latestRelease: null,
              isChecking: false,
              onCheckForUpdates: () => checkCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Software Update'), findsOneWidget);
      expect(find.textContaining('Running the latest release'), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);

      await tester.tap(find.text('Check for Updates'));
      await tester.pump();

      expect(checkCalled, isTrue);
    });

    testWidgets('renders Checking... state when isChecking is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SoftwareUpdateCard(
              latestRelease: null,
              isChecking: true,
              onCheckForUpdates: () {},
            ),
          ),
        ),
      );

      expect(find.text('Checking...'), findsOneWidget);
    });

    testWidgets('renders NEW badge and View Update button when update is available', (tester) async {
      bool openModalCalled = false;

      final release = UpdateReleaseInfo(
        tagName: 'v1.0.2',
        semVer: SemVer.parse('1.0.2'),
        title: 'Rythem v1.0.2',
        releaseNotes: 'Awesome new features',
        publishedAt: DateTime(2026, 9, 24),
        apkUrl: 'https://example.com/app.apk',
        apkName: 'app.apk',
        apkSizeBytes: 25600000,
        htmlUrl: 'https://github.com/ImSurajx/rythem-app/releases/tag/v1.0.2',
        isUpdateAvailable: true,
        currentVersion: SemVer.parse('1.0.1+2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SoftwareUpdateCard(
              latestRelease: release,
              isChecking: false,
              onCheckForUpdates: () {},
              onOpenUpdateModal: () => openModalCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.textContaining('A new version (v1.0.2) is available'), findsOneWidget);
      expect(find.text('View Update (v1.0.2)'), findsOneWidget);

      await tester.tap(find.text('View Update (v1.0.2)'));
      await tester.pump();

      expect(openModalCalled, isTrue);
    });
  });

  group('UpdateModalSheet Widget Tests', () {
    testWidgets('renders release details, version bump chips, and changelog', (tester) async {
      final release = UpdateReleaseInfo(
        tagName: 'v1.0.2',
        semVer: SemVer.parse('1.0.2'),
        title: 'Rythem v1.0.2 - Revision Shelf',
        releaseNotes: '## Highlights\n* Clean Revision Shelf\n* Spaced repetition\n* Performance fixes',
        publishedAt: DateTime(2026, 9, 24),
        apkUrl: 'https://example.com/app.apk',
        apkName: 'app.apk',
        apkSizeBytes: 25600000, // 24.4 MB
        htmlUrl: 'https://github.com/ImSurajx/rythem-app/releases/tag/v1.0.2',
        isUpdateAvailable: true,
        currentVersion: SemVer.parse('1.0.1+2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UpdateModalSheet.show(
                  ctx,
                  releaseInfo: release,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('SOFTWARE UPDATE'), findsOneWidget);
      expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('v1.0.1'), findsOneWidget);
      expect(find.text('v1.0.2'), findsOneWidget);
      expect(find.text('24.4 MB'), findsOneWidget);
      expect(find.text('Rythem v1.0.2 - Revision Shelf'), findsOneWidget);
      expect(find.text('Published Sep 24, 2026'), findsOneWidget);
      expect(find.text("WHAT'S NEW"), findsOneWidget);
      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Clean Revision Shelf'), findsOneWidget);
      expect(find.text('Spaced repetition'), findsOneWidget);
      expect(find.text('Download & Install'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
    });

    testWidgets('renders UP TO DATE state when release is not newer', (tester) async {
      final release = UpdateReleaseInfo(
        tagName: 'v1.0.1',
        semVer: SemVer.parse('1.0.1'),
        title: 'Rythem v1.0.1',
        releaseNotes: 'Current release',
        publishedAt: DateTime(2026, 9, 20),
        htmlUrl: 'https://github.com/ImSurajx/rythem-app/releases/tag/v1.0.1',
        isUpdateAvailable: false,
        currentVersion: SemVer.parse('1.0.1+2'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UpdateModalSheet.show(
                  ctx,
                  releaseInfo: release,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('UP TO DATE'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Download & Install'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('UP TO DATE'), findsNothing);
    });
  });

  group('NativeInstallerService Non-Android Fallback Tests', () {
    test('canRequestPackageInstalls returns true outside Android platform', () async {
      final service = NativeInstallerService();
      final canInstall = await service.canRequestPackageInstalls();
      expect(canInstall, isTrue);
    });
  });
}
