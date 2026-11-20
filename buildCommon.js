const path = require('path');
const fs = require('fs-extra');
const copyDir = require('copy-dir');

// --- constants ----------------------------------------------------------
// All relative paths resolve from <os>/scripts, where build.js is run.
// Source paths that may vary by product or tier live in app_config.json.
// What remains here is repo/clone layout and build-tree destinations.

const CONFIG_PATH = path.resolve('../../app_config.json');
const SIBLING_REPOS_DIR = path.resolve('../../../');  // where asset and client repos are cloned

const RESERVED_APP_KEYS = ['datetime'];
const REQUIRED_APP_KEYS = ['name', 'version', 'homepage'];
const REQUIRED_RESOURCE_KEYS = ['setup_lib', 'product', 'i18n_patch', 'i18n_overrides', 'product_resources', 'rocket_config'];
// Asset names the build and the runtime app depend on.
const REQUIRED_ASSET_NAMES = ['app_resources', 'templates'];

// --- app_config.json loading and tier resolution ------------------------

// Pick the tier: CLI arg > APP_TIER env var > tiers.default.
function selectTier(config) {
  const order = config.tiers && config.tiers.order;
  if (!Array.isArray(order) || order.length === 0) {
    throw new Error(`app_config.json: tiers.order must be a non-empty array`);
  }
  const requested = (process.argv[2] || process.env.APP_TIER || config.tiers.default || '').toLowerCase();
  if (!order.includes(requested)) {
    throw new Error(`Unknown tier '${requested}'. Expected one of: ${order.join(', ')}`);
  }
  return requested;
}

// Every branches array must be non-empty and use only known tiers.
function checkBranches(branches, label, order) {
  if (!Array.isArray(branches) || branches.length === 0) {
    throw new Error(`app_config.json: ${label} has missing or empty "branches"`);
  }
  for (const b of branches) {
    if (!order.includes(b)) {
      throw new Error(`app_config.json: ${label} has unknown branch '${b}'`);
    }
  }
}

// Resolve a [{ value, branches }] list to the single value for this tier.
// Returns undefined if no entry applies; throws if more than one does.
function resolveTiered(entries, tier, label, order) {
  if (!Array.isArray(entries)) {
    throw new Error(`app_config.json: ${label} must be an array of { value, branches } entries`);
  }
  entries.forEach((e, i) => checkBranches(e.branches, `${label}[${i}]`, order));
  const matches = entries.filter(e => e.branches.includes(tier));
  if (matches.length > 1) {
    throw new Error(`app_config.json: ${label} has ${matches.length} entries for tier '${tier}'`);
  }
  return matches.length ? matches[0].value : undefined;
}

// Resolve every key of an object of tiered lists, omitting keys with no value for this tier.
function resolveTieredObject(obj, tier, label, order) {
  const out = {};
  for (const [key, entries] of Object.entries(obj || {})) {
    const value = resolveTiered(entries, tier, `${label}.${key}`, order);
    if (value !== undefined) out[key] = value;
  }
  return out;
}

// Filter repo entries (assets/clients) to those included in this tier.
function filterByTier(list, tier, label, order) {
  return (list || []).filter((item, i) => {
    checkBranches(item.branches, `${label}[${i}] (${item.repo})`, order);
    return item.branches.includes(tier);
  });
}

function requireKeys(obj, keys, label, tier) {
  for (const key of keys) {
    if (obj[key] === undefined) {
      throw new Error(`app_config.json: ${label}.${key} has no value for tier '${tier}'`);
    }
  }
}

let cachedConfig = null;

