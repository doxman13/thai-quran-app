#!/usr/bin/env node

/**
 * Generate Apple Client Secret JWT for Supabase Auth
 * Usage: node scripts/generate_apple_jwt.js <TEAM_ID> [SERVICES_ID] [P8_PATH]
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function base64Url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

const teamId = process.argv[2];
const serviceId = process.argv[3] || 'com.abuzayd.iqra.web';

// Auto-detect downloaded .p8 key in ~/Downloads if not specified
let p8Path = process.argv[4];
if (!p8Path) {
  const downloadsDir = path.join(process.env.HOME || '', 'Downloads');
  try {
    const files = fs.readdirSync(downloadsDir);
    const p8File = files.find(f => f.startsWith('AuthKey_') && f.endsWith('.p8'));
    if (p8File) {
      p8Path = path.join(downloadsDir, p8File);
    }
  } catch (_) {}
}

if (!teamId) {
  console.error('\n❌ Error: Please provide your Apple Team ID.');
  console.error('Usage: node scripts/generate_apple_jwt.js <APPLE_TEAM_ID>\n');
  process.exit(1);
}

if (!p8Path || !fs.existsSync(p8Path)) {
  console.error('\n❌ Error: Could not find AuthKey_*.p8 in ~/Downloads or at the specified path.');
  console.error('Please specify the path: node scripts/generate_apple_jwt.js <TEAM_ID> [SERVICES_ID] /path/to/AuthKey.p8\n');
  process.exit(1);
}

const keyIdMatch = path.basename(p8Path).match(/AuthKey_([A-Za-z0-9]+)\.p8/);
const keyId = keyIdMatch ? keyIdMatch[1] : null;

if (!keyId) {
  console.error('\n❌ Error: Could not determine Key ID from filename: ' + path.basename(p8Path));
  process.exit(1);
}

const privateKey = fs.readFileSync(p8Path, 'utf8');

const header = {
  alg: 'ES256',
  kid: keyId,
};

const now = Math.floor(Date.now() / 1000);
const sixMonthsSeconds = 180 * 24 * 60 * 60; // 180 days (maximum allowed by Apple)

const payload = {
  iss: teamId.trim(),
  iat: now,
  exp: now + sixMonthsSeconds,
  aud: 'https://appleid.apple.com',
  sub: serviceId.trim(),
};

const encodedHeader = base64Url(JSON.stringify(header));
const encodedPayload = base64Url(JSON.stringify(payload));
const signingInput = `${encodedHeader}.${encodedPayload}`;

const signature = crypto.sign('sha256', Buffer.from(signingInput), {
  key: privateKey,
  dsaEncoding: 'ieee-p1363',
});

const clientSecretJwt = `${signingInput}.${base64Url(signature)}`;

console.log('\n✅ Apple Client Secret JWT successfully generated!');
console.log('--------------------------------------------------');
console.log('Key ID      :', keyId);
console.log('Team ID     :', teamId);
console.log('Services ID :', serviceId);
console.log('Valid for   : 180 days');
console.log('--------------------------------------------------');
console.log('\nCopy and paste this token into Supabase "Secret Key (for OAuth)":\n');
console.log(clientSecretJwt);
console.log('\n');
