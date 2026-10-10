// Fails when a platform's download size exceeds the 30 MB budget, or grows by more than 1 MB
// over docs/size_baseline.json without approval (constitution IV).
//
// Usage: dart run tool/size_check.dart <platform> <analyze-size.json> [--approved] [--update]
//   platform: android | ios
//   analyze-size.json: the file `flutter build ... --analyze-size` writes (path is printed by
//   the build, under ~/.flutter-devtools/).
//   --approved: the PR carries the `size-approved` label; growth over 1 MB is reported, not failed.
//   --update: write the measured size as the new baseline.
import 'dart:convert';
import 'dart:io';

const _budgetBytes = 30 * 1024 * 1024;
const _maxGrowthBytes = 1024 * 1024;
const _baselinePath = 'docs/size_baseline.json';

void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.length != 2 || !const {'android', 'ios'}.contains(positional[0])) {
    stderr.writeln('usage: dart run tool/size_check.dart <android|ios> <analyze-size.json> '
        '[--approved] [--update]');
    exit(64);
  }
  final platform = positional[0];
  final analysis = jsonDecode(File(positional[1]).readAsStringSync()) as Map<String, dynamic>;
  // --analyze-size reports the total size of the analysed archive at the top level as `value`
  // (bytes). Stores compress and split builds further, so this is an upper bound on the download.
  final size = (analysis['value'] as num).toInt();

  final baselineFile = File(_baselinePath);
  final baseline = baselineFile.existsSync()
      ? jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final previous = (baseline[platform] as num?)?.toInt();

  String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  stdout.writeln('$platform download size: ${mb(size)} (budget ${mb(_budgetBytes)}'
      '${previous == null ? '' : ', baseline ${mb(previous)}'})');

  var failed = false;
  if (size > _budgetBytes) {
    stderr.writeln('FAIL: over the 30 MB budget.');
    failed = true;
  }
  if (previous != null && size - previous > _maxGrowthBytes) {
    final message = 'grew by ${mb(size - previous)} (> 1 MB).';
    if (args.contains('--approved')) {
      stdout.writeln('NOTE: $message Approved by the size-approved label.');
    } else {
      stderr.writeln('FAIL: $message Explain in the PR and add the size-approved label.');
      failed = true;
    }
  }

  if (args.contains('--update') && !failed) {
    baseline[platform] = size;
    baselineFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(baseline)}\n');
    stdout.writeln('Baseline updated.');
  }
  exit(failed ? 1 : 0);
}
