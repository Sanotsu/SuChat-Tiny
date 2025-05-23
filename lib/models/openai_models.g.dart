// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openai_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatCompletionRequest _$ChatCompletionRequestFromJson(
  Map<String, dynamic> json,
) => ChatCompletionRequest(
  model: json['model'] as String,
  messages:
      (json['messages'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
  temperature: (json['temperature'] as num?)?.toDouble(),
  topP: (json['top_p'] as num?)?.toDouble(),
  n: (json['n'] as num?)?.toInt(),
  stream: json['stream'] as bool?,
  stop: (json['stop'] as List<dynamic>?)?.map((e) => e as String).toList(),
  maxTokens: (json['max_tokens'] as num?)?.toInt(),
  presencePenalty: (json['presence_penalty'] as num?)?.toDouble(),
  frequencyPenalty: (json['frequency_penalty'] as num?)?.toDouble(),
  responseFormat: json['response_format'] as Map<String, dynamic>?,
  functions:
      (json['functions'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
  tools:
      (json['tools'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
  toolChoice: json['tool_choice'] as String?,
  user: json['user'] as String?,
  extraParams: json['extra_params'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatCompletionRequestToJson(
  ChatCompletionRequest instance,
) => <String, dynamic>{
  'model': instance.model,
  'messages': instance.messages,
  'temperature': instance.temperature,
  'top_p': instance.topP,
  'n': instance.n,
  'stream': instance.stream,
  'stop': instance.stop,
  'max_tokens': instance.maxTokens,
  'presence_penalty': instance.presencePenalty,
  'frequency_penalty': instance.frequencyPenalty,
  'response_format': instance.responseFormat,
  'functions': instance.functions,
  'tools': instance.tools,
  'tool_choice': instance.toolChoice,
  'user': instance.user,
  'extra_params': instance.extraParams,
};

ChatCompletionChoice _$ChatCompletionChoiceFromJson(
  Map<String, dynamic> json,
) => ChatCompletionChoice(
  index: (json['index'] as num?)?.toInt(),
  finishReason: json['finish_reason'] as String?,
  message: json['message'] as Map<String, dynamic>?,
  delta: json['delta'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatCompletionChoiceToJson(
  ChatCompletionChoice instance,
) => <String, dynamic>{
  'index': instance.index,
  'finish_reason': instance.finishReason,
  'message': instance.message,
  'delta': instance.delta,
};

UsageInfo _$UsageInfoFromJson(Map<String, dynamic> json) => UsageInfo(
  promptTokens: (json['prompt_tokens'] as num?)?.toInt(),
  completionTokens: (json['completion_tokens'] as num?)?.toInt(),
  totalTokens: (json['total_tokens'] as num?)?.toInt(),
);

Map<String, dynamic> _$UsageInfoToJson(UsageInfo instance) => <String, dynamic>{
  'prompt_tokens': instance.promptTokens,
  'completion_tokens': instance.completionTokens,
  'total_tokens': instance.totalTokens,
};

ChatCompletionResponse _$ChatCompletionResponseFromJson(
  Map<String, dynamic> json,
) => ChatCompletionResponse(
  id: json['id'] as String?,
  object: json['object'] as String?,
  created: (json['created'] as num?)?.toInt(),
  model: json['model'] as String?,
  choices:
      (json['choices'] as List<dynamic>?)
          ?.map((e) => ChatCompletionChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
  usage:
      json['usage'] == null
          ? null
          : UsageInfo.fromJson(json['usage'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChatCompletionResponseToJson(
  ChatCompletionResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'choices': instance.choices?.map((e) => e.toJson()).toList(),
  'created': instance.created,
  'model': instance.model,
  'object': instance.object,
  'usage': instance.usage?.toJson(),
};
