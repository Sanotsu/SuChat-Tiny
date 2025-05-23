// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelSpec _$ModelSpecFromJson(Map<String, dynamic> json) => ModelSpec(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  type: $enumDecode(_$ModelTypeEnumMap, json['type']),
  platformId: json['platformId'] as String,
  version: json['version'] as String? ?? '',
  contextWindow: (json['contextWindow'] as num?)?.toInt(),
  inputPricePerK: (json['inputPricePerK'] as num?)?.toDouble(),
  outputPricePerK: (json['outputPricePerK'] as num?)?.toDouble(),
  supportsStreaming: json['supportsStreaming'] as bool? ?? false,
  supportsFunctionCalling: json['supportsFunctionCalling'] as bool? ?? false,
  supportsVision: json['supportsVision'] as bool? ?? false,
  maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt(),
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
  extraAttributes: json['extraAttributes'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ModelSpecToJson(ModelSpec instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'type': _$ModelTypeEnumMap[instance.type]!,
  'platformId': instance.platformId,
  'version': instance.version,
  'contextWindow': instance.contextWindow,
  'inputPricePerK': instance.inputPricePerK,
  'outputPricePerK': instance.outputPricePerK,
  'supportsStreaming': instance.supportsStreaming,
  'supportsFunctionCalling': instance.supportsFunctionCalling,
  'supportsVision': instance.supportsVision,
  'maxOutputTokens': instance.maxOutputTokens,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'extraAttributes': instance.extraAttributes,
};

const _$ModelTypeEnumMap = {
  ModelType.text: 'text',
  ModelType.vision: 'vision',
  ModelType.image: 'image',
};
