import '../env.dart';

class ApiConfig {
  // 環境変数からベースURLを取得
  static String get baseUrl => Env.firebaseBaseUrl;

  // API エンドポイント
  static String get searchByCategoryEndpoint => '$baseUrl/searchByCategory';
  static String get searchKeywordsEndpoint => '$baseUrl/searchFacilities';
}
