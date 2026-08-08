document.addEventListener('DOMContentLoaded', () => {
  const badge = document.getElementById('host-status-badge');
  const statusBox = document.getElementById('status-box');
  const statusIcon = document.getElementById('status-icon');
  const statusTitle = document.getElementById('status-title');
  const statusDesc = document.getElementById('status-desc');
  const btnRecheck = document.getElementById('btn-recheck');

  function checkNativeHost() {
    badge.className = 'badge';
    badge.textContent = 'Checking...';
    statusIcon.textContent = '🔄';
    statusTitle.textContent = 'Testing Native Host...';
    statusDesc.textContent = 'Attempting connection to Python host.';
    statusBox.className = 'status-box';

    let hasResponded = false;

    try {
      const port = chrome.runtime.connectNative('com.vlc.open');

      port.onMessage.addListener((msg) => {
        hasResponded = true;
        badge.className = 'badge success';
        badge.textContent = 'Connected';
        statusIcon.textContent = '✅';
        statusTitle.textContent = 'Native Host Connected';
        statusDesc.textContent = 'Backend is registered and active on this PC.';
        statusBox.className = 'status-box connected';
        try { port.disconnect(); } catch (e) {}
      });

      port.onDisconnect.addListener(() => {
        if (!hasResponded) {
          const errMessage = chrome.runtime.lastError ? chrome.runtime.lastError.message : 'Native messaging host disconnected.';
          badge.className = 'badge error';
          badge.textContent = 'Not Found';
          statusIcon.textContent = '⚠️';
          statusTitle.textContent = 'Native Host Not Found';
          statusDesc.textContent = 'Please run setup.bat or manually register the native host in registry.';
          statusBox.className = 'status-box disconnected';
        }
      });

      port.postMessage({ ping: true });

      setTimeout(() => {
        if (!hasResponded) {
          badge.className = 'badge error';
          badge.textContent = 'Not Found';
          statusIcon.textContent = '⚠️';
          statusTitle.textContent = 'Native Host Not Found';
          statusDesc.textContent = 'No response from Native Host. Please check host path and setup.';
          statusBox.className = 'status-box disconnected';
          try { port.disconnect(); } catch (e) {}
        }
      }, 1000);

    } catch (err) {
      badge.className = 'badge error';
      badge.textContent = 'Error';
      statusIcon.textContent = '❌';
      statusTitle.textContent = 'Connection Error';
      statusDesc.textContent = err.message || 'Failed to initialize native port.';
      statusBox.className = 'status-box disconnected';
    }
  }

  btnRecheck.addEventListener('click', checkNativeHost);
  checkNativeHost();
});
