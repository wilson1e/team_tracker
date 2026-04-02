# Team Tracker - 使用者體驗優化方案

## 🎨 UX 問題分析

### 問題 1: 載入狀態不明確
**現況**:
- 載入時只有轉圈圈
- 使用者不知道在做什麼
- 沒有進度提示

**改善方案**:
```dart
// 骨架屏 (Skeleton Loading)
Widget buildSkeleton() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[800]!,
    highlightColor: Colors.grey[700]!,
    child: ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: CircleAvatar(),
          title: Container(height: 16, color: Colors.white),
          subtitle: Container(height: 12, color: Colors.white),
        ),
      ),
    ),
  );
}
```

**效果**:
- 使用者知道正在載入
- 感覺更快
- 更專業的體驗

---

### 問題 2: 錯誤訊息不清楚
**現況**:
- 只顯示「發生錯誤」
- 使用者不知道怎麼解決
- 沒有重試按鈕

**改善方案**:
```dart
class ErrorHandler {
  static String getMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '權限不足，請檢查登入狀態';
        case 'unavailable':
          return '網絡連接失敗，請檢查網絡';
        case 'not-found':
          return '找不到數據，請重新整理';
        default:
          return '發生錯誤: ${error.message}';
      }
    }
    return '未知錯誤，請稍後再試';
  }

  static void show(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('錯誤'),
        content: Text(getMessage(error)),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: Text('重試'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('關閉'),
          ),
        ],
      ),
    );
  }
}
```

---

### 問題 3: 沒有離線提示
**現況**:
- 離線時操作會失敗
- 使用者不知道為什麼
- 沒有提示網絡狀態

**改善方案**:
```dart
// 使用 connectivity_plus 套件
class NetworkBanner extends StatelessWidget {
  final bool isOnline;

  const NetworkBanner({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      color: Colors.orange,
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 8),
          Text('離線模式 - 數據將在連線後同步',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
```

