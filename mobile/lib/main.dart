import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'splash.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const configuredSheetUrl = String.fromEnvironment('MEAL_SHEET_URL');
const orange = Color(0xFFFF6718);
const mealFields = ['breakfast', 'lunch', 'tea', 'juice'];
const mealIcons = [
  Icons.bakery_dining,
  Icons.restaurant,
  Icons.coffee,
  Icons.local_drink
];
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String title(String value) => '${value[0].toUpperCase()}${value.substring(1)}';

void main() => runApp(const MealsApp());

class MealsApp extends StatelessWidget {
  final MealSheet? sheet;
  const MealsApp({super.key, this.sheet});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AMEXA Meals',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
              primary: orange,
              onPrimary: Colors.white,
              secondary: orange,
              surface: Color(0xFF100703),
              onSurface: Color(0xFFE9E5E2),
              error: orange,
              outline: Color(0xFF34251C), outlineVariant: Color(0xFF302219)),
          dividerTheme: const DividerThemeData(color: Color(0xFF302219), thickness: 1),
          scaffoldBackgroundColor: const Color(0xFF090502),
          appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF090502),
              foregroundColor: Color(0xFFE9E5E2),
              surfaceTintColor: Colors.transparent),
          dividerColor: const Color(0xFF34251C),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)))),
        ),
        home: SplashGate(
            child: MealHome(sheet: sheet ?? MealSheet(configuredSheetUrl))),
      );
}

class SheetError implements Exception {
  final String message;
  SheetError(this.message);
  @override
  String toString() => message;
}

class Meal {
  final DateTime date;
  final Map<String, String> items;
  Meal(this.date, this.items);
}

class MealSheet {
  final String link;
  final http.Client client;
  MealSheet(this.link, {http.Client? client})
      : client = client ?? http.Client();

  Uri get editorUri {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'docs.google.com' ||
        !RegExp(r'^/spreadsheets/d/[\w-]+(?:/|$)').hasMatch(uri.path)) {
      throw SheetError(
          'The meal sheet link is not configured correctly in this app.');
    }
    return uri;
  }

  Uri get csvUri {
    final uri = editorUri;
    final id =
        RegExp(r'/spreadsheets/d/([\w-]+)').firstMatch(uri.path)!.group(1)!;
    final gid =
        uri.queryParameters['gid'] ?? Uri.splitQueryString(uri.fragment)['gid'];
    return Uri.https('docs.google.com', '/spreadsheets/d/$id/export', {
      'format': 'csv',
      if (gid != null) 'gid': gid,
    });
  }

  Future<List<Meal>> fetch() async {
    final uri = kIsWeb ? Uri.base.resolve('menu.csv') : csvUri;
    final http.Response response;
    try {
      response = await client.get(uri, headers: {
        'Cache-Control': 'no-cache'
      }).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw SheetError(
          'Could not reach Google Sheets. Check your connection and try again.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SheetError(
          'This sheet is no longer publicly readable. Check its sharing settings.');
    }
    if (response.statusCode != 200) {
      throw SheetError(
          'The meal sheet could not be loaded (${response.statusCode}). Please try again.');
    }
    try {
      return parseMeals(utf8.decode(response.bodyBytes));
    } on SheetError {
      rethrow;
    } catch (_) {
      throw SheetError(
          'The sheet returned an unexpected format. Check its date and meal columns.');
    }
  }
}

DateTime? parseDate(String value) {
  final s = value.trim();
  var match = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  int year, month, day;
  if (match != null) {
    year = int.parse(match[1]!);
    month = int.parse(match[2]!);
    day = int.parse(match[3]!);
  } else {
    match = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(s);
    if (match == null) {
      final words =
          RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$').firstMatch(s);
      if (words == null) return null;
      const months = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec'
      ];
      final name = words[2]!.toLowerCase();
      if (name.length < 3) return null;
      month = months.indexOf(name.substring(0, 3)) + 1;
      year = int.parse(words[3]!);
      day = int.parse(words[1]!);
    } else {
      day = int.parse(match[1]!);
      month = int.parse(match[2]!);
      year = int.parse(match[3]!);
      // Match the agent's day-first preference, accepting an unambiguous US date.
      if (month > 12 && day <= 12 && s.contains('/')) {
        final swap = day;
        day = month;
        month = swap;
      }
    }
  }
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

