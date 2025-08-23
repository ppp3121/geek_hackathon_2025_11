class MapTiles {
  static const String positron =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const String voyager =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  // 使用するタイルを選択（positronまたはvoyager）
  static const String current = voyager;

  // subdomainsリスト
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];
}
