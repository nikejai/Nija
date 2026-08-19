(function () {
  let deferredPrompt = null;

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    window.dispatchEvent(new CustomEvent('nija-pwa-install-available'));
  });

  window.addEventListener('appinstalled', function () {
    deferredPrompt = null;
    window.dispatchEvent(new CustomEvent('nija-pwa-installed'));
  });

  function detectPlatform() {
    const ua = navigator.userAgent || '';
    const isIOS =
      /iPad|iPhone|iPod/.test(ua) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    if (isIOS) return 'ios';
    if (/Android/i.test(ua)) return 'android';
    return 'desktop';
  }

  function isSafari() {
    const ua = navigator.userAgent || '';
    return /Safari/i.test(ua) && !/Chrome|CriOS|FxiOS|EdgiOS/i.test(ua);
  }

  function isInstalled() {
    if (window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    if (window.matchMedia('(display-mode: fullscreen)').matches) {
      return true;
    }
    if (window.navigator.standalone === true) {
      return true;
    }
    return false;
  }

  function canPromptInstall() {
    return !!deferredPrompt;
  }

  async function promptInstall() {
    if (!deferredPrompt) {
      return { outcome: 'unavailable' };
    }
    deferredPrompt.prompt();
    const choice = await deferredPrompt.userChoice;
    deferredPrompt = null;
    return { outcome: choice.outcome || 'dismissed' };
  }

  function requiresManualSteps() {
    if (isInstalled()) return false;
    if (canPromptInstall()) return false;
    const platform = detectPlatform();
    return platform === 'ios' || (platform === 'desktop' && isSafari());
  }

  window.nijaPwaInstall = {
    detectPlatform: detectPlatform,
    isInstalled: isInstalled,
    canPromptInstall: canPromptInstall,
    requiresManualSteps: requiresManualSteps,
    promptInstall: promptInstall,
  };
})();
