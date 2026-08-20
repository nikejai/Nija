(function () {
  'use strict';

  function openDb(dbName, storeName, version) {
    return new Promise(function (resolve, reject) {
      var request = window.indexedDB.open(dbName, version || 1);
      request.onupgradeneeded = function (event) {
        var db = event.target.result;
        if (!db.objectStoreNames.contains(storeName)) {
          db.createObjectStore(storeName);
        }
      };
      request.onsuccess = function () {
        resolve(request.result);
      };
      request.onerror = function () {
        reject(request.error || new Error('indexeddb_open_failed'));
      };
    });
  }

  async function readIndexedText(dbName, storeName, key, version) {
    var db = await openDb(dbName, storeName, version);
    return new Promise(function (resolve, reject) {
      var txn = db.transaction(storeName, 'readonly');
      var request = txn.objectStore(storeName).get(key);
      request.onsuccess = function () {
        var value = request.result;
        resolve(typeof value === 'string' && value.length > 0 ? value : null);
      };
      request.onerror = function () {
        reject(request.error || new Error('indexeddb_read_failed'));
      };
    });
  }

  async function writeIndexedText(dbName, storeName, key, value, version) {
    var db = await openDb(dbName, storeName, version);
    return new Promise(function (resolve, reject) {
      var txn = db.transaction(storeName, 'readwrite');
      var request = txn.objectStore(storeName).put(value, key);
      request.onsuccess = function () {
        resolve(true);
      };
      request.onerror = function () {
        reject(request.error || new Error('indexeddb_write_failed'));
      };
    });
  }

  async function deleteIndexedText(dbName, storeName, key, version) {
    var db = await openDb(dbName, storeName, version);
    return new Promise(function (resolve, reject) {
      var txn = db.transaction(storeName, 'readwrite');
      var request = txn.objectStore(storeName).delete(key);
      request.onsuccess = function () {
        resolve(true);
      };
      request.onerror = function () {
        reject(request.error || new Error('indexeddb_delete_failed'));
      };
    });
  }

  function readLocalText(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  function removeLocalText(key) {
    try {
      window.localStorage.removeItem(key);
    } catch (_) {}
  }

  function pickTextFile(accept) {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = accept || '';
      input.style.display = 'none';

      var done = false;
      function finish(value) {
        if (done) return;
        done = true;
        input.remove();
        resolve(value || null);
      }

      input.addEventListener('change', function () {
        var file = input.files && input.files.length > 0 ? input.files[0] : null;
        if (!file) {
          finish(null);
          return;
        }
        var reader = new FileReader();
        reader.onload = function () {
          finish({ name: file.name, content: String(reader.result || '') });
        };
        reader.onerror = function () {
          finish(null);
        };
        reader.readAsText(file);
      });
      input.addEventListener('cancel', function () {
        finish(null);
      });
      document.body.appendChild(input);
      input.click();
    });
  }

  function downloadBlob(fileName, blob) {
    var url = URL.createObjectURL(blob);
    var anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
    return true;
  }

  function downloadTextFile(fileName, content, mimeType) {
    return downloadBlob(fileName, new Blob([content], { type: mimeType }));
  }

  function base64ToBytes(base64) {
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  function downloadBase64File(fileName, base64, mimeType) {
    return downloadBlob(fileName, new Blob([base64ToBytes(base64)], { type: mimeType }));
  }

  async function shareFile(fileName, blob, title) {
    if (!navigator.share) return false;
    var file = new File([blob], fileName, { type: blob.type });
    var payload = { files: [file], title: title || fileName };
    if (navigator.canShare && !navigator.canShare(payload)) return false;
    try {
      await navigator.share(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  function shareTextFile(fileName, content, mimeType) {
    return shareFile(fileName, new Blob([content], { type: mimeType }), fileName);
  }

  function shareBase64File(fileName, base64, mimeType) {
    return shareFile(
      fileName,
      new Blob([base64ToBytes(base64)], { type: mimeType }),
      fileName
    );
  }

  function pwaStatus() {
    var bridge = window.nijaPwaInstall;
    if (!bridge) {
      return {
        isInstalled: false,
        canPrompt: false,
        requiresManualSteps: false,
        platform: 'unknown'
      };
    }
    return {
      isInstalled: !!bridge.isInstalled(),
      canPrompt: !!bridge.canPromptInstall(),
      requiresManualSteps: !!bridge.requiresManualSteps(),
      platform: String(bridge.detectPlatform() || 'unknown')
    };
  }

  async function promptPwaInstall() {
    var bridge = window.nijaPwaInstall;
    if (!bridge) return { outcome: 'unavailable' };
    return bridge.promptInstall();
  }

  function webAuthnBridge() {
    return window.nijaWebAuthn || null;
  }

  async function webAuthnIsAvailable() {
    var bridge = webAuthnBridge();
    return bridge ? bridge.isAvailable() : false;
  }

  async function webAuthnIsSupported() {
    var bridge = webAuthnBridge();
    return bridge ? bridge.isWebAuthnSupported() : false;
  }

  async function webAuthnSupportsPrf() {
    var bridge = webAuthnBridge();
    return bridge ? bridge.supportsPrf() : false;
  }

  async function webAuthnRegisterQuickUnlock(vaultId, displayName) {
    var bridge = webAuthnBridge();
    if (!bridge) throw new Error('WebAuthn is unavailable in this browser.');
    return bridge.registerQuickUnlock(vaultId, displayName);
  }

  async function webAuthnAuthenticateQuickUnlock(credentialId, prfSalt) {
    var bridge = webAuthnBridge();
    if (!bridge) return null;
    return bridge.authenticateQuickUnlock(credentialId, prfSalt);
  }

  window.nijaBrowser = {
    readIndexedText: readIndexedText,
    writeIndexedText: writeIndexedText,
    deleteIndexedText: deleteIndexedText,
    readLocalText: readLocalText,
    removeLocalText: removeLocalText,
    pickTextFile: pickTextFile,
    downloadTextFile: downloadTextFile,
    downloadBase64File: downloadBase64File,
    shareTextFile: shareTextFile,
    shareBase64File: shareBase64File,
    pwaStatus: pwaStatus,
    promptPwaInstall: promptPwaInstall,
    webAuthnIsAvailable: webAuthnIsAvailable,
    webAuthnIsSupported: webAuthnIsSupported,
    webAuthnSupportsPrf: webAuthnSupportsPrf,
    webAuthnRegisterQuickUnlock: webAuthnRegisterQuickUnlock,
    webAuthnAuthenticateQuickUnlock: webAuthnAuthenticateQuickUnlock
  };
})();
