import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'platform_spec.g.dart';

/// 平台类型枚举
/// 2025-05-21目前有用到但实际作用不大，可以改善设计
enum PlatformType {
  openAI, // OpenAI平台
  local, // 本地模型
  other, // 其他平台
}

/// 定义AI平台规格
@JsonSerializable(explicitToJson: true)
class PlatformSpec {
  /// 平台ID，唯一标识符
  /// 使用identityHashCode(name)作为唯一标识符
  /// 绝对不要使用uuid来生成，因为只要name不变，identityHashCode(name)就不会变，但uuid每次生成都会变
  final String id;

  /// 平台名称(不再使用id，直接使用名称作为唯一标识符，
  /// 避免在导出备份等情况下，重新导入，本来是同一个平台但id变了导致被认定为不同平台)
  final String name;

  /// 平台类型
  final PlatformType type;

  /// 平台基础URL
  final String baseUrl;

  /// 平台API版本
  final String apiVersion;

  /// 平台描述
  final String description;

  /// API密钥的请求头名称
  final String? apiKeyHeader;

  /// 组织ID的请求头名称（如果需要）
  final String? orgIdHeader;

  /// 是否使用OpenAI兼容格式
  final bool isOpenAICompatible;

  /// 模型创建时间
  final DateTime createdAt;

  /// 模型最后更新时间
  DateTime updatedAt;

  /// 额外请求头
  final Map<String, String>? extraHeaders;

  /// 额外属性，用于存储未来可能需要的特定属性
  final Map<String, dynamic>? extraAttributes;

  PlatformSpec({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    this.apiVersion = '',
    this.description = '',
    this.apiKeyHeader = 'Authorization',
    this.orgIdHeader,
    this.isOpenAICompatible = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.extraHeaders,
    this.extraAttributes,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PlatformSpec.fromJson(Map<String, dynamic> json) =>
      _$PlatformSpecFromJson(json);
  Map<String, dynamic> toJson() => _$PlatformSpecToJson(this);

  // 将平台对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'base_url': baseUrl,
      'api_version': apiVersion,
      'description': description,
      'api_key_header': apiKeyHeader,
      'org_id_header': orgIdHeader,
      'is_openai_compatible': isOpenAICompatible ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'extra_headers': extraHeaders != null ? json.encode(extraHeaders!) : null,
      'extra_attributes':
          extraAttributes != null ? json.encode(extraAttributes!) : null,
    };
  }

  // 将Map转换为平台对象
  factory PlatformSpec.fromMap(Map<String, dynamic> map) {
    return PlatformSpec(
      id: map['id'],
      name: map['name'],
      type: PlatformType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => PlatformType.other,
      ),
      baseUrl: map['base_url'],
      apiVersion: map['api_version'] ?? '',
      description: map['description'] ?? '',
      apiKeyHeader: map['api_key_header'],
      orgIdHeader: map['org_id_header'],
      isOpenAICompatible: map['is_openai_compatible'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      extraHeaders:
          map['extra_headers'] != null
              ? json.decode(map['extra_headers'])
              : null,
      extraAttributes:
          map['extra_attributes'] != null
              ? json.decode(map['extra_attributes'])
              : null,
    );
  }

  PlatformSpec copyWith({
    String? id,
    String? name,
    PlatformType? type,
    String? baseUrl,
    String? apiVersion,
    String? description,
    bool? supportsStreaming,
    String? apiKeyHeader,
    String? orgIdHeader,
    bool? isOpenAICompatible,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraAttributes,
  }) {
    return PlatformSpec(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      apiVersion: apiVersion ?? this.apiVersion,
      description: description ?? this.description,
      apiKeyHeader: apiKeyHeader ?? this.apiKeyHeader,
      orgIdHeader: orgIdHeader ?? this.orgIdHeader,
      isOpenAICompatible: isOpenAICompatible ?? this.isOpenAICompatible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraHeaders: extraHeaders ?? this.extraHeaders,
      extraAttributes: extraAttributes ?? this.extraAttributes,
    );
  }

  /// 创建预定义的OpenAI平台规格
  factory PlatformSpec.openAI() {
    return PlatformSpec(
      id: 'openai',
      name: 'OpenAI',
      type: PlatformType.openAI,
      baseUrl: 'https://api.openai.com',
      apiVersion: 'v1',
      description: 'OpenAI API平台',
      apiKeyHeader: 'Authorization',
      isOpenAICompatible: true,
    );
  }
}
