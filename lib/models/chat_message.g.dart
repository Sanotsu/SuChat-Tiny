// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContentItem _$ContentItemFromJson(Map<String, dynamic> json) => ContentItem(
  type: $enumDecode(_$ContentTypeEnumMap, json['type']),
  text: json['text'] as String?,
  mediaUrl: json['mediaUrl'] as String?,
  mimeType: json['mimeType'] as String?,
  filePath: json['filePath'] as String?,
  functionName: json['functionName'] as String?,
  functionArgs: json['functionArgs'] as Map<String, dynamic>?,
  extraAttributes: json['extraAttributes'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ContentItemToJson(ContentItem instance) =>
    <String, dynamic>{
      'type': _$ContentTypeEnumMap[instance.type]!,
      'text': instance.text,
      'mediaUrl': instance.mediaUrl,
      'mimeType': instance.mimeType,
      'filePath': instance.filePath,
      'functionName': instance.functionName,
      'functionArgs': instance.functionArgs,
      'extraAttributes': instance.extraAttributes,
    };

const _$ContentTypeEnumMap = {
  ContentType.text: 'text',
  ContentType.image: 'image',
  ContentType.audio: 'audio',
  ContentType.video: 'video',
  ContentType.file: 'file',
  ContentType.function: 'function',
  ContentType.multimodal: 'multimodal',
};

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String?,
  role: $enumDecode(_$MessageRoleEnumMap, json['role']),
  content:
      (json['content'] as List<dynamic>)
          .map((e) => ContentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
  conversationId: json['conversationId'] as String,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  functionCall: json['functionCall'] as Map<String, dynamic>?,
  toolCalls:
      (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
  name: json['name'] as String?,
  isFinal: json['isFinal'] as bool? ?? true,
  extraAttributes: json['extraAttributes'] as Map<String, dynamic>?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$MessageRoleEnumMap[instance.role]!,
      'content': instance.content.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
      'conversationId': instance.conversationId,
      'functionCall': instance.functionCall,
      'toolCalls': instance.toolCalls,
      'name': instance.name,
      'isFinal': instance.isFinal,
      'extraAttributes': instance.extraAttributes,
      'metadata': instance.metadata,
    };

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
  MessageRole.function: 'function',
};
