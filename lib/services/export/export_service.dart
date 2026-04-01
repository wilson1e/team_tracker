import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

/// 匯出報表服務
class ExportService {
  /// 匯出球員出席率報表為 Excel
  static Future<String> exportAttendanceReport({
    required String teamName,
    required List<Map<String, dynamic>> players,
    required List<Map<String, dynamic>> matches,
    required List<Map<String, dynamic>> training,
  }) async {
    try {
      // 建立 Excel
      var excel = Excel.createExcel();
      Sheet sheet = excel['出席率報表'];

    // 設定標題
    sheet.appendRow([
      TextCellValue('球隊名稱：$teamName'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // 表頭
    sheet.appendRow([
      TextCellValue('球員姓名'),
      TextCellValue('號碼'),
      TextCellValue('位置'),
      TextCellValue('比賽出席'),
      TextCellValue('比賽總數'),
      TextCellValue('比賽出席率'),
      TextCellValue('訓練出席'),
      TextCellValue('訓練總數'),
      TextCellValue('訓練出席率'),
      TextCellValue('總出席率'),
    ]);

    // 計算每個球員的出席率
    for (var player in players) {
      final name = player['name'] as String;
      final stats = _calculateAttendance(name, matches, training);

      sheet.appendRow([
        TextCellValue(name),
        IntCellValue(player['number'] as int),
        TextCellValue(player['position'] as String),
        IntCellValue(stats['matchAttended']),
        IntCellValue(stats['matchTotal']),
        TextCellValue('${stats['matchRate'].toStringAsFixed(1)}%'),
        IntCellValue(stats['trainingAttended']),
        IntCellValue(stats['trainingTotal']),
        TextCellValue('${stats['trainingRate'].toStringAsFixed(1)}%'),
        TextCellValue('${stats['overallRate'].toStringAsFixed(1)}%'),
      ]);
    }

      // 儲存檔案
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${teamName}_出席率報表.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // 返回檔案路徑供後續使用
      return filePath;
    } catch (e) {
      print('匯出報表錯誤: $e');
      rethrow;
    }
  }

  /// 分享已匯出的報表
  static Future<void> shareReport(String filePath, String teamName) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: '$teamName 出席率報表',
    );
  }

  /// 計算球員出席統計
  static Map<String, dynamic> _calculateAttendance(
    String playerName,
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> training,
  ) {
    int matchTotal = 0, matchAttended = 0;
    int trainingTotal = 0, trainingAttended = 0;

    // 計算比賽出席
    for (var match in matches) {
      final attendance = match['attendance'] as Map?;
      if (attendance != null && attendance.containsKey(playerName)) {
        matchTotal++;
        if (attendance[playerName] == true) matchAttended++;
      }
    }

    // 計算訓練出席
    for (var t in training) {
      final attendance = t['attendance'] as Map?;
      if (attendance != null && attendance.containsKey(playerName)) {
        trainingTotal++;
        if (attendance[playerName] == true) trainingAttended++;
      }
    }

    return {
      'matchTotal': matchTotal,
      'matchAttended': matchAttended,
      'matchRate': matchTotal > 0 ? (matchAttended / matchTotal * 100) : 0.0,
      'trainingTotal': trainingTotal,
      'trainingAttended': trainingAttended,
      'trainingRate': trainingTotal > 0 ? (trainingAttended / trainingTotal * 100) : 0.0,
      'overallRate': (matchTotal + trainingTotal) > 0
          ? ((matchAttended + trainingAttended) / (matchTotal + trainingTotal) * 100)
          : 0.0,
    };
  }
}
