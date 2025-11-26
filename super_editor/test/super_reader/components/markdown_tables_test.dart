import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/src/default_editor/tables/table_markdown.dart';

import '../reader_test_tools.dart';

void main() {
  group("Super Reader > components > Markdown tables >", () {
    testWidgetsOnAllPlatforms("builds and renders in shrink to fit mode", (tester) async {
      await _pumpScaffold(
        tester,
        columnWidth: const IntrinsicColumnWidth(),
        fit: TableComponentFit.scale,
      );

      // Let everything shake out, such as scroll controller attachment, to make sure
      // nothing blows up on frame 2+.
      await tester.pumpAndSettle();

      final findTable = find.byType(MarkdownTableComponent);
      expect(findTable, findsOne);

      final tableWidget = (findTable.evaluate().first as StatefulElement).widget as MarkdownTableComponent;
      expect(tableWidget.viewModel.fit, TableComponentFit.scale);
      expect(tableWidget.viewModel.columnWidth, const IntrinsicColumnWidth());
    });

    testWidgetsOnAllPlatforms("builds and renders in horizontal scrolling mode", (tester) async {
      await _pumpScaffold(
        tester,
        columnWidth: const FixedColumnWidth(250),
        fit: TableComponentFit.scroll,
      );

      // Let everything shake out, such as scroll controller attachment, to make sure
      // nothing blows up on frame 2+.
      await tester.pumpAndSettle();

      final findTable = find.byType(MarkdownTableComponent);
      expect(findTable, findsOne);

      final tableWidget = (findTable.evaluate().first as StatefulElement).widget as MarkdownTableComponent;
      expect(tableWidget.viewModel.fit, TableComponentFit.scroll);
      expect(tableWidget.viewModel.columnWidth, const FixedColumnWidth(250));

      // Make sure we can swipe the scrollable without blowing up.
      await tester.fling(findTable, const Offset(-250, 0), 3000);
      await tester.pumpAndSettle();
      // If we get here without an error then there's no fundamental error with processing
      // touch events on the scrollable table.
    });
  });
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  TableColumnWidth columnWidth = const IntrinsicColumnWidth(),
  TableComponentFit fit = TableComponentFit.scroll,
}) async {
  await tester //
      .createDocument()
      .fromMarkdown('''# Markdown Table document
This document contains a Markdown table.

| Version | Release date                                                            | Description / Major changes                                                                                                                                                                         | Release notes / URL / Supplemental info                                                                            |
| ------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 1.0.0   | 2018-12-04 (or December 4, 2018) ([Wikipedia][1])                       | First stable release of Flutter — mobile (iOS & Android) production-ready SDK. ([Wikipedia][1])                                                                                                     | Archive (old changelog) on Flutter site. ([Flutter Documentation][2])                                              |
| 1.5.0   | 2019-05-07 ([features-of-flutter-mobile-applications.my.canva.site][3]) | Minor but notable stable release (part of 1.x series) — incremental improvements. ([Flutter Documentation][4])                                                                                      | See archived release-notes (e.g. 1.5.x) linked from Flutter “Archived release notes.” ([Flutter Documentation][2]) |
| 1.12.0  | 2019-12-11 ([Wikipedia][5])                                             | Larger 1.x release — included updated add-to-app APIs, improvements in web-preview support (web in beta/channel), and tooling updates. ([features-of-flutter-mobile-applications.my.canva.site][3]) | Archived release-notes page. ([Flutter Documentation][2])                                                          |
| 1.17.0  | 2020-05-06 ([Wikipedia][1])                                             | Added support for Metal on iOS, performance and rendering improvements, updated widgets & tooling. ([Wikipedia][1])                                                                                 | Included in Flutter SDK archive. ([Flutter Documentation][6])                                                      |
| 1.20.0  | 2020-08-05 ([CSDN Blog][7])                                             | Performance improvements, UI enhancements, autofill improvements for mobile text fields, other fixes. ([Reddit][8])                                                                                 | Archived release notes (via archive page) ([Flutter Documentation][2])                                             |
| 2.0.0   | 2021-03-03 ([Wikipedia][1])                                             | Major milestone: Web stable, desktop (Windows/macOS/Linux) support in beta, optional null-safety (with Dart 2.x), broader cross-platform ambitions. ([Wikipedia][1])                                | Official release notes on Flutter site. ([Flutter Documentation][6])                                               |
| 2.2.0   | 2021-05-18 ([CSDN Blog][7])                                             | Performance improvements, enhancements in desktop tooling progress. ([Wikipedia][1])                                                                                                                | Release notes via Flutter archive. ([Flutter Documentation][2])                                                    |
| 2.5.0   | 2021-09-08 ([CSDN Blog][7])                                             | New features and improvements over 2.2 — incremental but significant for many users. ([features-of-flutter-mobile-applications.my.canva.site][3])                                                   | Release notes via Flutter archive. ([Flutter Documentation][2])                                                    |
| 2.10.0  | 2022-02-03 (first Windows stable support) ([Wikipedia][1])              | Stable Windows desktop support added — broadening desktop platform support. ([Wikipedia][1])                                                                                                        | Flutter SDK archive / release notes. ([Flutter Documentation][6])                                                  |
| 3.0.0   | 2022-05-12 ([Wikipedia][1])                                             | Full stable support for all desktop platforms (Windows, macOS, Linux) + continued cross-platform reinforcement. ([Wikipedia][1])                                                                    | Official release notes (on flutter.dev) and SDK archive. ([Flutter Documentation][6])                              |

This text appears after the table.''') //
      .withAddedComponents(
    [
      MarkdownTableComponentBuilder(
        columnWidth: columnWidth,
        fit: fit,
      )
    ], //
  ).pump();
}