// Load app_config.json and resolve everything for the selected tier.
function loadResolvedConfig() {
  if (cachedConfig) return cachedConfig;

  const raw = fs.readJsonSync(CONFIG_PATH);
  const tier = selectTier(raw);
  const order = raw.tiers.order;

  for (const key of RESERVED_APP_KEYS) {
    if (key in (raw.app || {})) {
      throw new Error(`app_config.json: app.${key} is reserved and generated at build time`);
    }
  }
  const app = resolveTieredObject(raw.app, tier, 'app', order);
  requireKeys(app, REQUIRED_APP_KEYS, 'app', tier);

  const resources = resolveTieredObject(raw.resources, tier, 'resources', order);
  requireKeys(resources, REQUIRED_RESOURCE_KEYS, 'resources', tier);

  const assets = filterByTier(raw.assets, tier, 'assets', order);
  for (const name of REQUIRED_ASSET_NAMES) {
    if (!assets.some(a => a.name === name)) {
      throw new Error(`app_config.json: tier '${tier}' must include an asset named '${name}'`);
    }
  }

  const rawServer = raw.server || {};
  const server = {
    crate: rawServer.crate,
    crate_version: resolveTiered(rawServer.crate_version || [], tier, 'server.crate_version', order),
    bin: resolveTiered(rawServer.bin || [], tier, 'server.bin', order),
  };
  requireKeys(server, ['bin'], 'server', tier);

  cachedConfig = {
    tier,
    app,
    assets,
    clients: filterByTier(raw.clients, tier, 'clients', order).map(c => c.repo),
    resources,
    server,
  };
  return cachedConfig;
}

// --- path helpers -------------------------------------------------------

// Absolute source dir of an asset entry: <siblings>/<repo><path>
function assetEntrySrc(asset) {
  return path.resolve(SIBLING_REPOS_DIR, `./${asset.repo}${asset.path}`);
}

// Absolute source dir of the asset with the given name, for this tier.
function makeAssetSrc(config) {
  return (name) => {
    const asset = config.assets.find(a => a.name === name);
    if (!asset) {
      throw new Error(`No asset named '${name}' is included in tier '${config.tier}'`);
    }
    return assetEntrySrc(asset);
  };
}

// Absolute source dir of a client repo.
function clientSrc(repo) {
  return path.join(SIBLING_REPOS_DIR, repo);
}

// --- generated artifacts ------------------------------------------------

// Generate app_setup.json from the tier's client list, written to the setup lib dir
// so it is copied to lib/setup with the other lib directories.
function writeAppSetupJson(config = loadResolvedConfig()) {
  const setupDir = path.resolve(config.resources.setup_lib);
  fs.mkdirpSync(setupDir);
  const appSetup = {
    clients: config.clients.map(c => ({ path: `%%PANKOSMIADIR%%/${c}` })),
  };
  const appSetupPath = path.join(setupDir, 'app_setup.json');
  fs.writeFileSync(appSetupPath, JSON.stringify(appSetup, null, 2) + '\n', 'utf8');
  return appSetupPath;
}

// Ensure the i18n patch file exists with branding/software/name/en = app.name.
// If it does not exist, create the minimal file. If it does exist, only set
// branding.software.name.en, preserving any other keys already present.
function ensureI18nPatch(config = loadResolvedConfig()) {
  const i18nPatchPath = path.resolve(config.resources.i18n_patch);
  let patch = fs.existsSync(i18nPatchPath) ? fs.readJsonSync(i18nPatchPath) : {};
  if (!patch.branding || typeof patch.branding !== 'object') patch.branding = {};
  if (!patch.branding.software || typeof patch.branding.software !== 'object') patch.branding.software = {};
  if (!patch.branding.software.name || typeof patch.branding.software.name !== 'object') patch.branding.software.name = {};
  patch.branding.software.name.en = config.app.name;

  fs.mkdirpSync(path.dirname(i18nPatchPath));
  fs.writeFileSync(i18nPatchPath, JSON.stringify(patch, null, 2) + '\n', 'utf8');
  return i18nPatchPath;
}

function formatProductDatetime() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const day = pad(now.getDate());
  const month = months[now.getMonth()];
  const year = now.getFullYear();
  const hours = pad(now.getHours());
  const minutes = pad(now.getMinutes());
  const seconds = pad(now.getSeconds());
  const offsetMinutes = -now.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? '+' : '-';
  const offsetHours = pad(Math.floor(Math.abs(offsetMinutes) / 60));
  const offsetMins = pad(Math.abs(offsetMinutes) % 60);
  return `${day} ${month} ${year} ${hours}:${minutes}:${seconds} UTC${sign}${offsetHours}:${offsetMins}`;
}

