# AMEXA Meals for Android

A link-only meal viewer for AMEXA's existing public Google Sheet. No backend, service-account credentials, access key, or Google API setup is needed.

- View breakfast, lunch, tea and juice by date.
- Select another day using the calendar or week strip.
- Tap **Open sheet to edit** to open the original Google Sheet in Google Sheets or your browser.
- Make edits in Google's interface and return to AMEXA Meals. The app refreshes on return; pull down or use the refresh button to retry.

This app does not write through the Sheets API or contain a custom meal editing form. Google controls its editor and any sign-in/app requirements. If a mobile browser only offers viewing, open the link with the Google Sheets Android app or use the browser's desktop-site option. Your sheet sharing permissions still apply.

The sheet URL is included in the APK and is not a secret. No other `.env` values are included. The app requires the sheet to remain publicly readable for CSV export. The existing agent keeps reading the same sheet; its two-minute cache still applies.

## Build

Install Flutter stable and the Android SDK/JDK: https://docs.flutter.dev/platform-integration/android/setup

From the repository root, generate the local build configuration (only the sheet URL is copied):

```sh
.venv/bin/python mobile/configure_sheet.py
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=sheet_config.json
```

`sheet_config.json` is ignored by Git. You can also create it manually as `{"MEAL_SHEET_URL":"https://docs.google.com/spreadsheets/d/YOUR_ID/edit#gid=0"}`. The `gid` selects the same worksheet for reading and editing.

The development APK is `build/app/outputs/flutter-apk/app-debug.apk`. Transfer it to your phone and open it, or install with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. A store release requires your own signing configuration; this project uses development signing.

## Data and validation

The sheet needs `date`, `lunch`, and `tea` headers. `breakfast` and `juice` are optional. Column order does not matter; other columns are ignored. Empty meal cells show “Not planned yet.” Dates should preferably use `YYYY-MM-DD`; the app also supports the existing agent's common day-first formats. Invalid or duplicate dates show an error rather than silently choosing a row.

Automated tests use mocked HTTP and URL launching, covering parsing, HTTP failures, displaying meals, opening the editor, and refreshing on return. A live read can be checked without writing any cells. An actual device check is still needed to verify which Google editor opens on your phone and confirm your edit permissions there.

## Preview on your laptop

From the repository root:

```sh
.venv/bin/python mobile/preview.py
```

Open http://localhost:8765 in Chrome. The script builds the web app, serves it locally, and fetches only your configured public sheet through a local read proxy so browser cross-origin restrictions do not prevent the preview. No Google credentials are needed. Reload the page to replay the animated splash. For a phone-sized view, open Chrome DevTools and enable its device toolbar.

After a build, restart faster with `.venv/bin/python mobile/preview.py --no-build`. Stop with Ctrl+C. If Flutter is installed elsewhere, put `flutter` on PATH; this workspace also supports the SDK downloaded to `/private/tmp/amexa-flutter`. The animation respects the operating system's reduced-motion setting.
