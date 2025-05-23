import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/model_spec.dart';
import '../models/platform_spec.dart';
import '../widgets/common/toast_utils.dart';
import '../core/services/chat_service.dart';
import '../core/storage/db_helper.dart';
import '../core/utils/tools.dart';

/// 对话提供者，管理对话和消息
class ConversationProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<ChatMessage> _currentMessages = [];

  ChatService? _chatService;
  StreamSubscription? _streamSubscription;
  bool _isGenerating = false;
  String? _generatingMessageId;

  /// 获取所有对话
  List<Conversation> get conversations => _conversations;

  /// 获取当前对话
  Conversation? get currentConversation => _currentConversation;

  /// 获取当前消息列表
  List<ChatMessage> get currentMessages => _currentMessages;

  /// 是否正在生成回复
  bool get isGenerating => _isGenerating;

  /// 初始化
  Future<void> init() async {
    await loadConversations();
  }

  /// 加载所有对话
  Future<void> loadConversations() async {
    _conversations = await _dbHelper.getAllConversations(
      state: ConversationState.active,
    );
    notifyListeners();
  }

  /// 创建新对话
  Future<Conversation> createConversation({
    required String title,
    required ModelSpec model,
    required PlatformSpec platform,
    String? systemPrompt,
  }) async {
    final conversation = Conversation.create(
      title: title,
      modelId: model.id,
      platformId: platform.id,
      systemPrompt: systemPrompt,
    );

    await _dbHelper.saveConversation(conversation);
    await loadConversations();

    return conversation;
  }

  /// 加载对话
  Future<void> loadConversation(String conversationId) async {
    final conversation = await _dbHelper.getConversation(conversationId);
    if (conversation != null) {
      _currentConversation = conversation;
      await loadMessages(conversationId);
      notifyListeners();
    }
  }

  /// 加载消息
  Future<void> loadMessages(String conversationId) async {
    _currentMessages = await _dbHelper.getMessagesForConversation(
      conversationId,
    );
    notifyListeners();
  }

  /// 设置当前对话
  void setCurrentConversation(Conversation conversation) {
    _currentConversation = conversation;
    loadMessages(conversation.id);
  }

  /// 加载最近的对话
  /// 如果有当天的对话，则加载最后一条；否则返回null
  Future<Conversation?> loadRecentConversation() async {
    // 加载所有活跃对话
    final conversations = await _dbHelper.getAllConversations(
      state: ConversationState.active,
    );

    if (conversations.isEmpty) {
      return null;
    }

    // 获取当前日期
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 查找当天更新的对话
    final todayConversations =
        conversations.where((conv) {
          final convDate = DateTime(
            conv.updatedAt.year,
            conv.updatedAt.month,
            conv.updatedAt.day,
          );
          return convDate.isAtSameMomentAs(today);
        }).toList();

    // 如果有当天的对话，按更新时间排序并返回最新的
    if (todayConversations.isNotEmpty) {
      todayConversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final recentConversation = todayConversations.first;

      // 设置为当前对话并加载消息
      setCurrentConversation(recentConversation);
      return recentConversation;
    }

    // 如果没有当天的对话，返回最近的一条对话
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recentConversation = conversations.first;

    // 设置为当前对话并加载消息
    setCurrentConversation(recentConversation);
    return recentConversation;
  }

  /// 清除当前对话
  void clearCurrentConversation() {
    _currentConversation = null;
    _currentMessages = [];
    notifyListeners();
  }

  /// 发送文本消息
  Future<void> sendTextMessage({
    required String text,
    required ModelSpec model,
    required PlatformSpec platform,
    String? conversationId,
    String? systemPrompt,
  }) async {
    // 如果提供了conversationId，尝试加载该对话
    if (conversationId != null) {
      await loadConversation(conversationId);
    }

    // 如果没有当前对话，创建一个新对话
    if (_currentConversation == null) {
      // 截取用户输入的前20个字符作为对话标题
      String title = text.length > 20 ? '${text.substring(0, 20)}...' : text;

      final conversation = await createConversation(
        title: title,
        model: model,
        platform: platform,
        systemPrompt: systemPrompt,
      );

      _currentConversation = conversation;
    }

    // 创建用户消息
    final userMessage = ChatMessage.userText(
      text: text,
      conversationId: _currentConversation!.id,
    );

    // 保存消息到数据库
    await _dbHelper.saveMessage(userMessage);

    // 添加到当前消息列表
    _currentMessages.add(userMessage);
    notifyListeners();

    // 获取系统提示（如果有）
    String? currentSystemPrompt = _currentConversation!.systemPrompt;
    List<ChatMessage> messagesToSend = [];

    // 添加系统提示
    if (currentSystemPrompt != null && currentSystemPrompt.isNotEmpty) {
      messagesToSend.add(
        ChatMessage.system(
          text: currentSystemPrompt,
          conversationId: _currentConversation!.id,
        ),
      );
    }

    // 添加历史消息和当前消息
    messagesToSend.addAll(_currentMessages);

    // 生成AI回复
    await generateResponse(
      messages: messagesToSend,
      model: model,
      platform: platform,
    );
  }

  /// 发送图片消息
  Future<void> sendImageMessage({
    required List<File> images,
    required String caption,
    required ModelSpec model,
    required PlatformSpec platform,
  }) async {
    // 创建内容项
    List<ContentItem> contentItems = [];

    // 先添加文本、再添加图片等，这样在构建消息显示时，图片在文本后，更方便看到
    // 添加文本说明（如果有）
    if (caption.isNotEmpty) {
      contentItems.add(ContentItem.text(caption));
    }

    // 添加图片内容
    for (final image in images) {
      contentItems.add(
        ContentItem.image(
          image.path, // 直接使用文件路径，转换为base64的工作在toOpenAIFormat中完成
          filePath: image.path,
          mimeType: _getMimeTypeFromFile(image),
        ),
      );
    }

    // 注意，如果先创建对话再构建contentItems，会出现创建完对话images变为空的情况，
    // 导致视觉模型第一次对话有图片时图片总为空
    if (_currentConversation == null) {
      // 如果没有当前对话，创建一个新对话
      final conversation = await createConversation(
        title:
            caption.isNotEmpty
                ? (caption.length > 30
                    ? '${caption.substring(0, 27)}...'
                    : caption)
                : '图片对话',
        model: model,
        platform: platform,
      );

      _currentConversation = conversation;
    }

    // 创建用户消息
    final userMessage = ChatMessage(
      role: MessageRole.user,
      content: contentItems,
      conversationId: _currentConversation!.id,
    );

    // 保存消息到数据库
    await _dbHelper.saveMessage(userMessage);

    // 添加到当前消息列表
    _currentMessages.add(userMessage);
    notifyListeners();

    // 获取系统提示（如果有）
    String? systemPrompt = _currentConversation!.systemPrompt;
    List<ChatMessage> messagesToSend = [];

    // 添加系统提示
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messagesToSend.add(
        ChatMessage.system(
          text: systemPrompt,
          conversationId: _currentConversation!.id,
        ),
      );
    }

    // 添加历史消息和当前消息
    messagesToSend.addAll(_currentMessages);

    // 生成AI回复
    await generateResponse(
      messages: messagesToSend,
      model: model,
      platform: platform,
    );
  }

  /// 发送多媒体消息（支持图片、视频、音频等）
  Future<void> sendMultiModalMessage({
    required List<Map<String, dynamic>> mediaItems,
    required String text,
    required ModelSpec model,
    required PlatformSpec platform,
  }) async {
    // 创建内容项
    List<ContentItem> contentItems = [];

    // 添加多媒体内容
    for (final item in mediaItems) {
      final type = item['type'] as ContentType;
      final file = item['file'] as File?;
      final url = item['url'] as String?;
      final mimeType = item['mimeType'] as String?;

      if (file != null) {
        // 本地文件
        switch (type) {
          case ContentType.image:
            contentItems.add(
              ContentItem.image(
                file.path,
                filePath: file.path,
                mimeType: mimeType ?? _getMimeTypeFromFile(file),
              ),
            );
            break;
          case ContentType.audio:
            contentItems.add(
              ContentItem(
                type: ContentType.audio,
                mediaUrl: file.path,
                filePath: file.path,
                mimeType: mimeType ?? 'audio/mpeg',
              ),
            );
            break;
          case ContentType.video:
            contentItems.add(
              ContentItem(
                type: ContentType.video,
                mediaUrl: file.path,
                filePath: file.path,
                mimeType: mimeType ?? 'video/mp4',
              ),
            );
            break;
          default:
            // 不支持的类型
            break;
        }
      } else if (url != null) {
        // 网络URL
        switch (type) {
          case ContentType.image:
            contentItems.add(
              ContentItem.image(url, mimeType: mimeType ?? 'image/jpeg'),
            );
            break;
          case ContentType.audio:
            contentItems.add(
              ContentItem(
                type: ContentType.audio,
                mediaUrl: url,
                mimeType: mimeType ?? 'audio/mpeg',
              ),
            );
            break;
          case ContentType.video:
            contentItems.add(
              ContentItem(
                type: ContentType.video,
                mediaUrl: url,
                mimeType: mimeType ?? 'video/mp4',
              ),
            );
            break;
          default:
            // 不支持的类型
            break;
        }
      }
    }

    // 添加文本内容（如果有）
    if (text.isNotEmpty) {
      contentItems.add(ContentItem.text(text));
    }

    // 如果没有当前对话，创建一个新对话
    if (_currentConversation == null) {
      final conversation = await createConversation(
        title:
            text.isNotEmpty
                ? (text.length > 30 ? '${text.substring(0, 27)}...' : text)
                : '多媒体对话',
        model: model,
        platform: platform,
      );

      _currentConversation = conversation;
    }

    // 创建用户消息
    final userMessage = ChatMessage(
      role: MessageRole.user,
      content: contentItems,
      conversationId: _currentConversation!.id,
    );

    // 保存消息到数据库
    await _dbHelper.saveMessage(userMessage);

    // 添加到当前消息列表
    _currentMessages.add(userMessage);
    notifyListeners();

    // 获取系统提示（如果有）
    String? systemPrompt = _currentConversation!.systemPrompt;
    List<ChatMessage> messagesToSend = [];

    // 添加系统提示
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messagesToSend.add(
        ChatMessage.system(
          text: systemPrompt,
          conversationId: _currentConversation!.id,
        ),
      );
    }

    // 添加历史消息和当前消息
    messagesToSend.addAll(_currentMessages);

    // 生成AI回复
    await generateResponse(
      messages: messagesToSend,
      model: model,
      platform: platform,
    );
  }

  /// 创建新对话并切换到新对话
  Future<Conversation> createAndSwitchToNewConversation({
    String? title,
    required ModelSpec model,
    required PlatformSpec platform,
    String? systemPrompt,
  }) async {
    final defaultTitle = '新对话 ${DateTime.now().toString().substring(0, 16)}';
    final conversation = await createConversation(
      title: title ?? defaultTitle,
      model: model,
      platform: platform,
      systemPrompt: systemPrompt,
    );

    // 切换到新对话
    setCurrentConversation(conversation);

    return conversation;
  }

  /// 根据文件获取MIME类型
  String _getMimeTypeFromFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  /// 生成响应
  Future<void> generateResponse({
    required List<ChatMessage> messages,
    required ModelSpec model,
    required PlatformSpec platform,
    Map<String, dynamic>? options,
    bool stream = true,
  }) async {
    if (_isGenerating) {
      // 如果已经在生成中，取消上一次请求
      cancelGeneration();
    }

    _isGenerating = true;

    // 创建一个占位消息
    final placeholderMessage = ChatMessage.assistantText(
      text: '',
      conversationId: _currentConversation!.id,
      isFinal: false,
    );

    _generatingMessageId = placeholderMessage.id;
    _currentMessages.add(placeholderMessage);
    notifyListeners();

    try {
      // 创建聊天服务
      _chatService = ChatServiceFactory.create();

      if (stream) {
        // 流式生成
        final responseStream = _chatService!.sendChatRequestStream(
          conversation: _currentConversation!,
          messages: messages,
          model: model,
          platform: platform,
          options: options,
        );

        _streamSubscription = responseStream.listen(
          (message) {
            // 如果生成的message没有ID，使用占位消息ID
            String messageToUseId = message.id;
            if (messageToUseId.isEmpty && _generatingMessageId != null) {
              messageToUseId = _generatingMessageId!;
            }

            // 总是先尝试更新ID匹配的消息
            int index = _currentMessages.indexWhere(
              (m) => m.id == messageToUseId || m.id == _generatingMessageId,
            );

            if (index >= 0) {
              // 创建新消息，保持ID一致性
              final updatedMessage = ChatMessage.assistantText(
                id: _currentMessages[index].id, // 保持原始ID
                text: message.getAllText(),
                conversationId: message.conversationId,
                isFinal: message.isFinal,
                metadata: message.metadata,
              );

              _currentMessages[index] = updatedMessage;
            } else {
              // 尝试查找任何非最终状态的助手消息
              index = _currentMessages.indexWhere(
                (m) => m.role == MessageRole.assistant && !m.isFinal,
              );

              if (index >= 0) {
                // 创建新消息，保持ID一致性,找到非最终状态的助手消息
                final updatedMessage = ChatMessage.assistantText(
                  id: _currentMessages[index].id, // 保持原始ID
                  text: message.getAllText(),
                  conversationId: message.conversationId,
                  isFinal: message.isFinal,
                  metadata: message.metadata,
                );

                _currentMessages[index] = updatedMessage;
              } else {
                // 如果没有找到任何可以更新的消息，作为最后的手段，添加新消息
                _currentMessages.add(message);

                // 更新跟踪ID，以便后续更新
                _generatingMessageId ??= message.id;
              }
            }

            notifyListeners();

            // 如果消息是final状态，立即保存到数据库
            if (message.isFinal) {
              final messageToSave =
                  (index >= 0) ? _currentMessages[index] : message;
              _dbHelper.saveMessage(messageToSave);
            }
          },
          onError: (error) async {
            logger.e('流式生成错误: $error');
            await _handleGenerationError(error.toString());
          },
          onDone: () async {
            // 流式生成完成，保存最后的消息（如果尚未保存）
            final index = _currentMessages.indexWhere(
              (m) => m.id == _generatingMessageId,
            );
            if (index >= 0) {
              final finalMessage = _currentMessages[index];

              // 确保消息被标记为终止状态
              if (!finalMessage.isFinal) {
                final updatedMessage = ChatMessage.assistantText(
                  id: finalMessage.id,
                  text: finalMessage.getAllText(),
                  conversationId: finalMessage.conversationId,
                  isFinal: true,
                  metadata: finalMessage.metadata,
                );

                _currentMessages[index] = updatedMessage;
                await _dbHelper.saveMessage(updatedMessage);
              } else if (_generatingMessageId != null) {
                // 再次检查确保消息已保存
                await _dbHelper.saveMessage(finalMessage);
              }
            }

            _isGenerating = false;
            _generatingMessageId = null;
            _streamSubscription = null;
            notifyListeners();
          },
        );
      } else {
        // 非流式生成
        final response = await _chatService!.sendChatRequest(
          conversation: _currentConversation!,
          messages: messages,
          model: model,
          platform: platform,
          options: options,
        );

        // 更新消息内容
        final index = _currentMessages.indexWhere(
          (m) => m.id == _generatingMessageId,
        );
        if (index >= 0) {
          _currentMessages[index] = response;
        } else {
          _currentMessages.add(response);
        }

        // 保存非流式响应已保存到数据库
        await _dbHelper.saveMessage(response);
        _isGenerating = false;
        _generatingMessageId = null;
        notifyListeners();
      }
    } catch (e) {
      await _handleGenerationError('生成响应时发生错误: $e');
    }
  }

  /// 处理生成错误
  Future<void> _handleGenerationError(String errorMessage) async {
    final index = _currentMessages.indexWhere(
      (m) => m.id == _generatingMessageId,
    );
    if (index >= 0) {
      // 将错误消息更新到占位消息
      _currentMessages[index] = ChatMessage.assistantText(
        id: _generatingMessageId,
        text: '生成回复时出错: $errorMessage',
        conversationId: _currentConversation!.id,
        isFinal: true,
      );

      // 将错误信息保存到数据库
      await _dbHelper.saveMessage(_currentMessages[index]);
    }

    _isGenerating = false;
    _generatingMessageId = null;
    _streamSubscription = null;
    notifyListeners();
  }

  /// 取消生成
  void cancelGeneration() async {
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }

    if (_chatService != null) {
      _chatService!.abortRequest();
    }

    // 如果有正在生成的消息，将其标记为终止状态并保存
    if (_generatingMessageId != null) {
      final index = _currentMessages.indexWhere(
        (m) => m.id == _generatingMessageId,
      );
      if (index >= 0) {
        final currentMessage = _currentMessages[index];

        // 检查是否是思考状态的消息
        final isThinking =
            currentMessage.metadata != null &&
            currentMessage.metadata!.containsKey('is_thinking') &&
            currentMessage.metadata!['is_thinking'] == true;

        // 获取思考过程(如果有)
        final hasThinkingProcess =
            currentMessage.metadata != null &&
            currentMessage.metadata!.containsKey('thinking_process') &&
            currentMessage.metadata!['thinking_process'] != null;

        // 两种情况处理：有思考内容或有正常内容
        if ((isThinking && hasThinkingProcess) ||
            currentMessage.getAllText().isNotEmpty) {
          // 手动终止响应，保存已生成的内容或思考过程

          // 创建新消息的内容
          String finalContent;
          if (isThinking && currentMessage.getAllText().isEmpty) {
            finalContent = '[在思考中终止，无正式回复]';
          } else {
            // 有正常内容，添加终止标记
            finalContent = '${currentMessage.getAllText()}\n[手动终止]';
          }

          // 创建一个新消息，标记为终止状态
          final finalMessage = ChatMessage.assistantText(
            id: currentMessage.id,
            text: finalContent,
            conversationId: currentMessage.conversationId,
            isFinal: true,
            metadata:
                currentMessage.metadata != null
                    ? Map<String, dynamic>.from(currentMessage.metadata!)
                    : <String, dynamic>{},
          );

          // 更新元数据
          finalMessage.metadata ??= {};
          finalMessage.metadata!['manually_terminated'] = true;
          finalMessage.metadata!['termination_time'] =
              DateTime.now().toIso8601String();

          // 如果是思考状态，记录这个信息并移除is_thinking标志
          if (isThinking) {
            finalMessage.metadata!['terminated_during_thinking'] = true;
            // 确保移除is_thinking标志，避免UI显示矛盾状态
            finalMessage.metadata!.remove('is_thinking');
          }

          // 更新UI中的消息
          _currentMessages[index] = finalMessage;

          // 保存到数据库
          await _dbHelper.saveMessage(finalMessage);
        } else {
          // 如果既没有思考过程也没有内容，则从列表中移除
          _currentMessages.removeAt(index);
        }
      }
    }

    _isGenerating = false;
    _generatingMessageId = null;
    notifyListeners();
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    await _dbHelper.deleteMessage(messageId);
    _currentMessages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  /// 删除对话
  Future<void> deleteConversation(String conversationId) async {
    await _dbHelper.deleteConversation(conversationId);

    if (_currentConversation?.id == conversationId) {
      clearCurrentConversation();
    }

    await loadConversations();
  }

  /// 清空对话消息
  Future<void> clearConversationMessages(String conversationId) async {
    await _dbHelper.deleteMessagesForConversation(conversationId);

    if (_currentConversation?.id == conversationId) {
      _currentMessages = [];
      notifyListeners();
    }
  }

  /// 重命名对话
  Future<void> renameConversation(
    String conversationId,
    String newTitle,
  ) async {
    final conversation = await _dbHelper.getConversation(conversationId);
    if (conversation != null) {
      conversation.updateTitle(newTitle);
      await _dbHelper.updateConversation(conversation);

      if (_currentConversation?.id == conversationId) {
        _currentConversation = conversation;
      }

      await loadConversations();
    }
  }

  /// 更新对话系统提示
  Future<void> updateSystemPrompt(
    String conversationId,
    String? systemPrompt,
  ) async {
    final conversation = await _dbHelper.getConversation(conversationId);
    if (conversation != null) {
      conversation.updateSystemPrompt(systemPrompt);
      await _dbHelper.updateConversation(conversation);

      if (_currentConversation?.id == conversationId) {
        _currentConversation = conversation;
      }

      notifyListeners();
    }
  }

  /// 归档对话
  Future<void> archiveConversation(String conversationId) async {
    final conversation = await _dbHelper.getConversation(conversationId);
    if (conversation != null) {
      conversation.archive();
      await _dbHelper.updateConversation(conversation);

      if (_currentConversation?.id == conversationId) {
        clearCurrentConversation();
      }

      await loadConversations();
    }
  }

  /// 重新生成最后的回复
  Future<void> regenerateLastResponse({
    required ModelSpec model,
    required PlatformSpec platform,
  }) async {
    if (_currentConversation == null || _currentMessages.isEmpty) return;

    // 找到最后一条AI消息的索引
    int? lastAssistantIndex;
    for (int i = _currentMessages.length - 1; i >= 0; i--) {
      if (_currentMessages[i].role == MessageRole.assistant) {
        lastAssistantIndex = i;
        break;
      }
    }

    if (lastAssistantIndex != null) {
      // 删除最后一条AI消息
      final lastAssistantMessage = _currentMessages[lastAssistantIndex];
      await _dbHelper.deleteMessage(lastAssistantMessage.id);
      _currentMessages.removeAt(lastAssistantIndex);
      notifyListeners();
    }

    // 获取系统提示（如果有）
    String? systemPrompt = _currentConversation!.systemPrompt;
    List<ChatMessage> messagesToSend = [];

    // 添加系统提示
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messagesToSend.add(
        ChatMessage.system(
          text: systemPrompt,
          conversationId: _currentConversation!.id,
        ),
      );
    }

    // 添加剩余的消息
    messagesToSend.addAll(_currentMessages);

    // 重新生成响应
    await generateResponse(
      messages: messagesToSend,
      model: model,
      platform: platform,
    );
  }

  /// 生成图像
  Future<void> generateImage({
    required String prompt,
    required ModelSpec model,
    required PlatformSpec platform,
    File? referenceImage,
    int? imageCount,
    String? imageSize,
    bool shouldCreateUserMessage = true, // 是否创建用户消息，重新生成时不需要
  }) async {
    if (_isGenerating) {
      // 如果已经在生成中，取消上一次请求
      cancelGeneration();
    }

    // 验证模型类型
    if (model.type != ModelType.image) {
      ToastUtils.showError('所选模型不支持图像生成');
      return;
    }

    _isGenerating = true;
    notifyListeners();

    List<String> imageUrls = [];

    try {
      // 如果没有当前对话，创建一个新对话
      if (_currentConversation == null) {
        // 使用提示作为对话标题
        String title =
            prompt.length > 20 ? '${prompt.substring(0, 20)}...' : prompt;
        title = "图像: $title"; // 添加前缀表明是图像生成对话

        final conversation = await createConversation(
          title: title,
          model: model,
          platform: platform,
        );

        _currentConversation = conversation;
      }

      // 只有在需要创建用户消息时才执行这一步
      if (shouldCreateUserMessage) {
        // 创建用户消息，包含参考图（如果有）
        List<ContentItem> userContent = [ContentItem.text(prompt)];

        // 如果有参考图，添加到用户消息中
        if (referenceImage != null) {
          userContent.add(
            ContentItem.image(
              referenceImage.path,
              filePath: referenceImage.path,
            ),
          );
        }

        // 创建用户消息
        final userMessage = ChatMessage(
          role: MessageRole.user,
          content: userContent,
          conversationId: _currentConversation!.id,
        );

        // 保存消息到数据库
        await _dbHelper.saveMessage(userMessage);

        // 添加到当前消息列表
        _currentMessages.add(userMessage);
        notifyListeners();
      }

      // 创建一个占位消息
      final placeholderMessage = ChatMessage.assistantText(
        text: '正在生成图像...',
        conversationId: _currentConversation!.id,
        isFinal: false,
      );

      _generatingMessageId = placeholderMessage.id;
      _currentMessages.add(placeholderMessage);
      notifyListeners();

      // 创建聊天服务
      _chatService = ChatServiceFactory.create();

      // 设置选项
      Map<String, dynamic> options = {};
      if (imageCount != null && imageCount > 1) {
        options['n'] = imageCount; // 设置生成的图片数量
      }

      // 设置图像尺寸
      if (imageSize != null && imageSize.isNotEmpty) {
        options['size'] = imageSize;
      }

      // 调用生成图像API
      try {
        imageUrls = await _chatService!.generateImage(
          prompt: prompt,
          model: model,
          platform: platform,
          options: options,
          referenceImage: referenceImage,
        );
      } catch (e) {
        logger.e('API调用错误: $e');
        throw Exception('图像生成API调用失败: $e');
      }

      // 检查图像URL是否有效
      if (imageUrls.isNotEmpty) {
        // 创建内容项目列表
        List<ContentItem> contentItems = [ContentItem.text('已生成图像:')];
        List<String> localPaths = [];

        // 保存所有图片并添加到内容列表
        for (int i = 0; i < imageUrls.length; i++) {
          String imageUrl = imageUrls[i];
          // 保存图片到本地（AI生成图片通常有时效）
          String localPath =
              (await saveImageToLocal(imageUrl, showSaveHint: false)) ?? '';
          localPaths.add(localPath);

          // 创建图片内容项
          contentItems.add(ContentItem.image(imageUrl, filePath: localPath));
        }

        // 创建助手回复消息
        final assistantMessage = ChatMessage(
          id: _generatingMessageId ?? const Uuid().v4(),
          role: MessageRole.assistant,
          content: contentItems,
          conversationId: _currentConversation!.id,
          isFinal: true,
          metadata: {
            'prompt': prompt,
            'generation_time': DateTime.now().toIso8601String(),
            'image_urls': imageUrls,
            'local_paths': localPaths,
            'is_image_generation': true,
            'reference_image': referenceImage?.path,
            'is_regeneration': !shouldCreateUserMessage, // 如果不创建用户消息，则为重新生成
            'image_size': imageSize,
            'image_count': imageCount,
          },
        );

        // 替换占位消息
        final index = _currentMessages.indexWhere(
          (m) => m.id == _generatingMessageId,
        );

        if (index >= 0) {
          _currentMessages[index] = assistantMessage;
        } else {
          _currentMessages.add(assistantMessage);
        }

        // 保存到数据库
        await _dbHelper.saveMessage(assistantMessage);
      } else {
        throw Exception('返回的图像URL列表为空');
      }
    } catch (e) {
      logger.e('生成图像错误: $e');

      // 更新占位消息显示错误
      final index = _currentMessages.indexWhere(
        (m) => m.id == _generatingMessageId,
      );

      if (index >= 0) {
        final errorMessage = ChatMessage.assistantText(
          id: _generatingMessageId,
          text: '生成图像失败: ${e.toString().replaceAll('Exception: ', '')}',
          conversationId: _currentConversation!.id,
          isFinal: true,
        );
        _currentMessages[index] = errorMessage;
        await _dbHelper.saveMessage(errorMessage);
      }
    } finally {
      _isGenerating = false;
      _generatingMessageId = null;
      notifyListeners();
    }
  }

  /// 重新生成图像
  Future<void> regenerateImage({
    String? customPrompt, // 可以传入自定义提示，如果不传则使用上一次的提示
    required ModelSpec model,
    required PlatformSpec platform,
    File? referenceImage, // 可以重新指定参考图像
    int? imageCount, // 可以指定生成的图片数量
    String? imageSize, // 可以指定图像尺寸
  }) async {
    if (_currentConversation == null || _currentMessages.isEmpty) return;

    // 找到最后一条用户消息和AI回复消息
    ChatMessage? lastUserMessage;
    ChatMessage? lastAssistantMessage;

    // 从后往前找
    for (int i = _currentMessages.length - 1; i >= 0; i--) {
      final message = _currentMessages[i];
      if (message.role == MessageRole.assistant &&
          lastAssistantMessage == null) {
        lastAssistantMessage = message;
      } else if (message.role == MessageRole.user && lastUserMessage == null) {
        lastUserMessage = message;
      }

      // 如果都找到了，退出循环
      if (lastUserMessage != null && lastAssistantMessage != null) {
        break;
      }
    }

    if (lastUserMessage == null) {
      ToastUtils.showError('未找到用户消息，无法重新生成');
      return;
    }

    // 从用户消息中提取提示文本
    String prompt = '';
    for (var contentItem in lastUserMessage.content) {
      if (contentItem.type == ContentType.text) {
        prompt = contentItem.text ?? '';
        break;
      }
    }

    // 如果提供了自定义提示，则使用自定义提示
    if (customPrompt != null && customPrompt.isNotEmpty) {
      prompt = customPrompt;
    }

    if (prompt.isEmpty) {
      ToastUtils.showError('无法获取生成提示，请重新输入');
      return;
    }

    // 如果有最后一条AI消息，删除它
    if (lastAssistantMessage != null) {
      await _dbHelper.deleteMessage(lastAssistantMessage.id);
      _currentMessages.removeWhere((m) => m.id == lastAssistantMessage!.id);
      notifyListeners();
    }

    // 获取用户消息中的参考图（如果有）
    File? userReferenceImage = referenceImage;
    if (userReferenceImage == null) {
      // 如果没有新的参考图，尝试从用户消息中获取之前的参考图
      for (var contentItem in lastUserMessage.content) {
        if (contentItem.type == ContentType.image &&
            contentItem.filePath != null) {
          final filePath = contentItem.filePath!;
          if (File(filePath).existsSync()) {
            userReferenceImage = File(filePath);
            break;
          }
        }
      }
    }

    // 调用generateImage但不创建新的用户消息
    await generateImage(
      prompt: prompt,
      model: model,
      platform: platform,
      referenceImage: userReferenceImage,
      imageCount: imageCount,
      imageSize: imageSize,
      shouldCreateUserMessage: false, // 不创建新的用户消息
    );
  }

  @override
  void dispose() {
    cancelGeneration();
    super.dispose();
  }
}
