// Prints how the server parses a content file, for the Dart test that keeps both parsers in step
// (test/unit/mutashabihat_parsers_agree_test.dart). Usage: node tool/mutashabihat/parse_cli.mjs <file>
import { readFileSync } from 'node:fs';
import { formatAyat, parse } from '../../functions/_lib/mutashabihat-content.js';

const { version, groups, problems } = parse(readFileSync(process.argv[2], 'utf8'));
process.stdout.write(JSON.stringify({
  version,
  groups: groups.map((g) => ({ ayat: formatAyat(g.ayat), explanation: g.explanation, line: g.line })),
  problems: problems.map((p) => ({ line: p.line, kind: p.kind, message: p.message })),
}));
