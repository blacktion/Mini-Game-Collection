import 'dart:io';
import 'package:yaml/yaml.dart';

String get serverUrlConfig {
  try {
    // 读取根目录的 config.yaml
    final file = File('../config.yaml');
    if (file.existsSync()) {
      final contents = file.readAsStringSync();
      final yaml = loadYaml(contents);
      return yaml['server_url'] ?? 'http://localhost:5000';
    }
  } catch (e) {
    // 如果读取失败，使用默认值
  }
  return 'http://localhost:5000';
}
