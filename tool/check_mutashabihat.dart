// Checks the Mutashabihat content file before a release (specs/010 FR-016,
// contracts/content-file.md). Exits non-zero on any error; warnings are printed but pass.
//
// Usage: dart run tool/check_mutashabihat.dart [path]
//   (default)  assets/mutashabihat/mutashabihat.md
import 'dart:io';

import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';

void main(List<String> args) {
  final path = args.isEmpty ? 'assets/mutashabihat/mutashabihat.md' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path.');
    exit(1);
  }
  final name = file.uri.pathSegments.last;
  final (content, problems) = parseMutashabihat(file.readAsStringSync());
  for (final p in problems) {
    (p.isError ? stderr : stdout).writeln('${p.isError ? 'error' : 'warning'}: $name ${p.message}');
  }
  final errors = problems.where((p) => p.isError).length;
  if (errors > 0) {
    stderr.writeln('$name: $errors error${errors == 1 ? '' : 's'}; fix them before a release.');
    exit(1);
  }
  stdout.writeln('$name: ${content.groups.length} groups, ${content.linkedCount} linked ayat, OK');
}
