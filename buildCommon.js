const path = require('path');
const fs = require('fs-extra');
const copyDir = require('copy-dir');
require('@dotenvx/dotenvx').config({ path: ['../../app_config.env'], quiet: true });

// --- app_config.env helpers ---------------------------------------------

// Strip surrounding single quotes (used for APP_NAME with spaces).
function unquote(v) {
  return (v || '').replace(/^'|'$/g, '');
}

// Collect the sequential ASSET{n}/ASSET{n}_PATH/ASSET{n}_NAME trios into lib entries.
// Stops at the first missing ASSET{n}. Yields { src, targetName } matching buildSpec.
function collectAssetLibs() {
  const libs = [];
  for (let i = 1; ; i++) {
    const asset = process.env[`ASSET${i}`];
    if (!asset) break;
    const assetPath = process.env[`ASSET${i}_PATH`] || '';
    const assetName = process.env[`ASSET${i}_NAME`] || '';
    libs.push({
      src: `../../../${asset}${assetPath}`,
      targetName: assetName,
    });
  }
  return libs;
}

// Collect the sequential CLIENT{n} entries. Stops at first missing CLIENT{n}.
function collectClients() {
  const clients = [];
  for (let i = 1; ; i++) {
    const client = process.env[`CLIENT${i}`];
    if (!client) break;
    clients.push(client);
  }
  return clients;
}

// --- generated artifacts ------------------------------------------------

// Build the in-memory spec to also replicate at /buildSpec.json as a visual copy
function buildSpecFromEnv() {
  const lib = collectAssetLibs();
  // Fixed setup lib entry (holds the generated app_setup.json).
  lib.push({ src: "../buildResources/setup", targetName: "setup" });

  return {
    app: {
      name: unquote(process.env.APP_NAME),
      version: process.env.APP_VERSION || '',
    },
    bin: {
      src: "../../local_server/target/release/local_server",
    },
    lib,
    libClients: collectClients().map(c => `../../../${c}`),
    favIcon: "../../globalBuildResources/favicon.ico",
    theme: "../../globalBuildResources/theme.json",
    product: "../../globalBuildResources/product.json",
    client_config: "../../globalBuildResources/client_config.json",
  };
}

// Generate app_setup.json from the client list, written to the OS setup dir
// so it is picked up by the "setup" lib entry during the copy step.
function writeAppSetupJson() {
  const setupDir = path.resolve('../buildResources/setup');
  fs.mkdirpSync(setupDir);
  const appSetup = {
    clients: collectClients().map(c => ({ path: `%%PANKOSMIADIR%%/${c}` })),
  };
  const appSetupPath = path.join(setupDir, 'app_setup.json');
  fs.writeFileSync(appSetupPath, JSON.stringify(appSetup, null, 2) + '\n', 'utf8');
  return appSetupPath;
}

// Ensure i18nPatch.json exists with branding/software/name/en = APP_NAME.
// If it does not exist, create the minimal file. If it does exist, only set
// branding.software.name.en, preserving any other keys already present.
function ensureI18nPatch() {
  const i18nPatchPath = path.resolve('../../globalBuildResources/i18nPatch.json');
  const appName = unquote(process.env.APP_NAME);

  let patch;
  if (fs.existsSync(i18nPatchPath)) {
    patch = fs.readJsonSync(i18nPatchPath);
  } else {
    patch = {};
  }
  if (!patch.branding || typeof patch.branding !== 'object') patch.branding = {};
  if (!patch.branding.software || typeof patch.branding.software !== 'object') patch.branding.software = {};
  if (!patch.branding.software.name || typeof patch.branding.software.name !== 'object') patch.branding.software.name = {};
  patch.branding.software.name.en = appName;

  fs.writeFileSync(i18nPatchPath, JSON.stringify(patch, null, 2) + '\n', 'utf8');
  return i18nPatchPath;
}

// --- product.json -------------------------------------------------------

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

