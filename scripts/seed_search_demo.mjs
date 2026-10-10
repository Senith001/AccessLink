import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';

const project = 'access-link-005';
const database = `projects/${project}/databases/(default)/documents`;
const endpoint = `https://firestore.googleapis.com/v1/${database}`;
const rows = JSON.parse(readFileSync(new URL('../lib/tools/search_demo_places.json', import.meta.url), 'utf8'));
const featureFlags = {
  wheelchairAccessible: 'hasWheelchairAccess',
  accessibleToilet: 'hasAccessibleToilet',
  elevator: 'hasElevator',
  accessibleParking: 'hasAccessibleParking',
  tactilePaving: 'hasTactilePaving',
  audioSupport: 'hasAudioSupport',
  hearingSupport: 'hasHearingSupport',
};
const categories = {
  Hospital: { id: 'cat_hospital', icon: 'local_hospital' },
  Restaurant: { id: 'cat_restaurant', icon: 'restaurant' },
  Park: { id: 'cat_park', icon: 'park' },
  Bank: { id: 'cat_bank', icon: 'account_balance' },
  Library: { id: 'cat_library', icon: 'library_books' },
};

// Explicit Firestore REST types preserve GeoPoint and Timestamp values.
function field(value) {
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') return Number.isInteger(value)
    ? { integerValue: String(value) } : { doubleValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
  return { mapValue: { fields: fields(value) } };
}

function fields(value) {
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, field(item)]));
}

function placeFields(row, timestamp) {
  const available = new Set(row.features);
  const accessibility = Object.fromEntries(Object.keys(featureFlags).map(key => [key, {
    available: available.has(key),
    notes: 'Demo scenario only; this feature has not been checked at a real location.',
    verified: false,
  }]));
  const openingHours = Object.fromEntries([
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ].map(day => [day, { open: '09:00', close: '17:00', closed: false }]));
  const result = fields({
    name: row.name,
    nameLower: row.name.toLowerCase(),
    description: 'Fictional demonstration place. Coordinates, opening hours and accessibility features are sample data, not verified visitor information.',
    categoryId: categories[row.category].id,
    categoryName: row.category,
    city: row.city,
    district: row.district,
    address: `Demo location, ${row.city}, ${row.district}, Sri Lanka`,
    photos: [],
    contact: { phone: '', email: '', website: '' },
    openingHours,
    accessibility,
    ...Object.fromEntries(Object.entries(featureFlags).map(([key, flag]) => [flag, available.has(key)])),
    accessibilityScore: Math.round(available.size / Object.keys(featureFlags).length * 100),
    isVerified: false,
    isDemo: true,
    dataSource: 'search-discovery-demo',
    ratingAverage: 0,
    ratingCount: 0,
  });
  result.location = { geoPointValue: { latitude: row.latitude, longitude: row.longitude } };
  result.createdAt = result.updatedAt = { timestampValue: timestamp };
  for (const item of Object.values(result.accessibility.mapValue.fields)) {
    item.mapValue.fields.lastUpdated = { timestampValue: timestamp };
  }
  return result;
}

function validate() {
  const ids = new Set();
  for (const row of rows) {
    assert.match(row.id, /^demo_[a-z0-9_]+$/);
    assert(!ids.has(row.id), `Duplicate ID: ${row.id}`);
    ids.add(row.id);
    assert(typeof row.name === 'string' && row.name.trim().length > 0);
    assert(categories[row.category], `Unknown category: ${row.category}`);
    assert(row.city && row.district);
    assert(Number.isFinite(row.latitude) && row.latitude >= -90 && row.latitude <= 90);
    assert(Number.isFinite(row.longitude) && row.longitude >= -180 && row.longitude <= 180);
    assert.equal(new Set(row.features).size, row.features.length);
    assert(row.features.every(key => key in featureFlags));
    const doc = placeFields(row, new Date().toISOString());
    assert.equal(Object.keys(doc.accessibility.mapValue.fields).length, 7);
    assert.equal(doc.accessibilityScore.integerValue, String(Math.round(row.features.length / 7 * 100)));
  }
}

