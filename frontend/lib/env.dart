import 'package:envied/envied.dart';
part "env.g.dart";

@Envied(path: 'scripts/env/.env')
abstract class Env {
  @EnviedField(varName: 'FIREBASE_BASE_URL', obfuscate: true)
  static String firebaseBaseUrl = _Env.firebaseBaseUrl;
}