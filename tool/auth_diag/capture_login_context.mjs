import { existsSync } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright-core';

const URLS = {
  idLogin:
    'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/bb5df85216504820be7bba2b0ae1535b/0',
  idLoginCheck: 'https://id.tsinghua.edu.cn/do/off/ui/auth/login/check',
  idLoginCheckSingle:
    'https://id.tsinghua.edu.cn/do/off/ui/auth/login/checkSingle',
  idPrefix: 'https://id.tsinghua.edu.cn',
  learnPrefix: 'https://learn.tsinghua.edu.cn',
};

const FORM_KEYS = [
  'fingerPrint',
  'fingerGenPrint',
  'fingerGenPrint3',
  'deviceName',
];

const OPTIONAL_LOGIN_KEYS = ['singleLogin'];
const TRUST_SAVE_URL_SUFFIX = '/b/doubleAuth/personal/saveFinger';

function parseArgs(argv) {
  const result = {
    output: null,
    browser: 'edge',
    timeoutMs: 180000,
    usernameEnv: 'LEARNY_AUTH_DIAG_USERNAME',
    passwordEnv: 'LEARNY_AUTH_DIAG_PASSWORD',
    autoSubmit: false,
    noPrefill: false,
    preserveTicket: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--output':
        result.output = argv[++i];
        break;
      case '--browser':
        result.browser = argv[++i];
        break;
      case '--timeout-ms':
        result.timeoutMs = Number(argv[++i]);
        break;
      case '--username-env':
        result.usernameEnv = argv[++i];
        break;
      case '--password-env':
        result.passwordEnv = argv[++i];
        break;
      case '--auto-submit':
        result.autoSubmit = true;
        break;
      case '--no-prefill':
        result.noPrefill = true;
        break;
      case '--preserve-ticket':
        result.preserveTicket = true;
        break;
      case '--help':
        console.log(
          'Usage: node capture_login_context.mjs --output <capture.json> ' +
            '[--browser edge|chrome|<path>] [--timeout-ms 180000] ' +
            '[--auto-submit] [--no-prefill] [--preserve-ticket]',
        );
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!result.output) {
    throw new Error('--output is required');
  }
  if (!Number.isFinite(result.timeoutMs) || result.timeoutMs <= 0) {
    throw new Error('--timeout-ms must be a positive integer');
  }
  return result;
}

function log(message) {
  console.log(`[auth-capture] ${message}`);
}

function mask(value, prefix = 6, suffix = 4) {
  if (!value) {
    return '(empty)';
  }
  if (value.length <= prefix + suffix) {
    return `${value[0]}***${value[value.length - 1]}`;
  }
  return `${value.slice(0, prefix)}***${value.slice(-suffix)}`;
}

function summarizeFormData(formData) {
  const summary = {};
  for (const key of [...FORM_KEYS, ...OPTIONAL_LOGIN_KEYS]) {
    const value = `${formData?.[key] ?? ''}`;
    summary[key] = {
      length: value.length,
      masked: mask(value, 4, 2),
    };
  }
  return summary;
}

function findBrowser(browserArg) {
  const candidates =
    browserArg === 'chrome'
      ? ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe']
      : browserArg === 'edge'
        ? [
            'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
            'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
          ]
        : [browserArg];

  for (const candidate of candidates) {
    if (candidate && existsSync(candidate)) {
      return candidate;
    }
  }

  throw new Error(`Could not resolve browser executable for "${browserArg}"`);
}

function pickEnv(name, optional = false) {
  const value = process.env[name];
  if (!value && !optional) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value || '';
}

function extractTicket(rawUrl) {
  try {
    const url = new URL(rawUrl);
    const ticket = url.searchParams.get('ticket');
    return ticket && ticket.trim() ? ticket.trim() : null;
  } catch (_) {
    return null;
  }
}

