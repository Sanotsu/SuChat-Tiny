import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/tools.dart';
import '../../../models/model_spec.dart';
import '../../../models/platform_spec.dart';
import '../../../providers/model_provider.dart';
import '../../../providers/platform_provider.dart';
import '../../../widgets/common/small_tool_widgets.dart';
import '../../../widgets/common/toast_utils.dart';
import 'model_detail_screen.dart';

class PlatformDetailScreen extends StatefulWidget {
  final PlatformSpec platform;

  const PlatformDetailScreen({super.key, required this.platform});

  @override
  State<PlatformDetailScreen> createState() => _PlatformDetailScreenState();
}

class _PlatformDetailScreenState extends State<PlatformDetailScreen> {
  final SecureStorageHelper _secureStorage = SecureStorageHelper();
  final _apiKeyController = TextEditingController();
  bool _obscureText = true; // 密钥初始状态为隐藏文本
  final _orgIdController = TextEditingController();
  bool _isLoading = true;
  bool _useOpenAICompatible = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _useOpenAICompatible = widget.platform.isOpenAICompatible;
    // 重置模型加载状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ModelProvider>(context, listen: false).resetLoadState();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _orgIdController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = await _secureStorage.getApiKey(widget.platform.id);
      final orgId = await _secureStorage.getOrgId(widget.platform.id);

