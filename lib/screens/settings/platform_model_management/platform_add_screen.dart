import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/tools.dart';
import '../../../models/platform_spec.dart';
import '../../../providers/platform_provider.dart';
import '../../../widgets/common/small_tool_widgets.dart';

class PlatformAddScreen extends StatefulWidget {
  const PlatformAddScreen({super.key});

  @override
  State<PlatformAddScreen> createState() => _PlatformAddScreenState();
}

class _PlatformAddScreenState extends State<PlatformAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureText = true; // 密钥初始状态为隐藏文本
  final _orgIdController = TextEditingController();
  bool _isLoading = false;
  bool _useOpenAICompatible = true;

  // 用于展示的预设平台标签
  List<CusLabel> displayPlatforms = [
    CusLabel(cnLabel: '硅基流动', value: 'siliconflow'),
    CusLabel(cnLabel: '阿里百炼', value: 'aliyun'),
    CusLabel(cnLabel: 'DeepSeek', value: 'deepseek'),
    CusLabel(cnLabel: '自定义', value: 'custom'),
    CusLabel(cnLabel: 'OpenAI', value: 'openai'),
  ];
  late CusLabel selectedPlatform;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _orgIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // 初始化选择和显示第一个预设平台的地址
    selectedPlatform = displayPlatforms.first;
    _setPresetValues(selectedPlatform);
  }

  void _setPresetValues(CusLabel provider) {
    setState(() {
      selectedPlatform = provider;

      switch (provider.value as String) {
        case 'siliconflow':
          _nameController.text = '硅基流动';
          _urlController.text = 'https://api.siliconflow.cn';
          break;
        case 'aliyun':
          _nameController.text = '阿里百炼';
          _urlController.text =
              'https://dashscope.aliyuncs.com/compatible-mode';
          break;
        case 'deepseek':
          _nameController.text = '深度求索';
          _urlController.text = 'https://api.deepseek.com';
          break;
        case 'openai':
          _nameController.text = 'OpenAI';
          _urlController.text = 'https://api.openai.com';
          break;
        case 'custom':
          _nameController.text = '';
          _urlController.text = '';
          break;
      }
    });
  }

  Future<void> _savePlatform() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final name = _nameController.text.trim();
        final url = _urlController.text.trim();
        final apiKey = _apiKeyController.text.trim();
        final orgId = _orgIdController.text.trim();

        // 创建平台
        final platform = PlatformSpec(
          id: identityHashCode(name).toString(),
          name: name,
          type: _determineType(name),
          baseUrl: url,
          apiVersion: 'v1',
          description: '',
          // 为自定义平台默认启用OpenAI兼容模式
          isOpenAICompatible: _useOpenAICompatible,
        );

        // 保存平台到数据库
        final platformProvider = Provider.of<PlatformProvider>(
          context,
          listen: false,
        );
        await platformProvider.savePlatform(platform);

        // 保存API密钥
        if (apiKey.isNotEmpty) {
          await platformProvider.saveApiKey(platform.id, apiKey);
        }

        // 保存组织ID
        if (orgId.isNotEmpty) {
          await platformProvider.saveOrgId(platform.id, orgId);
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        logger.e('保存提供商失败: $e');
        commonExceptionDialog(context, '保存提供商失败', '保存提供商失败: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 根据名称决定平台类型
  PlatformType _determineType(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('openai')) {
      return PlatformType.openAI;
    } else {
      return PlatformType.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加API提供商')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(key: _formKey, child: _buildFormColumn()),
              ),
    );
  }

  // 构建预设平台选择
  Widget _buildPlatformFilter() {
    return Container(
      height: 40,
      padding: EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  displayPlatforms.map((type) {
                    return Center(child: _buildCusChip(type));
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  _buildCusChip(CusLabel type) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _setPresetValues(type);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  type == selectedPlatform
                      ? Theme.of(context).primaryColorLight
                      : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              type.cnLabel,
              style: TextStyle(
                color:
                    type == selectedPlatform
                        ? Theme.of(context).primaryColor
                        : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建表单列
  _buildFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设选择
        Text('选择提供商', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        _buildPlatformFilter(),

        const SizedBox(height: 24),
        Text('提供商详情', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),

        // 名称输入框
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '例如: OpenAI, 深度求索',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入提供商名称';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // URL输入框
        TextFormField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: '基础URL(不带/v1和后面的内容)',
            hintText: '例如: https://api.openai.com',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入基础URL';
            }

            // 简单的URL格式验证
            if (!value.startsWith('http')) {
              return '请输入有效的URL（以http或https开头）';
            }

            return null;
          },
        ),

        const SizedBox(height: 24),

        if ((selectedPlatform.value as String).contains('custom')) ...[
          Text('API兼容性', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // OpenAI兼容模式开关
          SwitchListTile(
            title: const Text('使用OpenAI兼容模式'),
            subtitle: const Text(
              'OpenAI兼容的API格式（请保持开启）',
              style: TextStyle(fontSize: 12),
            ),
            value: _useOpenAICompatible,
            onChanged: (value) {
              setState(() {
                _useOpenAICompatible = value;
              });
            },
          ),
          const SizedBox(height: 24),
        ],

        Text('API凭据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),

        // API密钥输入框
        TextFormField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API密钥',
            hintText: '输入你的API密钥',
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
          ),
          obscureText: _obscureText,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入API密钥';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 组织ID输入框（仅OpenAI需要）
        if ((selectedPlatform.value as String).contains('openai'))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _orgIdController,
                decoration: const InputDecoration(
                  labelText: '组织ID（可选，仅OpenAI需要）',
                  hintText: '输入你的组织ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        // 保存按钮
        ElevatedButton(
          onPressed: _savePlatform,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