function isLoginSubmitRequest(requestUrl, method) {
  if (method !== 'POST') {
    return false;
  }

  try {
    const url = new URL(requestUrl);
    return (
      url.href === URLS.idLoginCheck ||
      url.href === URLS.idLoginCheckSingle ||
      url.pathname.endsWith('/do/off/ui/auth/login/check') ||
      url.pathname.endsWith('/do/off/ui/auth/login/checkSingle')
    );
  } catch (_) {
    return false;
  }
}

function parseUrlEncodedBody(rawBody) {
  if (!rawBody || !rawBody.trim()) {
    return {};
  }

  const parsed = {};
  const params = new URLSearchParams(rawBody);
  for (const [key, value] of params.entries()) {
    parsed[key] = value;
  }
  return parsed;
}

function looksLikeSaveFingerRequest(rawUrl, method = '') {
  try {
    const url = new URL(rawUrl);
    return (
      `${method}`.toUpperCase() === 'POST' &&
      url.pathname.endsWith(TRUST_SAVE_URL_SUFFIX)
    );
  } catch (_) {
    return false;
  }
}

function pickNonSensitiveLoginFields(payload) {
  const fields = {};
  for (const key of [...FORM_KEYS, ...OPTIONAL_LOGIN_KEYS]) {
    if (payload[key]) {
      fields[key] = payload[key];
    }
  }
  return fields;
}

function pickNonSensitiveRequestHeaders(headers) {
  if (!headers || typeof headers !== 'object') {
    return {};
  }

  const picked = {};
  for (const key of ['content-type', 'origin', 'referer', 'user-agent']) {
    const value = headers[key];
    if (value) {
      picked[key] = value;
    }
  }
  return picked;
}

function upsertCapturedAuthFields(state, fields, source) {
  if (!fields || typeof fields !== 'object') {
    return;
  }

  const next = { ...state.formData };
  let changed = false;
  for (const key of [...FORM_KEYS, ...OPTIONAL_LOGIN_KEYS]) {
    const value = `${fields[key] ?? ''}`;
    if (!value) {
      continue;
    }
    if (next[key] !== value) {
      next[key] = value;
      changed = true;
    }
  }

  if (!changed) {
    return;
  }

  state.formData = next;
  state.formDataSummary = summarizeFormData(next);
  state.browserEvents.push({
    ts: new Date().toISOString(),
    type: 'auth_fields_updated',
    source,
    keys: Object.keys(fields),
  });
}

async function ensureParent(filePath) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
}

async function readInlineError(page) {
  try {
    const url = page.url();
    if (!url.startsWith(URLS.idPrefix)) {
      return null;
    }
    const raw = await page.evaluate(() => {
      const selectors = ['#msg_note', '#c_note .red', '.alert-danger'];
      for (const selector of selectors) {
        const element = document.querySelector(selector);
        const text = element?.innerText?.trim?.() ?? '';
        if (text) {
          return text;
        }
      }
      return '';
    });
    const text = `${raw ?? ''}`.trim();
    return text || null;
  } catch (_) {
    return null;
  }
}

async function captureLearnArtifacts(page) {
  try {
    const url = page.url();
    if (!url.startsWith(URLS.learnPrefix)) {
      return null;
    }
    const payload = await page.evaluate(() => ({
      cookieString: document.cookie || '',
      html: document.documentElement?.outerHTML || '',
      title: document.title || '',
    }));
    return {
      cookieString: `${payload?.cookieString ?? ''}`,
      learnPageHtml: `${payload?.html ?? ''}`,
      pageTitle: `${payload?.title ?? ''}`,
    };
  } catch (_) {
    return null;
  }
}

