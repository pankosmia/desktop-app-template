const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  setCanClose: (canClose) => ipcRenderer.send('setCanClose', canClose)
})

contextBridge.exposeInMainWorld('electronPrinter', {
  print: (options) => ipcRenderer.invoke('print-page', options)
});

// Enable Print from Print Preview
(() => {
  if (globalThis.__pv_preload_installed) return;
  globalThis.__pv_preload_installed = true;

  let previewWin = null;
  let openInProgress = false;

  const openPreview = (url, name = 'pagedjs-preview') => {
    if (previewWin && !previewWin.closed) return previewWin;
    if (openInProgress) return previewWin;
    openInProgress = true;
    try {
      previewWin = window.open(url, name);
      const t = setInterval(() => {
        if (!previewWin || previewWin.closed) {
          previewWin = null;
          clearInterval(t);
        }
      }, 500);
    } finally { openInProgress = false; }
    return previewWin;
  }

  // If reading window.contextBridge or calling exposeInMainWorld is prevented (e.g., context isolation/security restrictions) then set window.previewBridge directly.
  try {
    if (window.contextBridge && typeof window.contextBridge.exposeInMainWorld === 'function') {
      window.contextBridge.exposeInMainWorld('previewBridge', { openPreview });
    } else {
      window.previewBridge = { openPreview };
    }
  } catch (e) {
    window.previewBridge = { openPreview };
  }
})();