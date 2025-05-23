import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/file_picker_helper.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/utils/tools.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/model_provider.dart';
import '../../providers/platform_provider.dart';
import '../common/small_tool_widgets.dart';
import '../common/toast_utils.dart';

/// 发送图片回调
typedef OnSendImage = void Function(List<File> images, String caption);

/// 发送文件回调
typedef OnSendFile = void Function(List<File> files, String caption);

/// 聊天输入组件
class ChatInput extends StatefulWidget {
  /// 发送文本回调
  final Function(String text) onSendText;

  /// 发送图片回调
  final OnSendImage? onSendImage;

  /// 发送文件回调
  final OnSendFile? onSendFile;

  /// 生成图片回调
  final Function(
    String prompt, {
    File? referenceImage,
    String? imageSize,
    int? imageCount,
  })?
  onGenerateImage;

  /// 是否启用输入框
  final bool enabled;

  /// 是否显示图片选择按钮
  final bool showImageButton;

  /// 是否显示文件选择按钮
  final bool showFileButton;

  /// 是否显示语音输入按钮
  final bool showVoiceButton;

  /// 是否为图片生成模式
  final bool isImageGenerationMode;

  /// 当前模型是否支持参考图
  final bool supportsReferenceImage;

  /// 占位文本
  final String placeholder;

  const ChatInput({
    super.key,
    required this.onSendText,
    this.onSendImage,
    this.onSendFile,
    this.onGenerateImage,
    this.enabled = true,
    this.showImageButton = true,
    this.showFileButton = true,
    this.showVoiceButton = true,
    this.isImageGenerationMode = false,
    this.supportsReferenceImage = false,
    this.placeholder = '输入消息...',
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  // 输入框焦点，用于检测文本输入框聚焦时，键盘展开，在小尺寸手机可能会因为输入框+键盘高度超过屏幕高度，导致溢出报错
  // 所以展开时固定输入框区域180（小米6测试1080P）,可以滚动查看
  final FocusNode _focusNode = FocusNode();
  bool _isKeyboardVisible = false;

  // 正在输入
  bool _isComposing = false;
  // 选中的图片
  final List<File> _selectedImages = [];
  // 选中的文件
  final List<File> _selectedFiles = [];

  // 添加参考图
  File? _referenceImage;

  // 添加图像生成参数
  String _selectedImageSize = '1024x1024';
  int _selectedImageCount = 1;

  // 图像尺寸选项
  final List<String> _imageSizes = [
    '256x256',
    '512x512',
    '1024x1024',
    '1024x1792',
    '1792x1024',
  ];

  // 图像数量选项
  final List<int> _imageCounts = [1, 2, 3, 4];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isKeyboardVisible = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedFiles.isEmpty) {
      return;
    }

    if (widget.isImageGenerationMode && text.trim().isNotEmpty) {
      // 图像生成模式下，调用图像生成回调
      if (widget.onGenerateImage != null) {
        widget.onGenerateImage!(
          text,
          referenceImage: _referenceImage,
          imageSize: _selectedImageSize,
          imageCount: _selectedImageCount,
        );
        _controller.clear();
        setState(() {
          _isComposing = false;
          _referenceImage = null; // 清除参考图
        });
      }
    } else if (_selectedImages.isNotEmpty && widget.onSendImage != null) {
      widget.onSendImage!(_selectedImages, text);
      _controller.clear();
      setState(() {
        _isComposing = false;
        _selectedImages.clear();
      });
    } else if (_selectedFiles.isNotEmpty && widget.onSendFile != null) {
      widget.onSendFile!(_selectedFiles, text);
      _controller.clear();
      setState(() {
        _isComposing = false;
        _selectedFiles.clear();
      });
    } else if (text.trim().isNotEmpty) {
      _controller.clear();
      // 使用新的发送消息方法，支持自动创建对话
      _sendTextMessage(text);
      setState(() {
        _isComposing = false;
      });
    }

    // 收起键盘
    unfocusHandle();
  }

