import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

/// 統一錯誤處理工具
class ErrorHandler {
  /// 獲取友善的錯誤訊息
  static String getMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '權限不足，請檢查登入狀態';
        case 'unavailable':
          return '網絡連接失敗，請檢查網絡';
        case 'not-found':
          return '找不到數據，請重新整理';
        case 'already-exists':
          return '數據已存在';
        case 'unauthenticated':
          return '請先登入';
        default:
          return '發生錯誤: ${error.message ?? "未知錯誤"}';
      }
    }
    return error.toString();
  }

  /// 顯示錯誤對話框（帶重試按鈕）
  static void showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('錯誤', style: TextStyle(color: Colors.white)),
        content: Text(
          getMessage(error),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              child: const Text('重試', style: TextStyle(color: Colors.orange)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  /// 顯示 SnackBar
  static void showSnackBar(
    BuildContext context,
    dynamic error,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getMessage(error)),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: '關閉',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
