import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/dashboard.dart';
import 'src/metrics.dart';
import 'src/widgets.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Roboto'],
        await rootBundle.loadString('assets/fonts/Roboto-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks(['Fira Mono'],
        await rootBundle.loadString('assets/fonts/FiraMono-OFL.txt'));
  });
  runApp(const PerformanceApp());
}

class PerformanceApp extends StatelessWidget {
  const PerformanceApp({super.key, this.data});
  final MetricsData? data;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Performance · Super Text Layout',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: 'DashboardSans',
          scaffoldBackgroundColor: Palette.background,
          colorScheme: const ColorScheme.dark(
              primary: Palette.green,
              onPrimary: Palette.background,
              secondary: Palette.green,
              surface: Palette.surface,
              onSurface: Palette.text,
              error: Palette.red),
          dividerColor: Palette.border,
          dividerTheme:
              const DividerThemeData(color: Palette.border, thickness: 1),
          splashColor: Palette.green.withValues(alpha: .06),
          highlightColor: Colors.white.withValues(alpha: .025),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.text,
                  side: const BorderSide(color: Palette.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                  textStyle: const TextStyle(
                      fontFamily: 'DashboardSans', fontSize: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)))),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Palette.green)),
          chipTheme: ChipThemeData(
              backgroundColor: Palette.surface,
              selectedColor: Palette.green.withValues(alpha: .1),
              side: const BorderSide(color: Palette.border),
              labelStyle: const TextStyle(color: Palette.text)),
          tooltipTheme: TooltipThemeData(
              decoration: BoxDecoration(
                  color: Palette.raised,
                  border: Border.all(color: Palette.border),
                  borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(
                  color: Palette.text, fontSize: 12, height: 1.6)),
          snackBarTheme: const SnackBarThemeData(
              backgroundColor: Palette.raised,
              contentTextStyle: TextStyle(color: Palette.text)),
        ),
        home: data == null
            ? const _MetricsLoader()
            : PerformanceDashboard(data: data!),
      );
}

class _MetricsLoader extends StatefulWidget {
  const _MetricsLoader();
  @override
  State<_MetricsLoader> createState() => _MetricsLoaderState();
}

class _MetricsLoaderState extends State<_MetricsLoader> {
  late Future<MetricsData> metrics = MetricsData.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<MetricsData>(
      future: metrics,
      builder: (context, snapshot) {
        if (snapshot.hasData) return PerformanceDashboard(data: snapshot.data!);
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline, color: Palette.red),
                        const SizedBox(height: 16),
                        const Text('Could not load the recorded metrics'),
                        const SizedBox(height: 10),
                        SelectableText('${snapshot.error}',
                            style: const TextStyle(color: Palette.muted)),
                        const SizedBox(height: 18),
                        OutlinedButton(
                            onPressed: () =>
                                setState(() => metrics = MetricsData.load()),
                            child: const Text('Try again')),
                      ]))));
        }
        return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      });
}
