import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'openai_models.g.dart';

/// OpenAI 聊天请求模型
@JsonSerializable(explicitToJson: true)
class ChatCompletionRequest {
  /// 模型ID
  final String model;

  /// 消息列表
  final List<Map<String, dynamic>> messages;

  /// 温度参数 (0-2)
  final double? temperature;

  /// Top P sampling (0-1)
  @JsonKey(name: 'top_p')
  final double? topP;

  /// 生成多少个候选响应
  final int? n;

  /// 是否以流式方式返回响应
  final bool? stream;

  /// 停止生成的标记
  final List<String>? stop;

  /// 最大生成token数
  @JsonKey(name: 'max_tokens')
  final int? maxTokens;

  /// 在生成时应用到每个token的惩罚（避免重复）
  @JsonKey(name: 'presence_penalty')
  final double? presencePenalty;

  /// 在生成时应用到已出现过token的惩罚
  @JsonKey(name: 'frequency_penalty')
  final double? frequencyPenalty;

  /// 响应格式，支持 json_object 等
  @JsonKey(name: 'response_format')
  final Map<String, dynamic>? responseFormat;

  /// 可用的函数列表
  final List<Map<String, dynamic>>? functions;

  /// 可用的工具列表
  final List<Map<String, dynamic>>? tools;

  /// 工具选择策略
  @JsonKey(name: 'tool_choice')
  final String? toolChoice;

  /// 用户标识符
  final String? user;

  /// 额外参数，用于支持不同平台特殊参数
  @JsonKey(name: 'extra_params')
  final Map<String, dynamic>? extraParams;

  /// TODO 可能还有很多不同平台自定义的参数，注意统一处理

  ChatCompletionRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.topP,
    this.n,
    this.stream,
    this.stop,
    this.maxTokens,
    this.presencePenalty,
    this.frequencyPenalty,
    this.responseFormat,
    this.functions,
    this.tools,
    this.toolChoice,
    this.user,
    this.extraParams,
  });

  // 从字符串转
  factory ChatCompletionRequest.fromRawJson(String str) =>
      ChatCompletionRequest.fromJson(json.decode(str));
  // 转为字符串
  String toRawJson() => json.encode(toJson());

  factory ChatCompletionRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatCompletionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChatCompletionRequestToJson(this);

  /// 转换为API请求格式
  /// TODO: 不同平台支持的参数可能不一样，这里可能需要适配，或者只让几个关键参数生效
  Map<String, dynamic> toRequestMap() {
    final Map<String, dynamic> requestMap = toJson();

    // 移除null值和extra_params
    requestMap.removeWhere(
      (key, value) => value == null || key == 'extra_params',
    );

    // 添加extra_params中的参数（如果有）
    if (extraParams != null) {
      requestMap.addAll(extraParams!);
    }

    return requestMap;
  }
}

/// OpenAI 聊天响应中的选择项
@JsonSerializable(explicitToJson: true)
class ChatCompletionChoice {
  /// 选择的索引
  final int? index;

  /// 选择结束的原因
  @JsonKey(name: 'finish_reason')
  final String? finishReason;

  /// 消息内容(非流式响应)
  final Map<String, dynamic>? message;

  /// Delta内容（流式响应）
  final Map<String, dynamic>? delta;

  ChatCompletionChoice({
    this.index,
    this.finishReason,
    this.message,
    this.delta,
  });

  factory ChatCompletionChoice.fromJson(Map<String, dynamic> json) =>
      _$ChatCompletionChoiceFromJson(json);
  Map<String, dynamic> toJson() => _$ChatCompletionChoiceToJson(this);
}

/// OpenAI 使用统计信息
@JsonSerializable(explicitToJson: true)
class UsageInfo {
  /// 提示token数
  @JsonKey(name: 'prompt_tokens')
  final int? promptTokens;

  /// 完成token数
  @JsonKey(name: 'completion_tokens')
  final int? completionTokens;

  /// 总token数
  @JsonKey(name: 'total_tokens')
  final int? totalTokens;

  /// TODO 还有深度思考token数等很多参数

