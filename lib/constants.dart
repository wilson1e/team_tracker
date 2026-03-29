// App constants
class AppConstants {
  // Jersey colors
  static const List<String> jerseyColors = [
    '紅色', '藍色', '綠色', '黃色', '白色', '黑色', '紫色', '橙色', '粉色', '棕色', '青色', '藍綠色'
  ];

  // Hong Kong venues
  static const List<String> hkVenues = [
    '維多利亞公園',
    '觀塘體育館',
    '大埔體育館',
    '沙田體育館',
    '屯門體育館',
    '荃灣體育館',
    '旺角麥花臣場館',
    '伊利沙伯體育館',
    '灣仔伊利沙伯體育館',
    '將軍澳體育館',
    '銅鑼灣體育館',
    '北葵涌體育館',
  ];

  // Leagues
  static const List<String> leagues = ['HBL', 'SBL', 'TYL'];

  // Home/Away options
  static const List<String> homeAwayOptions = ['主場', '客場'];

  // Time options
  static List<String> get timeOptions => 
    List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
}