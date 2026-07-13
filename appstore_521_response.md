# App Review Response — Guideline 5.2.1

**App:** Buds Connect (formerly GalaxyBudsMac)  
**Submission ID:** aa266298-c95f-4d42-b504-852e540031d9  
**Guideline:** 5.2.1 — Intellectual Property

---

## Response to App Review Team

Dear App Review Team,

Thank you for reviewing *Buds Connect* and for the detailed feedback. We would like to respectfully address the concern raised under Guideline 5.2.1 regarding content or features from Galaxy Buds without the necessary authorization.

**Buds Connect is a fully independent, open-source companion app** licensed under the GNU General Public License v3 (GPLv3). It does not use any SDK, library, binary, asset, trademark logo, or proprietary code owned by Samsung Electronics Co., Ltd. All source code is publicly available for inspection at:

> https://github.com/felipesilvax1/GalaxyBudsMacintosh

### Communication Protocol — Open Standard

The app communicates with Galaxy Buds hardware exclusively via the **Serial Port Profile (SPP)**, which is built on top of the **RFCOMM protocol** — a fully open, standardized Bluetooth transport protocol defined by the **Bluetooth Special Interest Group (Bluetooth SIG)**. This is the same generic Bluetooth channel that countless third-party accessories and companion apps use across all platforms. No Samsung-proprietary API, binary interface, or licensed SDK is involved at any layer of the communication stack.

The protocol messages sent over this channel were documented through independent reverse-engineering of publicly observable Bluetooth traffic — a widely accepted and legally recognized practice in software interoperability research (see EU Software Directive Article 6, and U.S. DMCA §1201(f)).

### No Commercial Exploitation of Samsung's Brand

Buds Connect does not:
- Resell, redistribute, or repackage any Samsung product or service.
- Display Samsung's logo, trademarks, or trade dress within its UI.
- Claim any official affiliation, endorsement, or partnership with Samsung.
- Charge users for access to Samsung hardware features.

A clear disclaimer is displayed within the app and in all public-facing documentation: *"Buds Connect is not affiliated with, endorsed by, or in any way officially connected with Samsung Electronics Co., Ltd."*

### Precedent Within the App Store

Third-party companion apps that interact with proprietary hardware via standard Bluetooth protocols are a well-established category on the App Store. Apps such as **AirBuddy** (which provides enhanced controls for Apple and third-party wireless headphones via standard Bluetooth APIs) have been approved under similar conditions. Buds Connect operates under the same principle: using documented, open transport protocols to provide users with value-added functionality for hardware they already own.

### Summary

| Claim | Our Position |
|---|---|
| Uses Samsung SDK or proprietary code | ❌ No — only open Bluetooth SPP/RFCOMM |
| Uses Samsung assets or trade dress | ❌ No — all UI assets are original |
| Claims official Samsung affiliation | ❌ No — explicit disclaimer included |
| Source code publicly auditable | ✅ Yes — GPLv3 on GitHub |
| Comparable to approved App Store apps | ✅ Yes — e.g., AirBuddy |

We are confident that *Buds Connect* complies with Guideline 5.2.1 and respectfully request that this submission be reconsidered. We are happy to provide any additional technical documentation, code references, or protocol analysis notes if that would assist the review.

Thank you for your time and consideration.

Sincerely,  
The Buds Connect Development Team  
https://github.com/felipesilvax1/GalaxyBudsMacintosh
