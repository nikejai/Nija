(function () {
  const textEncoder = new TextEncoder();

  function bufferToBase64Url(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function randomBuffer(length) {
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    return bytes.buffer;
  }

  function base64UrlToBuffer(base64Url) {
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '==='.slice((base64.length + 3) % 4);
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  function extensionResults(credential) {
    if (!credential || typeof credential.getClientExtensionResults !== 'function') {
      return {};
    }
    return credential.getClientExtensionResults() || {};
  }

  async function isAvailable() {
    if (!window.PublicKeyCredential || !navigator.credentials) {
      return false;
    }
    try {
      if (
        PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable
      ) {
        return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  async function isWebAuthnSupported() {
    return !!(window.PublicKeyCredential && navigator.credentials);
  }

  async function supportsPrf() {
    if (!(await isAvailable())) {
      return false;
    }
    if (!window.crypto || !window.crypto.getRandomValues) {
      return false;
    }
    if (PublicKeyCredential.getClientCapabilities) {
      try {
        const capabilities = await PublicKeyCredential.getClientCapabilities();
        return capabilities.prf === true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  async function createPlatformCredential(vaultId, displayName, prfSalt) {
    const challenge = randomBuffer(32);
    const userId = textEncoder.encode(String(vaultId).slice(0, 64));

    return navigator.credentials.create({
      publicKey: {
        challenge: challenge,
        rp: { name: 'Nija' },
        user: {
          id: userId,
          name: displayName || vaultId,
          displayName: displayName || vaultId,
        },
        pubKeyCredParams: [
          { alg: -7, type: 'public-key' },
          { alg: -257, type: 'public-key' },
        ],
        authenticatorSelection: {
          userVerification: 'required',
          residentKey: 'discouraged',
        },
        timeout: 60000,
        attestation: 'none',
        extensions: {
          prf: {
            eval: {
              first: prfSalt,
            },
          },
        },
      },
    });
  }

  async function registerQuickUnlock(vaultId, displayName) {
    try {
      if (!(await supportsPrf())) {
        throw new Error('prf_unavailable');
      }
      const prfSalt = randomBuffer(32);
      let credential;
      try {
        credential = await createPlatformCredential(vaultId, displayName, prfSalt);
      } catch (error) {
        if (error && error.name === 'InvalidStateError') {
          throw new Error('credential_exists');
        }
        throw error;
      }
      if (!credential) {
        throw new Error('registration_failed');
      }

      const credentialId = bufferToBase64Url(credential.rawId);
      const createExtensions = extensionResults(credential);
      if (createExtensions.prf && createExtensions.prf.enabled === false) {
        throw new Error('prf_unavailable');
      }
      const verification = await authenticateQuickUnlock(
        credentialId,
        bufferToBase64Url(prfSalt)
      );
      if (!verification.ok || !verification.prfKey) {
        throw new Error(verification.reason || 'prf_unavailable');
      }
      return {
        credentialId: credentialId,
        prfSalt: bufferToBase64Url(prfSalt),
        prfKey: verification.prfKey,
      };
    } catch (error) {
      const name = error && error.name ? String(error.name) : 'unknown';
      const message = error && error.message ? String(error.message) : 'registration_failed';
      throw new Error(name + ':' + message);
    }
  }

  async function authenticateQuickUnlock(credentialId, prfSalt) {
    try {
      if (!prfSalt) {
        throw new Error('prf_unavailable');
      }
      const assertion = await navigator.credentials.get({
        publicKey: {
          challenge: randomBuffer(32),
          allowCredentials: [
            {
              id: base64UrlToBuffer(credentialId),
              type: 'public-key',
            },
          ],
          userVerification: 'required',
          timeout: 60000,
          extensions: {
            prf: {
              eval: {
                first: base64UrlToBuffer(prfSalt),
              },
            },
          },
        },
      });
      const extensions = extensionResults(assertion);
      const prfFirst = extensions.prf && extensions.prf.results
        ? extensions.prf.results.first
        : null;
      if (!assertion || !prfFirst) {
        return { ok: false, reason: 'prf_unavailable' };
      }
      return { ok: true, prfKey: bufferToBase64Url(prfFirst) };
    } catch (error) {
      const name = error && error.name ? String(error.name) : 'unknown';
      const message = error && error.message ? String(error.message) : 'authentication_failed';
      return { ok: false, reason: name + ':' + message };
    }
  }

  window.nijaWebAuthn = {
    isAvailable: isAvailable,
    isWebAuthnSupported: isWebAuthnSupported,
    supportsPrf: supportsPrf,
    registerQuickUnlock: registerQuickUnlock,
    authenticateQuickUnlock: authenticateQuickUnlock,
  };
})();
