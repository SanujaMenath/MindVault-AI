# 🧠 MindVault AI  
### Personal AI-Powered Digital Organizer  

**MindVault AI** is a smart, secure, and all-in-one productivity app built with **Flutter**.  
It combines task scheduling, note management, AI-powered summarization, and a secure password vault — all protected with biometrics and cloud backup support.  

---

## ✨ Features  

- 📅 **Smart Task Scheduler** – Plan your day with a calendar and set reminders.  
- 📝 **AI Notes** – Write, organize, and let AI summarize long notes into quick points.  
- 🔐 **Vault for Secrets** – Store passwords, confidential notes, and sensitive data safely.  
- 👆 **Biometric Security** – Fingerprint/Face unlock for maximum protection.  
- ☁️ **Cloud Backup & Restore** – Sync with Google Drive / OneDrive.  
- 🔍 **Fast Search & Filters** – Find tasks or notes instantly.  
- 📶 **Offline Mode** – Access tasks and notes without internet.  
- 🔔 **Reminders & Notifications** – Never miss a deadline again.  

---

## 🛠️ Tech Stack  

- **Frontend:** Flutter (Dart)  
- **Backend:** Spring Boot (Java)  
- **Database:** MySQL + SQLite (offline storage)  
- **AI Integration:** OpenAI API (for summarization)  
- **Cloud Storage:** Google Drive / OneDrive APIs  
- **Security:** AES Encryption + Biometrics (Android/iOS SDKs)  

---

## 🚀 Getting Started  

### 1️⃣ Prerequisites  
- [Flutter SDK](https://docs.flutter.dev/get-started/install)  
- Android Studio / VS Code with Flutter plugin  
- A backend server (Spring Boot + MySQL)  
- OpenAI API Key (if using AI features)  

### 2️⃣ Installation  

Clone the repository:  
```bash
git clone https://github.com/sanujamenath/mindvault_ai.git
cd mindvault_ai
```  
Install dependencies: 
```bash
flutter pub get
```  
Run the app:
```bash
flutter run
``` 
---

🔒 App Security

# 1. Local Data Protection

 - Store sensitive data in flutter_secure_storage (not SharedPreferences).

 - Encrypt files if saving locally (ex:- text, images).

 - Protect sensitive screens with local_auth (biometric / PIN).

 [//]: # (Block screenshots/recording with FlutterWindowManager.FLAG_SECURE.)

 
# 2. API Security

 - All API calls use HTTPS (TLS/SSL).

 [//]: # (SSL Pinning enabled (e.g. ssl_pinning_plugin).)

 - No API keys or secrets hardcoded in the app.

 <!-- Use short-lived tokens (JWT / OAuth2) + refresh tokens. -->

 - All authorization is verified on the server (not just the client).

# 3. Authentication & Session

 - Logout clears tokens and secure storage.
 - Backend validates permissions.
 <!-- Session timeout or token expiry is enforced. -->

# 4. Code Security

 - Flutter build uses --obfuscate --split-debug-info.  
 - API keys/configs hidden (Remote Config / server-side).  
 <!-- Android Proguard/R8 enabled. -->
 - iOS builds hardened (Bitcode/Release mode).

# 5. Runtime Security

 <!-- Jailbreak/Root detection (with flutter_jailbreak_detection). -->
 <!-- Handle offline cache carefully (no sensitive logs). -->
 - Errors don’t expose sensitive info (stack traces hidden in production).  

 # 6. Dependencies & Updates 

 - All packages checked with flutter pub outdated.  
 - Remove unused dependencies.  
 - Use only trusted & maintained packages.  

# 7. Testing & Validation

 <!-- Run MobSF / APK Analyzer for static security checks. -->
 <!-- Test API with Burp Suite / Charles Proxy to confirm SSL pinning. -->
 - Do manual penetration testing (try modifying requests, bypassing auth).  
 - Check logs (no sensitive info printed in debugPrint or console).  