      _apiKeyController.text = apiKey ?? '';
      _orgIdController.text = orgId ?? '';
    } catch (e) {
      logger.e('加载API密钥失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiKey = _apiKeyController.text.trim();
      final orgId = _orgIdController.text.trim();
      final platformProvider = Provider.of<PlatformProvider>(
        context,
        listen: false,
      );

      // 更新平台的OpenAI兼容性设置
      if (_useOpenAICompatible != widget.platform.isOpenAICompatible) {
        final updatedPlatform = widget.platform.copyWith(
          isOpenAICompatible: _useOpenAICompatible,
        );
        await platformProvider.savePlatform(updatedPlatform);
      }

      if (apiKey.isNotEmpty) {
        await _secureStorage.saveApiKey(widget.platform.id, apiKey);
      } else {
        await _secureStorage.deleteApiKey(widget.platform.id);
      }

      if (orgId.isNotEmpty) {
        await _secureStorage.saveOrgId(widget.platform.id, orgId);
      } else {
        await _secureStorage.deleteOrgId(widget.platform.id);
      }

      if (!mounted) return;
      ToastUtils.showSuccess('API信息保存成功');
      Navigator.pop(context, true);
    } catch (e) {
      logger.e('保存API密钥失败: $e');
      commonExceptionDialog(context, '保存API密钥失败', '$e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePlatform() async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('删除提供商'),
                content: Text(
                  '确定要删除提供商 "${widget.platform.name}" 吗？这将删除所有相关的API密钥。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 删除API密钥
        await _secureStorage.deleteApiKey(widget.platform.id);
        await _secureStorage.deleteOrgId(widget.platform.id);

        // 删除平台
        if (!mounted) return;
        final platformProvider = Provider.of<PlatformProvider>(
          context,
          listen: false,
        );
        await platformProvider.deletePlatform(widget.platform.id);

        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        logger.e('删除提供商失败: $e');
        if (!mounted) return;
        commonExceptionDialog(context, '删除提供商失败', '$e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.platform.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deletePlatform,
            tooltip: '删除提供商',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 提供商信息
                    _buildTileLable('提供商详情'),
                    _buildPlatformInfo(),
                    const SizedBox(height: 24),

                    /// API兼容性
                    _buildTileLable('API兼容性'),
                    // OpenAI兼容模式开关
                    SwitchListTile(
                      title: const Text('使用OpenAI兼容模式'),
                      subtitle: const Text('启用此选项以使用OpenAI兼容的API格式（推荐用于自定义平台）'),
                      value: _useOpenAICompatible,
                      onChanged: (value) {
                        setState(() {
                          _useOpenAICompatible = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    /// API凭据
                    _buildTileLable('API凭据'),
                    ..._buildAPIInputInfo(),
                    const SizedBox(height: 24),

                    /// 模型管理
                    _buildTileLable('模型管理'),
                    // 显示当前平台的模型列表
                    _buildModelManagement(),
                    // 添加模型
                    const SizedBox(height: 16),
                    _buildAddModelButton(),
                    const SizedBox(height: 8),
                    // 测试连接
                    // buildTestConnectionButton(),
                  ],
                ),
              ),
    );
  }

  // 构建标题文本
  Widget _buildTileLable(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  // 提供商信息
  Widget _buildPlatformInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('名称'),
              subtitle: Text(widget.platform.name),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              title: const Text('基础URL'),
              subtitle: Text(widget.platform.baseUrl),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  // API密钥输入保存等按钮组件
  List<Widget> _buildAPIInputInfo() {
    // API密钥输入框
    return [
      TextField(
        controller: _apiKeyController,
        decoration: InputDecoration(
          labelText: 'API密钥',
          hintText: '输入你的API密钥',
          border: OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
        ),

        obscureText: _obscureText,
      ),
      const SizedBox(height: 16),

      // 组织ID输入框（仅OpenAI需要）
      if (widget.platform.name.toLowerCase().contains('openai'))
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _orgIdController,
              decoration: const InputDecoration(
                labelText: '组织ID（可选）',
                hintText: '输入你的组织ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),

      // 保存按钮
      ElevatedButton(
        onPressed: _saveApiKey,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('保存'),
      ),
    ];
  }

  // 模型管理部分
  Widget _buildModelManagement() {
    return Consumer<ModelProvider>(
      builder: (context, modelProvider, _) {
        // 初始化时加载模型，使用一个FutureBuilder来处理异步加载
        return FutureBuilder<void>(
          future:
              !modelProvider.isModelsLoaded
                  ? modelProvider.loadModelsByPlatform(widget.platform.id)
                  : Future.value(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('加载模型失败: ${snapshot.error}'),
              );
            }

            // 过滤平台ID(初始化时加载指定平台模型，但这里拿到的是所有模型，所有过滤)
            final models =
                modelProvider.models
                    .where(
                      (element) => element.platformId == widget.platform.id,
                    )
                    .toList();

            if (models.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('此平台尚未添加任何模型'),
              );
            }

            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      '已添加的模型：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: models.length,
                    itemBuilder: (context, index) {
                      final model = models[index];
                      return _buildModelTile(model, modelProvider);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 模型列
  Widget _buildModelTile(ModelSpec model, ModelProvider modelProvider) {
    return ListTile(
      dense: true,
      title: Text(model.name),
      subtitle: Text("${MT_NAME_MAP[model.type] ?? '未知模型'} ${model.id}"),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          final confirm =
              await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('删除模型'),
                      content: Text('确定要删除模型"${model.name}"吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
              ) ??
              false;

          if (confirm) {
            await modelProvider.deleteModel(model.id);
            await modelProvider.loadModelsByPlatform(widget.platform.id);

            if (!mounted) return;
            ToastUtils.showSuccess('模型删除成功');
          }
        },
      ),
    );
  }

  // 添加模型按钮
  Widget _buildAddModelButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ModelDetailScreen(platformId: widget.platform.id),
          ),
        );

        if (result == true) {
          if (!mounted) return;
          ToastUtils.showSuccess('模型添加成功');
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('为此平台添加模型'),
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }

  // // 测试连接按钮
  // Widget buildTestConnectionButton() {
  //   return OutlinedButton(
  //     onPressed: () {
  //       // TODO: 实现测试连接功能
  //       ToastUtils.showError('测试连接功能尚未实现');
  //     },
  //     style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  //     child: const Text('测试连接'),
  //   );
  // }
}