List<Meal> parseMeals(String source) {
  final rows = const CsvToListConverter(shouldParseNumbers: false).convert(
      source.replaceFirst('\uFEFF', ''),
      eol: source.contains('\r\n') ? '\r\n' : '\n');
  if (rows.isEmpty) throw SheetError('The meal sheet is empty.');
  final headers =
      rows.first.map((v) => v.toString().trim().toLowerCase()).toList();
  if (headers.where((h) => h == 'date').length != 1 ||
      !headers.contains('lunch') ||
      !headers.contains('tea')) {
    throw SheetError(
        'The sheet needs date, lunch and tea column headings. Check that the link is publicly readable.');
  }
  final result = <Meal>[];
  final dates = <String>{};
  for (final row in rows.skip(1)) {
    String cell(String name) {
      final i = headers.indexOf(name);
      return i < 0 || i >= row.length ? '' : row[i].toString().trim();
    }

    if (row.every((v) => v.toString().trim().isEmpty)) continue;
    final date = parseDate(cell('date'));
    if (date == null) {
      throw SheetError(
          'A row has an invalid or missing date. Use YYYY-MM-DD in the sheet.');
    }
    if (!dates.add(dateKey(date))) {
      throw SheetError(
          'There is more than one menu for ${dateKey(date)}. Check the sheet for duplicate dates.');
    }
    result
        .add(Meal(date, {for (final field in mealFields) field: cell(field)}));
  }
  return result..sort((a, b) => a.date.compareTo(b.date));
}

class MealHome extends StatefulWidget {
  final MealSheet sheet;
  final Future<bool> Function(Uri)? openEditor;
  const MealHome({super.key, required this.sheet, this.openEditor});
  @override
  State<MealHome> createState() => _MealHomeState();
}

