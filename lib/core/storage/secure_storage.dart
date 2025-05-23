import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储键名常量
class SecureStorageKeys {
  static const String prefixApiKey = 'api_key_';
  static const String prefixOrgId = 'org_id_';
}

/// 安全存储工具类
class SecureStorageHelper {
  static final SecureStorageHelper _instance = SecureStorageHelper._internal();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // 单例模式
  factory SecureStorageHelper() => _instance;
  SecureStorageHelper._internal();

  /// 保存API密钥
  Future<void> saveApiKey(String platformId, String apiKey) async {
    await _secureStorage.write(
      key: '${SecureStorageKeys.prefixApiKey}$platformId',
      value: apiKey,
    );
  }

  /// 获取API密钥
  Future<String?> getApiKey(String platformId) async {
    return await _secureStorage.read(
      key: '${SecureStorageKeys.prefixApiKey}$platformId',
    );
  }

  /// 删除API密钥
  Future<void> deleteApiKey(String platformId) async {
    await _secureStorage.delete(
      key: '${SecureStorageKeys.prefixApiKey}$platformId',
    );
  }

  /// 保存组织ID
  Future<void> saveOrgId(String platformId, String orgId) async {
    await _secureStorage.write(
      key: '${SecureStorageKeys.prefixOrgId}$platformId',
      value: orgId,
    );
  }

  /// 获取组织ID
  Future<String?> getOrgId(String platformId) async {
    return await _secureStorage.read(
      key: '${SecureStorageKeys.prefixOrgId}$platformId',
    );
  }

  /// 删除组织ID
  Future<void> deleteOrgId(String platformId) async {
    await _secureStorage.delete(
      key: '${SecureStorageKeys.prefixOrgId}$platformId',
    );
  }

  /// 检查是否有API密钥
  Future<bool> hasApiKey(String platformId) async {
    final apiKey = await getApiKey(platformId);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// 清除所有存储的密钥
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  /// 保存通用安全数据
  Future<void> saveSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// 获取通用安全数据
  Future<String?> getSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// 删除通用安全数据
  Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }
} 