# 🏀 Team Tracker App - Source Code Package

## 📦 點樣用：

1. **Unzip呢個folder**
2. **Install Flutter** (如果未有)
   - Download: https://flutter.dev
   - 或者 `choco install flutter`
3. **Open folder in VS Code / Android Studio**
4. **Run:**
```bash
flutter pub get
flutter build apk --debug
```

---

## 📁 Files結構：

```
team_tracker_package/
├── lib/                    # 所有Dart code
│   ├── main.dart
│   ├── login_page.dart
│   ├── teams_list_page.dart
│   ├── team_detail_page.dart
│   ├── team_members_page.dart
│   ├── team_settings_page.dart
│   ├── settings_page.dart
│   ├── matches_page.dart
│   ├── notification_service.dart
│   ├── calendar_service.dart
│   ├── theme_service.dart
│   ├── ad_service.dart
│   ├── constants.dart
│   └── exceptions.dart
├── android/                 # Android config
│   ├── app/google-services.json  # Firebase config
│   └── app/build.gradle.kts
├── assets/                 # Images/Icons
└── pubspec.yaml           # Dependencies
```

---

## 🔧 必整既Setup：

### 1. Firebase Setup
- 去 https://console.firebase.google.com/
- 加入呢個App (Android: com.basketball.team_tracker)
- Download `google-services.json` -> 放入 `android/app/`

### 2. AdMob (Optional)
- 去 https://admob.google.com/
- Create Ad Unit，拎ID
- Replace 去 `lib/ad_service.dart`

### 3. Build
```bash
flutter pub get
flutter build apk --debug    # Android APK
flutter build web            # Web version
```

---

## 🆕 最新Version:

- Android APK: `team_tracker_v58_firebase.apk`
- Backup: `team_tracker_backup_2026-03-28_v2/`

---

## 📱 主要功能：

- ✅ Firebase Auth (Email login)
- ✅ Cloud Firestore (數據sync)
- ✅ 球隊管理
- ✅ 球員管理 (位置、身高、體重)
- ✅ 比賽管理 (日期、時間、場地、聯賽)
- ✅ 訓練管理
- ✅ 加入Calendar
- ✅ Google Ads (Admob)
- ✅ Settings & Theme toggle
- ✅ Team invite code

---

有問題可以問我！😊
