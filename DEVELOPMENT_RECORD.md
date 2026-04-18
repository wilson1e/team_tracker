# Team Tracker App 開發記錄

**App 路徑：** `/Users/wilsonmac/team_tracker`
**GitHub：** `https://github.com/wilson1e/team_tracker.git`
**平台：** Flutter (iOS + Android)
**最後更新：** 2026-04-05

---

## 版本歷史

| 版本 | 日期 | 主要內容 |
|------|------|---------|
| 1.0.0+8 | 2026-04-04 前 | 初始版本，iOS 黑屏問題未修復 |
| 1.0.0+9 | 2026-04-04 | iOS 黑屏修復、Firebase 保護 |
| 1.0.0+10 | 2026-04-05 | App icon 修復、5項功能更新 |
| 1.0.0+11 | 2026-04-05 | 球員出席記錄頁面 |
| 1.0.0+12 | 2026-04-05 | Changelog 更新、icon 備份 |

---

## Build 指令

```bash
cd /Users/wilsonmac/team_tracker

# iOS (IPA → Transporter → TestFlight)
flutter build ipa --release

# Android (APK)
flutter build apk --release

# 重新生成 App Icon
dart run flutter_launcher_icons
```

**輸出位置：**
- IPA: `build/ios/ipa/*.ipa`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## iOS 黑屏修復（重要）

### 根本原因
`Info.plist` 的 `UISceneDelegateClassName` 格式錯誤。

| | 值 |
|-|-|
| ❌ 錯誤 | `SceneDelegate` |
| ✅ 正確 | `$(PRODUCT_MODULE_NAME).SceneDelegate` |

iOS 需要 module name 前綴才能找到 Swift class。沒有前綴 → Scene 不創建 → window 不存在 → Flutter engine 運行但無處 render → 黑屏。

### 三個文件修復組合

**1. `ios/Runner/Info.plist`**
```xml
<key>UISceneDelegateClassName</key>
<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
```

**2. `ios/Runner/AppDelegate.swift`**
```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "main flutter engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**3. `ios/Runner/SceneDelegate.swift`**
```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, ...) {
  guard let windowScene = scene as? UIWindowScene else { return }
  let appDelegate = UIApplication.shared.delegate as! AppDelegate
  let flutterViewController = FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
  let win = UIWindow(windowScene: windowScene)
  win.rootViewController = flutterViewController
  win.makeKeyAndVisible()
  self.window = win
}
```

### 黑屏診斷方法
1. 先加 `theme: ThemeData(scaffoldBackgroundColor: Colors.white)` 臨時測試
2. 白色出現 → 查 ThemeService
3. 仍黑屏 → 查 SceneDelegate / Info.plist
4. `flutter run` 出現 `runApp returned (should not happen)` → SceneDelegate/Info.plist 問題

---

## App Icon 設定

**原始圖片：** `assets/icon_final.png`
**備份位置：** `assets/icon_backup/`（iOS + Android 所有尺寸）

**pubspec.yaml 設定：**
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon_final.png"
  adaptive_icon_background: "#1A1A2E"
  adaptive_icon_foreground: "assets/icon_final.png"
  remove_alpha_ios: true
```

> ⚠️ `remove_alpha_ios: true` 必須設定，否則 App Store 上傳失敗（alpha channel 不允許）

---

## Firebase 初始化保護

`lib/main.dart` 使用 `Completer<bool>` 保護 Firebase 初始化：

```dart
final firebaseReady = Completer<bool>();
// Firebase/ATT/AdMob 各有 timeout 或 try-catch
// login_page.dart 中：await firebaseReady.future
```

**已知注意事項：**
- AdService.initialize() 已有 5s timeout
- ATT request 有 5s timeout
- Firebase import 在 login_page.dart 是安全的（有 firebaseReady 保護）

---

## 功能修改記錄

### v1.0.0+10 — 5項功能

#### 1. 球員數量同步 + 出席點名修復
**問題：** `team_detail_page._players` 與 `PlayersTab._players` 是獨立 list，TabBar 計數永遠為 0。

**修改：**
- `lib/pages/team_detail/tabs/players_tab.dart` — 加 `onPlayersChanged` callback
- `lib/team_detail_page.dart` — PlayersTab 加 `onPlayersChanged: (players) => setState(() => _players = players)`

