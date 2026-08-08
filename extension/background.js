// Create context menu item on installation
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "open-with-vlc",
    title: "Open with VLC",
    contexts: ["link", "video", "audio"]
  });
  console.log("Open with VLC context menu registered.");
});

// Listener for context menu clicks
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "open-with-vlc") {
    const targetUrl = info.linkUrl || info.srcUrl;
    if (targetUrl) {
      console.log("Sending URL to VLC Host: " + targetUrl);
      
      // Connect to the native messaging host
      try {
        const port = chrome.runtime.connectNative('com.vlc.open');
        
        port.postMessage({ url: targetUrl });
        
        port.onMessage.addListener((response) => {
          console.log("Received response from Native Host:", response);
        });
        
        port.onDisconnect.addListener(() => {
          if (chrome.runtime.lastError) {
            console.error("Disconnected from Native Host with error:", chrome.runtime.lastError.message);
          } else {
            console.log("Disconnected from Native Host.");
          }
        });
      } catch (err) {
        console.error("Failed to connect to native messaging host:", err);
      }
    } else {
      console.warn("No link or source URL found for target.");
    }
  }
});
