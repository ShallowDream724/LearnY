import fs from 'node:fs/promises';
import https from 'node:https';
import path from 'node:path';
import process from 'node:process';
import vm from 'node:vm';

const LOGIN_URL =
  'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/bb5df85216504820be7bba2b0ae1535b/0';
const CHECK_URL = 'https://id.tsinghua.edu.cn/do/off/ui/auth/login/check';

function parseArgs(argv) {
  const result = {
    usernameEnv: 'LEARNY_AUTH_DIAG_USERNAME',
    passwordEnv: 'LEARNY_AUTH_DIAG_PASSWORD',
    output: null,
    bodyDir: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--username-env':
        result.usernameEnv = argv[++i];
        break;
      case '--password-env':
        result.passwordEnv = argv[++i];
        break;
      case '--output':
        result.output = argv[++i];
        break;
      case '--body-dir':
        result.bodyDir = argv[++i];
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return result;
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

function log(message) {
  console.log(`[js-sm2-probe] ${message}`);
}

function request(url, { method = 'GET', headers = {}, body } = {}) {
  return new Promise((resolve, reject) => {
    const requestUrl = new URL(url);
    const req = https.request(
      requestUrl,
      {
        method,
        headers,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          resolve({
            statusCode: res.statusCode ?? 0,
            headers: res.headers,
            body: Buffer.concat(chunks).toString('utf8'),
          });
        });
      },
    );
    req.on('error', reject);
    if (body) {
      req.write(body);
    }
    req.end();
  });
}

function extractPublicKey(html) {
  const match = html.match(/id="sm2publicKey">([0-9a-fA-F]+)</);
  return match?.[1]?.trim() ?? '';
}

function extractSm2UtilPath(html) {
  const match = html.match(/src="([^"]*sm2Util\.js[^"]*)"/i);
  return match?.[1] ?? '';
}

function extractFirstCookie(setCookieHeaders) {
  if (!setCookieHeaders) {
    return '';
  }
  const first = Array.isArray(setCookieHeaders)
    ? setCookieHeaders[0]
    : setCookieHeaders;
  return `${first}`.split(';')[0] ?? '';
}

function extractTicket(responseBody) {
  const patterns = [
    /ticket=([A-Za-z0-9]+)/,
    /name=['"]ticket['"]\s+value=['"]([^'"]+)['"]/i,
  ];
  for (const pattern of patterns) {
    const match = responseBody.match(pattern);
    if (match?.[1]) {
      return match[1];
    }
  }
  return null;
}

function looksLikeBadCredential(responseBody) {
  return (
    responseBody.includes('用户名或密码不正确') ||
    responseBody.includes('密码不正确') ||
    responseBody.includes('请重试')
  );
}

function preview(text, maxLength = 240) {
  const normalized = `${text}`.replace(/\s+/g, ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, maxLength)}...`;
}

async function loadSm2Util(scriptUrl) {
  const response = await request(scriptUrl);
  if (response.statusCode !== 200) {
    throw new Error(`Failed to fetch sm2Util.js: HTTP ${response.statusCode}`);
  }

  const context = {};
  vm.createContext(context);
  vm.runInContext(response.body, context);
  if (!context.sm2Util?.doEncryptStr) {
    throw new Error('sm2Util.doEncryptStr not found');
  }
  return context.sm2Util;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const username = process.env[options.usernameEnv] ?? '';
  const password = process.env[options.passwordEnv] ?? '';
  if (!username || !password) {
    throw new Error('Username/password env vars are required');
  }

  const loginResponse = await request(LOGIN_URL);
  const cookieHeader = extractFirstCookie(loginResponse.headers['set-cookie']);
  const publicKey = extractPublicKey(loginResponse.body);
  const sm2UtilPath = extractSm2UtilPath(loginResponse.body);
  const sm2UtilUrl = new URL(sm2UtilPath, LOGIN_URL).toString();

  const sm2Util = await loadSm2Util(sm2UtilUrl);
  const encryptedPassword = sm2Util.doEncryptStr(password, publicKey);
  const basePayload = {
    i_user: username,
    i_pass: encryptedPassword,
    fingerPrint: '8164fc4a66e072a944c2e0f5d0aef34d',
    fingerGenPrint: '',
    fingerGenPrint3: '',
    deviceName: 'windows,Edge/146',
    i_captcha: '',
  };

  async function runVariant(name, extraPayload = {}) {
    const requestBody = new URLSearchParams({
      ...basePayload,
      ...extraPayload,
    }).toString();
    const checkResponse = await request(CHECK_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        origin: 'https://id.tsinghua.edu.cn',
        referer: LOGIN_URL,
        cookie: cookieHeader,
      },
      body: requestBody,
    });

    const ticket = extractTicket(checkResponse.body);
    if (options.bodyDir) {
      await fs.mkdir(options.bodyDir, { recursive: true });
      await fs.writeFile(
        path.join(options.bodyDir, `${name}.html`),
        checkResponse.body,
      );
    }
    return {
      name,
      checkStatus: checkResponse.statusCode,
      badCredential: looksLikeBadCredential(checkResponse.body),
      ticketMasked: mask(ticket),
      responsePreview: preview(checkResponse.body),
    };
  }

  const variants = [
    await runVariant('default'),
    await runVariant('singleLogin', { singleLogin: 'on' }),
  ];

  const summary = {
    loginStatus: loginResponse.statusCode,
    cookieHeader: mask(cookieHeader),
    publicKeyLength: publicKey.length,
    sm2UtilUrl,
    encryptedPasswordPrefix: encryptedPassword.slice(0, 20),
    encryptedPasswordLength: encryptedPassword.length,
    variants,
  };

  if (options.output) {
    await fs.mkdir(path.dirname(options.output), { recursive: true });
    await fs.writeFile(options.output, JSON.stringify(summary, null, 2));
  }

  log(`loginStatus=${summary.loginStatus}`);
  log(`encryptedPasswordPrefix=${summary.encryptedPasswordPrefix}`);
  log(`encryptedPasswordLength=${summary.encryptedPasswordLength}`);
  for (const variant of variants) {
    log(`variant=${variant.name} checkStatus=${variant.checkStatus}`);
    if (variant.ticketMasked !== '(empty)') {
      log(`variant=${variant.name} ticket=${variant.ticketMasked}`);
    } else if (variant.badCredential) {
      log(`variant=${variant.name} result=badCredential`);
    } else {
      log(
        `variant=${variant.name} result=unknown responsePreview=${variant.responsePreview}`,
      );
    }
  }
}

main().catch((error) => {
  console.error(`[js-sm2-probe] ${error.stack || error.message || error}`);
  process.exitCode = 1;
});