#### 2. 測試版球隊加入限制
**問題：** 創建限制 1 隊，但加入邀請碼無限制。

**修改：** `lib/teams_list_page.dart` → `_showJoinTeamDialog()` 開頭加：
```dart
if (_teams.isNotEmpty) {
  // 顯示測試版限制 dialog
  return;
}
```

#### 3. 通知時間 Slider
**修改：** `lib/settings_page.dart`
- 移除 DropdownButton（固定4選項）
- 換成 Slider（1-24 小時，存為 `'N小時前'` 格式）
- `notification_service.dart` 已支援 `'N小時前'` 格式，無需改動

#### 4. 比賽比數顯示
**修改：** `lib/team_detail_page.dart`（比賽 tab）
- 比數從 title Row 移到 trailing Column 上方
- 加勝/負/和文字：`'$us - $them 勝/負/和'`
- 顏色：勝=綠、負=紅、和=白

#### 5. 匯出功能測試版限制
已在更早版本實現，按鈕顯示「功能即將開放」dialog，無需再修改。

---

### v1.0.0+11-12 — 球員出席記錄頁面

**新文件：** `lib/pages/player_attendance_page.dart`

**功能：**
- 點擊球員卡片進入獨立出席頁面
- 顯示總出席率（進度條，綠/橙/紅）
- 最近10場比賽出席記錄（日期 + 對手 + ✓/✗）
- 最近10次訓練出席記錄（日期 + 標題 + ✓/✗）

**相關修改：**
- `PlayersTab` 加 `matches` 和 `training` 參數，傳入 `PlayerAttendancePage`
- 球員卡片 `onTap` → push 到出席頁面

---

## 資料結構

### Firestore 路徑
```
users/{uid}/teams/{teamId}/players/data → players[]
users/{uid}/teams/{teamId}/matches/data → matches[]
users/{uid}/teams/{teamId}/training/data → training[]
```

### 出席資料格式
```dart
match['attendance'] = {
  '球員A': true,   // 出席
  '球員B': false,  // 缺席
}
```

### 球員資料格式
```dart
{
  'name': '陳大文',
  'number': 23,
  'height': 180,
  'weight': 75,
  'position': 'PG/SG',
}
```

---

## 主要文件索引

| 文件 | 用途 |
|------|------|
| `lib/main.dart` | App 入口，Firebase/ATT/AdMob 初始化 |
| `lib/teams_list_page.dart` | 球隊列表，創建/加入球隊 |
| `lib/team_detail_page.dart` | 球隊詳情（主要文件，22K+ 行） |
| `lib/pages/team_detail/tabs/players_tab.dart` | 球員管理 Tab |
| `lib/pages/player_attendance_page.dart` | 球員出席記錄頁面（新增） |
| `lib/notification_service.dart` | 通知排程服務 |
| `lib/settings_page.dart` | 設定頁面（通知、主題） |
| `lib/services/changelog_service.dart` | App 內更新日誌 |
| `lib/services/export/export_service.dart` | 匯出 Excel 報表（測試版禁用） |
| `ios/Runner/AppDelegate.swift` | iOS FlutterEngine 預熱 |
| `ios/Runner/SceneDelegate.swift` | iOS Scene/Window 管理 |
| `ios/Runner/Info.plist` | iOS App 設定 |
| `assets/icon_backup/` | App Icon 備份（所有尺寸） |

---

## TestFlight 上傳流程

1. `flutter build ipa --release`
2. 開啟 **Transporter** app
3. 拖入 `build/ios/ipa/*.ipa`
4. 點擊「交付」
5. 等待 App Store Connect 處理（約5-10分鐘）
6. TestFlight → 選擇版本 → 開放測試員

**注意：** IPA 必須用 `--release` 旗標，不可用 `--simulator`（會包含 simulator framework，App Store 拒絕）

---

## 技術架構

- **框架：** Flutter 3.x（Dart SDK ^3.11.1）
- **狀態管理：** Provider（ThemeService）
- **後端：** Firebase（Auth, Firestore, Storage, Analytics, Crashlytics）
- **廣告：** Google Mobile Ads + App Tracking Transparency
- **本地儲存：** SharedPreferences
- **通知：** flutter_local_notifications + timezone
- **UI 主題：** 深色（`#1A1A2E` / `#16213E`），橙色 accent

---

*文檔生成日期：2026-04-05*
