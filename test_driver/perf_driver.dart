// Driver for integration_test/paging_perf_test.dart. Writes build/perf/<key>.json and fails when
// a run misses frame budgets (constitution III: 60 fps; dropped frames are bugs).
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// 90th-percentile frame build and raster times must stay within one 60 fps frame.
const _frameBudgetMs = 16.0;

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        Directory('build/perf').createSync(recursive: true);
        final failures = <String>[];
        for (final entry in data.entries) {
          final summary = (entry.value as Map).cast<String, dynamic>();
          File('build/perf/${entry.key}.json')
              .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));
          final build = (summary['90th_percentile_frame_build_time_millis'] as num).toDouble();
          final raster =
              (summary['90th_percentile_frame_rasterizer_time_millis'] as num).toDouble();
          final missed = (summary['missed_frame_build_budget_count'] as num).toInt() +
              (summary['missed_frame_rasterizer_budget_count'] as num).toInt();
          stdout.writeln('${entry.key}: p90 build ${build.toStringAsFixed(1)} ms, '
              'p90 raster ${raster.toStringAsFixed(1)} ms, missed frames $missed');
          if (build > _frameBudgetMs || raster > _frameBudgetMs) {
            failures.add('${entry.key}: p90 frame time over $_frameBudgetMs ms');
          }
          if (entry.key == 'mushaf_paging' && missed > 0) {
            failures.add('${entry.key}: $missed missed frames while paging (SC-002)');
          }
        }
        if (failures.isNotEmpty) {
          stderr.writeln(failures.join('\n'));
          exit(1);
        }
      },
    );