  Future<void> _pickImage() async {
    final pickedImages = await ImagePickerHelper.pickMultipleImages();

    if (pickedImages.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(
          pickedImages.map((xFile) => File(xFile.path)).toList(),
        );
        _isComposing = true;
      });
    }
  }

  Future<void> _takePicture() async {
    final pickedImage = await ImagePickerHelper.takePhotoAndSave();

    if (pickedImage != null) {
      setState(() {
        _selectedImages.add(File(pickedImage.path));
        _isComposing = true;
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePickerHelper.pickAndSaveMultipleFiles(
      fileType: CusFileType.any,
      overwrite: true,
    );

    if (result.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(result);
        _isComposing = true;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _isComposing =
          _controller.text.trim().isNotEmpty ||
          _selectedImages.isNotEmpty ||
          _selectedFiles.isNotEmpty;
    });
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _isComposing =
          _controller.text.trim().isNotEmpty ||
          _selectedImages.isNotEmpty ||
          _selectedFiles.isNotEmpty;
    });
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
            ],
          ),
    );
  }

  // 发送文本消息
  void _sendTextMessage(String text) {
    if (text.trim().isEmpty) return;

    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );

    final model = modelProvider.selectedModel;
    final platform = platformProvider.selectedPlatform;

    if (model == null || platform == null) {
      ToastUtils.showInfo('请先选择模型和平台');
      return;
    }

    // 发送消息
    conversationProvider.sendTextMessage(
      text: text,
      model: model,
      platform: platform,
    );

    // 清空输入框
    _controller.clear();

    // 收起键盘
    unfocusHandle();
  }

  // 选择参考图
  Future<void> _pickReferenceImage() async {
    final pickedImage = await ImagePickerHelper.pickSingleImage();

    if (pickedImage != null) {
      setState(() {
        _referenceImage = pickedImage;
      });

      ToastUtils.showSuccess('已添加参考图片');
    }
  }

  // 移除参考图
  void _removeReferenceImage() {
    setState(() {
      _referenceImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        // maxHeight: _isKeyboardVisible ? 180 : double.infinity,
        // 2025-05-21 上面测试用，开发机不报溢出错。实际使用时不限制高度
        maxHeight: _isKeyboardVisible ? double.infinity : double.infinity,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
          borderRadius: BorderRadius.circular(16.0),
          color: Theme.of(context).cardColor,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 预览区域
              if (_selectedImages.isNotEmpty || _selectedFiles.isNotEmpty)
                _buildPreviewArea(),

              // 参考图预览
              if (widget.isImageGenerationMode &&
                  widget.supportsReferenceImage &&
                  _referenceImage != null)
                _buildReferenceImagePreview(),

              // 如果是图片生成模式，显示相关提示
              if (widget.isImageGenerationMode)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '图像生成模式：输入描述内容，模型将生成对应图像',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 输入框区域
              _buildInputArea(),

              // 工具按钮区域
              _buildToolbarArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片预览
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(4),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_selectedImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // 文件预览
          if (_selectedFiles.isNotEmpty)
            SizedBox(
              height: 100,
              child: SingleChildScrollView(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getFileIcon(file.path.split('.').last),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        file.path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        formatFileSize(file.lengthSync()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeFile(index),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  // textAlign: TextAlign.justify, // 双端对齐
                  decoration: InputDecoration(
                    hintText:
                        widget.isImageGenerationMode
                            ? '输入图像描述...'
                            : widget.placeholder,
                    border: InputBorder.none,
                    // 给输入框增加内边距，避免遮挡放大按钮（根据按钮显示位置来确定空哪些边距）
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  onChanged: (text) {
                    setState(() {
                      _isComposing =
                          text.trim().isNotEmpty ||
                          _selectedImages.isNotEmpty ||
                          _selectedFiles.isNotEmpty;
                    });
                  },
                  onSubmitted:
                      widget.enabled && _isComposing ? _handleSubmitted : null,
                ),
                // 按钮使用Material包装，提高可点击性
                if (_controller.text.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '清空输入',
                      onPressed:
                          widget.enabled
                              ? () => setState(() => _controller.text = "")
                              : null,
                      color: Theme.of(context).colorScheme.primary,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(24, 24), // 最小尺寸
                        padding: EdgeInsets.zero, // 移除内边距
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap, // 缩小点击区域
                        visualDensity: VisualDensity.compact, // 紧凑模式
                        // iconSize: 20, // 图标大小
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),

      child: Row(
        children: [
          // 不在图片生成模式下才显示这些图标
          if (!widget.isImageGenerationMode) ...[
            // 图片按钮
            if (widget.showImageButton && widget.onSendImage != null)
              IconButton(
                icon: const Icon(Icons.image),
                tooltip: '发送图片',
                onPressed: widget.enabled ? _showImageOptions : null,
              ),

            // 文件按钮
            if (widget.showFileButton && widget.onSendFile != null)
              IconButton(
                icon: const Icon(Icons.attach_file),
                tooltip: '发送文件',
                onPressed: widget.enabled ? _pickFiles : null,
              ),

            // 语音按钮
            // 2025-05-23 暂时不弄
            // if (widget.showVoiceButton)
            //   IconButton(
            //     icon: const Icon(Icons.mic),
            //     tooltip: '语音输入',
            //     onPressed:
            //         widget.enabled
            //             ? () {
            //               // 语音输入功能，后续实现
            //               ToastUtils.showInfo(
            //                 '语音输入功能开发中',
            //                 align: Alignment.center,
            //               );
            //             }
            //             : null,
            //   ),
          ],

          // 在图片生成模式下显示魔法棒图标和图像参数选择
          if (widget.isImageGenerationMode) ...[
            // IconButton(
            //   icon: const Icon(Icons.auto_awesome),
            //   tooltip: '图像生成',
            //   color: Theme.of(context).colorScheme.primary,
            //   onPressed: null, // 仅作为指示器
            // ),

            // 如果支持参考图，显示添加参考图按钮
            if (widget.supportsReferenceImage)
              IconButton(
                icon: const Icon(Icons.add_photo_alternate),
                tooltip: '添加参考图片',
                onPressed:
                    widget.enabled && _referenceImage == null
                        ? _pickReferenceImage
                        : null,
              ),

            // 图像尺寸选择下拉框
            _buildSizeDropdown(),

            // 图像数量选择下拉框
            _buildCountDropdown(),
          ],

          const Spacer(),

          // 发送按钮
          IconButton(
            icon: Icon(widget.isImageGenerationMode ? Icons.brush : Icons.send),
            color: Theme.of(context).colorScheme.primary,
            tooltip: widget.isImageGenerationMode ? '生成图像' : '发送',
            onPressed:
                (!widget.enabled || !_isComposing)
                    ? null
                    : () => _handleSubmitted(_controller.text),
          ),
        ],
      ),
    );
  }

  // 参考图预览
  Widget _buildReferenceImagePreview() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '参考图：',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _removeReferenceImage,
                tooltip: '移除参考图',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(_referenceImage!, height: 150, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.article;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  // 构建图像尺寸选择下拉框
  Widget _buildSizeDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: DropdownButton<String>(
        value: _selectedImageSize,
        icon: Icon(
          Icons.aspect_ratio,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        isDense: true,
        underline: const SizedBox(),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onChanged:
            widget.enabled
                ? (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedImageSize = newValue;
                    });
                  }
                }
                : null,
        items:
            _imageSizes.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
      ),
    );
  }

  // 构建图像数量选择下拉框
  Widget _buildCountDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: DropdownButton<int>(
        value: _selectedImageCount,
        icon: Icon(
          Icons.filter_none,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        isDense: true,
        underline: const SizedBox(),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onChanged:
            widget.enabled
                ? (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedImageCount = newValue;
                    });
                  }
                }
                : null,
        items:
            _imageCounts.map<DropdownMenuItem<int>>((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value张'),
              );
            }).toList(),
      ),
    );
  }
}
