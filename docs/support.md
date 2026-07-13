# Buds Connect — Support

Welcome to the Buds Connect support page. Buds Connect is an unofficial, open-source macOS companion app for Samsung Galaxy Buds devices. This page covers common setup steps, troubleshooting guidance, and frequently asked questions.

---

## Getting Started

### Requirements
- macOS 12 (Monterey) or later
- A supported Samsung Galaxy Buds device (Galaxy Buds, Buds+, Buds Live, Buds Pro, Buds2, Buds2 Pro, Buds FE)
- Bluetooth enabled on your Mac

### First-Time Setup
1. **Install Buds Connect** from the Mac App Store.
2. **Pair your Galaxy Buds** with your Mac using System Settings → Bluetooth. Make sure they appear as connected.
3. **Launch Buds Connect.** The app will scan for paired Buds devices automatically.
4. **Grant Bluetooth permission** when macOS prompts you — this is required for the app to communicate with your earbuds.
5. Your device should appear in the sidebar within a few seconds. Battery levels and settings will populate automatically.

---

## Troubleshooting

### 1. My Galaxy Buds are not detected by the app
- Ensure your Buds are **connected** (not just paired) via macOS Bluetooth settings.
- Try placing the Buds back in the case, then removing them again to re-trigger the connection.
- Quit and relaunch Buds Connect.
- Go to **System Settings → Privacy & Security → Bluetooth** and confirm that Buds Connect is listed and allowed.
- If using a Buds2 Pro or newer model, make sure the earbuds are not simultaneously connected to another device (phone, tablet).

### 2. The app shows "Connection Failed" or a persistent loading spinner
- Disconnect and reconnect your Buds in System Settings → Bluetooth.
- Check that no other app is holding an exclusive RFCOMM connection to the device (e.g., the Galaxy Wearable app on a paired phone nearby).
- Restart Bluetooth on your Mac: hold **Option** and click the Bluetooth menu bar icon → Turn Bluetooth Off, then back On.
- Restart your Mac and try again.

### 3. Battery levels are not updating
- Battery information is refreshed when a new Bluetooth SPP session is established. Reconnecting the Buds (case in/out) usually triggers a refresh.
- If the issue persists, quit the app, wait 10 seconds, and relaunch.

### 4. Equalizer or touch controls settings are not being saved
- Settings are sent to the Buds in real time over the Bluetooth connection. If the Buds lose connection mid-change, the setting may not be applied.
- Reconnect your Buds and try applying the setting again.
- Some settings may revert if the official Galaxy Wearable Android app is also connected to the same Buds at the same time. Disconnect from the Android app first.

### 5. The app crashes on launch or shows a blank window
- Make sure you are running macOS 12 or later (`Apple menu → About This Mac`).
- Try deleting the app's preferences: open **Terminal** and run:
  ```
  defaults delete tech.miguellabs.GalaxyBudsMac
  ```
  Then relaunch the app.
- If the crash persists, please [open a bug report on GitHub](https://github.com/felipesilvax1/GalaxyBudsMacintosh/issues/new) with the crash log from **Console.app**.

### 6. ANC (Active Noise Cancellation) toggle is grayed out
- ANC is only available on supported models: Buds Pro, Buds2 Pro, Buds Live, Buds2. It is not available on the original Buds or Buds+.
- Ensure your Buds firmware is up to date (update via the Galaxy Wearable app on Android).

### 7. macOS Ventura / Sonoma — App not showing in Bluetooth privacy settings
- On some versions of macOS, the app may need to be launched once with Bluetooth already enabled for the permission dialog to appear.
- Navigate to **System Settings → Privacy & Security → Bluetooth**, scroll down and look for Buds Connect. If it's not there, relaunch the app with Bluetooth on.

---

## FAQ

**Q: Is Buds Connect an official Samsung app?**  
A: No. Buds Connect is an independent, community-developed open-source project. It is not affiliated with, endorsed by, or in any way officially connected with Samsung Electronics Co., Ltd.

**Q: Is it safe to use? Will it damage my earbuds?**  
A: Buds Connect only reads status information and sends standard configuration commands over the same Bluetooth channel used by the official Galaxy Wearable app. It does not modify firmware or low-level device parameters (unless you explicitly use diagnostic tools). That said, the software is provided "as is" — use at your own risk.

**Q: Does Buds Connect work on Apple Silicon (M1/M2/M3/M4) Macs?**  
A: Yes. Buds Connect is a native Universal Binary that runs natively on both Apple Silicon and Intel Macs.

**Q: Why does the app need Bluetooth permission?**  
A: Buds Connect communicates with your Galaxy Buds over Bluetooth using the Serial Port Profile (SPP/RFCOMM). macOS requires explicit user permission for apps to access Bluetooth connections to paired devices. No data is sent to the internet.

**Q: Will Buds Connect interfere with my Galaxy Wearable app on Android?**  
A: Galaxy Buds can only maintain one active SPP/RFCOMM session at a time. If your phone is actively connected, Buds Connect may not be able to establish its own session. Disconnecting from the phone (or moving the phone out of range) allows Buds Connect to connect.

**Q: Which Galaxy Buds models are supported?**  
A: Buds Connect currently supports: Galaxy Buds (2019), Galaxy Buds+, Galaxy Buds Live, Galaxy Buds Pro, Galaxy Buds2, Galaxy Buds2 Pro, and Galaxy Buds FE. Support for newer models is added as the protocol is documented.

**Q: Can I contribute to or fork this project?**  
A: Absolutely. Buds Connect is open-source under the GPLv3 license. Contributions, bug reports, and pull requests are welcome on GitHub.

**Q: Where do I find the privacy policy?**  
A: Buds Connect does not collect, store, or transmit any personal data or usage analytics. All communication is local between your Mac and your earbuds via Bluetooth.

---

## Contact & Bug Reports

If your issue is not resolved by the steps above, please open a ticket on GitHub:

🐛 **[Open an Issue on GitHub](https://github.com/felipesilvax1/GalaxyBudsMacintosh/issues)**

When reporting a bug, please include:
- Your macOS version
- Your Galaxy Buds model
- A description of what you expected vs. what happened
- Any relevant logs from **Console.app** (filter by "BudsConnect")

---

*Buds Connect is not affiliated with Samsung Electronics Co., Ltd. All trademarks are the property of their respective owners.*
