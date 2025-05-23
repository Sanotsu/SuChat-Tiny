import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'conversation.g.dart';

/// 对话状态枚举
enum ConversationState {
  active, // 活跃（正在进行）
  archived, // 已归档
  deleted, // 已删除
}

/// 对话类
@JsonSerializable(explicitToJson: true)
class Conversation {
  /// 对话唯一ID
  final String id;

  /// 对话标题
  String title;

  /// 对话创建时间
  final DateTime createdAt;

  /// 对话最后更新时间
  DateTime updatedAt;

  /// 对话状态
  ConversationState state;

  /// 相关模型ID
  final String modelId;

  /// 相关平台ID
  final String platformId;

  /// 系统提示（可选）
  String? systemPrompt;

  /// 对话的消息数量
  int messageCount;

  /// 最后一条消息预览
  String? lastMessagePreview;

  /// 对话元数据，包含自定义属性
  Map<String, dynamic>? metadata;

  /// 对话标签列表
  List<String>? tags;

  Conversation({
    String? id,
    required this.title,
    required this.modelId,
    required this.platformId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.state = ConversationState.active,
    this.systemPrompt,
    this.messageCount = 0,
    this.lastMessagePreview,
    this.metadata,
    this.tags,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  // 从字符串转
  factory Conversation.fromRawJson(String str) =>
      Conversation.fromJson(json.decode(str));
  // 转为字符串
  String toRawJson() => json.encode(toJson());

  // 将对话对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'state': state.toString().split('.').last,
      'model_id': modelId,
      'platform_id': platformId,
      'system_prompt': systemPrompt,
      'message_count': messageCount,
      'last_message_preview': lastMessagePreview,
      'metadata': metadata != null ? json.encode(metadata!) : null,
      'tags': tags != null ? json.encode(tags!) : null,
    };
  }

  // 将Map转换为对话对象
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      state: ConversationState.values.firstWhere(
        (e) => e.toString().split('.').last == map['state'],
        orElse: () => ConversationState.active,
      ),
      modelId: map['model_id'],
      platformId: map['platform_id'],
      systemPrompt: map['system_prompt'],
      messageCount: map['message_count'],
      lastMessagePreview: map['last_message_preview'],
      metadata: map['metadata'] != null ? json.decode(map['metadata']) : null,
      tags:
          map['tags'] != null
              ? List<String>.from(json.decode(map['tags']))
              : null,
    );
  }

  /// 创建新对话
  factory Conversation.create({
    required String title,
    required String modelId,
    required String platformId,
    String? systemPrompt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      title: title,
      modelId: modelId,
      platformId: platformId,
      systemPrompt: systemPrompt,
      tags: tags,
      metadata: metadata,
    );
  }

  /// 标记为已归档
  void archive() {
    state = ConversationState.archived;
    updatedAt = DateTime.now();
  }

  /// 标记为已删除
  void markAsDeleted() {
    state = ConversationState.deleted;
    updatedAt = DateTime.now();
  }

  /// 恢复为活跃状态
  void restore() {
    state = ConversationState.active;
    updatedAt = DateTime.now();
  }

  /// 更新对话标题
  void updateTitle(String newTitle) {
    title = newTitle;
    updatedAt = DateTime.now();
  }

  /// 更新对话系统提示
  void updateSystemPrompt(String? newSystemPrompt) {
    systemPrompt = newSystemPrompt;
    updatedAt = DateTime.now();
  }

  /// 增加消息计数
  void incrementMessageCount() {
    messageCount++;
    updatedAt = DateTime.now();
  }

  /// 更新最后一条消息预览
  void updateLastMessagePreview(String preview) {
    lastMessagePreview = preview;
    updatedAt = DateTime.now();
  }

  /// 添加标签
  void addTag(String tag) {
    tags ??= [];
    if (!tags!.contains(tag)) {
      tags!.add(tag);
      updatedAt = DateTime.now();
    }
  }

  /// 移除标签
  void removeTag(String tag) {
    if (tags != null && tags!.contains(tag)) {
      tags!.remove(tag);
      updatedAt = DateTime.now();
    }
  }

  /// 更新元数据
  void updateMetadata(Map<String, dynamic> newMetadata) {
    metadata ??= {};
    metadata!.addAll(newMetadata);
    updatedAt = DateTime.now();
  }

  /// 克隆对话（创建新的对话，但内容相同）
  Conversation clone({String? newTitle, bool keepMessages = false}) {
    return Conversation(
      title: newTitle ?? '$title (副本)',
      modelId: modelId,
      platformId: platformId,
      systemPrompt: systemPrompt,
      messageCount: keepMessages ? messageCount : 0,
      lastMessagePreview: keepMessages ? lastMessagePreview : null,
      metadata: metadata != null ? Map<String, dynamic>.from(metadata!) : null,
      tags: tags != null ? List<String>.from(tags!) : null,
    );
  }
}
