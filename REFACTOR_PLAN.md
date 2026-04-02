# Team Tracker App - 重構計劃

## 🎯 重構目標

1. 將 2062 行的 `team_detail_page.dart` 拆分成可維護的模組
2. 提取共用元件，減少重複程式碼
3. 改善程式碼結構，提升可測試性

---

## 📋 重構步驟

### Phase 1: 拆分 Tab Widgets (優先)

**目標**: 將三個 Tab 拆分成獨立檔案

#### 1.1 建立目錄結構
```
lib/pages/team_detail/
├── team_detail_page.dart
└── tabs/
    ├── players_tab.dart
    ├── matches_tab.dart
    └── training_tab.dart
```

#### 1.2 拆分順序
1. ✅ 先拆分 `players_tab.dart` (最簡單)
2. ✅ 再拆分 `matches_tab.dart`
3. ✅ 最後拆分 `training_tab.dart`

---

### Phase 2: 提取共用元件

**目標**: 建立可重用的 Widget

#### 2.1 共用元件列表
```
lib/widgets/
├── pickers/
│   ├── venue_picker.dart       # 場地選擇器
│   └── date_time_picker.dart   # 日期時間選擇
├── lists/
│   └── attendance_list.dart    # 出席勾選列表
└── common/
    ├── empty_state.dart        # 空狀態顯示
    └── stat_card.dart          # 統計卡片
```

---

### Phase 3: 建立 Service 層

**目標**: 統一數據處理邏輯

#### 3.1 Service 結構
```
lib/services/
├── data/
│   ├── player_service.dart
│   ├── match_service.dart
│   └── training_service.dart
├── sync_service.dart
└── config_service.dart
```

---

## 🚀 開始重構

接下來我會為你示範：
1. 如何拆分 `players_tab.dart`
2. 如何建立 `venue_picker.dart` 共用元件
3. 如何建立 `player_service.dart`

準備好了嗎？
