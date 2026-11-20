const path = require('path');
const fs = require('fs-extra');
const { build } = require('../../buildCommon.js');

build({
  cliExt: "bat",
  findFreePort: "find_free_port.bat",
  binSrcSuffix: ".exe",
  binDest: "server.exe",
  writeScripts: ({ OS_BUILD_RESOURCES, BUILD_DIR, FILE_APP_NAME, CLI_EXT }) => {
    fs.copySync(path.join(OS_BUILD_RESOURCES, "appLauncher.bat"), path.join(BUILD_DIR, FILE_APP_NAME + "." + CLI_EXT));
  },
  readmeReplace: (readMe, { APP_NAME, CLI_EXT, APP_VERSION }) =>
    readMe
      .replace(/%%APP_NAME%%/g, APP_NAME)
      .replace(/%%CLI_EXT%%/g, CLI_EXT)
      .replace(/%%APP_VERSION%%/g, APP_VERSION),
  copyIcon: ({ BUILD_DIR, config }) => {
    const appIcon = config.resources.app_icon;
    if (!appIcon) {
      throw new Error(`app_config.json: resources.app_icon has no value for tier '${config.tier}' (required on Windows)`);
    }
    fs.copySync(path.resolve(appIcon), path.join(BUILD_DIR, "icon.ico"));
  },
  postProcess: ({ BUILD_DIR, assetSrc }) => {
    // Fix mis-encoded infinity symbols in paged.js from the app_resources asset.
    const fixWindowsUtf8 = (srcFilePath, destFilePath) => {
      const data = fs.readFileSync(srcFilePath, 'utf8');
      fs.writeFileSync(destFilePath, data.replace(/âˆž/g, '∞'), 'utf8');
    };
    const PAGED_JS_REL = path.join('pdf', 'paged.polyfill.js');
    fixWindowsUtf8(
      path.join(assetSrc('app_resources'), PAGED_JS_REL),
      path.join(BUILD_DIR, 'lib', 'app_resources', PAGED_JS_REL)
    );
  },
});
