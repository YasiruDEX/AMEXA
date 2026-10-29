import 'package:amexa_meals/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const link = 'https://docs.google.com/spreadsheets/d/example/edit#gid=123';
String menu(String lunch) =>
    'date,day,lunch,tea,breakfast,juice\r\n${dateKey(DateTime.now())},Wednesday,"$lunch",Tea,Toast,Lime\r\n';

void main() {
  test('CSV handles sheet column order, quoted meals and blank cells', () {
    final meals = parseMeals(
        'date,day,lunch,tea,breakfast,juice\r\n2026-10-28,Wed,"Rice, curry",Tea,,Lime\r\n');
    expect(meals.single.items['lunch'], 'Rice, curry');
    expect(meals.single.items['breakfast'], '');
    expect(dateKey(meals.single.date), '2026-10-28');
  });

  test('Parses legacy dates and rejects invalid calendar dates', () {
    expect(dateKey(parseDate('28/10/2026')!), '2026-10-28');
    expect(dateKey(parseDate('10/28/2026')!), '2026-10-28');
    expect(dateKey(parseDate('28 October 2026')!), '2026-10-28');
    expect(parseDate('2026-02-31'), isNull);
  });

  test('Duplicate dates and invalid sheet responses are explicit errors', () {
    expect(
        () => parseMeals(
            'date,lunch,tea\n2026-10-28,Rice,Tea\n28/10/2026,Rice,Tea'),
        throwsA(isA<SheetError>()));
    expect(
        () => parseMeals('<html>Sign in</html>'), throwsA(isA<SheetError>()));
    expect(() => parseMeals('date,lunch,tea\ninvalid,Rice,Tea'),
        throwsA(isA<SheetError>()));
  });

  test('Reads only public CSV and preserves worksheet gid', () async {
    final sheet = MealSheet(link, client: MockClient((request) async {
      expect(request.url.host, 'docs.google.com');
      expect(request.url.path, '/spreadsheets/d/example/export');
      expect(request.url.queryParameters, {'format': 'csv', 'gid': '123'});
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(menu('Rice'), 200);
    }));
    expect((await sheet.fetch()).single.items['lunch'], 'Rice');
    sheet.client.close();
  });

  test('Reports loss of public access', () async {
    final sheet = MealSheet(link,
        client: MockClient((_) async => http.Response('', 403)));
    await expectLater(
        sheet.fetch(),
        throwsA(isA<SheetError>().having(
            (e) => e.message, 'message', contains('publicly readable'))));
    sheet.client.close();
  });

  testWidgets('Shows fetched meals without backend configuration',
      (tester) async {
    final sheet = MealSheet(link,
        client: MockClient(
            (_) async => http.Response(menu('Rice and curry'), 200)));
    await tester.pumpWidget(MealsApp(sheet: sheet));
    await tester.pumpAndSettle();
    expect(find.text('Rice and curry'), findsOneWidget);
    expect(find.text('Open sheet to edit'), findsOneWidget);
    expect(find.text('Backend URL'), findsNothing);
  });

  testWidgets('Opens original sheet and refreshes after returning',
      (tester) async {
    int reads = 0;
    Uri? opened;
    final sheet = MealSheet(link,
        client: MockClient((_) async =>
            http.Response(menu(++reads == 1 ? 'Rice' : 'Updated curry'), 200)));
    await tester.pumpWidget(MaterialApp(
        home: MealHome(
            sheet: sheet,
            openEditor: (uri) async {
              opened = uri;
              return true;
            })));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    await tester.ensureVisible(find.text('Open sheet to edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet to edit'));
    await tester.pumpAndSettle();
    expect(opened.toString(), link);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Updated curry'), findsOneWidget);
  });

  testWidgets('Failed load can be retried without losing editor access',
      (tester) async {
    int reads = 0;
    final sheet = MealSheet(link,
        client: MockClient((_) async => ++reads == 1
            ? http.Response('', 503)
            : http.Response(menu('Rice'), 200)));
    await tester.pumpWidget(MealsApp(sheet: sheet));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('Open sheet to edit'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
  });
}
