# Security & Privacy Report: UPI Lens

**Plain English Summary:**
UPI Lens is designed with a "Privacy-First" philosophy. All your financial data stays on your phone. The app reads your bank transaction SMS messages to help you track spending, but it never uploads this data to the internet. It uses an AI model that runs entirely offline on your device, meaning your personal spending habits are never shared with Google, Meta, or any other cloud service.

---

### 1. How the app reads your transactions
UPI Lens works by reading only the SMS messages in your device's inbox. 
- It **does not** connect directly to GPay, PhonePe, Paytm, or any other UPI application.
- It has no access to your payment app's internal data, login credentials, or hidden transaction history.
- It only knows what is sent to you in bank SMS notifications.
- **Crucially, the app cannot initiate or authorize payments.**

### 2. What data it actually sees
The app only extracts specific pieces of information needed for tracking:
- **Amount:** The total Rupees spent or received.
- **Merchant/ID:** The name of the shop or the UPI ID of the person.
- **Bank Name:** Which bank sent the SMS.
- **Reference:** The transaction reference number (UTR).
- **Time:** When the transaction happened.

**What it NEVER sees:**
- **UPI PIN:** The app never asks for and cannot read your PIN.
- **Passwords:** Your banking passwords are never accessed.
- **Full Account Numbers:** Banks only send the last 4 digits in SMS; the app only sees those 4 digits.
- **CVV/OTP:** The app specifically ignores OTP (One-Time Password) messages as they come from different sender IDs and are filtered out of the processing flow.

### 3. Where your data lives
- **Local Storage:** All your transaction data is stored in a private database (SQLite) on your phone only.
- **No Cloud Uploads:** None of your financial records are uploaded to any server.
- **On-Device AI:** The Gemma 3 AI model used for summarizing your spending runs 100% offline. Your data is processed locally and is never sent to any AI cloud service for analysis.

### 4. Google Sign-In Scope
UPI Lens uses Google Sign-In only to provide a personalized profile experience (displaying your name and photo).
- The app requests **only basic profile information** (Name, Email, Profile Photo).
- It **does not** request access to your Google Pay history, Gmail, Google Drive, or any other private Google service.

### 5. Permissions Used
- `READ_SMS`: To read existing bank transaction notifications from your inbox.
- `RECEIVE_SMS`: To detect and categorize new transactions in real-time as they arrive.
- `INTERNET`: Required only for the initial download of the AI model and for Google Sign-In authentication.
- `ACCESS_NETWORK_STATE`: To check if you are connected to the internet before attempting a download.

### 6. Security Risks & Recommendations
In the interest of full transparency:
- **Broad SMS Permission:** Android's SMS permission is not "scoped"—it technically allows an app to read all SMS messages. While UPI Lens is programmed to strictly filter only bank messages by sender ID, the operating system permission itself is broad.
- **Device Security:** If your device is "rooted" or compromised by other malicious software, your local transaction database could theoretically be accessed by other rouge apps on your device.
- **Recommendation:** Only install UPI Lens from trusted sources and ensure your device has a secure lock screen.

### 7. What this app CANNOT do
- **CANNOT** make payments or transfer money.
- **CANNOT** read or guess your UPI PIN.
- **CANNOT** access the internal data/bank links of GPay, PhonePe, or Paytm.
- **CANNOT** read your OTPs for login or authorization.
- **CANNOT** access your bank account directly via API or web.
- **CANNOT** transmit your financial data over the internet.

---
*Last updated: March 23, 2026*
