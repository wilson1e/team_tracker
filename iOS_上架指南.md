# Team Tracker iOS 上架 TestFlight 完整指南

## 前置條件
✅ Apple Developer 帳號（已付費 $99/年）
⚠️ Firebase iOS 配置（需要設置）
⚠️ Codemagic 簽名證書（需要設置）

---

## 步驟 1：Firebase iOS 設置

### 1.1 在 Firebase Console 添加 iOS app

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 選擇你的專案（Team Tracker）
3. 點擊「新增應用程式」→ 選擇 iOS
4. 輸入 iOS Bundle ID：`com.basketball.team.tracker`
5. App 暱稱：`Team Tracker`
6. 點擊「註冊應用程式」

### 1.2 下載 GoogleService-Info.plist

1. 在 Firebase 設置頁面下載 `GoogleService-Info.plist`
2. **重要**：將此文件放到專案的 `ios/Runner/` 目錄
3. 確認文件路徑：`ios/Runner/GoogleService-Info.plist`

### 1.3 提交到 Git

```bash
git add ios/Runner/GoogleService-Info.plist
git commit -m "Add iOS Firebase configuration"
git push
```

---

## 步驟 2：App Store Connect 設置

### 2.1 創建 App

1. 前往 [App Store Connect](https://appstoreconnect.apple.com/)
2. 點擊「我的 App」→「+」→「新增 App」
3. 填寫資料：
   - **平台**：iOS
   - **名稱**：Team Tracker
   - **主要語言**：繁體中文
   - **Bundle ID**：選擇 `com.basketball.team.tracker`（如果沒有，需要先在 Apple Developer 創建）
   - **SKU**：`team-tracker-001`（任意唯一識別碼）
4. 點擊「建立」

### 2.2 創建 Bundle ID（如果還沒有）

1. 前往 [Apple Developer](https://developer.apple.com/account/)
2. 點擊「Certificates, IDs & Profiles」
3. 點擊「Identifiers」→「+」
4. 選擇「App IDs」→「Continue」
5. 填寫：
   - **Description**：Team Tracker
   - **Bundle ID**：`com.basketball.team.tracker`（Explicit）
6. 勾選需要的 Capabilities：
   - Push Notifications
   - Sign in with Apple（如果需要）
7. 點擊「Continue」→「Register」

---

## 步驟 3：App Store Connect API Key

### 3.1 創建 API Key

1. 在 App Store Connect，點擊「使用者和存取權限」
2. 點擊「金鑰」標籤
3. 點擊「+」創建新金鑰
4. 填寫：
   - **名稱**：Codemagic CI
   - **存取權限**：App Manager 或 Developer
5. 點擊「產生」
6. **重要**：下載 `.p8` 文件（只能下載一次！）
7. 記錄：
   - **Key ID**（例如：ABC123DEF4）
   - **Issuer ID**（在金鑰頁面頂部）

---

## 步驟 4：Codemagic 簽名設置

Codemagic 提供自動簽名功能，不需要手動創建證書。

### 4.1 在 Codemagic 設置 App Store Connect

1. 登入 [Codemagic](https://codemagic.io/)
2. 選擇你的專案
3. 點擊「Settings」→「iOS code signing」
4. 選擇「Automatic code signing」
5. 點擊「Add key」
6. 填寫：
   - **Key ID**：（步驟 3.1 記錄的）
   - **Issuer ID**：（步驟 3.1 記錄的）
   - **Private Key**：上傳 `.p8` 文件或貼上內容
7. 點擊「Save」

### 4.2 設置環境變數

在 Codemagic 專案設置中：

1. 點擊「Environment variables」
2. 添加以下變數：
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`：你的 Key ID
   - `APP_STORE_CONNECT_ISSUER_ID`：你的 Issuer ID
   - `APP_STORE_CONNECT_PRIVATE_KEY`：貼上 .p8 文件內容（包含 BEGIN/END 行）
3. 勾選「Secure」保護敏感資訊

---

## 步驟 5：更新 codemagic.yaml

配置文件已經準備好，但需要確認：

1. Bundle ID 正確：`com.basketball.team.tracker`
2. 環境變數已設置
3. 自動簽名已啟用

---

## 步驟 6：觸發構建

### 6.1 推送代碼

```bash
git add .
git commit -m "Ready for iOS TestFlight"
git push
```

### 6.2 在 Codemagic 啟動構建

1. 在 Codemagic 選擇 `ios-workflow`
2. 點擊「Start new build」
3. 選擇分支（通常是 `main` 或 `master`）
4. 點擊「Start build」

### 6.3 監控構建過程

構建時間約 15-25 分鐘，包括：
- ✅ 安裝依賴
- ✅ Flutter 構建
- ✅ 自動簽名
- ✅ 上傳到 TestFlight

---

## 步驟 7：TestFlight 測試

### 7.1 構建成功後

1. 前往 App Store Connect
2. 點擊你的 App → TestFlight
3. 等待「處理中」變成「可供測試」（約 5-10 分鐘）

### 7.2 添加測試人員

1. 在 TestFlight 點擊「內部測試」或「外部測試」
2. 點擊「+」添加測試人員
3. 輸入 Email 地址
4. 測試人員會收到邀請郵件

### 7.3 測試人員安裝

1. 在 iPhone 安裝 TestFlight app
2. 點擊邀請郵件中的連結
3. 在 TestFlight 中下載 Team Tracker

---

## 常見問題排查

### 問題 1：構建失敗 - "GoogleService-Info.plist not found"
**解決**：確認文件已放在 `ios/Runner/` 並已提交到 Git

### 問題 2：簽名失敗 - "No valid code signing"
**解決**：檢查 Codemagic 的 App Store Connect API Key 是否正確設置

### 問題 3：上傳失敗 - "Invalid Bundle ID"
**解決**：確認 Bundle ID 在 Apple Developer 和 App Store Connect 中一致

### 問題 4：TestFlight 處理失敗
**解決**：檢查 Info.plist 中的權限描述是否完整

---

## 下一步

構建成功後，你會收到郵件通知。然後：
1. 在 TestFlight 添加測試人員
2. 收集測試反饋
3. 修復問題後重新構建
4. 準備正式上架 App Store

---

## 需要協助？

如果遇到問題，提供以下資訊：
- Codemagic 構建日誌
- 錯誤訊息截圖
- 當前進行到哪個步驟
