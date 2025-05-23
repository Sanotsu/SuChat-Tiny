import '../../models/platform_spec.dart';
import '../storage/secure_storage.dart';

/// API辅助类，用于构建请求头等操作
class ApiHelper {
  /// 根据平台规格构建请求头
  ///
  /// 参数：
  /// - [platform]: 平台规格
  /// - [apiKey]: API密钥(可选，如果不提供会从安全存储中获取)
  /// - [orgId]: 组织ID(可选，如果不提供会从安全存储中获取)
  ///
  /// 返回包含必要请求头的Map
  static Future<Map<String, dynamic>> buildHeaders(
    PlatformSpec platform, {
    String? apiKey,
    String? orgId,
  }) async {
    final SecureStorageHelper secureStorage = SecureStorageHelper();

    // 构建基本请求头
    Map<String, dynamic> headers = {};

    // 获取API密钥（如果未提供则从安全存储中获取）
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = await secureStorage.getApiKey(platform.id);
    }

    // 获取组织ID（如果未提供则从安全存储中获取）
    if (orgId == null || orgId.isEmpty) {
      orgId = await secureStorage.getOrgId(platform.id);
    }

    // 设置API密钥
    if (apiKey != null && apiKey.isNotEmpty && platform.apiKeyHeader != null) {
      // OpenAI要求添加Bearer前缀(暂时都这样处理密钥)
      if (platform.type == PlatformType.openAI || platform.isOpenAICompatible) {
        headers[platform.apiKeyHeader!] = 'Bearer $apiKey';
      } else {
        // headers[platform.apiKeyHeader!] = apiKey;
        headers[platform.apiKeyHeader!] = 'Bearer $apiKey';
      }
    }
    if (orgId != null && orgId.isNotEmpty && platform.orgIdHeader != null) {
      headers[platform.orgIdHeader!] = orgId;
    }

    // 添加额外请求头
    if (platform.extraHeaders != null) {
      headers.addAll(platform.extraHeaders!);
    }

    return headers;
  }

  /// 构建完整的API路径
  ///
  /// 参数：
  /// - [platform]: 平台规格
  /// - [path]: API路径
  ///
  /// 返回完整的API路径
  static String buildFullPath(PlatformSpec platform, String path) {
    String fullPath = path;

    // 如果path已经包含完整URL，直接返回
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 确保baseUrl不以/结尾
    String baseUrl = platform.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // 确保path以/开头
    if (!path.startsWith('/')) {
      fullPath = '/$path';
    }

    return baseUrl + fullPath;
  }
}
