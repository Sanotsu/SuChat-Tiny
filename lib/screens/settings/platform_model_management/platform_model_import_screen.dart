import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/tools.dart';
import '../../../models/platform_spec.dart';
import '../../../models/model_spec.dart';
import '../../../providers/platform_provider.dart';
import '../../../providers/model_provider.dart';
import '../../../widgets/common/toast_utils.dart';
import '../../../widgets/common/small_tool_widgets.dart';
import '../../../core/storage/db_helper.dart';

class PlatformModelImportScreen extends StatefulWidget {
  const PlatformModelImportScreen({super.key});

  @override
  State<PlatformModelImportScreen> createState() =>
      _PlatformModelImportScreenState();
}

class _PlatformModelImportScreenState extends State<PlatformModelImportScreen> {
  bool _isLoading = false;
  final DBHelper _dbHelper = DBHelper();

  // 是否获得了存储权限(没获得就无法备份恢复)
  bool isPermissionGranted = false;

  // 导出模式：简化或完整
  bool _isSimpleExport = true;

  @override
  void initState() {
    super.initState();

    _getPermission();
  }

  _getPermission() async {
    bool flag = await requestStoragePermission();
    setState(() {
      isPermissionGranted = flag;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台模型导入/导出')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImportSection(),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildExportSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildImportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('导入', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '从JSON文件导入平台和模型配置。\n支持完整格式和简化格式的JSON文件。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // 导入按钮
        ElevatedButton.icon(
          onPressed: _importFromFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('从文件导入'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('导出', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '将所有平台和模型配置导出为JSON格式。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // 导出模式选择
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('简化版'),
                subtitle: const Text('必要字段'),
                value: true,
                groupValue: _isSimpleExport,
                onChanged: (value) {
                  setState(() {
                    _isSimpleExport = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('完整版'),
                subtitle: const Text('所有字段'),
                value: false,
                groupValue: _isSimpleExport,
                onChanged: (value) {
                  setState(() {
                    _isSimpleExport = value!;
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 导出按钮
        ElevatedButton.icon(
          onPressed: _exportToFile,
          icon: const Icon(Icons.download),
          label: const Text('导出到文件'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  // 从文件导入
  Future<void> _importFromFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 读取文件内容
      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();

      // 解析JSON
      final jsonData = json.decode(jsonString);

      // 获取提供者
      if (!mounted) return;
      final platformProvider = Provider.of<PlatformProvider>(
        context,
        listen: false,
      );
      final modelProvider = Provider.of<ModelProvider>(context, listen: false);

      // 检查JSON格式
      if (jsonData is List) {
        // 统一格式 [{"platform": "name", "baseUrl": "url", ...}]
        await _importFromJsonList(jsonData, platformProvider, modelProvider);
      } else {
        throw Exception('无效的JSON格式，应为数组格式');
      }

      // 更新统计
      setState(() {
        _isLoading = false;
      });

      // 刷新列表
      await platformProvider.loadPlatforms();
      await modelProvider.loadModels();

      ToastUtils.showSuccess('导入成功');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      commonExceptionDialog(context, '导入失败', e.toString());
    }
  }

  // 从JSON列表导入
  Future<void> _importFromJsonList(
    List jsonData,
    PlatformProvider platformProvider,
    ModelProvider modelProvider,
  ) async {
    // 先加载所有现有平台，用于后续匹配
    final existingPlatforms = await _dbHelper.getAllPlatforms();

    // 遍历每个平台配置
    for (var platformData in jsonData) {
      if (platformData is! Map) {
        continue; // 跳过非对象格式的数据
      }

      final platformName = platformData['platform'] as String?;
      final baseUrl = platformData['baseUrl'] as String?;
      final apiKey = platformData['apiKey'] as String?;
      final platformId = platformData['id'] as String?;

      if (platformName == null || baseUrl == null) {
        continue; // 跳过缺少必要字段的数据
      }

      // 用于存储实际使用的平台ID
      String actualPlatformId;
      bool platformExists = false;

      // 情况1：如果JSON中包含平台ID，检查是否已存在
      if (platformId != null) {
        // 查找是否有匹配的平台ID
        PlatformSpec? existingPlatform;
        try {
          existingPlatform = existingPlatforms.firstWhere(
            (p) => p.id == platformId,
          );
          // 平台ID已存在，使用现有平台ID
          actualPlatformId = existingPlatform.id;
          platformExists = true;
        } catch (e) {
          // 平台ID不存在，使用JSON中的ID创建新平台
          actualPlatformId = platformId;
        }
      }
      // 情况2：JSON中不包含平台ID，根据平台名称和baseUrl查找
      else {
        // 查找是否有匹配的平台名称和baseUrl
        PlatformSpec? existingPlatform;
        try {
          existingPlatform = existingPlatforms.firstWhere(
            (p) => p.name == platformName && p.baseUrl == baseUrl,
          );
          // 找到匹配的平台，使用现有平台ID
          actualPlatformId = existingPlatform.id;
          platformExists = true;
        } catch (e) {
          // 未找到匹配的平台，生成新ID
          actualPlatformId = identityHashCode(platformName).toString();
        }
      }

      // 如果平台不存在，创建并保存新平台
      if (!platformExists) {
        // 创建平台对象，尽可能使用提供的数据，否则使用默认值
        final platform = PlatformSpec(
          id: actualPlatformId,
          name: platformName,
          type:
              platformData['type'] != null
                  ? _parsePlatformType(platformData['type'].toString())
                  : PlatformType.openAI,
          baseUrl: baseUrl,
          apiVersion: platformData['apiVersion'] as String? ?? 'v1',
          description: platformData['description'] as String? ?? '',
          apiKeyHeader:
              platformData['apiKeyHeader'] as String? ?? 'Authorization',
          orgIdHeader: platformData['orgIdHeader'] as String?,
          isOpenAICompatible:
              platformData['isOpenAICompatible'] as bool? ?? true,
          extraHeaders: platformData['extraHeaders'] as Map<String, String>?,
          extraAttributes:
              platformData['extraAttributes'] as Map<String, dynamic>?,
        );

        // 保存平台
        await platformProvider.savePlatform(platform);

        // 如果有API密钥，也保存
        if (apiKey != null) {
          await platformProvider.saveApiKey(actualPlatformId, apiKey);
        }

        // 如果有组织ID，也保存
        final orgId = platformData['orgId'] as String?;
        if (orgId != null) {
          await platformProvider.saveOrgId(actualPlatformId, orgId);
        }
      } else if (apiKey != null) {
        // 即使平台已存在，也更新API密钥（如果提供了）
        await platformProvider.saveApiKey(actualPlatformId, apiKey);

        // 如果有组织ID，也更新
        final orgId = platformData['orgId'] as String?;
        if (orgId != null) {
          await platformProvider.saveOrgId(actualPlatformId, orgId);
        }
      }

      // 处理模型 - 无论平台是新建还是已存在，都处理模型
      final models = platformData['models'] as List?;
      if (models != null) {
        for (var modelData in models) {
          if (modelData is! Map) {
            continue; // 跳过非对象格式的数据
          }

          final modelId = modelData['id'] as String?;
          final modelTypeStr = modelData['type'] as String?;

          if (modelId == null || modelTypeStr == null) {
            continue; // 跳过缺少必要字段的数据
          }

          // 检查模型是否已存在
          final existingModel = await _dbHelper.getModel(modelId);
          if (existingModel != null) {
            // 模型已存在，可以选择跳过或更新
            continue;
          }

          // 解析模型类型
          final modelType = _parseModelType(modelTypeStr);

          // 创建模型对象，尽可能使用提供的数据，否则使用默认值
          final model = ModelSpec(
            id: modelId,
            name: modelData['name'] as String? ?? modelId,
            description: modelData['description'] as String? ?? '',
            type: modelType,
            platformId: actualPlatformId, // 使用实际的平台ID，可能是现有的也可能是新建的
            version: modelData['version'] as String? ?? '',
            contextWindow: modelData['contextWindow'] as int?,
            inputPricePerK: modelData['inputPricePerK'] as double?,
            outputPricePerK: modelData['outputPricePerK'] as double?,
            supportsStreaming:
                modelData['supportsStreaming'] as bool? ??
                modelType != ModelType.image,
            supportsFunctionCalling:
                modelData['supportsFunctionCalling'] as bool? ??
                (modelType == ModelType.text),
            supportsVision:
                modelData['supportsVision'] as bool? ??
                (modelType == ModelType.vision),
            maxOutputTokens: modelData['maxOutputTokens'] as int?,
            extraAttributes:
                modelData['extraAttributes'] as Map<String, dynamic>?,
          );

          // 保存模型
          await modelProvider.saveModel(model);
        }
      }
    }
  }

  // 导出到文件
  Future<void> _exportToFile() async {
    // 用户没有授权，简单提示一下
    if (!isPermissionGranted) {
      ToastUtils.showError(
        "用户已禁止访问内部存储,无法进行json文件导入。\n如需启用，请到应用的权限管理中授权读写手机存储。",
      );
      return;
    }

    // 用户选择指定文件夹
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    // 如果有选中文件夹，执行导出数据库的json文件，并添加到压缩档。
    if (selectedDirectory != null) {
      if (_isLoading) return;

      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        // 获取提供者
        final platformProvider = Provider.of<PlatformProvider>(
          context,
          listen: false,
        );
        final modelProvider = Provider.of<ModelProvider>(
          context,
          listen: false,
        );

        // 加载所有平台和模型
        await platformProvider.loadPlatforms();
        await modelProvider.loadModels();

        final platforms = platformProvider.platforms;
        final models = modelProvider.models;

        // 根据选择的导出模式执行不同的导出逻辑
        String jsonString;
        if (_isSimpleExport) {
          // 简化格式导出
          jsonString = await _exportSimpleFormat(
            platforms,
            models,
            platformProvider,
          );
        } else {
          // 完整格式导出
          jsonString = await _exportCompleteFormat(
            platforms,
            models,
            platformProvider,
          );
        }

        // 导出的文件名
        final exportType = _isSimpleExport ? '简化版' : '完整版';
        final fileName =
            'SuChatTiny平台模型导出_${exportType}_${fileTs(DateTime.now())}.json';

        // 获取临时目录
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        // 写入文件
        final file = File(filePath);
        await file.writeAsString(jsonString);

        // 把文件从缓存的临时位置放到用户选择的位置
        file.copySync(p.join(selectedDirectory, fileName));

        // 更新统计
        setState(() {
          _isLoading = false;
        });

        ToastUtils.showSuccess('导出成功');
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        commonExceptionDialog(context, '导出失败', e.toString());
      }
    }
  }

  // 导出简化格式
  Future<String> _exportSimpleFormat(
    List<PlatformSpec> platforms,
    List<ModelSpec> models,
    PlatformProvider platformProvider,
  ) async {
    // 构建导出数据
    final List<Map<String, dynamic>> exportData = [];

    // 遍历每个平台
    for (var platform in platforms) {
      final platformData = <String, dynamic>{
        'platform': platform.name,
        'baseUrl': platform.baseUrl,
      };

      // 获取API密钥
      final apiKey = await platformProvider.getApiKey(platform.id);
      if (apiKey != null) {
        platformData['apiKey'] = apiKey;
      }

      // 获取该平台下的所有模型
      final platformModels =
          models.where((m) => m.platformId == platform.id).toList();
      if (platformModels.isNotEmpty) {
        platformData['models'] =
            platformModels
                .map((model) => {'id': model.id, 'type': model.type.name})
                .toList();
      } else {
        platformData['models'] = [];
      }

      exportData.add(platformData);
    }

    // 转换为JSON字符串
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  // 导出完整格式
  Future<String> _exportCompleteFormat(
    List<PlatformSpec> platforms,
    List<ModelSpec> models,
    PlatformProvider platformProvider,
  ) async {
    // 构建导出数据
    final List<Map<String, dynamic>> exportData = [];

    // 遍历每个平台
    for (var platform in platforms) {
      final platformData = <String, dynamic>{
        'id': platform.id,
        'platform': platform.name,
        'baseUrl': platform.baseUrl,
        'type': platform.type.name,
        'apiVersion': platform.apiVersion,
        'description': platform.description,
        'apiKeyHeader': platform.apiKeyHeader,
        'orgIdHeader': platform.orgIdHeader,
        'isOpenAICompatible': platform.isOpenAICompatible,
        'extraHeaders': platform.extraHeaders,
        'extraAttributes': platform.extraAttributes,
      };

      // 获取API密钥和组织ID
      final apiKey = await platformProvider.getApiKey(platform.id);
      final orgId = await platformProvider.getOrgId(platform.id);

      if (apiKey != null) {
        platformData['apiKey'] = apiKey;
      }

      if (orgId != null) {
        platformData['orgId'] = orgId;
      }

      // 获取该平台下的所有模型
      final platformModels =
          models.where((m) => m.platformId == platform.id).toList();
      if (platformModels.isNotEmpty) {
        platformData['models'] =
            platformModels
                .map(
                  (model) => {
                    'id': model.id,
                    'name': model.name,
                    'description': model.description,
                    'type': model.type.name,
                    'platformId': model.platformId,
                    'version': model.version,
                    'contextWindow': model.contextWindow,
                    'inputPricePerK': model.inputPricePerK,
                    'outputPricePerK': model.outputPricePerK,
                    'supportsStreaming': model.supportsStreaming,
                    'supportsFunctionCalling': model.supportsFunctionCalling,
                    'supportsVision': model.supportsVision,
                    'maxOutputTokens': model.maxOutputTokens,
                    'extraAttributes': model.extraAttributes,
                  },
                )
                .toList();
      } else {
        platformData['models'] = [];
      }

      exportData.add(platformData);
    }

    // 转换为JSON字符串
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  // 解析平台类型
  PlatformType _parsePlatformType(String typeStr) {
    switch (typeStr) {
      case 'openAI':
        return PlatformType.openAI;
      default:
        return PlatformType.other;
    }
  }

  // 解析模型类型
  ModelType _parseModelType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'text':
        return ModelType.text;
      case 'image':
        return ModelType.image;
      case 'vision':
        return ModelType.vision;
      default:
        return ModelType.text; // 默认为文本类型
    }
  }
}