async function accessToken() {
  if (process.env.FIRESTORE_ACCESS_TOKEN) return process.env.FIRESTORE_ACCESS_TOKEN;
  // Reuse the Firebase CLI login; never save credentials in the project.
  const executable = realpathSync(execFileSync('which', ['firebase'], { encoding: 'utf8' }).trim());
  const require = createRequire(executable);
  const cliRoot = dirname(require.resolve('firebase-tools/package.json'));
  const auth = require(resolve(cliRoot, 'lib/auth.js'));
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account?.tokens?.refresh_token) throw new Error('Run firebase login before seeding.');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  return token.access_token;
}

async function request(path, token, options = {}) {
  const response = await fetch(`${endpoint}${path}`, {
    ...options,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    signal: AbortSignal.timeout(30000),
  });
  if (response.status === 404 && !options.method) return null;
  const body = await response.json();
  if (!response.ok) throw new Error(`Firestore ${response.status}: ${body.error?.message ?? response.statusText}`);
  return body;
}

async function main() {
  const modes = process.argv.slice(2);
  assert(modes.every(arg => ['--write', '--dry-run', '--rename'].includes(arg)), 'Use --dry-run, --write or --rename.');
  assert(modes.length <= 1, 'Choose one mode.');
  validate();
  console.log(`Validated ${rows.length} demo places for ${project}.`);
  for (const row of rows) {
    console.log(`${row.name} | ${row.city}, ${row.district} | ${Math.round(row.features.length / 7 * 100)}%`);
  }
  if (process.argv.includes('--rename')) {
    const token = await accessToken();
    const writes = [];
    const before = new Map();
    for (const row of rows) {
      const doc = await request(`/places/${row.id}`, token);
      assert(doc?.fields?.isDemo?.booleanValue === true &&
        doc.fields.dataSource?.stringValue === 'search-discovery-demo',
      `Not a search demo document: ${row.id}`);
      before.set(row.id, doc.fields);
      writes.push({
        update: { name: doc.name, fields: fields({ name: row.name, nameLower: row.name.toLowerCase() }) },
        updateMask: { fieldPaths: ['name', 'nameLower'] },
        currentDocument: { updateTime: doc.updateTime },
      });
    }
    await request(':commit', token, { method: 'POST', body: JSON.stringify({ writes }) });
    for (const row of rows) {
      const doc = await request(`/places/${row.id}`, token);
      const expected = { ...before.get(row.id), ...fields({ name: row.name, nameLower: row.name.toLowerCase() }) };
      assert.deepEqual(doc.fields, expected, `Unexpected document change: ${row.id}`);
    }
    console.log(`Renamed and verified all ${rows.length} places; only name and nameLower changed.`);
    return;
  }
  if (!process.argv.includes('--write')) {
    console.log('Dry run: no Firebase documents changed. Use --write to add missing documents.');
    return;
  }
  const token = await accessToken();
  const timestamp = new Date().toISOString();
  const writes = [];
  for (const [name, category] of Object.entries(categories)) {
    if (await request(`/categories/${category.id}`, token)) continue;
    writes.push({
      update: { name: `${database}/categories/${category.id}`, fields: {
        ...fields({ name, description: `${name} places`, icon: category.icon,
          order: Object.keys(categories).indexOf(name) + 1, isActive: true }),
        createdAt: { timestampValue: timestamp },
      } },
      currentDocument: { exists: false },
    });
  }
  let added = 0;
  for (const row of rows) {
    if (await request(`/places/${row.id}`, token)) {
      console.log(`Keeping existing document: ${row.id}`);
      continue;
    }
    writes.push({ update: { name: `${database}/places/${row.id}`, fields: placeFields(row, timestamp) },
      currentDocument: { exists: false } });
    added++;
  }
  if (writes.length) {
    // One atomic commit, with create-only preconditions protecting existing data.
    await request(':commit', token, { method: 'POST', body: JSON.stringify({ writes }) });
  }
  for (const row of rows) {
    const document = await request(`/places/${row.id}`, token);
    assert(document?.fields?.location?.geoPointValue, `Missing coordinates: ${row.id}`);
    assert.equal(document.fields.name.stringValue, row.name);
    assert.equal(document.fields.accessibilityScore.integerValue, String(Math.round(row.features.length / 7 * 100)));
    assert.equal(document.fields.isVerified.booleanValue, false);
  }
  console.log(`Added ${added} demo places. Verified all ${rows.length} demo documents in Firebase.`);
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