// Every resolved app key is written verbatim, in app_config.json order,
// with the generated datetime inserted right after version.
function writeProductJson(config = loadResolvedConfig()) {
  const productPath = path.resolve(config.resources.product);
  const product = {};
  for (const [key, value] of Object.entries(config.app)) {
    product[key] = value;
    if (key === 'version') product.datetime = formatProductDatetime();
  }
  fs.mkdirpSync(path.dirname(productPath));
  fs.writeFileSync(productPath, JSON.stringify(product, null, 2) + '\n', 'utf8');
  return productPath;
}

// Apply the i18n patch file (3 levels deep) onto the built i18n.json template.
function patchI18n(builtI18nPath, i18nPatchPath) {
  const i18nJson = fs.readJsonSync(builtI18nPath);
  const patchJson = fs.readJsonSync(i18nPatchPath);
  for (const [level1, level1Values] of Object.entries(patchJson)) {
    for (const [level2, level2Values] of Object.entries(level1Values)) {
      for (const [level3, payload] of Object.entries(level2Values)) {
        if (!i18nJson[level1] || !i18nJson[level1][level2] || !i18nJson[level1][level2][level3]) {
          throw new Error(`Trying to patch i18n for '${level1}/${level2}/${level3}' which does not exist in i18n template`);
        }
        i18nJson[level1][level2][level3] = payload;
      }
    }
  }
  fs.writeJsonSync(builtI18nPath, i18nJson);
}

// --- build --------------------------------------------------------------

