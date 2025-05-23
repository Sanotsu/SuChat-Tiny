import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/tools.dart';
import '../../../models/platform_spec.dart';
import '../../../models/model_spec.dart';
import '../../../providers/model_provider.dart';
import '../../../providers/platform_provider.dart';
import '../../../widgets/common/small_tool_widgets.dart';
import '../../../widgets/common/toast_utils.dart';

/// 模型操作模式
enum ModelOperationMode {
  /// 新增模型
  add,

  /// 编辑模型
  edit,

  /// 查看模型详情
  view,
}

class ModelDetailScreen extends StatefulWidget {
  final String? platformId; // 如果提供，则预先选择该平台
  final ModelSpec? model; // 如果提供，表示编辑或查看现有模型
  final ModelOperationMode mode; // 操作模式

  const ModelDetailScreen({
    super.key,
    this.platformId,
    this.model,
    this.mode = ModelOperationMode.add,
  });

  @override
  State<ModelDetailScreen> createState() => _ModelDetailScreenState();
}

class _ModelDetailScreenState extends State<ModelDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedPlatformId;
  ModelType _selectedModelType = ModelType.text;
  bool _supportsStreaming = true;
  bool _supportsFunctionCalling = false;
  bool _supportsVision = false;
  bool _supportsReferenceImage = false;
  bool _supportsThinking = false;
  final _contextWindowController = TextEditingController();
  final _maxOutputTokensController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    // 如果传入了平台ID，设置选中的平台
    if (widget.platformId != null) {
      _selectedPlatformId = widget.platformId;
    }

    // 如果是编辑或查看模式，填充模型数据
    if (widget.model != null) {
      _idController.text = widget.model!.id;
      _nameController.text = widget.model!.name;
      _descriptionController.text = widget.model!.description;
      _selectedPlatformId = widget.model!.platformId;
      _selectedModelType = widget.model!.type;
      _supportsStreaming = widget.model!.supportsStreaming;
      _supportsFunctionCalling = widget.model!.supportsFunctionCalling;
      _supportsVision = widget.model!.supportsVision;

      // 检查额外属性中是否有参考图支持
      if (widget.model!.extraAttributes != null &&
          widget.model!.extraAttributes!['supports_reference_image'] == true) {
        _supportsReferenceImage = true;
      }

      // 检查额外属性中是否有深度思考支持
      if (widget.model!.extraAttributes != null &&
          widget.model!.extraAttributes!['supports_thinking'] == true) {
        _supportsThinking = true;
      }

      // 填充高级参数
      if (widget.model!.contextWindow != null) {
        _contextWindowController.text = widget.model!.contextWindow.toString();
      }
      if (widget.model!.maxOutputTokens != null) {
        _maxOutputTokensController.text =
            widget.model!.maxOutputTokens.toString();
      }
    }

    // 设置是否处于编辑模式
    _isEditing =
        widget.mode == ModelOperationMode.add ||
        widget.mode == ModelOperationMode.edit;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _contextWindowController.dispose();
    _maxOutputTokensController.dispose();
    super.dispose();
  }

  // 切换到编辑模式
  void _switchToEditMode() {
    setState(() {
      _isEditing = true;
    });
  }

  // 保存模型
  Future<void> _saveModel() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final modelId = _idController.text.trim();
        final name = _nameController.text.trim();
        final description = _descriptionController.text.trim();
        final contextWindow =
            _contextWindowController.text.isEmpty
                ? null
                : int.tryParse(_contextWindowController.text);
        final maxOutputTokens =
            _maxOutputTokensController.text.isEmpty
                ? null
                : int.tryParse(_maxOutputTokensController.text);

        if (_selectedPlatformId == null) {
          throw Exception('请选择平台');
        }

        // 创建额外参数
        final Map<String, dynamic> extraParams =
            widget.model?.extraAttributes != null
                ? Map<String, dynamic>.from(widget.model!.extraAttributes!)
                : {};

        // 如果支持参考图，添加到额外参数中
        if (_selectedModelType == ModelType.image) {
          if (_supportsReferenceImage) {
            extraParams['supports_reference_image'] = true;
          } else {
            extraParams.remove('supports_reference_image');
          }
        }

        // 如果支持深度思考，添加到额外参数中
        if (_selectedModelType == ModelType.text ||
            _selectedModelType == ModelType.vision) {
          if (_supportsThinking) {
            extraParams['supports_thinking'] = true;
          } else {
            extraParams.remove('supports_thinking');
          }
        }

        // 创建新模型或更新现有模型
        final model = ModelSpec(
          id: modelId,
          name: name.isEmpty ? modelId : name,
          description: description.isEmpty ? "<未设置描述>" : description,
          type: _selectedModelType,
          platformId: _selectedPlatformId!,
          contextWindow: contextWindow,
          maxOutputTokens: maxOutputTokens,
          supportsStreaming: _supportsStreaming,
          supportsFunctionCalling: _supportsFunctionCalling,
          supportsVision: _supportsVision,
          extraAttributes: extraParams.isNotEmpty ? extraParams : null,
          // 保留其他字段的原始值
          version: widget.model?.version ?? '',
          inputPricePerK: widget.model?.inputPricePerK,
          outputPricePerK: widget.model?.outputPricePerK,
        );

        // 保存模型
        final modelProvider = Provider.of<ModelProvider>(
          context,
          listen: false,
        );
        await modelProvider.saveModel(model);

        // 根据不同模式显示不同提示
        if (widget.mode == ModelOperationMode.add) {
          ToastUtils.showSuccess('模型添加成功');
        } else {
          ToastUtils.showSuccess('模型更新成功');
          // 如果在编辑模式，回到详情模式
          if (widget.mode == ModelOperationMode.edit) {
            setState(() {
              _isEditing = false;
            });
          }
        }

        if (widget.mode == ModelOperationMode.add && mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        logger.e('保存模型失败: $e');
        if (!mounted) return;
        commonExceptionDialog(context, '保存模型失败', '$e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 删除模型
  Future<void> _deleteModel() async {
    if (widget.model == null) return;

    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('删除模型'),
                content: Text('确定要删除模型"${widget.model!.name}"吗？此操作不可恢复。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final modelProvider = Provider.of<ModelProvider>(
          context,
          listen: false,
        );
        await modelProvider.deleteModel(widget.model!.id);
        ToastUtils.showSuccess('模型已删除');

        if (mounted) {
          Navigator.pop(context, true); // 返回并刷新列表
        }
      } catch (e) {
        logger.e('删除模型失败: $e');
        if (!mounted) return;
        commonExceptionDialog(context, '删除模型失败', '$e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformProvider = Provider.of<PlatformProvider>(context);
    final platforms = platformProvider.platforms;

    // 根据模式确定页面标题
    String pageTitle;
    switch (widget.mode) {
      case ModelOperationMode.add:
        pageTitle = '添加模型';
        break;
      case ModelOperationMode.edit:
        pageTitle = '编辑模型';
        break;
      case ModelOperationMode.view:
        pageTitle = '模型详情';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          // 在查看模式下显示编辑和删除按钮
          if (widget.mode == ModelOperationMode.view && !_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑',
              onPressed: _switchToEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              color: Colors.red,
              onPressed: _deleteModel,
            ),
          ],
          // 在编辑模式下显示保存按钮
          if (_isEditing && widget.mode != ModelOperationMode.add)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存',
              onPressed: _saveModel,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(key: _formKey, child: _buildFormColumn(platforms)),
              ),
      // 在添加模式下显示底部保存按钮
      bottomNavigationBar:
          (widget.mode == ModelOperationMode.add)
              ? BottomAppBar(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ElevatedButton(
                    onPressed: _saveModel,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('保存模型'),
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildFormColumn(List<PlatformSpec> platforms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 平台选择
        Text('选择平台', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // 平台下拉菜单
        DropdownButtonFormField<String>(
          value: _selectedPlatformId,
          decoration: const InputDecoration(
            labelText: '平台(必选)',
            border: OutlineInputBorder(),
          ),
          items:
              platforms.map((platform) {
                return DropdownMenuItem<String>(
                  value: platform.id,
                  child: Text(platform.name),
                );
              }).toList(),
          onChanged:
              _isEditing
                  ? (value) {
                    setState(() {
                      _selectedPlatformId = value;
                    });
                  }
                  : null,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请选择平台';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        Text('模型详情', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // 模型ID输入框
        TextFormField(
          controller: _idController,
          decoration: const InputDecoration(
            labelText: '模型ID(必填)',
            hintText: '例如: gpt-3.5-turbo-0125',
            border: OutlineInputBorder(),
          ),
          readOnly:
              !_isEditing ||
              widget.mode == ModelOperationMode.edit, // 编辑模式下不允许修改ID
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入模型ID';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 模型名称输入框
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '模型名称',
            hintText: '例如: GPT-3.5 Turbo',
            border: OutlineInputBorder(),
          ),
          readOnly: !_isEditing,
        ),
        const SizedBox(height: 16),

        // 模型描述输入框
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: '模型描述',
            hintText: '例如: OpenAI的GPT-3.5模型，适合一般对话和编程任务',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          readOnly: !_isEditing,
        ),
        const SizedBox(height: 24),

        Text('模型类型', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // 模型类型选择
        DropdownButtonFormField<ModelType>(
          value: _selectedModelType,
          decoration: const InputDecoration(
            labelText: '类型',
            border: OutlineInputBorder(),
          ),
          items:
              ModelType.values.map((type) {
                return DropdownMenuItem<ModelType>(
                  value: type,
                  child: Text(MT_NAME_MAP[type] ?? "<未知模型>"),
                );
              }).toList(),
          onChanged:
              _isEditing
                  ? (value) {
                    if (value != null) {
                      setState(() {
                        _selectedModelType = value;
                        // 如果选择了视觉模型，自动启用视觉支持
                        if (value == ModelType.vision) {
                          _supportsVision = true;
                        } else {
                          _supportsVision = false;
                        }

                        // 如果选择类型不是图像生成，则重置参考图支持
                        if (value != ModelType.image) {
                          _supportsReferenceImage = false;
                        }
                      });
                    }
                  }
                  : null,
        ),
        const SizedBox(height: 24),

        Text('模型能力', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // 支持深度思考
        if (_selectedModelType == ModelType.text ||
            _selectedModelType == ModelType.vision) ...[
          // 支持流式输出
          SwitchListTile(
            title: const Text('支持流式输出'),
            subtitle: const Text('模型能够实时流式返回生成内容'),
            value: _supportsStreaming,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _supportsStreaming = value;
                      });
                    }
                    : null,
          ),
          // 支持函数调用
          SwitchListTile(
            title: const Text('支持函数调用'),
            subtitle: const Text('模型能够调用函数或使用工具'),
            value: _supportsFunctionCalling,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _supportsFunctionCalling = value;
                      });
                    }
                    : null,
          ),
          // 支持视觉输入
          SwitchListTile(
            title: const Text('支持视觉输入'),
            subtitle: const Text('模型能够理解和分析图像'),
            value: _supportsVision,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _supportsVision = value;
                      });
                    }
                    : null,
          ),
          // 支持深度思考
          SwitchListTile(
            title: const Text('支持深度思考'),
            subtitle: const Text('模型能够进行深度思考'),
            value: _supportsThinking,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _supportsThinking = value;
                      });
                    }
                    : null,
          ),
        ],

        // 如果是图像生成模型，显示支持参考图选项
        if (_selectedModelType == ModelType.image)
          SwitchListTile(
            title: const Text('支持参考图'),
            subtitle: const Text('图像生成时可以上传参考图片'),
            value: _supportsReferenceImage,
            onChanged:
                _isEditing
                    ? (value) {
                      setState(() {
                        _supportsReferenceImage = value;
                      });
                    }
                    : null,
          ),

        const SizedBox(height: 24),
        Text('高级参数', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // 上下文窗口大小
        TextFormField(
          controller: _contextWindowController,
          decoration: const InputDecoration(
            labelText: '上下文窗口大小 (tokens)',
            hintText: '例如: 16385',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          readOnly: !_isEditing,
        ),
        const SizedBox(height: 16),

        // 最大输出token数
        TextFormField(
          controller: _maxOutputTokensController,
          decoration: const InputDecoration(
            labelText: '最大输出token数',
            hintText: '例如: 4096',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          readOnly: !_isEditing,
        ),

        // 仅在添加模式下显示底部的保存按钮
        if (widget.mode == ModelOperationMode.add) const SizedBox(height: 32),
      ],
    );
  }
}
