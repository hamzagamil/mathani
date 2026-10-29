// Prepares build/web and deploys it to get.mthani.app (Cloudflare Pages), specs/008 contracts/hosting.md.
//
//   flutter build web --wasm --release --no-web-resources-cdn
//   node tool/web_deploy.mjs --dry-run        a preview deployment; prints its URL
//   node tool/web_deploy.mjs                  a production deploy
//   node tool/web_deploy.mjs --restore        how to roll back to an earlier deployment
//   node tool/web_deploy.mjs --prepare-only   only the build steps below, for local checks
//
// Build steps (research R4, R9): gzips the Quran database, compiles the speech worker when its
// Dart source is newer, writes asset-hashes.json, stamps sw.js with the version, build id and the
// shell's file list, and fills in the inline script's hash in _headers. The deploy is a full one:
// build/web is the whole site, uploaded by wrangler (`npx wrangler@4 login` once per machine).
// Static files on Pages carry no bandwidth charge, unlike Netlify's shared credit pool (R5).
import { createHash } from 'node:crypto';
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

// The Cloudflare Pages project behind get.mthani.app; see docs/release.md › Web.
const PROJECT = 'mthani-web';

const repo = join(dirname(fileURLToPath(import.meta.url)), '..');
const web = join(repo, 'build', 'web');
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const prepareOnly = args.includes('--prepare-only');
const restoreAt = args.indexOf('--restore');

function fail(message) {
  console.error(`web_deploy: ${message}`);
  process.exit(1);
}

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]);
}

const rel = (path) => relative(web, path).replace(/\\/g, '/');
const sha = (algorithm, bytes) => createHash(algorithm).update(bytes).digest('hex');

// --- Build steps -----------------------------------------------------------------------------

function prepare() {
  if (!existsSync(join(web, 'index.html'))) fail('no build/web: run flutter build web first');
  // Wrangler compiles repository-root Functions; static assets bypass them.
  for (const endpoint of ['prayer-location', 'prayer-places', 'prayer-resolve']) {
    if (!existsSync(join(repo, 'functions', 'api', endpoint + '.js'))) {
      fail('missing prayer location Function: ' + endpoint);
    }
  }
  writeFileSync(join(web, '_routes.json'), readFileSync(join(repo, 'web', '_routes.json')));

  // The version the build reports must be the one being released (FR-029).
  const pubspec = readFileSync(join(repo, 'pubspec.yaml'), 'utf8').match(/^version:\s*(\S+)/m)[1];
  const built = JSON.parse(readFileSync(join(web, 'version.json'), 'utf8'));
  const builtVersion = `${built.version}+${built.build_number}`;
  if (builtVersion !== pubspec) fail(`build/web is ${builtVersion}, pubspec.yaml is ${pubspec}: build again`);

  // Engine files from this site, never Google's CDN, and no font fallback from Google (R1). The
  // engine carries Google's URLs as defaults, so the build's own settings are what is checked.
  const bootstrap = readFileSync(join(web, 'flutter_bootstrap.js'), 'utf8');
  if (!/"useLocalCanvasKit"\s*:\s*true/.test(bootstrap)) {
    fail('the build loads the engine from a CDN: build with --no-web-resources-cdn');
  }
  if (!bootstrap.includes("fontFallbackBaseUrl: 'font-fallback/'")) {
    fail('flutter_bootstrap.js no longer points font fallback at font-fallback/');
  }

  // The unsupported-browser page names the same browsers as the app.
  const listed = [...readFileSync(join(repo, 'lib/platform/supported_browsers.dart'), 'utf8')
    .matchAll(/\(name: '([^']+)'/g)].map((m) => m[1]).join(', ');
  const page = readFileSync(join(web, 'index.html'), 'utf8').match(/var browsers = '([^']+)'/)?.[1];
  if (page !== listed) fail(`index.html names "${page}", supported_browsers.dart "${listed}"`);

  // The speech worker, once memorization is on the web (research R10).
  const workerSource = join(repo, 'lib/features/memorization/web_worker_main.dart');
  const worker = join(web, 'speech', 'speech_worker.dart.js');
  if (existsSync(workerSource)) {
    const newer = !existsSync(worker) || walk(join(repo, 'lib')).some((f) =>
      f.endsWith('.dart') && statSync(f).mtimeMs > statSync(worker).mtimeMs);
    if (newer) {
      console.log('compiling the speech worker');
      // `dart` is a .bat on Windows, which needs a shell; the paths are this repository's own.
      execSync(`dart compile js -O2 -o "${worker}" "${workerSource}"`, { cwd: repo, stdio: 'inherit' });
      for (const extra of ['.deps', '.map']) rmSync(worker + extra, { force: true });
    }
    // sherpa-onnx's own WebAssembly build, from the sherpa_onnx_web package (web-only assets).
    if (!existsSync(join(web, 'assets', 'packages', 'sherpa_onnx_web', 'assets', 'sherpa-onnx-wasm-web.wasm'))) {
      fail('the build has no sherpa-onnx WebAssembly assets (sherpa_onnx_web)');
    }
  }

  // The Quran database, gzipped: Netlify does not compress it (R4).
  const db = join(web, 'assets', 'assets', 'db', 'quran.db');
  if (existsSync(db)) {
    writeFileSync(`${db}.gz`, gzipSync(readFileSync(db), { level: 9 }));
    rmSync(db);
  }

  // Flutter's own service worker is not used (R9).
  rmSync(join(web, 'flutter_service_worker.js'), { force: true });

  // Hashes of the cached-at-runtime files, so a new service worker drops changed ones (R9).
  const files = walk(web);
  const runtime = (p) => p.startsWith('assets/') || p.startsWith('speech/');
  const hashes = Object.fromEntries(files.map(rel).filter(runtime).sort()
    .map((p) => [p, sha('sha256', readFileSync(join(web, p)))]));
  writeFileSync(join(web, 'asset-hashes.json'), JSON.stringify(hashes));

  // The service worker learns its version and the small shell it precaches. The app build and
  // engine files are left out: a browser needs only one variant, cached when it is used.
  const swPath = join(web, 'sw.js');
  if (existsSync(swPath)) {
    const skip = new Set(['sw.js', '_headers', 'version.json', 'asset-hashes.json']);
    const onUse = (p) => p.startsWith('canvaskit/') || p.startsWith('main.dart.') || p.endsWith('.symbols');
    const shell = files.map(rel).filter((p) => !runtime(p) && !skip.has(p) && !onUse(p));
    const sw = readFileSync(swPath, 'utf8')
      .replaceAll('__VERSION__', pubspec)
      .replaceAll('__BUILD__', sha('sha1', JSON.stringify(hashes) + shell.join()).slice(0, 12))
      // The page as `./` only: Netlify redirects /index.html to /, and the two entries would
      // collide ("Entry already exists"), failing the worker's install.
      .replace('self.__PRECACHE', JSON.stringify(['./', ...shell.filter((p) => p !== 'index.html' && !p.endsWith('.md') && p !== '.last_build_id')]));
    writeFileSync(swPath, sw);
  }

  // The inline script is allowed by its hash, not by 'unsafe-inline'. _headers comes from web/
  // every time: Flutter does not always copy it, and the hash is filled in afresh.
  const index = readFileSync(join(web, 'index.html'), 'utf8');
  const inline = [...index.matchAll(/<script>([\s\S]*?)<\/script>/g)]
    .map((m) => `'sha256-${createHash('sha256').update(m[1]).digest('base64')}'`);
  const headers = readFileSync(join(repo, 'web', '_headers'), 'utf8')
    .replaceAll('__INLINE_SCRIPT_HASHES__', inline.join(' '));
  writeFileSync(join(web, '_headers'), headers);

  // A placeholder left in a published file breaks the site (an unfilled CSP blocks the app).
  for (const file of ['_headers', 'sw.js']) {
    const text = readFileSync(join(web, file), 'utf8');
    const left = text.match(/__[A-Z_]+__|self\.__PRECACHE/);
    if (left) fail(`${file} still has ${left[0]}`);
  }
  console.log(`prepared build/web ${pubspec}: ${walk(web).length} files`);
}

