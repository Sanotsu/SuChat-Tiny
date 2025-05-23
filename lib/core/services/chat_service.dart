import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/model_spec.dart';
import '../../models/openai_models.dart';
import '../../models/platform_spec.dart';
import '../network/api_helper.dart';
import '../network/dio_client/custom_http_client.dart';
import '../network/dio_client/custom_http_request.dart';
import '../network/stream_response_handler.dart';
import '../utils/tools.dart';

/// 聊天服务接口
abstract class ChatService {
  /// 发送聊天请求，等待完成后返回完整响应
  Future<ChatMessage> sendChatRequest({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
  });

  /// 发送聊天请求，返回流式响应
  Stream<ChatMessage> sendChatRequestStream({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
  });

  /// 生成图像，返回图像URL数组
  Future<List<String>> generateImage({
    required String prompt,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
    File? referenceImage,
  });

  /// 中止当前请求
  void abortRequest();
}

/// 聊天服务实现
class ChatServiceImpl implements ChatService {
  CancelToken? _cancelToken;

  @override
  void abortRequest() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消请求');
    }
  }

  @override
  Future<ChatMessage> sendChatRequest({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
  }) async {
    // 获取请求头
    final headers = await ApiHelper.buildHeaders(platform);

    // 构建完整路径
    final String path = _getCompletionPath(platform);
    final String fullPath = ApiHelper.buildFullPath(platform, path);

    // 准备请求数据
    final requestData = _createRequestData(
      messages: messages,
      model: model,
      platform: platform,
      options: options,
      stream: false,
    );

    try {
      // 发送请求
      final response = await HttpUtils.post(
        path: fullPath,
        data: requestData,
        headers: headers,
        showLoading: false,
      );

      // 解析响应
      String content = '';
      // 处理OpenAI格式响应
      if (response is Map<String, dynamic> &&
          response.containsKey('choices') &&
          response['choices'] is List &&
          response['choices'].isNotEmpty) {
        final chatCompletionResponse = ChatCompletionResponse.fromJson(
          response,
        );
        content = chatCompletionResponse.getFirstContent() ?? '';
      }
      // 处理未知格式响应
      else {
        content = response.toString();
      }

      return ChatMessage.assistantText(
        text: content,
        conversationId: conversation.id,
      );
    } catch (e) {
      logger.e('发送请求失败: $e');
      throw Exception('发送请求失败: $e');
    }
  }

  @override
  Stream<ChatMessage> sendChatRequestStream({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
  }) {
    // 创建流控制器
    final streamController = StreamController<ChatMessage>();

    // 处理请求
    _handleStreamRequest(
      conversation: conversation,
      messages: messages,
      model: model,
      platform: platform,
      options: options,
      streamController: streamController,
    );

    return streamController.stream;
  }

  Future<void> _handleStreamRequest({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
    required StreamController<ChatMessage> streamController,
  }) async {
    String accumulatedText = '';
    String messageId = '';
    String accumulatedThinking = ''; // 存储思考过程
    bool isInThinkingPhase = false; // 标记是否处于思考阶段
    DateTime? thinkingStartTime; // 思考开始时间
    String thinkingDuration = ''; // 保存思考时长

    try {
      // 获取请求头
      final headers = await ApiHelper.buildHeaders(platform);

      // 构建完整路径
      final String path = _getCompletionPath(platform);
      final String fullPath = ApiHelper.buildFullPath(platform, path);

      // 准备请求数据
      final requestData = _createRequestData(
        messages: messages,
        model: model,
        platform: platform,
        options: options,
        stream: true,
      );

      // 创建取消令牌
      _cancelToken = CancelToken();

      // 发送流式请求
      final response = await HttpUtils.post(
        path: fullPath,
        data: requestData,
        headers: headers,
        responseType: CusRespType.stream,
        cancelToken: _cancelToken,
        showLoading: false,
      );

      // 处理响应流
      final stream = response.stream as Stream;
      stream.listen(
        (chunk) {
          // 使用流式响应处理器处理数据块
          StreamResponseHandler.handleStreamChunk(chunk, (processedChunk) {
            // 处理流结束
            if (processedChunk is Map<String, dynamic> &&
                processedChunk.containsKey('done')) {
              // 计算思考时长（如果有）
              if (thinkingStartTime != null && thinkingDuration.isEmpty) {
                final duration = DateTime.now().difference(thinkingStartTime!);
                thinkingDuration =
                    '思考用时: ${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}秒';
              }

              // 处理无内容情况
              if (accumulatedText.isEmpty) {
                // 如果有思考内容但没有实际文本，将思考内容作为输出
                if (accumulatedThinking.isNotEmpty) {
                  // 响应无实际内容，但有思考过程，将思考作为输出
                  accumulatedText = '思考过程:\n$accumulatedThinking';
                } else {
                  // 响应为空
                  accumulatedText = '(模型未返回内容)';
                }
              }

              final chatMessage = ChatMessage.assistantText(
                id: messageId,
                text: accumulatedText,
                conversationId: conversation.id,
                isFinal: true,
              );

              // 将思考过程添加到消息元数据，并包含思考时长
              if (accumulatedThinking.isNotEmpty) {
                chatMessage.metadata ??= {};
                chatMessage.metadata!['thinking_process'] = accumulatedThinking;
                if (thinkingDuration.isNotEmpty) {
                  chatMessage.metadata!['thinking_duration'] = thinkingDuration;
                }
              }

              streamController.add(chatMessage);
              // 发送最终消息，文本长度: ${accumulatedText.length}
              streamController.close();
              return;
            }

            try {
              // 使用 ChatCompletionResponse 类解析响应
              final chunkObj = ChatCompletionResponse.fromJson(processedChunk);

              // 保存消息ID (如果是第一个消息块)
              if (messageId.isEmpty && chunkObj.id != null) {
                messageId = chunkObj.id!;
              }

              // 获取内容和思考过程
              final deltaContent = chunkObj.getFirstContent();
              final reasoningContent = chunkObj.getReasoningContent();

              // 处理思考过程内容
              if (reasoningContent != null) {
                // 如果是第一个思考内容，标记思考开始
                if (accumulatedThinking.isEmpty && !isInThinkingPhase) {
                  isInThinkingPhase = true;
                  thinkingStartTime = DateTime.now();
                  logger.i('思考阶段开始: ${thinkingStartTime!.toIso8601String()}');
                }

                accumulatedThinking += reasoningContent;

                // 发送思考过程到UI
                final chatMessage = ChatMessage.assistantText(
                  id: messageId,
                  text: accumulatedText,
                  conversationId: conversation.id,
                  isFinal: false,
                );
                chatMessage.metadata ??= {};
                chatMessage.metadata!['is_thinking'] = true;
                chatMessage.metadata!['thinking_process'] = accumulatedThinking;

                streamController.add(chatMessage);
              }

              // 处理普通内容增量
              if (deltaContent != null) {
                // 如果之前处于思考阶段，现在有了正式内容，标记思考结束
                if (isInThinkingPhase) {
                  isInThinkingPhase = false;
                  final thinkingEndTime = DateTime.now();
                  final duration = thinkingEndTime.difference(
                    thinkingStartTime!,
                  );
                  thinkingDuration =
                      '思考用时: ${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}秒';

                  logger.i(
                    '思考阶段结束，持续时间: ${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}秒',
                  );

                  // 立即保存思考时长，避免后续内容追加影响计算
                  if (accumulatedThinking.isNotEmpty) {
                    ChatMessage chatMessage = ChatMessage.assistantText(
                      id: messageId,
                      text: accumulatedText,
                      conversationId: conversation.id,
                      isFinal: false,
                    );
                    chatMessage.metadata ??= {};
                    chatMessage.metadata!['thinking_process'] =
                        accumulatedThinking;
                    chatMessage.metadata!['thinking_duration'] =
                        thinkingDuration;
                    // 不需要更新UI，因为马上会有普通内容的更新
                  }
                }

                accumulatedText += deltaContent;

                final chatMessage = ChatMessage.assistantText(
                  id: messageId,
                  text: accumulatedText,
                  conversationId: conversation.id,
                  isFinal: false,
                );

                // 如果有思考过程，添加到元数据
                if (accumulatedThinking.isNotEmpty) {
                  chatMessage.metadata ??= {};
                  chatMessage.metadata!['thinking_process'] =
                      accumulatedThinking;
                  // 使用已保存的思考时长，而不是重新计算
                  if (thinkingStartTime != null &&
                      thinkingDuration.isNotEmpty) {
                    chatMessage.metadata!['thinking_duration'] =
                        thinkingDuration;
                  } else if (thinkingStartTime != null) {
                    // 如果尚未计算思考时长，则计算（兜底措施）
                    final duration = DateTime.now().difference(
                      thinkingStartTime!,
                    );
                    chatMessage.metadata!['thinking_duration'] =
                        '思考用时: ${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}秒';
                  }
                }

                streamController.add(chatMessage);
              }

              // 检查是否有结束标志和最终内容
              if (chunkObj.choices != null &&
                  chunkObj.choices!.isNotEmpty &&
                  chunkObj.choices![0].finishReason != null) {
                // 检查是否有最终内容
                if (chunkObj.choices![0].delta != null) {
                  final deltaMap = chunkObj.choices![0].delta!;
                  if (deltaMap.containsKey('content') &&
                      deltaMap['content'] is String) {
                    final finalContent = deltaMap['content'] as String;

                    // 将最终内容添加到累积文本
                    accumulatedText += finalContent;

                    // 发送更新的消息
                    final chatMessage = ChatMessage.assistantText(
                      id: messageId,
                      text: accumulatedText,
                      conversationId: conversation.id,
                      isFinal: true,
                    );

                    // 如果有思考过程，添加到元数据
                    if (accumulatedThinking.isNotEmpty) {
                      chatMessage.metadata ??= {};
                      chatMessage.metadata!['thinking_process'] =
                          accumulatedThinking;
                      if (thinkingStartTime != null) {
                        final duration = DateTime.now().difference(
                          thinkingStartTime!,
                        );
                        chatMessage.metadata!['thinking_duration'] =
                            '思考用时: ${duration.inSeconds}.${(duration.inMilliseconds % 1000) ~/ 100}秒';
                      }
                    }

                    streamController.add(chatMessage);
                  }
                }
              }
            } catch (e) {
              // 解析失败，直接保留整体内容作为响应

              // 如果是首次收到内容，生成消息ID
              if (messageId.isEmpty) {
                messageId = const Uuid().v4();
              }

              // 尝试从原始chunk中提取有用信息
              String rawContent = '';

              if (processedChunk is Map<String, dynamic>) {
                // 保存原始chunk为文本
                rawContent = processedChunk.toString();

                // 尝试提取一个可能的简单ID (如果存在)
                if (processedChunk.containsKey('id') && messageId.isEmpty) {
                  messageId = processedChunk['id']?.toString() ?? messageId;
                }
              } else if (processedChunk is String) {
                rawContent = processedChunk;
              } else {
                rawContent = processedChunk.toString();
              }

              // 将原始内容添加到消息中
              accumulatedText += '\n[原始响应: $rawContent]';

              // 创建消息并发送
              final chatMessage = ChatMessage.assistantText(
                id: messageId,
                text: accumulatedText,
                conversationId: conversation.id,
                isFinal: false,
              );

              streamController.add(chatMessage);
            }
          });
        },
        onError: (error) {
          logger.i('流式响应错误: $error');
          streamController.addError(error);
          streamController.close();
        },
        onDone: () {
          logger.i('流式响应完成');
          if (!streamController.isClosed) {
            streamController.close();
          }
        },
      );
    } catch (e) {
      logger.i('发送流式请求失败: $e');
      streamController.addError(Exception('发送流式请求失败: $e'));
      streamController.close();
    }
  }

  String _getCompletionPath(PlatformSpec platform) {
    switch (platform.type) {
      case PlatformType.openAI:
      case PlatformType.other: // 如果是其他类型但兼容OpenAI
        return '/v1/chat/completions';
      default:
        if (platform.isOpenAICompatible) {
          return '/v1/chat/completions';
        }
        throw Exception('不支持的平台类型');
    }
  }

  Map<String, dynamic> _createRequestData({
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
    bool stream = false,
  }) {
    // 默认使用OpenAI格式
    if (platform.type == PlatformType.openAI || platform.isOpenAICompatible) {
      return _createOpenAIRequestData(messages, model, options, stream);
    } else {
      // 默认使用OpenAI格式
      return _createOpenAIRequestData(messages, model, options, stream);
    }
  }

  Map<String, dynamic> _createOpenAIRequestData(
    List<ChatMessage> messages,
    ModelSpec model,
    Map<String, dynamic>? options,
    bool stream,
  ) {
    // 将应用内消息模型转换为OpenAI格式的消息
    final openAIMessages = messages.map((msg) => msg.toOpenAIFormat()).toList();

    return {
      'model': model.id,
      'messages': openAIMessages,
      'stream': stream,
      'temperature': options?['temperature'] ?? 0.7,
      'top_p': options?['top_p'] ?? 1.0,
      if (options?['max_tokens'] != null)
        'max_tokens': options?['max_tokens'] ?? model.maxOutputTokens,
      if (options?['presence_penalty'] != null)
        'presence_penalty': options?['presence_penalty'],
      if (options?['frequency_penalty'] != null)
        'frequency_penalty': options?['frequency_penalty'],
      if (options?['stop'] != null) 'stop': options?['stop'],
      if (options?['user'] != null) 'user': options?['user'],
      if (options?['functions'] != null) 'functions': options?['functions'],
      if (options?['tools'] != null) 'tools': options?['tools'],
      if (options?['tool_choice'] != null)
        'tool_choice': options?['tool_choice'],
      if (options?['response_format'] != null)
        'response_format': options?['response_format'],
      ...?options?['extra_params'],
    };
  }

  @override
  Future<List<String>> generateImage({
    required String prompt,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
    File? referenceImage,
  }) async {
    if (platform.type != PlatformType.openAI && !platform.isOpenAICompatible) {
      // logger.i('平台不支持图像生成: ${platform.name}');
      throw Exception('所选平台不支持图像生成功能');
    }

    if (model.type != ModelType.image) {
      // logger.i('模型不是图像生成类型: ${model.name}');
      throw Exception('所选模型不支持图像生成功能');
    }

    try {
      // 获取请求头
      final headers = await ApiHelper.buildHeaders(platform);

      // 构建请求路径
      final String path = '/v1/images/generations';
      final String fullPath = ApiHelper.buildFullPath(platform, path);

      // 构建请求数据
      // TODO 这里可能需要根据不同的平台进行不同的处理，参数不一定一样
      // 但是硅基流动API显示本来尺寸和数量是image_size和batch_size，但传size和n实测有效，所以暂时不处理
      final requestData = {
        'model': model.id,
        'prompt': prompt,
        'n': options?['n'] ?? 1,
        'size': options?['size'] ?? '1024x1024',
        'response_format': options?['response_format'] ?? 'url',
      };

      // 如果提供了参考图且模型支持参考图
      final supportsReferenceImage =
          model.extraAttributes != null &&
          model.extraAttributes!['supports_reference_image'] == true;

      if (referenceImage != null && supportsReferenceImage) {
        try {
          // 读取图片文件
          final bytes = await referenceImage.readAsBytes();
          // 转换为base64
          final base64Image = base64Encode(bytes);
          // 根据文件扩展名判断MIME类型
          final extension = referenceImage.path.split('.').last.toLowerCase();
          String mimeType;
          switch (extension) {
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'png':
              mimeType = 'image/png';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
            default:
              mimeType = 'image/jpeg'; // 默认JPEG
          }

          // 将参考图添加到请求中
          // 不同平台的API可能有不同的参数名，
          // 2025-05-21 目前就硅基流动是image，其他iti还没测过，所以后续还是要需要区分
          requestData['image'] = 'data:$mimeType;base64,$base64Image';
        } catch (e) {
          logger.i('处理参考图片失败: $e');
          // 如果处理参考图片失败，我们仍然继续请求，但不包含参考图
        }
      }

      // 发送请求
      final response = await HttpUtils.post(
        path: fullPath,
        data: requestData,
        headers: headers,
        showLoading: false,
      );

      // 提取图像URL列表
      if (response is Map<String, dynamic> &&
          response.containsKey('data') &&
          response['data'] is List &&
          response['data'].isNotEmpty) {
        final dataList = response['data'] as List;
        final urls = <String>[];

        for (var item in dataList) {
          if (item is Map<String, dynamic> &&
              item.containsKey('url') &&
              item['url'] is String &&
              item['url'].isNotEmpty) {
            urls.add(item['url'] as String);

            logger.i('获取到图像URL: ${item['url']}');
          }
        }

        if (urls.isNotEmpty) {
          return urls;
        } else {
          logger.w('响应中没有有效的图像URL: $response');
          throw Exception('图像生成成功，但未返回有效的图像URL');
        }
      } else {
        logger.e('无效的图像生成响应格式: $response');
        throw Exception('图像生成响应格式错误');
      }
    } catch (e) {
      logger.e('生成图像失败: $e');
      throw Exception('生成图像失败: $e');
    }
  }
}

/// 聊天服务工厂
class ChatServiceFactory {
  // 创建统一的聊天服务
  static ChatService create() {
    return ChatServiceImpl();
  }
}
