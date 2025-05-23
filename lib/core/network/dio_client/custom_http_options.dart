// 超时时间配置
class HttpOptions {
  // 请求地址，这个应该在使用时从平台规格中获取
  static const String baseUrl = '';

  // 普通请求超时时间(60秒连接，5分钟接收，60秒发送)
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 5 * 60);
  static const Duration sendTimeout = Duration(seconds: 60);

  // 自定义content-type
  static const String contentType = "application/json;charset=utf-8";

  // 大模型流式请求超时时间(60秒连接，10分钟接收，60秒发送)
  static const Duration streamConnectTimeout = Duration(seconds: 60);
  static const Duration streamReceiveTimeout = Duration(seconds: 600);
  static const Duration streamSendTimeout = Duration(seconds: 60);

  // 流式请求content-type
  static const String streamContentType = "application/json;charset=utf-8";
}