// Per-OS configuration (cfg) from thin build.js scripts, where "ctx" is a context object
// and "=> void" returns nothing. All properties are required, with null where not applicable.
// cfg = {
//   cliExt,                 // "zsh"|"bat"|"sh"|null
//   findFreePort,           // "find_free_port.sh"|"find_free_port.bat"
//   binSrcSuffix,           // ""|".exe"
//   binDest,                // "server.bin"|"server.exe"
//   writeScripts,           // (ctx) => void
//   readmeReplace,          // (readme, ctx) => string
//   copyIcon,               // (ctx) => void | null
//   postProcess,            // (ctx) => void | null
// }
// copyIcon ctx    = { BUILD_DIR, config }
// postProcess ctx = { BUILD_DIR, config, assetSrc }
//   config   -- app_config.json resolved for the selected tier
//   assetSrc -- (name) => absolute source dir of the asset with that name
function build(cfg) {
  // Locations
  const BUILD_DIR = path.resolve('../build');
  if (BUILD_DIR.split(path.sep).length < 5) {
    throw new Error(`Deleting build dir, but the path '${BUILD_DIR}' seems dangerously short. Aborting!`);
  }
  const OS_BUILD_RESOURCES = path.resolve('../buildResources');
  const LIB_DIR = path.join(BUILD_DIR, 'lib');
  const CLIENTS_DIR = path.join(LIB_DIR, 'clients');
  const PRODUCT_DIR = path.join(LIB_DIR, 'app_resources', 'product');

  // Resolve app_config.json for the selected tier.
  const config = loadResolvedConfig();
  const { app, assets, clients, resources, server } = config;
  console.log(`Building tier '${config.tier}' (app version ${app.version}, ${clients.length} clients, ${assets.length} assets)`);

  // Generate artifacts derived from app_config.json BEFORE the build copies anything.
  writeAppSetupJson(config);
  const i18nPatchPath = ensureI18nPatch(config);

  // Delete build dir if it exists, then recreate it
  if (fs.existsSync(BUILD_DIR)) { fs.rmSync(BUILD_DIR, { recursive: true, force: true }); }
  fs.mkdirSync(BUILD_DIR);

  const APP_NAME = app.name;
  const FILE_APP_NAME = app.name.toLowerCase().replace(/ /g, '-');
  const APP_VERSION = app.version;
  const CLI_EXT = cfg.cliExt;

  // Copy rocket config
  fs.copySync(path.resolve(resources.rocket_config), path.join(BUILD_DIR, 'Rocket.toml'));

  // Write Scripts -- CLI launchers, and a MacOS post install script.
  cfg.writeScripts({ OS_BUILD_RESOURCES, BUILD_DIR, FILE_APP_NAME, CLI_EXT, APP_NAME });

  // Copy port checker for CLI
  fs.copySync(path.join(OS_BUILD_RESOURCES, cfg.findFreePort), path.join(BUILD_DIR, cfg.findFreePort));

  // Copy and customize README
  const readMe = cfg.readmeReplace(
    fs.readFileSync(path.join(OS_BUILD_RESOURCES, 'README.txt')).toString(),
    { APP_NAME, APP_VERSION, FILE_APP_NAME, CLI_EXT }
  );
  fs.writeFileSync(path.join(BUILD_DIR, 'README.txt'), readMe);

  // Copy icon
  if (cfg.copyIcon) { cfg.copyIcon({ BUILD_DIR, config }); }

  // Copy server binary
  fs.mkdirSync(path.join(BUILD_DIR, 'bin'));
  fs.copySync(path.resolve(server.bin + cfg.binSrcSuffix), path.join(BUILD_DIR, 'bin', cfg.binDest));

  // Copy asset directories, then the setup directory, into lib/
  fs.mkdirSync(LIB_DIR);
  for (const asset of assets) {
    copyDir.sync(assetEntrySrc(asset), path.join(LIB_DIR, asset.name), {});
  }
  copyDir.sync(path.resolve(resources.setup_lib), path.join(LIB_DIR, 'setup'), {});

  // Patch i18n
  patchI18n(path.join(LIB_DIR, 'templates', 'i18n.json'), i18nPatchPath);

  // Copy clients into lib/clients/<repo>
  fs.mkdirSync(CLIENTS_DIR);
  for (const repo of clients) {
    const src = clientSrc(repo);
    const dest = path.join(CLIENTS_DIR, repo);
    fs.mkdirSync(dest);
    const storageId = path.join(src, 'storage_id.json');
    if (fs.existsSync(storageId)) { fs.copySync(storageId, path.join(dest, 'storage_id.json')); }
    fs.copySync(path.join(src, 'package.json'), path.join(dest, 'package.json'));
    fs.copySync(path.join(src, 'pankosmia_metadata.json'), path.join(dest, 'pankosmia_metadata.json'));
    copyDir.sync(path.join(src, 'build'), path.join(dest, 'build'), {});
    if (resources.fav_icon) {
      fs.copySync(path.resolve(resources.fav_icon), path.join(dest, 'build', 'favicon.ico'));
    }
  }

  // Theme
  if (resources.theme) {
    fs.copySync(path.resolve(resources.theme), path.join(LIB_DIR, 'app_resources', 'themes', 'default.json'));
  }
  // Product
  fs.copySync(writeProductJson(config), path.join(PRODUCT_DIR, 'product.json'));
  // i18n overrides
  fs.copySync(path.resolve(resources.i18n_overrides), path.join(PRODUCT_DIR, 'i18n-overrides.json'));
  // Client config
  if (resources.client_config) {
    fs.copySync(path.resolve(resources.client_config), path.join(PRODUCT_DIR, 'client_config.json'));
  }
  // Product resources
  fs.copySync(path.resolve(resources.product_resources), path.join(PRODUCT_DIR, 'product_resources'), { recursive: true });

  // Post process
  if (cfg.postProcess) {
    cfg.postProcess({ BUILD_DIR, config, assetSrc: makeAssetSrc(config) });
  }
}

module.exports = {
  build,
  loadResolvedConfig,
  writeAppSetupJson,
  ensureI18nPatch,
  writeProductJson,
  formatProductDatetime,
};