  UsageInfo({this.promptTokens, this.completionTokens, this.totalTokens});

  factory UsageInfo.fromJson(Map<String, dynamic> json) =>
      _$UsageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UsageInfoToJson(this);
}

/// OpenAI 聊天完成响应
/// 流式和非流式结构是类似的，只不过一个是取choices的message.content，一个是取choices的delta.content
@JsonSerializable(explicitToJson: true)
class ChatCompletionResponse {
  /// 响应ID
  final String? id;

  /// 响应选择列表
  final List<ChatCompletionChoice>? choices;

  /// 创建时间戳
  final int? created;

  /// 使用的模型
  final String? model;

  /// 对象类型
  final String? object;

  /// 使用统计
  final UsageInfo? usage;

  ChatCompletionResponse({
    this.id,
    this.object,
    this.created,
    this.model,
    this.choices,
    this.usage,
  });

  factory ChatCompletionResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatCompletionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ChatCompletionResponseToJson(this);

  /// 获取第一个响应的内容
  String? getFirstContent() {
    // 没有响应内容直接返回空
    if (choices == null || choices!.isEmpty) return null;

    // 非流式时，直接取chices第一个的message.content即可
    final message = choices!.first.message;
    if (message != null) {
      return message['content'] as String?;
    }

    // 流式时，直接取chices第一个的delta.content即可
    final delta = choices!.first.delta;
    if (delta != null) {
      // 首先检查常规content
      // content可能是null、String或Map<String, dynamic>，需要处理各种情况
      final dynamic contentValue = delta['content'];
      String? content;

      if (contentValue is String) {
        content = contentValue;
      } else if (contentValue is Map) {
        // 如果content是一个Map，尝试提取text字段
        content = contentValue['text'] as String?;
      } else if (contentValue == null) {
        // content为null，表示这是一个思考过程块，没有实际内容
        content = null;
      }

      return content;
    }

    return null;
  }

  /// 获取推理内容（如果有）注意，虽然部分平台模型思考模式下仅支持流式输出，但也避免同步时也有
  String? getReasoningContent() {
    // 没有响应内容直接返回空
    if (choices == null || choices!.isEmpty) return null;

    String? getThinkText(dynamic item) {
      // 直接检查 reasoning_content 相关字段
      final dynamic reasoningValue =
          item['reasoning_content'] ?? item['reasoning'];
      if (reasoningValue is String) {
        return reasoningValue;
      }

      // 检查content中是否有<think>标签包裹的内容
      final dynamic contentValue = item['content'];
      String? content;

      if (contentValue is String) {
        content = contentValue;
      } else if (contentValue is Map && contentValue['text'] != null) {
        content = contentValue['text'] as String;
      }

      if (content != null && content.contains('<think>')) {
        // 提取<think>标签中的内容
        final RegExp thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
        final match = thinkRegex.firstMatch(content);
        if (match != null && match.groupCount >= 1) {
          return match.group(1);
        }
      }
      return null;
    }

    final message = choices!.first.message;
    final delta = choices!.first.delta;

    if (message != null) {
      return getThinkText(message);
    }

    if (delta != null) {
      return getThinkText(delta);
    }

    return null;
  }
}

/// 模型适配器接口，用于将不同平台的响应转换为统一格式
abstract class ModelResponseAdapter {
  /// 将平台响应转换为标准ChatCompletionResponse
  ChatCompletionResponse adaptResponse(Map<String, dynamic> rawResponse);

  /// 将标准请求转换为平台特定请求
  Map<String, dynamic> adaptRequest(ChatCompletionRequest request);
}

/// OpenAI兼容平台的适配器
class OpenAICompatibleAdapter implements ModelResponseAdapter {
  @override
  ChatCompletionResponse adaptResponse(Map<String, dynamic> rawResponse) {
    // OpenAI格式已兼容，直接转换
    return ChatCompletionResponse.fromJson(rawResponse);
  }

  @override
  Map<String, dynamic> adaptRequest(ChatCompletionRequest request) {
    // 直接返回请求数据
    return request.toRequestMap();
  }
}
