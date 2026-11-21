// Run via test-browser-activity.sh in a fresh, network-disabled container.
// Ops polls `sand-browser activity` every few seconds for Live Browsers. It must
// answer quickly even when a tab cannot run script (a frozen or memory-starved
// renderer); a hung poll piles up one node process per poll until the VM is out
// of memory.
const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { test } = require('node:test');

const cli = process.argv[2];

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

test('sand-browser activity answers while a tab is blocked', async (t) => {
  const root = fs.mkdtempSync(path.join(tmpdir(), 'sand-activity-test-'));
  const profile = path.join(root, 'profile');
  const calm = path.join(root, 'calm.html');
  const stuck = path.join(root, 'stuck.html');
  fs.writeFileSync(calm, '<!doctype html><title>Calm tab</title>');
  // The renderer freezes after tab-new returns, so any script evaluation in the
  // page (Playwright's page.title()) waits forever.
  fs.writeFileSync(stuck, '<!doctype html><title>Stuck tab</title><script>setTimeout(() => { for (;;) {} }, 300)</script>');
  const chrome = spawn('chromium', [
    '--headless', '--no-sandbox', '--disable-dev-shm-usage', '--disable-background-networking', '--disable-gpu',
    '--no-first-run', '--disable-extensions', '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: 'ignore' });
  t.after(() => chrome.kill());
  const env = {
    ...process.env,
    SAND_BROWSER_CDP: await devtoolsEndpoint(profile, chrome),
    SAND_BROWSER_UPLOADS: path.join(root, 'Uploads'),
    SAND_BROWSER_DOWNLOADS: path.join(root, 'Downloads'),
    SAND_BROWSER_TAB_NAMES: path.join(root, 'tabs.json'),
  };
  const run = (args, timeout = 45000) => spawnSync(process.execPath, [cli, ...args], { env, encoding: 'utf8', timeout });

  assert.equal(run(['tab-new', 'calm', pathToFileURL(calm).href]).status, 0);
  assert.equal(run(['tab-new', 'stuck', pathToFileURL(stuck).href]).status, 0);
  await new Promise((resolve) => setTimeout(resolve, 1500)); // let the renderer freeze

  const started = Date.now();
  const result = run(['activity'], 15000);
  const took = Date.now() - started;
  assert.equal(result.error, undefined, `activity hung for ${took} ms with a blocked tab`);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(took < 8000, `activity took ${took} ms`);

  const activity = JSON.parse(result.stdout);
  assert.equal(activity.held, false);
  const pages = activity.tabs.filter((tab) => tab.url.startsWith('file:'));
  assert.deepEqual(pages.map((tab) => [tab.name, tab.title]), [['calm', 'Calm tab'], ['stuck', 'Stuck tab']],
    'named tabs in the order they opened, newest last (Ops shows the last as the page)');
});