function writeProductJson() {
  const productPath = path.resolve('../../globalBuildResources/product.json');
  const product = {
    name: unquote(process.env.APP_NAME),
    short_name: process.env.APP_SHORT_NAME || '',
    version: process.env.APP_VERSION || '',
    datetime: formatProductDatetime(),
    homepage: process.env.HOMEPAGE || '',
    start_offline: process.env.START_OFFLINE === 'true' ? true : false,
  };
  fs.writeFileSync(productPath, JSON.stringify(product, null, 2) + '\n', 'utf8');
  return productPath;
}

// --- build --------------------------------------------------------------

// Per-OS configuration (cfg) from thin scripts, where "ctx" is a context object and "=> void" returns nothing:
//   All properties are required, with null as an option where not applicable.
// cfg = {
//   separator,              // "/"|"\\"
//   cliExt,                 // "zsh"|"bat"|null
//   findFreePort,           // "find_free_port.sh"|"find_free_port.bat"
//   binSrcSuffix,           // ""|".exe"
//   binDest,                // "server.bin"|"server.exe"
//   writeScripts,           // (ctx) => void
//   readmeReplace,          // (readme, ctx) => string
//   copyIcon,               // (ctx) => void | null
//   postProcess,            // (ctx) => void | null
// }
function build(cfg) {
  // Locations
  const BUILD_DIR = path.resolve('../build');
  if (BUILD_DIR.split(cfg.separator).length < 5) {
    throw new Error(`Deleting build dir, but the path '${BUILD_DIR}' seems dangerously short. Aborting!`);
  }
  const OS_BUILD_RESOURCES = path.resolve('../buildResources');
  const REPO_ROOT = path.resolve("../../");

  // Generate artifacts derived from app_config.env BEFORE the build copies anything.
  //  - app_setup.json goes into ../buildResources/setup so the "setup" lib entry picks it up.
  //  - i18nPatch.json is created/updated so the i18n patch step below has APP_NAME.
  writeAppSetupJson();
  ensureI18nPatch();

  // Spec, formerly loaded from buildSpec.json, now derived from env.
  const spec = buildSpecFromEnv();

  //  - Emit a visual copy of the spec.
  const specPath = path.join(REPO_ROOT, 'buildSpec.json');
  fs.writeFileSync(specPath, JSON.stringify(spec, null, 2) + '\n', 'utf8');

  // Delete build dir if it exists
  if (fs.existsSync(BUILD_DIR)) { fs.rmSync(BUILD_DIR, {recursive: true, force: true}); }
  // Make build directory
  fs.mkdirSync(BUILD_DIR);

  const APP_NAME = spec['app']['name'];
  const FILE_APP_NAME = spec['app']['name'].toLowerCase().replace(/ /g, "-");
  const APP_VERSION = process.env.APP_VERSION;
  const CLI_EXT = cfg.cliExt;

  // Copy rocket config
  fs.copySync(path.join(REPO_ROOT, "Rocket.toml"), path.join(BUILD_DIR, "Rocket.toml"));

  // Write Scripts -- CLI launchers, and a MacOS post install script.
  cfg.writeScripts({ OS_BUILD_RESOURCES, BUILD_DIR, FILE_APP_NAME, CLI_EXT, APP_NAME });

  // Copy port checker for CLI
  const FIND_FREE_PORT = cfg.findFreePort;
  fs.copySync(path.join(OS_BUILD_RESOURCES, FIND_FREE_PORT), path.join(BUILD_DIR, FIND_FREE_PORT));

  // Copy and customize README
  const readMe = cfg.readmeReplace(
    fs.readFileSync(path.join(OS_BUILD_RESOURCES, "README.txt")).toString(),
    { APP_NAME, APP_VERSION, FILE_APP_NAME, CLI_EXT }
  );
  fs.writeFileSync(path.join(BUILD_DIR, "README.txt"), readMe);

  // Copy icon
  if (cfg.copyIcon) { cfg.copyIcon({ BUILD_DIR }); }

  // Make bin directory
  fs.mkdirSync(path.join(BUILD_DIR, "bin"));
  // Copy bin
  const BIN_SRC = path.resolve(spec['bin']['src'] + cfg.binSrcSuffix);   // [BIN_SRC_SUFFIX]
  fs.copySync(BIN_SRC, path.join(BUILD_DIR, "bin", cfg.binDest));        // [BIN_DEST]

  // Make lib directory
  const libDirPath = path.join(BUILD_DIR, "lib");
  fs.mkdirSync(libDirPath);
  // Copy lib directories
  for (const libSpec of spec['lib'].map(s => ({ src: path.resolve(s.src), dest: path.join(libDirPath, s.targetName) }))) {
    copyDir.sync(libSpec.src, path.join(libSpec.dest), {});
  }

  // Patch i18n
  const builtI18nPath = path.join(BUILD_DIR, "lib", "templates", "i18n.json");
  const i18nJson = fs.readJsonSync(builtI18nPath);
  const i18nPatchPath = path.resolve("../../globalBuildResources/i18nPatch.json");
  const patchJson = fs.readJsonSync(i18nPatchPath);
  for ([level1, level1Values] of Object.entries(patchJson)) {
    for ([level2, level2Values] of Object.entries(level1Values)) {
      for ([level3, payload] of Object.entries(level2Values)) {
        if (!i18nJson[level1] || !i18nJson[level1][level2] || !i18nJson[level1][level2][level3]) {
          throw new Error(`Trying to patch i18n for '${level1}/${level2}/${level3}' which does not exist in i18n template`);
        }
        i18nJson[level1][level2][level3] = payload;
      }
    }
  }
  fs.writeJsonSync(builtI18nPath, i18nJson);

  // Make lib/clients
  fs.mkdirSync(path.join(BUILD_DIR, "lib", "clients"));
  // Copy clients
  for (const libClientSrc of spec['libClients'].map(s => path.resolve(s))) {
    const clientSrcLeaf = libClientSrc.split(cfg.separator).reverse()[0];
    const clientDestParent = path.join(BUILD_DIR, "lib", "clients", clientSrcLeaf);
    fs.mkdirSync(clientDestParent);
    const uuidSrc = path.join(libClientSrc, "storage_id.json");
    const uuidDest = path.join(clientDestParent, "storage_id.json");
    if (fs.existsSync(uuidSrc)) { fs.copySync(uuidSrc, uuidDest); }
    fs.copySync(path.join(libClientSrc, "package.json"), path.join(clientDestParent, "package.json"));
    fs.copySync(path.join(libClientSrc, "pankosmia_metadata.json"), path.join(clientDestParent, "pankosmia_metadata.json"));
    copyDir.sync(path.join(libClientSrc, "build"), path.join(clientDestParent, "build"), {});
    if (spec.favIcon) {
      fs.copySync(path.resolve(spec.favIcon), path.join(clientDestParent, "build", "favicon.ico"));
    }
  }

  // Theme
  if (spec.theme) {
    fs.copySync(path.resolve(spec.theme), path.join(BUILD_DIR, "lib", "app_resources", "themes", "default.json"));
  }
  // Product
  const generatedProductPath = writeProductJson();
  if (spec.product) {
    fs.copySync(generatedProductPath, path.join(BUILD_DIR, "lib", "app_resources", "product", "product.json"));
  }
  // i18n overrides
  const I18N_OVERRIDES = "../../globalBuildResources/i18n-overrides.json";
  if (I18N_OVERRIDES) {
    fs.copySync(path.resolve(I18N_OVERRIDES), path.join(BUILD_DIR, "lib", "app_resources", "product", "i18n-overrides.json"));
  }
  // Client config
  if (spec.client_config) {
    fs.copySync(path.resolve(spec.client_config), path.join(BUILD_DIR, "lib", "app_resources", "product", "client_config.json"));
  }
  // Product resources
  fs.copySync(path.resolve("../../globalBuildResources/product_resources"), path.join(BUILD_DIR, "lib", "app_resources", "product", "product_resources"), { recursive: true });

  // Post process
  if (cfg.postProcess) { cfg.postProcess({ BUILD_DIR, spec }); }
}

module.exports = {
  build,
  writeProductJson,
  formatProductDatetime,
  buildSpecFromEnv,
  writeAppSetupJson,
  ensureI18nPatch,
};
