import '../../config/env/app_env.dart';

/// Turns what a person types ("192.168.1.10:8080", "http://salon-pc:8080/")
/// into the API base URL ("http://192.168.1.10:8080/api/v1").
/// Returns null when the input cannot be a server address.
/// The reverse, for showing to people: "http://192.168.1.10:8080/api/v1" →
/// "192.168.1.10:8080". Returns null when no server is set.
String? displayServerAddress(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || uri.host.isEmpty) return null;
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

String? normalizeServerAddress(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;

  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (!path.endsWith(AppEnv.apiPath)) path = '$path${AppEnv.apiPath}';
  return uri.replace(path: path, query: null, fragment: null).toString().replaceAll(RegExp(r'[?#]$'), '');
}
