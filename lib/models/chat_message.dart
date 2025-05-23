import 'dart:convert';
import 'dart:io';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/tools.dart';

part 'chat_message.g.dart';

/// 消息角色枚举
enum MessageRole {
  user, // 用户消息
  assistant, // 助手（AI）消息
  system, // 系统消息（通常用于设置上下文）
  function, // 函数调用消息
}

/// 消息内容类型枚举
enum ContentType {
  text, // 纯文本内容
  image, // 图片内容
  audio, // 音频内容
  video, // 视频内容
  file, // 文件内容
  function, // 函数调用
  multimodal, // 多模态内容
}

/// 内容项
@JsonSerializable(explicitToJson: true)
class ContentItem {
  /// 内容类型
  final ContentType type;

  /// 文本内容 (如果类型是text)
  final String? text;

  /// 媒体URL (如果类型是image, audio, video)
  final String? mediaUrl;

  /// 内容的MIME类型
  final String? mimeType;

  /// 文件路径 (如果是本地文件)
  final String? filePath;

  /// 函数调用名称 (如果类型是function)
  final String? functionName;

  /// 函数调用参数 (如果类型是function)
  final Map<String, dynamic>? functionArgs;

  /// 额外属性
  final Map<String, dynamic>? extraAttributes;

  ContentItem({
    required this.type,
    this.text,
    this.mediaUrl,
    this.mimeType,
    this.filePath,
    this.functionName,
    this.functionArgs,
    this.extraAttributes,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) =>
      _$ContentItemFromJson(json);
  Map<String, dynamic> toJson() => _$ContentItemToJson(this);

  /// 创建文本内容项
  factory ContentItem.text(String text) {
    return ContentItem(type: ContentType.text, text: text);
  }

  /// 创建图片内容项
  factory ContentItem.image(
    String mediaUrl, {
    String? mimeType,
    String? filePath,
  }) {
    return ContentItem(
      type: ContentType.image,
      mediaUrl: mediaUrl,
      mimeType: mimeType ?? 'image/jpeg',
      filePath: filePath,
    );
  }

  /// 创建函数调用内容项
  factory ContentItem.function(
    String functionName,
    Map<String, dynamic> functionArgs,
  ) {
    return ContentItem(
      type: ContentType.function,
      functionName: functionName,
      functionArgs: functionArgs,
    );
  }
}

/// 聊天消息类
@JsonSerializable(explicitToJson: true)
class ChatMessage {
  /// 消息唯一ID
  final String id;

  /// 消息角色
  final MessageRole role;

  /// 消息内容项列表
  final List<ContentItem> content;

  /// 消息创建时间
  final DateTime createdAt;

  /// 消息所属的对话ID
  final String conversationId;

  /// 函数调用 (OpenAI格式)
  final Map<String, dynamic>? functionCall;

  /// 工具调用列表 (OpenAI格式)
  final List<Map<String, dynamic>>? toolCalls;

  /// 名称 (如果角色是function，表示函数名称)
  final String? name;

  /// 是否是最终消息(流式响应的最后一条)
  final bool isFinal;

  /// 额外属性
  final Map<String, dynamic>? extraAttributes;

