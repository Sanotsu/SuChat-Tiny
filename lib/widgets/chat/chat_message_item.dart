import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/chat_message.dart';
import '../common/custom_markdown_renderer.dart';
import '../common/image_carousel_slider.dart';
import '../common/loading_indicator.dart';
import '../common/text_selection_dialog.dart';
import '../common/toast_utils.dart';

/// 聊天消息项组件
class ChatMessageItem extends StatefulWidget {
  /// 消息数据
  final ChatMessage message;

  /// 是否为最后一条消息
  final bool isLast;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 复制回调
  final VoidCallback? onCopy;

  const ChatMessageItem({
    super.key,
    required this.message,
    this.isLast = false,
    this.onDelete,
    this.onRetry,
    this.onCopy,
  });

  @override
  State<ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<ChatMessageItem> {
  // 思考内容是否展开
  bool _isThinkingExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    final textColor =
        isUser
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface;

    // 检查是否是手动终止的消息
    final isManuallyTerminated =
        widget.message.metadata != null &&
        widget.message.metadata!['manually_terminated'] == true;

    // 检查是否是thinking状态 (如果是手动终止的，不再显示为思考状态)
    final isThinking =
        !isManuallyTerminated &&
        widget.message.metadata != null &&
        widget.message.metadata!.containsKey('is_thinking') &&
        widget.message.metadata!['is_thinking'] == true;

    // 检查是否是在思考过程中被终止的
    final isTerminatedDuringThinking =
        widget.message.metadata != null &&
        widget.message.metadata!['terminated_during_thinking'] == true;

    // 获取思考过程
    final hasThinkingProcess =
        widget.message.metadata != null &&
        widget.message.metadata!.containsKey('thinking_process') &&
        widget.message.metadata!['thinking_process'] != null;

    // 检查是否是图像生成消息
    final isImageGeneration =
        widget.message.metadata != null &&
        widget.message.metadata!['is_image_generation'] == true;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Card(
          color:
              isUser
                  ? Theme.of(context).colorScheme.primary
                  : isThinking
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onLongPress: () => _showMessageOptions(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 如果是思考过程，显示一个指示器 (确保手动终止后不再显示思考指示器)
                  if (isThinking) _buildThinkingIndicator(context, textColor),

                  /// 如果是思考过程中，直接显示思考内容
                  if (isThinking && hasThinkingProcess)
                    // buildThinkingProcess(context, textColor),
                    // 其实和下面共用一个也可以，更统一
                    _buildThinkingContent(context, textColor),

                  // 如果有思考过程、不是思考中、且不是被终止的思考过程，添加可折叠的思考过程
                  if (!isThinking &&
                      hasThinkingProcess &&
                      !isTerminatedDuringThinking)
                    _buildThinkingContent(context, textColor),

                  // 如果不是思考状态，显示正常消息内容
                  if (!isThinking) ...buildMessageContent(context, textColor),

                  // 消息操作
                  if (!isThinking &&
                      widget.message.role == MessageRole.assistant &&
                      widget.message.isFinal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 只有最后一条才可以重新生成
                          if (widget.onRetry != null && widget.isLast)
                            IconButton(
                              icon: Icon(
                                isImageGeneration ? Icons.brush : Icons.refresh,
                                size: 16,
                              ),
                              onPressed: widget.onRetry,
                              tooltip: isImageGeneration ? '重新生成图像' : '重新生成',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () => _copyMessageToClipboard(context),
                            tooltip: '复制',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.share, size: 16),
                            onPressed: () => _shareMessage(context),
                            tooltip: '分享',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 思考指示器
  Widget _buildThinkingIndicator(BuildContext context, Color color) {
    return Row(
      children: [
        Icon(Icons.psychology, size: 16, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          '思考中...',
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 12,
          height: 12,
          child: const LoadingIndicator(size: 12, strokeWidth: 2),
        ),
      ],
    );
  }

  /// 思考过程，还在流式追加中
  Widget buildThinkingProcess(BuildContext context, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: CustomMarkdownRenderer.instance.render(
        widget.message.metadata!['thinking_process'] as String,
        textStyle: TextStyle(
          color: color,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }

  /// 构建可折叠的思考内容
  Widget _buildThinkingContent(BuildContext context, Color color) {
    // 获取思考时长
    final thinkingDuration =
        widget.message.metadata != null &&
                widget.message.metadata!.containsKey('thinking_duration')
            ? widget.message.metadata!['thinking_duration'] as String?
            : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示思考时长（如果有）
          if (thinkingDuration != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                thinkingDuration,
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // 可展开的思考过程
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isThinkingExpanded = !_isThinkingExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    _isThinkingExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                    color: color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isThinkingExpanded ? '隐藏思考过程' : '查看思考过程',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 展开时显示思考内容(和思考过程样式稍微不一样)
          if (_isThinkingExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: CustomMarkdownRenderer.instance.render(
                  widget.message.metadata!['thinking_process'] as String,
                  textStyle: TextStyle(
                    color: color,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建消息内容
  List<Widget> buildMessageContent(BuildContext context, Color textColor) {
    final List<Widget> widgets = [];

    // 检查是否是手动终止的消息
    final bool isManuallyTerminated =
        widget.message.metadata != null &&
        widget.message.metadata!['manually_terminated'] == true;

    // 检查是否是在思考过程中被终止的
    final bool isTerminatedDuringThinking =
        widget.message.metadata != null &&
        widget.message.metadata!['terminated_during_thinking'] == true;

    // 获取思考过程(如果有)
    final hasThinkingProcess =
        widget.message.metadata != null &&
        widget.message.metadata!.containsKey('thinking_process') &&
        widget.message.metadata!['thinking_process'] != null;

    // 处理不同类型的内容
    // for (final content in widget.message.content) {
    //   if (content.type == ContentType.text) {
    //     String messageText = content.text ?? '';

    //     // 如果是手动终止的消息，移除[手动终止]标记以避免重复显示
    //     if (isManuallyTerminated && messageText.endsWith('\n[手动终止]')) {
    //       messageText = messageText.substring(
    //         0,
    //         messageText.length - '\n[手动终止]'.length,
    //       );
    //     }

    //     // 正常的文本内容
    //     widgets.add(
    //       CusMarkdownRenderer.instance.render(
    //         messageText,
    //         textStyle: TextStyle(color: textColor),
    //       ),
    //     );
    //   } else if (content.type == ContentType.image) {
    //     // widgets.add(buildImageCarouselSlider(task.imageUrls!, aspectRatio: 1));

    //     // 图片内容
    //     if (content.filePath != null) {
    //       // 本地图片
    //       widgets.add(
    //         Padding(
    //           padding: const EdgeInsets.symmetric(vertical: 8.0),
    //           child: ClipRRect(
    //             borderRadius: BorderRadius.circular(8.0),
    //             child: Image.file(File(content.filePath!), fit: BoxFit.cover),
    //           ),
    //         ),
    //       );
    //     } else {
    //       // 网络图片
    //       widgets.add(
    //         Padding(
    //           padding: const EdgeInsets.symmetric(vertical: 8.0),
    //           child: ClipRRect(
    //             borderRadius: BorderRadius.circular(8.0),
    //             child: Image.network(
    //               content.mediaUrl ?? '',
    //               fit: BoxFit.cover,
    //               loadingBuilder: (context, child, loadingProgress) {
    //                 if (loadingProgress == null) return child;
    //                 return Center(
    //                   child: CircularProgressIndicator(
    //                     value:
    //                         loadingProgress.expectedTotalBytes != null
    //                             ? loadingProgress.cumulativeBytesLoaded /
    //                                 loadingProgress.expectedTotalBytes!
    //                             : null,
    //                   ),
    //                 );
    //               },
    //               errorBuilder: (context, error, stackTrace) {
    //                 return Container(
    //                   width: 200,
    //                   height: 100,
    //                   color: Colors.grey[300],
    //                   child: const Center(child: Icon(Icons.broken_image)),
    //                 );
    //               },
    //             ),
    //           ),
    //         ),
    //       );
    //     }
    //   }

    //   // 在内容项之间添加间隔
    //   if (widget.message.content.last != content) {
    //     widgets.add(const SizedBox(height: 8.0));
    //   }
    // }

    // 处理不同类型的内容
    // 2025-05-21 一个消息可能有多个content，理论上应该把他们按照不同类型分别拼接起来
    var concatText = '';
    List<String> imageUrls = [];
    for (final content in widget.message.content) {
      // 文本内容
      if (content.type == ContentType.text) {
        String messageText = content.text ?? '';

        // 如果是手动终止的消息，移除[手动终止]标记以避免重复显示
        if (isManuallyTerminated && messageText.endsWith('\n[手动终止]')) {
          messageText = messageText.substring(
            0,
            messageText.length - '\n[手动终止]'.length,
          );
        }

        concatText += messageText;
      } else if (content.type == ContentType.image) {
        // 图片内容
        if (content.filePath != null) {
          // 本地图片
          if (content.filePath!.trim().isNotEmpty) {
            imageUrls.add(content.filePath!);
          }
        } else {
          // 网络图片
          if (content.mediaUrl != null && content.mediaUrl!.trim().isNotEmpty) {
            imageUrls.add(content.mediaUrl!);
          }
        }
      }
    }

    // 正常的文本内容
    widgets.add(
      CustomMarkdownRenderer.instance.render(
        concatText,
        textStyle: TextStyle(color: textColor),
      ),
    );

    if (imageUrls.isNotEmpty) {
      // widgets.add(buildImageCarouselSlider(imageUrls, aspectRatio: 1));

      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              imageUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 2.6,
                        // 添加RepaintBoundary，避免图片重绘影响其他元素
                        child: RepaintBoundary(
                          child: buildImageView(
                            url,
                            context,
                            isFileUrl: true,
                            imageErrorHint: '图片地址异常，无法显示',
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      );
    }

    // 如果是在思考过程中被终止的，显示思考过程
    if (isTerminatedDuringThinking && hasThinkingProcess) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 14,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '思考过程:',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 渲染思考过程
                CustomMarkdownRenderer.instance.render(
                  widget.message.metadata!['thinking_process'] as String,
                  textStyle: TextStyle(
                    color: textColor,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 如果是手动终止的消息，添加一个醒目的终止标记
    if (isManuallyTerminated) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                Text(
                  isTerminatedDuringThinking ? '思考过程已终止' : '手动终止',
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.amber
                            : Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// 显示消息操作选项
  void _showMessageOptions(BuildContext context) {
    // 检查是否是图像生成消息
    final isImageGeneration =
        widget.message.metadata != null &&
        widget.message.metadata!['is_image_generation'] == true;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制'),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessageToClipboard(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('选择文本'),
                onTap: () {
                  Navigator.pop(context);
                  String textToCopy = '';
                  // 提取所有文本内容
                  for (final content in widget.message.content) {
                    if (content.type == ContentType.text) {
                      textToCopy += content.text ?? '';
                    }
                  }
                  showDialog(
                    context: context,
                    builder: (context) => TextSelectionDialog(text: textToCopy),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('分享'),
                onTap: () {
                  Navigator.pop(context);
                  _shareMessage(context);
                },
              ),
              // 如果有思考过程，添加复制思考过程的选项
              if (widget.message.metadata != null &&
                  widget.message.metadata!.containsKey('thinking_process') &&
                  widget.message.metadata!['thinking_process'] != null)
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: const Text('复制思考过程'),
                  onTap: () {
                    Navigator.pop(context);
                    _copyThinkingToClipboard(context);
                  },
                ),
              // 如果是图像生成消息，添加复制提示词的选项
              if (isImageGeneration &&
                  widget.message.metadata != null &&
                  widget.message.metadata!.containsKey('prompt'))
                ListTile(
                  leading: const Icon(Icons.format_quote),
                  title: const Text('复制生成提示词'),
                  onTap: () {
                    Navigator.pop(context);
                    _copyPromptToClipboard(context);
                  },
                ),
              if (widget.onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('删除', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                ),
              // 只有最后一条AI响应可以重新生成
              if (widget.message.role == MessageRole.assistant &&
                  widget.onRetry != null &&
                  widget.isLast)
                ListTile(
                  leading: Icon(
                    isImageGeneration ? Icons.brush : Icons.refresh,
                  ),
                  title: Text(isImageGeneration ? '重新生成图像' : '重新生成'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRetry!();
                  },
                ),
            ],
          ),
    );
  }

  /// 复制消息到剪贴板
  void _copyMessageToClipboard(BuildContext context) {
    String textToCopy = '';

    // 提取所有文本内容
    for (final content in widget.message.content) {
      if (content.type == ContentType.text) {
        textToCopy += content.text ?? '';
      }
    }

    if (textToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textToCopy));
      ToastUtils.showSuccess('已复制到剪贴板');
    }
  }

  /// 复制思考过程到剪贴板
  void _copyThinkingToClipboard(BuildContext context) {
    if (widget.message.metadata != null &&
        widget.message.metadata!.containsKey('thinking_process') &&
        widget.message.metadata!['thinking_process'] != null) {
      final String thinkingProcess =
          widget.message.metadata!['thinking_process'] as String;

      Clipboard.setData(ClipboardData(text: thinkingProcess));

      ToastUtils.showSuccess('已复制思考过程到剪贴板');
    }
  }

  /// 复制提示词到剪贴板
  void _copyPromptToClipboard(BuildContext context) {
    if (widget.message.metadata != null &&
        widget.message.metadata!.containsKey('prompt')) {
      final prompt = widget.message.metadata!['prompt'] as String;
      Clipboard.setData(ClipboardData(text: prompt));
      ToastUtils.showSuccess('已复制提示词到剪贴板');
    }
  }

  /// 分享消息
  void _shareMessage(BuildContext context) {
    String textToShare = '';

    // 提取所有文本内容
    for (final content in widget.message.content) {
      if (content.type == ContentType.text) {
        textToShare += content.text ?? '';
      }
    }

    if (textToShare.isNotEmpty) {
      SharePlus.instance.share(ShareParams(text: textToShare));
    }
  }
}
