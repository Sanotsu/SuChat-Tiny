import 'dart:convert';

/// 流式响应处理类
class StreamResponseHandler {
  /// 处理流式响应数据，支持SSE(Server-Sent Events)格式
  ///
  /// 参数：
  /// - [chunk]: 收到的数据块，可能是List\<int>、String或其他类型
  /// - [callback]: 处理解析后数据的回调函数
  static void handleStreamChunk(dynamic chunk, Function(dynamic) callback) {
    try {
      // 如果数据是字节形式，转换为字符串
      if (chunk is List<int>) {
        final chunkStr = utf8.decode(chunk);

        // 分割数据，处理多行情况
        final lines = chunkStr.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          // 处理SSE格式数据
          if (line.startsWith('data: ')) {
            line = line.substring(6);

            if (line == '[DONE]') {
              // 流结束标志

              callback({'done': true});
            } else {
              try {
                // 解析JSON数据
                final json = jsonDecode(line);

                callback(json);
              } catch (e) {
                // JSON解析失败，返回原始文本;
                callback({'text': line});
              }
            }
          } else {
            // 非SSE数据行;
            callback({'text': line});
          }
        }
      } else if (chunk is String) {
        // 接收到字符串;
        callback({'text': chunk});
      } else {
        // 接收到其他类型数据
        callback(chunk);
      }
    } catch (e) {
      throw Exception('处理流块失败: $e');
    }
  }
}