async function waitForCompletion(page, timeoutMs, state) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (page.isClosed()) {
      return 'browser_closed';
    }

    if (state.ticketDisposition === 'preserved' && state.ticket) {
      await page.waitForTimeout(400);
      return 'ticket_preserved';
    }

    const currentUrl = page.url();
    if (currentUrl.startsWith(URLS.learnPrefix)) {
      await page.waitForTimeout(2500);
      return 'reached_learn';
    }

    if (state.submissionDetected || state.navigation.length > 1) {
      const inlineError = await readInlineError(page);
      if (inlineError) {
        state.inlineError = inlineError;
        return 'inline_error';
      }
    }

    await page.waitForTimeout(500);
  }
  return 'timeout';
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const username = pickEnv(options.usernameEnv, options.noPrefill);
  const password = pickEnv(options.passwordEnv, options.noPrefill);
  const executablePath = findBrowser(options.browser);

  const state = {
    capturedAt: new Date().toISOString(),
    browserExecutable: executablePath,
    finalUrl: null,
    status: 'started',
    submissionDetected: false,
    inlineError: null,
    ticket: null,
    ticketSource: null,
    ticketDisposition: 'none',
    formData: {},
    formDataSummary: {},
    loginRequest: null,
    trustSaveRequest: null,
    trustSaveResponse: null,
    cookieString: '',
    learnPageHtml: '',
    pageTitle: '',
    cookies: [],
    navigation: [],
    browserEvents: [],
  };

  await ensureParent(options.output);

  const browser = await chromium.launch({
    executablePath,
    headless: false,
  });
  const context = await browser.newContext();
  const page = await context.newPage();

  await context.route(
    /https:\/\/learn\.tsinghua\.edu\.cn\/b\/j_spring_security_thauth_roaming_entry\?ticket=/,
    async (route) => {
      const request = route.request();
      const ticket = extractTicket(request.url());
      if (ticket && !state.ticket) {
        state.ticket = ticket;
        state.ticketSource = 'route';
        log(`Captured roaming ticket ${mask(ticket, 8, 4)}`);
      }

      state.browserEvents.push({
        ts: new Date().toISOString(),
        type: 'roaming_request',
        url: request.url(),
        preserved: options.preserveTicket,
      });

      if (options.preserveTicket) {
        state.ticketDisposition = 'preserved';
        await route.abort('blockedbyclient');
        return;
      }

      state.ticketDisposition = 'observed';
      await route.continue();
    },
  );

  page.on('request', async (request) => {
    if (looksLikeSaveFingerRequest(request.url(), request.method())) {
      const parsedBody = parseUrlEncodedBody(request.postData() ?? '');
      state.trustSaveRequest = {
        ts: new Date().toISOString(),
        url: request.url(),
        method: request.method(),
        bodyKeys: Object.keys(parsedBody).sort(),
        fields: {
          fingerprint: parsedBody.fingerprint ?? '',
          deviceName: parsedBody.deviceName ?? '',
          radioVal: parsedBody.radioVal ?? '',
          singleLogin: parsedBody.singleLogin ?? '',
        },
      };
      state.browserEvents.push({
        ts: new Date().toISOString(),
        type: 'trust_save_request',
        keys: state.trustSaveRequest.bodyKeys,
      });
      log(
        `Captured trust-save request with keys ${state.trustSaveRequest.bodyKeys.join(', ')}`,
      );
      return;
    }

    if (!isLoginSubmitRequest(request.url(), request.method())) {
      return;
    }

    state.submissionDetected = true;
    const parsedBody = parseUrlEncodedBody(request.postData() ?? '');
    const fields = pickNonSensitiveLoginFields(parsedBody);
    const headers = pickNonSensitiveRequestHeaders(await request.allHeaders());
    state.loginRequest = {
      ts: new Date().toISOString(),
      url: request.url(),
      method: request.method(),
      endpoint: request.url().includes('checkSingle') ? 'checkSingle' : 'check',
      bodyKeys: Object.keys(parsedBody).sort(),
      fields,
      headers,
    };
    upsertCapturedAuthFields(state, fields, 'login_request');
    log(
      `Captured login request (${state.loginRequest.endpoint}) with keys ${state.loginRequest.bodyKeys.join(', ')}`,
    );
  });

  await page.exposeBinding('__learnyDiagCaptureForm', async (_, payload) => {
    if (!payload || typeof payload !== 'object') {
      return;
    }
    upsertCapturedAuthFields(state, payload, 'dom_capture');
  });

  await page.exposeBinding('__learnyDiagReportEvent', async (_, payload) => {
    if (!payload || typeof payload !== 'object') {
      return;
    }
    state.browserEvents.push({
      ts: new Date().toISOString(),
      ...payload,
    });
  });

  await page.addInitScript(
    ({ usernameValue, passwordValue, autoSubmit, keys }) => {
      const selectors = ['#msg_note', '#c_note .red', '.alert-danger'];

      const setInputValue = (selector, value) => {
        const input = document.querySelector(selector);
        if (!input) {
          return;
        }
        input.value = value;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
      };

      const collect = () => {
        const payload = {};
        for (const key of keys) {
          const element = document.getElementById(key);
          payload[key] =
            element && 'value' in element ? `${element.value || ''}` : '';
        }
        return payload;
      };

      const emitFormData = (source) => {
        try {
          window.__learnyDiagCaptureForm?.(collect());
          window.__learnyDiagReportEvent?.({
            type: 'form_capture',
            source,
          });
        } catch (_) {}
      };

      const emitInlineError = () => {
        try {
          for (const selector of selectors) {
            const element = document.querySelector(selector);
            const text = element?.innerText?.trim?.() ?? '';
            if (text) {
              window.__learnyDiagReportEvent?.({
                type: 'inline_error',
                message: text,
              });
              return;
            }
          }
        } catch (_) {}
      };

      const attach = () => {
        if (usernameValue) setInputValue('#i_user', usernameValue);
        if (passwordValue) setInputValue('#i_pass', passwordValue);

        const form = document.getElementById('theform');
        if (form && !form.__learnyDiagInstalled) {
          form.__learnyDiagInstalled = true;
          form.addEventListener(
            'submit',
            () => {
              emitFormData('submit');
            },
            true,
          );
          const originalSubmit = form.submit?.bind(form);
          if (originalSubmit) {
            form.submit = function learnyDiagSubmitOverride() {
              emitFormData('form.submit');
              return originalSubmit();
            };
          }
        }

        emitFormData('attach');
        emitInlineError();

        if (autoSubmit && !window.__learnyDiagAutoSubmitTriggered) {
          const captcha = document.getElementById('c_code');
          const captchaVisible =
            captcha && !captcha.classList.contains('hidden');
          if (!captchaVisible) {
            window.__learnyDiagAutoSubmitTriggered = true;
            setTimeout(() => {
              if (typeof window.doLogin === 'function') {
                window.doLogin();
                return;
              }
              const loginButton = document.querySelector(
                'a.btn.btn-lg.btn-primary.btn-block',
              );
              loginButton?.click?.();
            }, 250);
          }
        }
      };

      if (!window.__learnyDiagMutationObserver) {
        window.__learnyDiagMutationObserver = new MutationObserver(attach);
        window.__learnyDiagMutationObserver.observe(document.documentElement, {
          childList: true,
          subtree: true,
        });
      }

      if (!window.__learnyDiagInterval) {
        window.__learnyDiagInterval = setInterval(() => {
          emitFormData('interval');
          emitInlineError();
        }, 500);
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', attach, { once: true });
      } else {
        attach();
      }
    },
    {
      usernameValue: username,
      passwordValue: password,
      autoSubmit: options.autoSubmit,
      keys: FORM_KEYS,
    },
  );

  page.on('framenavigated', (frame) => {
    if (frame !== page.mainFrame()) {
      return;
    }
    const url = frame.url();
    state.navigation.push({
      ts: new Date().toISOString(),
      url,
    });
    const ticket = extractTicket(url);
    if (ticket && !state.ticket) {
      state.ticket = ticket;
      state.ticketSource = 'navigation';
      log(`Captured roaming ticket ${mask(ticket, 8, 4)}`);
    }
  });

  page.on('response', (response) => {
    const responseUrl = response.url();

    if (looksLikeSaveFingerRequest(responseUrl, response.request().method())) {
      response
        .text()
        .then((body) => {
          try {
            const parsed = JSON.parse(body || '{}');
            state.trustSaveResponse = {
              ts: new Date().toISOString(),
              url: responseUrl,
              status: response.status(),
              result: parsed?.result ?? '',
              trustedFingerGenPrint: `${parsed?.object ?? ''}`,
            };
            state.browserEvents.push({
              ts: new Date().toISOString(),
              type: 'trust_save_response',
              status: response.status(),
              result: parsed?.result ?? '',
              trustedFingerGenPrintLength: `${parsed?.object ?? ''}`.length,
            });
            log(
              `Captured trust-save response result=${parsed?.result ?? '(empty)'}`,
            );
          } catch (_) {
            state.trustSaveResponse = {
              ts: new Date().toISOString(),
              url: responseUrl,
              status: response.status(),
              result: 'unparseable',
              trustedFingerGenPrint: '',
            };
          }
        })
        .catch(() => {});
    }

    const ticket = extractTicket(responseUrl);
    if (ticket && !state.ticket) {
      state.ticket = ticket;
      state.ticketSource = 'response';
      if (!options.preserveTicket && state.ticketDisposition === 'none') {
        state.ticketDisposition = 'observed';
      }
      log(`Captured roaming ticket ${mask(ticket, 8, 4)}`);
    }

    if (ticket) {
      state.browserEvents.push({
        ts: new Date().toISOString(),
        type: 'roaming_response',
        url: responseUrl,
        status: response.status(),
      });
    }
  });

  log('Opening identity login page in a real browser');
  await page.goto(URLS.idLogin, {
    waitUntil: 'domcontentloaded',
    timeout: options.timeoutMs,
  });
  if (options.noPrefill) {
    log('Manual mode: type your credentials directly in the browser window.');
  }
  log(
    'Browser is ready. Finish login in the opened window; the tool will continue automatically.',
  );

  const completion = await waitForCompletion(page, options.timeoutMs, state);
  state.status = completion;
  state.finalUrl = page.isClosed() ? null : page.url();
  if (
    state.status === 'reached_learn' &&
    state.ticket &&
    (state.ticketDisposition === 'observed' || state.ticketDisposition === 'none')
  ) {
    state.ticketDisposition = 'consumed';
  }

  const learnArtifacts = page.isClosed() ? null : await captureLearnArtifacts(page);
  if (learnArtifacts) {
    state.cookieString = learnArtifacts.cookieString;
    state.learnPageHtml = learnArtifacts.learnPageHtml;
    state.pageTitle = learnArtifacts.pageTitle;
  }

  if (!page.isClosed()) {
    const cookies = await context.cookies();
    state.cookies = cookies.map((cookie) => ({
      name: cookie.name,
      value: cookie.value,
      domain: cookie.domain,
      path: cookie.path,
      expires: cookie.expires,
      httpOnly: cookie.httpOnly,
      secure: cookie.secure,
      sameSite: cookie.sameSite,
    }));
  }

  state.formDataSummary = summarizeFormData(state.formData);

  log(`Capture status: ${state.status}`);
  if (state.inlineError) {
    log(`Inline error: ${state.inlineError}`);
  }
  log(`Form snapshot: ${JSON.stringify(state.formDataSummary)}`);
  log(`Cookie count: ${state.cookies.length}`);

  await fs.writeFile(options.output, JSON.stringify(state, null, 2), 'utf8');
  log(`Wrote capture file to ${options.output}`);

  await context.close();
  await browser.close();
}

main().catch((error) => {
  console.error(`[auth-capture] Fatal error: ${error?.stack ?? error}`);
  process.exitCode = 1;
});