  /// 元数据，用于存储非业务核心但有用的信息（如思考过程、调试信息等）
  Map<String, dynamic>? metadata;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    required this.conversationId,
    DateTime? createdAt,
    this.functionCall,
    this.toolCalls,
    this.name,
    this.isFinal = true,
    this.extraAttributes,
    this.metadata,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // 从字符串转
  factory ChatMessage.fromRawJson(String str) =>
      ChatMessage.fromJson(json.decode(str));
  // 转为字符串
  String toRawJson() => json.encode(toJson());

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  // 将消息对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'content': json.encode(content.map((item) => item.toJson()).toList()),
      'created_at': createdAt.millisecondsSinceEpoch,
      'conversation_id': conversationId,
      'function_call': functionCall != null ? json.encode(functionCall!) : null,
      'tool_calls': toolCalls != null ? json.encode(toolCalls!) : null,
      'name': name,
      'is_final': isFinal ? 1 : 0,
      'extra_attributes':
          extraAttributes != null ? json.encode(extraAttributes!) : null,
      'metadata': metadata != null ? json.encode(metadata!) : null,
    };
  }

  // 将Map转换为消息对象
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final contentData = json.decode(map['content']) as List;
    final contentItems =
        contentData
            .map((item) => ContentItem.fromJson(item as Map<String, dynamic>))
            .toList();

    return ChatMessage(
      id: map['id'],
      role: MessageRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => MessageRole.user,
      ),
      content: contentItems,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      conversationId: map['conversation_id'],
      functionCall:
          map['function_call'] != null
              ? json.decode(map['function_call'])
              : null,
      toolCalls:
          map['tool_calls'] != null
              ? List<Map<String, dynamic>>.from(json.decode(map['tool_calls']))
              : null,
      name: map['name'],
      isFinal: map['is_final'] == 1,
      extraAttributes:
          map['extra_attributes'] != null
              ? json.decode(map['extra_attributes'])
              : null,
      metadata: map['metadata'] != null ? json.decode(map['metadata']) : null,
    );
  }

  /// 创建用户文本消息
  factory ChatMessage.userText({
    required String text,
    required String conversationId,
    String? id,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.user,
      content: [ContentItem.text(text)],
      conversationId: conversationId,
      createdAt: createdAt,
      metadata: metadata,
    );
  }

  /// 创建助手文本消息
  factory ChatMessage.assistantText({
    required String text,
    required String conversationId,
    String? id,
    DateTime? createdAt,
    bool isFinal = true,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.assistant,
      content: [ContentItem.text(text)],
      conversationId: conversationId,
      createdAt: createdAt,
      isFinal: isFinal,
      metadata: metadata,
    );
  }

  /// 创建系统消息
  factory ChatMessage.system({
    required String text,
    required String conversationId,
    String? id,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.system,
      content: [ContentItem.text(text)],
      conversationId: conversationId,
      createdAt: createdAt,
      metadata: metadata,
    );
  }

  /// 检查消息是否包含特定类型的内容
  bool hasContentType(ContentType type) {
    return content.any((item) => item.type == type);
  }

  /// 获取所有文本内容
  String getAllText() {
    return content
        .where((item) => item.type == ContentType.text && item.text != null)
        .map((item) => item.text!)
        .join('\n');
  }

  /// 创建消息的副本并添加新的内容项
  ChatMessage copyWithAddedContent(ContentItem newItem) {
    return ChatMessage(
      id: id,
      role: role,
      content: [...content, newItem],
      conversationId: conversationId,
      createdAt: createdAt,
      functionCall: functionCall,
      toolCalls: toolCalls,
      name: name,
      isFinal: isFinal,
      extraAttributes: extraAttributes,
      metadata: metadata,
    );
  }

  /// 创建消息的副本并替换内容
  ChatMessage copyWithContent(List<ContentItem> newContent) {
    return ChatMessage(
      id: id,
      role: role,
      content: newContent,
      conversationId: conversationId,
      createdAt: createdAt,
      functionCall: functionCall,
      toolCalls: toolCalls,
      name: name,
      isFinal: isFinal,
      extraAttributes: extraAttributes,
      metadata: metadata,
    );
  }

  /// 转换为OpenAI格式的消息
  Map<String, dynamic> toOpenAIFormat() {
    final Map<String, dynamic> result = {
      'role': role.toString().split('.').last,
    };

    // 处理内容字段
    if (content.length == 1 && content.first.type == ContentType.text) {
      // 简单文本消息
      result['content'] = content.first.text;
    } else {
      // 多模态或复杂消息
      result['content'] =
          content.map((item) {
            if (item.type == ContentType.text) {
              return {'type': 'text', 'text': item.text};
            } else if (item.type == ContentType.image) {
              // 处理图片内容
              String? imageUrl = item.mediaUrl;

              // 如果有本地文件路径，将图片转换为base64
              if (item.filePath != null && File(item.filePath!).existsSync()) {
                try {
                  final bytes = File(item.filePath!).readAsBytesSync();
                  final base64Image = base64Encode(bytes);
                  // 根据MIME类型构建data URL
                  final mimeType = item.mimeType ?? 'image/jpeg';
                  imageUrl = 'data:$mimeType;base64,$base64Image';
                } catch (e) {
                  logger.i('图片转base64错误: $e');
                }
              }

              return {
                'type': 'image_url',
                'image_url': {'url': imageUrl, 'detail': 'auto'},
              };
            } else if (item.type == ContentType.audio) {
              // 处理音频内容
              String? audioUrl = item.mediaUrl;

              // 如果有本地文件路径，将音频转换为base64
              if (item.filePath != null && File(item.filePath!).existsSync()) {
                try {
                  final bytes = File(item.filePath!).readAsBytesSync();
                  final base64Audio = base64Encode(bytes);
                  final mimeType = item.mimeType ?? 'audio/mpeg';
                  audioUrl = 'data:$mimeType;base64,$base64Audio';
                } catch (e) {
                  logger.e('音频转base64错误: $e');
                }
              }

              // 目前OpenAI不直接支持audio_url，但我们按照image_url的格式提供以备将来支持
              return {
                'type': 'audio_url',
                'audio_url': {'url': audioUrl},
              };
            } else if (item.type == ContentType.video) {
              // 处理视频内容
              String? videoUrl = item.mediaUrl;

              // 视频一般不适合直接转base64，文件过大，但如果需要可以添加类似逻辑

              return {
                'type': 'video_url',
                'video_url': {'url': videoUrl},
              };
            }

            // 其他类型可根据需要扩展
            return {'type': 'text', 'text': item.text ?? ''};
          }).toList();
    }

    // 处理函数调用
    if (functionCall != null) {
      result['function_call'] = functionCall;
    }

    // 处理工具调用
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      result['tool_calls'] = toolCalls;
    }

    // 处理名称
    if (name != null) {
      result['name'] = name;
    }

    return result;
  }
}
