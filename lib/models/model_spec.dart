// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'model_spec.g.dart';

/// 模型类型枚举
enum ModelType {
  text, // 纯文本模型
  vision, // 视觉理解模型
  image, // 图像生成模型
  // embedding, // 嵌入模型
  // audio, // 音频处理模型
  // multimodal, // 多模态模型
}

// 模型类型对应的中文名
final Map<ModelType, String> MT_NAME_MAP = {
  ModelType.text: '文本模型',
  ModelType.vision: '视觉理解模型',
  ModelType.image: '图像生成模型',
  // ModelType.embedding: '嵌入模型',
  // ModelType.audio: '音频处理模型',
  // ModelType.multimodal: '多模态模型',
};

/// 定义大模型规格
@JsonSerializable(explicitToJson: true)
class ModelSpec {
  /// 模型ID，通常是API调用中使用的名称
  final String id;

  /// 模型显示名称
  final String name;

  /// 模型描述
  final String description;

  /// 模型类型
  final ModelType type;

  /// 所属平台ID
  final String platformId;

  /// 模型版本
  final String version;

  /// 模型上下文窗口大小（token数）
  final int? contextWindow;

  /// 模型输入费率 (每1000 tokens的价格，单位：元)
  final double? inputPricePerK;

  /// 模型输出费率 (每1000 tokens的价格，单位：元)
  final double? outputPricePerK;

  /// 是否支持流式输出
  final bool supportsStreaming;

  /// 是否支持函数调用
  final bool supportsFunctionCalling;

  /// 是否支持视觉输入
  final bool supportsVision;

  /// 模型最大响应token数
  final int? maxOutputTokens;

  /// 模型创建时间
  final DateTime createdAt;

  /// 模型最后更新时间
  DateTime updatedAt;

  /// 额外属性，用于存储未来可能需要的或平台特定的属性
  final Map<String, dynamic>? extraAttributes;

  ModelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.platformId,
    this.version = '',
    this.contextWindow,
    this.inputPricePerK,
    this.outputPricePerK,
    this.supportsStreaming = false,
    this.supportsFunctionCalling = false,
    this.supportsVision = false,
    this.maxOutputTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.extraAttributes,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ModelSpec.fromJson(Map<String, dynamic> json) =>
      _$ModelSpecFromJson(json);
  Map<String, dynamic> toJson() => _$ModelSpecToJson(this);

  // 将模型对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'platform_id': platformId,
      'version': version,
      'context_window': contextWindow,
      'input_price_per_k': inputPricePerK,
      'output_price_per_k': outputPricePerK,
      'supports_streaming': supportsStreaming ? 1 : 0,
      'supports_function_calling': supportsFunctionCalling ? 1 : 0,
      'supports_vision': supportsVision ? 1 : 0,
      'max_output_tokens': maxOutputTokens,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'extra_attributes':
          extraAttributes != null ? json.encode(extraAttributes!) : null,
    };
  }

  // 将Map转换为模型对象
  factory ModelSpec.fromMap(Map<String, dynamic> map) {
    return ModelSpec(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: ModelType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ModelType.text,
      ),
      platformId: map['platform_id'],
      version: map['version'] ?? '',
      contextWindow: map['context_window'],
      inputPricePerK: map['input_price_per_k'],
      outputPricePerK: map['output_price_per_k'],
      supportsStreaming: map['supports_streaming'] == 1,
      supportsFunctionCalling: map['supports_function_calling'] == 1,
      supportsVision: map['supports_vision'] == 1,
      maxOutputTokens: map['max_output_tokens'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      extraAttributes:
          map['extra_attributes'] != null
              ? json.decode(map['extra_attributes'])
              : null,
    );
  }

  ModelSpec copyWith({
    String? id,
    String? name,
    String? description,
    ModelType? type,
    String? platformId,
    String? version,
    int? contextWindow,
    double? inputPricePerK,
    double? outputPricePerK,
    bool? supportsStreaming,
    bool? supportsFunctionCalling,
    bool? supportsVision,
    int? maxOutputTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? extraAttributes,
  }) {
    return ModelSpec(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      platformId: platformId ?? this.platformId,
      version: version ?? this.version,
      contextWindow: contextWindow ?? this.contextWindow,
      inputPricePerK: inputPricePerK ?? this.inputPricePerK,
      outputPricePerK: outputPricePerK ?? this.outputPricePerK,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsFunctionCalling:
          supportsFunctionCalling ?? this.supportsFunctionCalling,
      supportsVision: supportsVision ?? this.supportsVision,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraAttributes: extraAttributes ?? this.extraAttributes,
    );
  }
}