class _MealHomeState extends State<MealHome> with WidgetsBindingObserver {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  List<Meal> meals = [];
  bool loading = true, opening = false, refreshOnReturn = false;
  String? error;
  DateTime? refreshedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sheet.client.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && refreshOnReturn) {
      refreshOnReturn = false;
      if (!loading) refresh();
    }
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final items = await widget.sheet.fetch();
      if (mounted) {
        setState(() {
          meals = items;
          refreshedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    setState(() => opening = true);
    try {
      refreshOnReturn = true;
      final uri = widget.sheet.editorUri;
      final opened = widget.openEditor != null
          ? await widget.openEditor!(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw SheetError(
            'Could not open the sheet. Install Google Sheets or a web browser.');
      }
    } catch (e) {
      refreshOnReturn = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Meal? get current {
    for (final meal in meals) {
      if (dateKey(meal.date) == dateKey(selected)) return meal;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final record = current;
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    const border = Color(0xFF302219);
    const muted = Color(0xFFBDB4AE);
    Widget panel(Widget child) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFF100703),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12)),
        child: child);
    return Scaffold(
      appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.restaurant_outlined, color: orange, size: 22),
            SizedBox(width: 12),
            Text('AMEXA',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(width: 12),
            Text('/ Meals', style: TextStyle(fontSize: 14, color: muted))
          ]),
          actions: [
            IconButton(
                onPressed: loading ? null : refresh,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh meals'),
            const SizedBox(width: 12),
          ]),
      body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                Color(0xFF210B02),
                Color(0xFF090502),
                Color(0xFF090502)
              ])),
          child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  const Text('Meal planner',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 7),
                                  const Text('Your team’s daily menu',
                                      style: TextStyle(
                                          color: muted, fontSize: 13)),
                                  const SizedBox(height: 24),
                                  panel(Column(children: [
                                    Row(children: [
                                      const Icon(Icons.calendar_month_outlined,
                                          size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(
                                              MaterialLocalizations.of(context)
                                                  .formatMonthYear(selected),
                                              style: const TextStyle(
                                                  fontSize: 15))),
                                      TextButton(
                                          onPressed: () => setState(() =>
                                              selected = DateUtils.dateOnly(
                                                  DateTime.now())),
                                          child: const Text('Today')),
                                      IconButton(
                                          tooltip: 'Choose date',
                                          icon: const Icon(Icons.expand_more,
                                              size: 20),
                                          onPressed: () async {
                                            final date = await showDatePicker(
                                                context: context,
                                                initialDate: selected,
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100));
                                            if (date != null && mounted) {
                                              setState(() => selected = date);
                                            }
                                          })
                                    ]),
                                    const Divider(height: 26),
                                    Row(
                                        children: List.generate(7, (i) {
                                      final day = start.add(Duration(days: i));
                                      final active =
                                          dateKey(day) == dateKey(selected);
                                      return Expanded(
                                          child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () => setState(
                                                  () => selected = day),
                                              child: Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 3),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  decoration: BoxDecoration(
                                                      color: active
                                                          ? orange
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: active
                                                              ? orange
                                                              : border)),
                                                  child: Column(children: [
                                                    Text(
                                                        [
                                                          'M',
                                                          'T',
                                                          'W',
                                                          'T',
                                                          'F',
                                                          'S',
                                                          'S'
                                                        ][i],
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: active
                                                                ? Colors.black
                                                                : muted)),
                                                    const SizedBox(height: 8),
                                                    Text('${day.day}',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: active
                                                                ? Colors.black
                                                                : const Color(
                                                                    0xFFE9E5E2)))
                                                  ]))));
                                    })),
                                  ])),
                                  const SizedBox(height: 20),
                                  if (loading)
                                    const Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator())),
                                  if (error != null)
                                    panel(Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(error!,
                                              style: const TextStyle(
                                                  color: orange)),
                                          TextButton(
                                              onPressed:
                                                  loading ? null : refresh,
                                              child: const Text('Try again'))
                                        ])),
                                  if (!loading && error == null) ...[
                                    Row(children: [
                                      const Icon(Icons.schedule,
                                          size: 15, color: muted),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              MaterialLocalizations.of(context)
                                                  .formatFullDate(selected),
                                              style: const TextStyle(
                                                  fontSize: 13, color: muted))),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF477534)),
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle_outline,
                                                    size: 13,
                                                    color: Color(0xFF79AC5D)),
                                                SizedBox(width: 5),
                                                Text('Synced',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xFF79AC5D)))
                                              ]))
                                    ]),
                                    const SizedBox(height: 16),
                                    if (record == null)
                                      const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: Text(
                                              'No menu for this date yet. Add one in the sheet.')),
                                    LayoutBuilder(
                                        builder: (context, constraints) => Wrap(
                                            spacing: 16,
                                            runSpacing: 16,
                                            children: List.generate(
                                                mealFields.length,
                                                (i) => SizedBox(
                                                    width: constraints.maxWidth >=
                                                            650
                                                        ? (constraints
                                                                    .maxWidth -
                                                                16) /
                                                            2
                                                        : constraints.maxWidth,
                                                    child: panel(Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(children: [
                                                            Icon(mealIcons[i],
                                                                size: 19,
                                                                color: muted),
                                                            const SizedBox(
                                                                width: 10),
                                                            Text(
                                                                title(
                                                                    mealFields[
                                                                        i]),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            15)),
                                                            const Spacer(),
                                                            const Icon(
                                                                Icons
                                                                    .more_horiz,
                                                                size: 18,
                                                                color: muted)
                                                          ]),
                                                          const Divider(
                                                              height: 28),
                                                          Container(
                                                              width: double
                                                                  .infinity,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                      minHeight:
                                                                          46),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                      12),
                                                              decoration: BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF080402),
                                                                  border: Border.all(
                                                                      color:
                                                                          border),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          8)),
                                                              child: Text(
                                                                  record?.items[mealFields[i]]?.isNotEmpty ==
                                                                          true
                                                                      ? record!
                                                                          .items[mealFields[i]]!
                                                                      : 'Not planned yet',
                                                                  style: const TextStyle(fontSize: 14, height: 1.4))),
                                                        ])))))),
                                    const SizedBox(height: 18),
                                    if (refreshedAt != null)
                                      Row(children: [
                                        const Icon(Icons.history,
                                            size: 14, color: muted),
                                        const SizedBox(width: 6),
                                        Text(
                                            'Last updated  ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(refreshedAt!))}',
                                            style: const TextStyle(
                                                fontSize: 12, color: muted))
                                      ]),
                                  ],
                                  const Divider(height: 36),
                                  Row(children: [
                                    const Icon(Icons.open_in_new,
                                        size: 16, color: muted),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                        child: Text(
                                            'Edit your menu in Google Sheets',
                                            style: TextStyle(
                                                fontSize: 12, color: muted))),
                                    FilledButton.icon(
                                        onPressed: opening ? null : edit,
                                        icon: const Icon(Icons.arrow_forward,
                                            size: 17),
                                        label: Text(
                                            opening
                                                ? 'Opening…'
                                                : 'Open sheet to edit',
                                            style:
                                                const TextStyle(fontSize: 12)))
                                  ]),
                                  const SizedBox(height: 14),
                                  const Text(
                                      'Refreshes when you return. Pull down to refresh anytime.',
                                      style: TextStyle(
                                          fontSize: 12, color: muted)),
                                  const SizedBox(height: 32),
                                ]))),
                  ]))),
    );
  }
}
