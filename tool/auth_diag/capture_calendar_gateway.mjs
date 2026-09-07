import fs from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const root = path.dirname(fileURLToPath(import.meta.url));
const executablePath = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find(existsSync);
if (!executablePath) throw new Error('Microsoft Edge is not installed');
const context = await chromium.launchPersistentContext(path.join(root, '.profile/calendar'), {
  executablePath, headless: false, viewport: null, args: ['--start-maximized'],
});
const page = context.pages()[0] ?? await context.newPage();
const output = path.join(root, '.out/calendar-gateway/cookies.json');
await page.goto('https://webvpn.tsinghua.edu.cn/', { waitUntil: 'domcontentloaded' });
await page.bringToFront();
console.log('[calendar-gateway] Browser ready. Complete the campus login in Edge.');
try {
  await page.waitForURL(url => url.hostname === 'webvpn.tsinghua.edu.cn' && url.pathname === '/', { timeout: 300000 });
  await page.waitForLoadState('domcontentloaded');
  const cookies = (await context.cookies()).filter(cookie =>
    ['webvpn.tsinghua.edu.cn', 'oauth.tsinghua.edu.cn', 'id.tsinghua.edu.cn'].includes(cookie.domain.replace(/^\./, '')));
  await fs.mkdir(path.dirname(output), { recursive: true });
  await fs.writeFile(output, JSON.stringify(cookies), { mode: 0o600 });
  console.log(`[calendar-gateway] Captured ${cookies.length} campus cookies. No values logged.`);
} catch {
  console.log('[calendar-gateway] Login did not complete before the diagnostic timeout.');
  process.exitCode = 1;
} finally {
  await context.close();
}
