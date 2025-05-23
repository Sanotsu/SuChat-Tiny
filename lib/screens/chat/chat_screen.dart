import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../core/utils/tools.dart';
import '../../models/chat_message.dart';
import '../../models/model_spec.dart';
import '../../models/platform_spec.dart';
import '../../models/conversation.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/model_provider.dart';
import '../../providers/platform_provider.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/chat_message_item.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/custom_dropdown.dart';
import '../../widgets/common/small_tool_widgets.dart';
import '../../widgets/common/toast_utils.dart';
import '../settings/index.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 声明属性来保存常用Provider和状态
  late ConversationProvider _conversationProvider;
  late PlatformProvider _platformProvider;
  late ModelProvider _modelProvider;
  List<ChatMessage> _messages = [];
  Conversation? _currentConversation;
  bool _isGenerating = false;
  PlatformSpec? _selectedPlatform;
  ModelSpec? _selectedModel;
  List<Conversation> _conversations = [];

  // 添加一个标志，用于跟踪用户是否正在手动滚动
  bool _userScrolling = false;

  // 判断当前是否为图片生成模式
  bool get _isImageGenerationMode => _selectedModel?.type == ModelType.image;

  // 追踪历史记录抽屉长按位置的偏移量(用于弹窗显示操作按钮)
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    // 添加滚动监听器
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    // 移除滚动监听器
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听回调
  void _scrollListener() {
    // 如果用户正在滚动，记录当前位置
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _userScrolling = true;
    }

    // 如果用户滚动到了底部，重置标志
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent) {
      _userScrolling = false;
    }
  }

  Future<void> _loadInitialData() async {
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    // 首先加载平台列表
    await platformProvider.loadPlatforms();

    // 加载对话历史
    await conversationProvider.loadConversations();

    // 尝试加载最近的对话
    final recentConversation =
        await conversationProvider.loadRecentConversation();

    if (recentConversation != null) {
      // 如果有最近对话，设置对应的平台和模型
      await _updatePlatformAndModelForConversation(recentConversation);
    } else {
      // 如果没有最近对话，使用默认的第一个平台和模型
      if (platformProvider.platforms.isNotEmpty) {
        final firstPlatform = platformProvider.platforms.first;
        platformProvider.selectPlatform(firstPlatform);

        // 加载选定平台的模型
        await modelProvider.loadModelsByPlatform(firstPlatform.id);

        // 如果该平台有模型，选择第一个模型
        if (modelProvider.models.isNotEmpty) {
          modelProvider.selectModel(modelProvider.models.first);
        }
      } else {
        // 如果没有平台，加载所有模型
        await modelProvider.loadModels();
      }
    }
  }

  // 根据对话更新平台和模型选择
  Future<void> _updatePlatformAndModelForConversation(
    Conversation conversation,
  ) async {
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);

    // 查找对应平台
    final platformExists = platformProvider.platforms.any(
      (p) => p.id == conversation.platformId,
    );

    if (platformExists) {
      // 找到平台并选中
      final platform = platformProvider.platforms.firstWhere(
        (p) => p.id == conversation.platformId,
      );
      platformProvider.selectPlatform(platform);

      // 加载该平台的模型
      await modelProvider.loadModelsByPlatform(platform.id);

      // 查找对应模型
      final modelExists = modelProvider.models.any(
        (m) => m.id == conversation.modelId,
      );

      if (modelExists) {
        // 找到模型并选中
        final model = modelProvider.models.firstWhere(
          (m) => m.id == conversation.modelId,
        );
        modelProvider.selectModel(model);
      } else if (modelProvider.models.isNotEmpty) {
        ToastUtils.showInfo('该对话使用模型不存在，切换到该平台第一个模型');
        // 如果模型不存在但有其他模型，选择第一个
        modelProvider.selectModel(modelProvider.models.first);
      }
    } else if (platformProvider.platforms.isNotEmpty) {
      ToastUtils.showInfo('该对话使用平台不存在，切换到默认的第一个平台');

      // 如果平台不存在，使用第一个平台
      final firstPlatform = platformProvider.platforms.first;
      platformProvider.selectPlatform(firstPlatform);

      // 加载该平台的模型
      await modelProvider.loadModelsByPlatform(firstPlatform.id);

      // 如果有模型，选择第一个
      if (modelProvider.models.isNotEmpty) {
        modelProvider.selectModel(modelProvider.models.first);
      }
    }
  }

  // 更新状态的方法
  void _updateState() {
    _conversationProvider = Provider.of<ConversationProvider>(context);
    _platformProvider = Provider.of<PlatformProvider>(context);
    _modelProvider = Provider.of<ModelProvider>(context);

    // 当前会话中的消息
    _messages = _conversationProvider.currentMessages;
    _currentConversation = _conversationProvider.currentConversation;

    // 是否正在生成回复
    _isGenerating = _conversationProvider.isGenerating;

    // 选定的平台和模型
    _selectedPlatform = _platformProvider.selectedPlatform;
    _selectedModel = _modelProvider.selectedModel;

    // 获取所有对话
    _conversations = _conversationProvider.conversations;
  }

  void _scrollToBottom() {
    // 只有当用户没有手动滚动时，才自动滚动到底部
    if (_scrollController.hasClients && !_userScrolling) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 刷新平台和模型数据
  Future<void> _refreshPlatformsAndModels() async {
    // 重新加载平台和模型数据
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);

    await platformProvider.loadPlatforms();

    // 如果有选择的平台，重新加载该平台的模型
    if (_selectedPlatform != null) {
      await modelProvider.loadModelsByPlatform(_selectedPlatform!.id);

      // 重要：检查当前选中的模型是否还存在于更新后的模型列表中
      if (_selectedModel != null) {
        final modelStillExists = modelProvider.models.any(
          (m) => m.id == _selectedModel!.id,
        );
        if (!modelStillExists) {
          // 如果当前选中的模型不再存在，则重置为null或设置为列表中的第一个
          _selectedModel =
              modelProvider.models.isNotEmpty
                  ? modelProvider.models.first
                  : null;
          // 更新Provider中的选中模型
          if (_selectedModel != null) {
            modelProvider.selectModel(_selectedModel!);
          }
        } else {
          // 如果模型仍然存在，但需要获取更新后的实例
          _selectedModel = modelProvider.models.firstWhere(
            (m) => m.id == _selectedModel!.id,
          );
          modelProvider.selectModel(_selectedModel!);
        }
      }
    }

    // 重新加载最新状态
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 更新状态
    _updateState();

    // 当消息列表更新时滚动到底部，但尊重用户的滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _currentConversation?.title ?? '新对话',
          style: TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () async {
            // 打开抽屉前刷新对话列表
            await _conversationProvider.loadConversations();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          if (_currentConversation != null) _buildToolButton(),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              ).then((value) async {
                // 从设置页面回来，可能有改动到平台和模型的内容，所以重新加载
                await _refreshPlatformsAndModels();
              });
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: GestureDetector(
        // 允许子控件（如TextField）接收点击事件
        behavior: HitTestBehavior.translucent,
        // 点击空白处可以移除焦点，关闭键盘
        onTap: unfocusHandle,
        child: Stack(
          children: [
            Column(
              children: [
                // 模型选择区域
                _buildPlatformAndModelSelect(),

                // 消息列表
                _buildMessageList(),

                // 正在生成指示器
                _buildGeneratingIndicator(),

                // 输入区域
                _buildChatInput(),
              ],
            ),
            // 自定义新增对话按钮的位置
            Positioned(
              top: 4,
              right: 4,
              child: FloatingActionButton(
                shape: const CircleBorder(),
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                mini: true,
                onPressed: () {
                  // 清除当前对话状态，不立即创建新对话
                  _conversationProvider.clearCurrentConversation();
                },
                tooltip: '新建对话',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        // 通过stack自定义位置
        // floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
        // floatingActionButton: FloatingActionButton(
        //   mini: true,
        //   onPressed: () {
        //     // 清除当前对话状态，不立即创建新对话
        //     _conversationProvider.clearCurrentConversation();
        //   },
        //   tooltip: '新建对话',
        //   child: const Icon(Icons.add),
        // ),
      ),
    );
  }

  /// 绘制右上角工具按钮
  /// 2025-05-21 添加右上角工具按钮，用于重命名、设置系统提示词、清空消息、删除对话
  /// TODO 这有个大问题，必须用户发送消息之后才会创建对话(避免生成无意义的空对话)，
  /// 但发送之后再补充系统提示词就很怪，这一堆功能都依靠对话编号，所以又必须先有对话
  /// => 目前是发送消息构建好对话->清除对话->添加系统提示词->发送消息进行对话……
  Widget _buildToolButton() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        final conversationId = _currentConversation!.id;
        switch (value) {
          case 'rename':
            // 重命名对话
            final newTitle = await _showRenameDialog(
              context,
              _currentConversation!.title,
            );
            if (newTitle != null && newTitle.isNotEmpty) {
              await _conversationProvider.renameConversation(
                conversationId,
                newTitle,
              );
            }
            break;

          case 'system_prompt':
            // 设置系统提示词
            final newPrompt = await _showSystemPromptDialog(
              context,
              _currentConversation!.systemPrompt,
            );
            if (newPrompt != null) {
              await _conversationProvider.updateSystemPrompt(
                conversationId,
                newPrompt.isEmpty ? null : newPrompt,
              );
            }
            break;

          case 'clear':
            // 清空消息
            final confirm = await _showConfirmDialog(
              context,
              '清空消息',
              '确定要清空此对话中的所有消息吗？此操作不可恢复。',
            );
            if (confirm) {
              await _conversationProvider.clearConversationMessages(
                conversationId,
              );
            }
            break;

          case 'delete':
            // 删除对话
            final confirm = await _showConfirmDialog(
              context,
              '删除对话',
              '确定要删除此对话吗？此操作不可恢复。',
            );
            if (confirm) {
              await _conversationProvider.deleteConversation(conversationId);
            }
            break;
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem<String>(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Text('重命名'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'system_prompt',
              child: Row(
                children: [
                  Icon(Icons.message, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Text('系统提示词'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.cleaning_services, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Text('清空消息'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('删除对话', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  /// 绘制抽屉
  Widget _buildDrawer() {
    return SafeArea(
      child: Drawer(
        child: Column(
          children: [
            // DrawerHeader(
            //   decoration: BoxDecoration(
            //     color: Theme.of(context).colorScheme.primary,
            //   ),
            //   child: Center(
            //     child: Column(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         Icon(
            //           Icons.chat_bubble_outline,
            //           size: 48,
            //           color: Theme.of(context).colorScheme.onPrimary,
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           '对话历史',
            //           style: Theme.of(context).textTheme.titleLarge?.copyWith(
            //             color: Theme.of(context).colorScheme.onPrimary,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            // 使用 SizedBox 来占位状态栏的高度
            SizedBox(height: MediaQuery.of(context).padding.top),

            Expanded(
              child:
                  _conversations.isEmpty
                      ? Center(
                        child: Text(
                          '没有历史对话',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                      : ListView.builder(
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return _buildConversationItem(conversation);
                        },
                      ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建对话'),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                // 清除当前对话状态，不立即创建新对话
                _conversationProvider.clearCurrentConversation();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 构建平台和模型选择区域
  Widget _buildPlatformAndModelSelect() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: buildDropdownButton2<PlatformSpec?>(
                  value: _selectedPlatform,
                  items: _platformProvider.platforms,
                  height: 48,
                  labelSize: 14,
                  hintLabel: "选择平台",
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  // backgroundColor: Colors.red,
                  onChanged: (platform) {
                    if (platform != null) {
                      _platformProvider.selectPlatform(platform);
                      _modelProvider.loadModelsByPlatform(platform.id);
                    }
                  },
                  itemToString: (e) => (e as PlatformSpec).name,
                  itemToId: (e) => (e as PlatformSpec).id,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: buildDropdownButton2<ModelSpec?>(
                  value: _selectedModel,
                  items: _modelProvider.models,
                  height: 48,
                  labelSize: 14,
                  hintLabel: "选择模型",
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onChanged: (model) {
                    if (model != null) {
                      final previousModel = _selectedModel;
                      _modelProvider.selectModel(model);

                      // 如果切换到图片生成模型，显示提示
                      if (model.type == ModelType.image) {
                        ToastUtils.showInfo('已切换到图像生成模式');
                        // 清除当前对话，准备创建新的图像生成对话
                        _conversationProvider.clearCurrentConversation();
                      }
                      // 如果从图片生成模型切换到其他模型
                      else if (previousModel?.type == ModelType.image) {
                        ToastUtils.showInfo('已退出图像生成模式');
                        // 清除当前对话，准备创建新的对话
                        _conversationProvider.clearCurrentConversation();
                      }
                    }
                  },
                  itemToString: (e) => (e as ModelSpec).name,
                  itemToId: (e) => (e as ModelSpec).id,
                ),
              ),
              // 新建对话按钮宽度48,右侧已经有外边距4，所以左边再留4,也就是空48+4
              const SizedBox(width: 52),
            ],
          ),

          // 显示当前模型类型的指示器
          if (_selectedModel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color:
                    _isImageGenerationMode
                        ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getModelTypeIcon(_selectedModel!.type),
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    MT_NAME_MAP[_selectedModel!.type] ?? '未知类型',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Expanded(child: _buildEmptyState());
    }

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];

          // 检查是否是图像生成消息
          final isImageGeneration =
              message.metadata != null &&
              message.metadata!['is_image_generation'] == true;

          return Padding(
            padding: EdgeInsets.all(0),
            child: ChatMessageItem(
              message: message,
              isLast: index == _messages.length - 1,
              onRetry: () async {
                if (_selectedModel != null && _selectedPlatform != null) {
                  if (isImageGeneration &&
                      _selectedModel!.type == ModelType.image) {
                    // 获取相关的用户消息
                    ChatMessage? userMessage;
                    for (int i = index - 1; i >= 0; i--) {
                      if (_messages[i].role == MessageRole.user) {
                        userMessage = _messages[i];
                        break;
                      }
                    }

                    // 检查是否有参考图片
                    File? referenceImage;
                    if (userMessage != null) {
                      for (final contentItem in userMessage.content) {
                        if (contentItem.type == ContentType.image &&
                            contentItem.filePath != null) {
                          final path = contentItem.filePath!;
                          if (File(path).existsSync()) {
                            referenceImage = File(path);
                            break;
                          }
                        }
                      }
                    }

                    // 获取原始消息中保存的图像尺寸和数量
                    String? imageSize;
                    int? imageCount;

                    if (message.metadata != null) {
                      // 从元数据中获取图像尺寸
                      if (message.metadata!.containsKey('image_size')) {
                        imageSize = message.metadata!['image_size'] as String?;
                      }

                      // 从元数据中获取图像数量
                      if (message.metadata!.containsKey('image_count')) {
                        final countValue = message.metadata!['image_count'];
                        if (countValue is int) {
                          imageCount = countValue;
                        } else if (countValue is String) {
                          // 尝试将字符串转换为int
                          imageCount = int.tryParse(countValue);
                        }
                      }
                    }

                    // 如果是图像生成消息，调用regenerateImage方法
                    await _conversationProvider.regenerateImage(
                      model: _selectedModel!,
                      platform: _selectedPlatform!,
                      referenceImage: referenceImage,
                      imageSize: imageSize, // 传递原始图像尺寸
                      imageCount: imageCount, // 传递原始图像数量
                    );
                  } else {
                    // 常规文本消息重新生成
                    await _conversationProvider.regenerateLastResponse(
                      model: _selectedModel!,
                      platform: _selectedPlatform!,
                    );
                  }
                }
              },
              onDelete: () async {
                await _conversationProvider.deleteMessage(message.id);
              },
            ),
          );
        },
      ),
    );
  }

  /// 构建正在生成指示器
  Widget _buildGeneratingIndicator() {
    if (!_isGenerating) return const SizedBox.shrink();

    // TODO 后续思考一下如何把这个使用Stack放在消息列表上层，但是要兼容输入框扩大之后的位置
    // if (!_isGenerating) {
    //   return Container(
    //     color: Colors.transparent,
    //     child: Row(
    //       children: [
    //         const Spacer(),
    //         IconButton(
    //           // 清除当前对话状态，但不立即创建新对话
    //           onPressed: () => _conversationProvider.clearCurrentConversation(),
    //           style: TextButton.styleFrom(
    //             minimumSize: Size.zero,
    //             padding: EdgeInsets.zero,
    //             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    //           ),
    //           icon: const Icon(Icons.add_circle_outline),
    //         ),
    //         const SizedBox(width: 8),
    //       ],
    //     ),
    //   );
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingIndicator(size: 12, strokeWidth: 2),
          const SizedBox(width: 8),
          Text(
            '正在生成回复...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(width: 16),
          TextButton(
            onPressed: () {
              _conversationProvider.cancelGeneration();
            },
            style: TextButton.styleFrom(
              // 将最小尺寸设置为零
              minimumSize: Size.zero,
              // 将内边距设置为零
              padding: EdgeInsets.zero,
              // 缩小点击目标区域
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 构建输入框
  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ChatInput(
        onSendText: (text) async {
          if (_selectedModel != null && _selectedPlatform != null) {
            await _conversationProvider.sendTextMessage(
              text: text,
              model: _selectedModel!,
              platform: _selectedPlatform!,
            );
          }
        },
        onSendImage: (images, caption) async {
          if (_selectedModel != null &&
              _selectedPlatform != null &&
              _selectedModel!.supportsVision) {
            await _conversationProvider.sendImageMessage(
              images: images,
              caption: caption,
              model: _selectedModel!,
              platform: _selectedPlatform!,
            );
          } else {
            ToastUtils.showError('所选模型不支持图像功能');
          }
        },
        // 图片生成回调
        onGenerateImage: (
          prompt, {
          File? referenceImage,
          String? imageSize,
          int? imageCount,
        }) async {
          if (_selectedModel != null &&
              _selectedPlatform != null &&
              _selectedModel!.type == ModelType.image) {
            await _conversationProvider.generateImage(
              prompt: prompt,
              model: _selectedModel!,
              platform: _selectedPlatform!,
              referenceImage: referenceImage,
              imageSize: imageSize,
              imageCount: imageCount,
            );
          } else {
            ToastUtils.showError('所选模型不支持图像生成');
          }
        },
        // onSendFile: (files, caption) async {
        //   if (_selectedModel != null &&
        //       _selectedPlatform != null &&
        //       _selectedModel!.supportsVision) {
        //     log.info('files: $files, caption: $caption');
        //     ToastUtils.showInfo('暂不支持上传文件');
        //   } else {
        //     ToastUtils.showError('所选模型不支持上传文件');
        //   }
        // },
        showImageButton: _selectedModel?.supportsVision ?? false,
        enabled:
            !_isGenerating &&
            _selectedModel != null &&
            _selectedPlatform != null,
        // 设置图片生成模式
        isImageGenerationMode: _isImageGenerationMode,
        // 设置是否支持参考图
        supportsReferenceImage:
            _selectedModel?.extraAttributes?['supports_reference_image'] ==
            true,
        // 根据模式设置提示信息
        placeholder: _isImageGenerationMode ? '输入图像描述...' : '输入消息...',
      ),
    );
  }

  ///
  /// 下面的就不是主build方法中的了，一般是更小的组件
  /// 会话列表项
  ///
  Widget _buildConversationItem(Conversation conversation) {
    final isSelected = _currentConversation?.id == conversation.id;

    // 2025-05-21 这里显示平台和模型有问题，模型会是始终时未知，只要对话中有切换模型
    // // 这里理论上一定有的，所以不判断为空或者其他报错
    // var platformName = "[未知平台]";
    // var modelName = "[未知模型]";
    // var plats = _platformProvider.platforms.where(
    //   (e) => e.id == conversation.platformId,
    // );
    // var mods = _modelProvider.models.where((e) => e.id == conversation.modelId);

    // if (plats.isNotEmpty) {
    //   platformName = plats.first.name;
    // }
    // if (mods.isNotEmpty) {
    //   modelName = mods.first.name;
    // }

    return GestureDetector(
      onLongPress: () {
        // 长按处理，显示上下文菜单
        _showContextMenu(context, conversation);
      },
      onTapDown: (TapDownDetails details) {
        // 记录长按的位置，用于显示菜单
        _tapPosition = details.globalPosition;
      },
      child: ListTile(
        dense: true,
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          // '$platformName $modelName\n'
          '更新于: ${formatRecentDate(conversation.updatedAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        // leading: CircleAvatar(
        //   backgroundColor:
        //       isSelected
        //           ? Theme.of(context).colorScheme.primary
        //           : Theme.of(context).colorScheme.surfaceContainerHighest,
        //   child: Icon(
        //     Icons.chat,
        //     color:
        //         isSelected
        //             ? Theme.of(context).colorScheme.onPrimary
        //             : Theme.of(context).colorScheme.onSurfaceVariant,
        //   ),
        // ),
        selected: isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        onTap: () async {
          // 加载会话并切换
          _conversationProvider.setCurrentConversation(conversation);

          // 更新平台和模型选择以匹配对话
          await _updatePlatformAndModelForConversation(conversation);

          if (!mounted) return;
          Navigator.pop(context); // 关闭抽屉
        },
      ),
    );
  }

  // 在长按位置显示上下文菜单
  void _showContextMenu(BuildContext context, Conversation conversation) async {
    // 获取RenderBox以定位菜单
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // 创建菜单项
    final List<PopupMenuEntry<String>> items = [
      PopupMenuItem<String>(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit, color: Colors.grey, size: 20),
            SizedBox(width: 10),
            Text('重命名'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text('删除', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];

    // 显示菜单并获取结果
    final String? result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        _tapPosition & Size(40, 40), // 长按位置和一个小区域
        Offset.zero & overlay.size, // 整个屏幕的大小
      ),
      items: items,
    );

    // 处理菜单选择结果
    if (context.mounted && result != null) {
      switch (result) {
        case 'rename':
          final newTitle = await _showRenameDialog(context, conversation.title);
          if (newTitle != null && newTitle.isNotEmpty) {
            await _conversationProvider.renameConversation(
              conversation.id,
              newTitle,
            );
          }
          break;
        case 'delete':
          final confirm = await _showConfirmDialog(
            context,
            '删除对话',
            '确定要删除此对话吗？此操作不可恢复。',
          );
          if (confirm) {
            await _conversationProvider.deleteConversation(conversation.id);
          }
          break;
      }
    }
  }

  // 空消息状态
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .5),
            ),
            const SizedBox(height: 16),
            Text('开始新的对话', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '在下方输入框中发送消息开始聊天',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 重命名对话对话框
  Future<String?> _showRenameDialog(BuildContext context, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('重命名对话'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '对话名称',
                hintText: '输入对话名称',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(context, text);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  // 系统提示词对话框
  Future<String?> _showSystemPromptDialog(
    BuildContext context,
    String? currentPrompt,
  ) {
    final controller = TextEditingController(text: currentPrompt ?? '');
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('系统提示词'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '系统提示词',
                hintText: '输入系统提示词（可选）',
              ),
              maxLines: 5,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.text = '';
                  Navigator.pop(context, '');
                },
                child: const Text('清除'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, controller.text.trim());
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  // 确认对话框
  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // 获取模型类型对应的图标
  IconData _getModelTypeIcon(ModelType type) {
    switch (type) {
      case ModelType.text:
        return Icons.chat_bubble_outline;
      case ModelType.vision:
        return Icons.visibility;
      case ModelType.image:
        return Icons.brush;
      // default:
      //   return Icons.help_outline;
    }
  }
}
