// Run via test-browser-upload.sh in a fresh, network-disabled container.
const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const fs = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { test } = require('node:test');

const cli = process.argv[2];
const held = '/tmp/sand-browser-held';
const lastAction = '/tmp/sand-browser-last.json';
const size = 80 * 1024 * 1024;
const name = 'synthetic upload.bin';
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

async function devtoolsEndpoint(profile, chrome) {
  for (let i = 0; i < 100; i++) {
    assert.equal(chrome.exitCode, null, 'Chromium stopped before starting DevTools');
    try {
      const [port, socket] = fs.readFileSync(path.join(profile, 'DevToolsActivePort'), 'utf8').split('\n');
      if (Number(port) > 0 && socket?.startsWith('/devtools/browser/')) return `ws://127.0.0.1:${port}${socket}`;
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Chromium did not write DevToolsActivePort');
}

test('sand-browser upload against disposable Chromium', async (t) => {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'sand-upload-test-'));
  const uploads = path.join(root, 'Uploads');
  const downloads = path.join(root, 'Downloads');
  const html = path.join(root, 'upload.html');
  const profile = path.join(root, 'profile');
  fs.mkdirSync(downloads);
  fs.writeFileSync(html, `<!doctype html><title>Upload fixture</title>
<input type="file" id="direct" multiple>
<button id="picker">Choose a file</button><input type="file" id="chosen" hidden>
<script>
  window.clicks = 0;
  document.querySelector('#picker').onclick = () => {
    window.clicks++;
    document.querySelector('#chosen').click();
  };
</script>`);
  const chrome = spawn('chromium', [
    '--headless', '--no-sandbox', '--disable-dev-shm-usage', '--disable-background-networking', '--disable-gpu',
    '--no-first-run', '--disable-extensions', '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: 'ignore' });
  t.after(() => chrome.kill()); // Docker --rm also discards the profile and fixtures.
  const env = {
    ...process.env,
    SAND_BROWSER_CDP: await devtoolsEndpoint(profile, chrome),
    SAND_BROWSER_UPLOADS: uploads,
    SAND_BROWSER_DOWNLOADS: downloads,
    SAND_BROWSER_TAB_NAMES: path.join(root, 'tabs.json'),
  };
  function run(args, { input, status = 0, stderr, cdp = env.SAND_BROWSER_CDP } = {}) {
    const result = spawnSync(process.execPath, [cli, ...args], {
      env: { ...env, SAND_BROWSER_CDP: cdp }, encoding: 'utf8', input, timeout: 45000,
    });
    if (result.error) throw new Error(`${args.join(' ')}: ${result.error.message}\n${result.stdout}${result.stderr}`);
    assert.equal(result.status, status, `${args.join(' ')}\n${result.stdout}${result.stderr}`);
    if (stderr) assert.match(result.stderr, stderr);
    return result.stdout.trim();
  }
  const target = ['--tab', 'target'];
  const page = (js, tab = target) => JSON.parse(run([...tab, 'eval', js]));
  const fileInfo = (id) => page(`(async () => Promise.all(Array.from(document.querySelector('#${id}').files, async f => ({
    name: f.name, size: f.size,
    sha256: Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', await f.arrayBuffer())),
      b => b.toString(16).padStart(2, '0')).join('')
  }))))()`);
  const fixtureURL = pathToFileURL(html).href;
  run(['tab-new', 'target', fixtureURL]);
  run(['tab-new', 'decoy', fixtureURL]); // tab-new makes the decoy the default.

  const bytes = Buffer.alloc(size);
  for (let off = 0; off < size; off += 1024) bytes.writeUInt32LE(off, off);
  const large = { name, size, sha256: sha256(bytes) };
  const staged = path.join(uploads, name);
  assert.equal(run(['upload-put', name], { input: bytes }), `uploaded: ${staged}`);
  assert.equal(fs.statSync(staged).size, size);
  assert.equal(sha256(fs.readFileSync(staged)), large.sha256);
  t.diagnostic(`Staged ${size} bytes; SHA-256 ${large.sha256}`);

  for (const [kind, selector, id] of [['direct input', '#direct', 'direct'], ['picker button', '#picker', 'chosen']]) {
    await t.test(`large staged file reaches the ${kind} in the named tab`, () => {
      assert.equal(run([...target, 'upload', selector, name]), `attached: ${name}`);
      assert.deepEqual(fileInfo(id), [large]);
      assert.deepEqual(page(`[document.querySelector('#${id}').files.length, window.clicks]`, ['--tab', 'decoy']), [0, 0]);
    });
  }

  const small = Buffer.from('synthetic small file\n');
  const smallInfo = (filename) => ({ name: filename, size: small.length, sha256: sha256(small) });
  assert.equal(run(['upload-put', 'small.txt'], { input: small }), `uploaded: ${path.join(uploads, 'small.txt')}`);
  fs.writeFileSync(path.join(downloads, 'download.txt'), small);
  const absolute = path.join(root, 'absolute.txt');
  fs.writeFileSync(absolute, small);
  await t.test('small files, multiple files, Downloads fallback and explicit guest absolute path', () => {
    run([...target, 'upload', '#direct', 'small.txt', 'download.txt']);
    assert.deepEqual(fileInfo('direct'), [smallInfo('small.txt'), smallInfo('download.txt')]);
    run([...target, 'upload', '#picker', 'small.txt']);
    assert.deepEqual(fileInfo('chosen'), [smallInfo('small.txt')]);
    run([...target, 'upload', '#direct', absolute]);
    assert.deepEqual(fileInfo('direct'), [smallInfo('absolute.txt')]);
  });

  await t.test('relative paths, traversal, hidden/partial names and missing paths stay rejected', () => {
    fs.writeFileSync(path.join(uploads, '.hidden'), small);
    fs.writeFileSync(path.join(uploads, 'partial.crdownload'), small);
    const before = page('[document.querySelector("#direct").files[0].name, window.clicks]');
    const invalid = ['absolute.txt', './small.txt', '../absolute.txt', '.hidden', 'partial.crdownload', path.join(root, 'missing.txt')];
    for (const [i, file] of invalid.entries()) {
      run([...target, 'upload', i % 2 ? '#direct' : '#picker', file], { status: 1, stderr: /no file .* in Uploads or Downloads/ });
    }
    assert.deepEqual(page('[document.querySelector("#direct").files[0].name, window.clicks]'), before);
  });

  await t.test('Take control blocks both attachment paths before CDP and leaves staging available', () => {
    const before = [fileInfo('direct'), fileInfo('chosen'), page('window.clicks')];
    const last = fs.readFileSync(lastAction, 'utf8');
    fs.writeFileSync(held, '');
    try {
      for (const selector of ['#direct', '#picker']) {
        run([...target, 'upload', selector, name], {
          status: 75, stderr: /Onur has control/, cdp: 'http://127.0.0.1:0',
        });
      }
      assert.match(run(['tabs']), /\ttarget(?:\n|$)/);
      run(['upload-put', 'while-held.txt'], { input: small });
      assert.equal(fs.readFileSync(lastAction, 'utf8'), last);
    } finally {
      fs.unlinkSync(held);
    }
    assert.deepEqual([fileInfo('direct'), fileInfo('chosen'), page('window.clicks')], before);
  });
});
