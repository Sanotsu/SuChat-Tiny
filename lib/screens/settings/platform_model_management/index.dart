import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/platform_spec.dart';
import '../../../models/model_spec.dart';
import '../../../providers/platform_provider.dart';
import '../../../providers/model_provider.dart';
import '../../../widgets/common/toast_utils.dart';

import 'platform_add_screen.dart';
import 'platform_detail_screen.dart';
import 'platform_model_import_screen.dart';
import 'model_detail_screen.dart';

class PlatformModelManagementScreen extends StatefulWidget {
  const PlatformModelManagementScreen({super.key});

  @override
  State<PlatformModelManagementScreen> createState() =>
      _PlatformModelManagementScreenState();
}

class _PlatformModelManagementScreenState
    extends State<PlatformModelManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 加载平台和模型数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final platformProvider = Provider.of<PlatformProvider>(
        context,
        listen: false,
      );
      final modelProvider = Provider.of<ModelProvider>(context, listen: false);

      platformProvider.loadPlatforms();
      modelProvider.loadModels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('平台与模型管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: '导入/导出',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlatformModelImportScreen(),
                ),
              );
            },
          ),
        ],

        // bottom: TabBar(
        //   controller: _tabController,
        //   overlayColor: MaterialStateProperty.all(const Color.fromARGB(0, 163, 79, 79)),
        //   tabs: const [
        //     Tab(text: 'API提供商', icon: Icon(Icons.cloud)),
        //     Tab(text: '模型', icon: Icon(Icons.model_training)),
        //   ],
        // ),
        // 自定义TabBar背景色(不使用PreferredSize会和appbar使用同一个背景色，不好区分)
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            MediaQuery.of(context).padding.top + 46,
          ),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'API提供商', icon: Icon(Icons.cloud_outlined)),
                Tab(text: '模型', icon: Icon(Icons.model_training_outlined)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPlatformTab(), _buildModelTab()],
      ),
    );
  }

  // 构建平台管理标签页
  Widget _buildPlatformTab() {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, _) {
        platformProvider.loadPlatforms();
        final platforms = platformProvider.platforms;

        return Stack(
          children: [
            // 平台列表
            platforms.isEmpty
                ? _buildEmptyState('尚未添加任何API提供商', Icons.cloud_off)
                : ListView.builder(
                  itemCount: platforms.length,
                  itemBuilder: (context, index) {
                    final platform = platforms[index];
                    return _buildPlatformItem(platform, platformProvider);
                  },
                ),

            // 添加平台按钮
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                shape: const CircleBorder(),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlatformAddScreen(),
                    ),
                  );

                  if (result == true && context.mounted) {
                    // 刷新平台列表
                    await platformProvider.loadPlatforms();
                    ToastUtils.showSuccess('平台添加成功');
                  }
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  // 构建模型管理标签页
  Widget _buildModelTab() {
    return Consumer<ModelProvider>(
      builder: (context, modelProvider, _) {
        modelProvider.loadModels();
        final models = modelProvider.models;

        return Stack(
          children: [
            // 模型列表
            models.isEmpty
                ? _buildEmptyState('尚未添加任何模型', Icons.model_training)
                : ListView.builder(
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    return _buildModelItem(context, models[index]);
                  },
                ),

            // 添加模型按钮
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                shape: const CircleBorder(),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const ModelDetailScreen(
                            mode: ModelOperationMode.add,
                          ),
                    ),
                  );

                  if (result == true && context.mounted) {
                    // 刷新模型列表
                    await modelProvider.loadModels();
                    ToastUtils.showSuccess('模型添加成功');
                  }
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  // 构建平台列表项
  Widget _buildPlatformItem(
    PlatformSpec platform,
    PlatformProvider platformProvider,
  ) {
    return FutureBuilder<bool>(
      future: platformProvider.hasApiKey(platform.id),
      builder: (context, snapshot) {
        final hasApiKey = snapshot.data ?? false;

        return Card(
          child: ListTile(
            title: Text(
              platform.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(platform.baseUrl),
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                platform.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasApiKey ? Icons.check_circle : Icons.error,
                  color: hasApiKey ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => PlatformDetailScreen(platform: platform),
                ),
              );

              if (result == true && context.mounted) {
                // 刷新平台列表
                await platformProvider.loadPlatforms();
              }
            },
          ),
        );
      },
    );
  }

  /// 构建模型列表项
  Widget _buildModelItem(BuildContext context, ModelSpec model) {
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);

    final platformName =
        platformProvider.getPlatformName(model.platformId) ?? '未知平台';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () {
          // 导航到模型详情页
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ModelDetailScreen(
                    model: model,
                    mode: ModelOperationMode.view,
                  ),
            ),
          ).then((result) {
            // 如果返回结果为true，刷新模型列表
            if (result == true) {
              _refreshModels();
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: _buildModelCard(model, platformName, modelProvider),
      ),
    );
  }

  /// 构建模型卡片内容
  Widget _buildModelCard(
    // BuildContext context,
    ModelSpec model,
    String platformName,
    ModelProvider modelProvider,
  ) {
    Widget infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 模型平台和标签
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                platformName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                MT_NAME_MAP[model.type] ?? "<未知模型>",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 设定模型描述区域最大高度，超过则滚动
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 80),
          child: SingleChildScrollView(
            child: SelectableText(
              model.description.isNotEmpty ? model.description : '暂无描述',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildCapabilities(model),
        if (model.contextWindow != null || model.maxOutputTokens != null)
          const SizedBox(height: 8),
        Row(
          children: [
            if (model.contextWindow != null)
              Expanded(child: Text('上下文窗口: ${model.contextWindow} tokens')),
            if (model.maxOutputTokens != null)
              Expanded(child: Text('最大输出: ${model.maxOutputTokens} tokens')),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(
            model.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(model.id),
          leading: CircleAvatar(
            backgroundColor: _getModelTypeColor(model.type),
            child: Icon(_getModelTypeIcon(model.type), color: Colors.white),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
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
                await modelProvider.loadModels();
              }
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: infoColumn,
        ),
      ],
    );
  }

  /// 构建模型能力标签
  Widget _buildCapabilities(ModelSpec model) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (model.supportsStreaming)
          _buildCapabilityChip('流式输出', model.supportsStreaming),
        if (model.supportsFunctionCalling)
          _buildCapabilityChip('函数调用', model.supportsFunctionCalling),
        if (model.supportsVision)
          _buildCapabilityChip('视觉输入', model.supportsVision),
        // 检查是否支持深度思考
        if (model.extraAttributes != null &&
            model.extraAttributes!['supports_thinking'] == true)
          _buildCapabilityChip('推理模型', true),
        // 检查是否支持参考图
        if (model.extraAttributes != null &&
            model.extraAttributes!['supports_reference_image'] == true)
          _buildCapabilityChip('支持参考图', true),
      ],
    );
  }

  Widget _buildCapabilityChip(String label, bool isSupported) {
    return Chip(
      label: Text(label),
      // 缩小内边距
      visualDensity: VisualDensity.compact,
      // 缩小点击区域
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor:
          isSupported
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSupported ? Colors.green.shade700 : Colors.grey.shade700,
        fontSize: 12,
      ),
    );
  }

  // 构建空状态
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // 获取模型类型对应的颜色
  Color _getModelTypeColor(ModelType type) {
    switch (type) {
      case ModelType.text:
        return Colors.blue;
      case ModelType.vision:
        return Colors.purple;
      case ModelType.image:
        return Colors.orange;
    }
  }

  // 获取模型类型对应的图标
  IconData _getModelTypeIcon(ModelType type) {
    switch (type) {
      case ModelType.text:
        return Icons.chat;
      case ModelType.vision:
        return Icons.visibility;
      case ModelType.image:
        return Icons.image;
    }
  }

  void _refreshModels() {
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    modelProvider.loadModels();
  }
}