// --- Cloudflare Pages ------------------------------------------------------------------------

/** Runs wrangler, signed in with `npx wrangler@4 login` (its OAuth session; never read here). */
function wrangler(command) {
  // HTTPS inspection on the development machine needs the Windows certificate store, and its
  // network needs IPv4 first and patient connects, or the parallel uploads time out.
  const nodeOptions = [process.env.NODE_OPTIONS ?? '', '--use-system-ca',
    '--dns-result-order=ipv4first', '--network-family-autoselection-attempt-timeout=5000'].join(' ');
  // wrangler reports on stderr: both streams are captured, and echoed.
  const out = execSync(`npx --yes wrangler@4 ${command} 2>&1`, {
    cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, NODE_OPTIONS: nodeOptions },
  });
  process.stdout.write(out);
  return out;
}

function cloudflare() {
  if (restoreAt !== -1) {
    // Pages keeps every deployment; a rollback is one click and needs no upload.
    console.log(`Roll back in the Cloudflare dashboard: Workers & Pages > ${PROJECT} > Deployments >
the deployment to restore > ... > Rollback to this deployment. List them with:
  npx wrangler@4 pages deployment list --project-name ${PROJECT}`);
    return;
  }
  // Production is the `main` branch; any other branch is a preview at <hash>.${PROJECT}.pages.dev.
  const branch = dryRun ? 'preview' : 'main';
  const out = wrangler(`pages deploy build/web --project-name ${PROJECT} --branch ${branch} --commit-dirty=true`);
  const url = out.match(new RegExp(`https://[a-z0-9-]+\\.${PROJECT}\\.pages\\.dev`))?.[0];
  if (!url) fail(`wrangler did not report a deployment:\n${out}`);
  console.log(dryRun ? `preview: ${url}` : `live: https://get.mthani.app (this deployment: ${url})`);
}

if (restoreAt === -1) prepare();
if (!prepareOnly) cloudflare();
