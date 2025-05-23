// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conversation _$ConversationFromJson(Map<String, dynamic> json) => Conversation(
  id: json['id'] as String?,
  title: json['title'] as String,
  modelId: json['modelId'] as String,
  platformId: json['platformId'] as String,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
  state:
      $enumDecodeNullable(_$ConversationStateEnumMap, json['state']) ??
      ConversationState.active,
  systemPrompt: json['systemPrompt'] as String?,
  messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
  lastMessagePreview: json['lastMessagePreview'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ConversationToJson(Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'state': _$ConversationStateEnumMap[instance.state]!,
      'modelId': instance.modelId,
      'platformId': instance.platformId,
      'systemPrompt': instance.systemPrompt,
      'messageCount': instance.messageCount,
      'lastMessagePreview': instance.lastMessagePreview,
      'metadata': instance.metadata,
      'tags': instance.tags,
    };

const _$ConversationStateEnumMap = {
  ConversationState.active: 'active',
  ConversationState.archived: 'archived',
  ConversationState.deleted: 'deleted',
};
