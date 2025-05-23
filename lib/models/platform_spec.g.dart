// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlatformSpec _$PlatformSpecFromJson(Map<String, dynamic> json) => PlatformSpec(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$PlatformTypeEnumMap, json['type']),
  baseUrl: json['baseUrl'] as String,
  apiVersion: json['apiVersion'] as String? ?? '',
  description: json['description'] as String? ?? '',
  apiKeyHeader: json['apiKeyHeader'] as String? ?? 'Authorization',
  orgIdHeader: json['orgIdHeader'] as String?,
  isOpenAICompatible: json['isOpenAICompatible'] as bool? ?? false,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
  extraHeaders: (json['extraHeaders'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  extraAttributes: json['extraAttributes'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$PlatformSpecToJson(PlatformSpec instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$PlatformTypeEnumMap[instance.type]!,
      'baseUrl': instance.baseUrl,
      'apiVersion': instance.apiVersion,
      'description': instance.description,
      'apiKeyHeader': instance.apiKeyHeader,
      'orgIdHeader': instance.orgIdHeader,
      'isOpenAICompatible': instance.isOpenAICompatible,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'extraHeaders': instance.extraHeaders,
      'extraAttributes': instance.extraAttributes,
    };

const _$PlatformTypeEnumMap = {
  PlatformType.openAI: 'openAI',
  PlatformType.local: 'local',
  PlatformType.other: 'other',
};
