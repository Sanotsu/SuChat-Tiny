// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/db_ddl.dart';
import '../../../core/storage/db_helper.dart';
import '../../../core/storage/db_init.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/tools.dart';
import '../../../models/chat_message.dart';
import '../../../models/conversation.dart';
import '../../../models/model_spec.dart';
import '../../../models/platform_spec.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/small_tool_widgets.dart';
import '../../../widgets/common/toast_utils.dart';

///
/// 优化版备份恢复功能
///
// 全量备份导出的文件的前缀(_时间戳.zip)
const ZIP_FILE_PREFIX = "SuChatTiny全量数据备份_";
// 导出文件要压缩，临时存放的地址
const ZIP_TEMP_DIR_AT_EXPORT = "temp_dir_at_export";
const ZIP_TEMP_DIR_AT_UNZIP = "temp_dir_at_unzip";
const ZIP_TEMP_DIR_AT_RESTORE = "temp_dir_at_restore";

class BackupAndRestoreScreen extends StatefulWidget {
  const BackupAndRestoreScreen({super.key});

  @override
  State<BackupAndRestoreScreen> createState() => _BackupAndRestoreScreenState();
}

class _BackupAndRestoreScreenState extends State<BackupAndRestoreScreen> {
  final DBHelper _dbHelper = DBHelper();
  final DBInit _dbInit = DBInit();

  bool isLoading = false;
  String _loadingMessage = '';

  // 备份统计信息
  int _fileCount = 0;
  String _totalFileSize = '0 B';

  // 是否获得了存储权限(没获得就无法备份恢复)
  bool isPermissionGranted = false;

  String note = """**全量备份** 是把应用本地数据库中的所有数据导出保存在本地，包括用智能助手的对话历史、平台配置、模型配置等。
\n\n**覆写恢复** 是把 '全量备份' 导出的压缩包，重新导入到应用中，覆盖应用本地数据库中的所有数据。""";

  @override
  void initState() {
    super.initState();
    _getPermission();
  }

  /// 获取存储权限
  Future<void> _getPermission() async {
    bool flag = await requestStoragePermission();
    setState(() {
      isPermissionGranted = flag;
    });
  }

  ///
  /// 全量备份：导出db中所有的数据
  ///
  /// 1. 检查存储权限
  /// 2. 用户选择导出文件存放位置
  /// 3. 处理备份流程:
  ///   3.1 创建临时文件夹
  ///   3.2 将数据库导出为JSON文件
  ///   3.3 将JSON文件压缩到ZIP文件
  ///   3.4 将ZIP文件复制到用户指定位置
  ///   3.5 清理临时文件
  ///
  Future<void> _exportAllData() async {
    // 用户没有授权，提示错误
    if (!mounted) return;
    if (!isPermissionGranted) {
      ToastUtils.showError("用户已禁止访问内部存储,无法进行数据备份。\n如需启用，请到应用的权限管理中授权读写手机存储。");
      return;
    }

    // 用户选择指定文件夹
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
      _loadingMessage = '正在准备备份...';
    });

    try {
      // 获取临时目录
      Directory tempDir = await getTemporaryDirectory();
      var tempZipDir = await Directory(
        p.join(tempDir.path, ZIP_TEMP_DIR_AT_EXPORT),
      ).create(recursive: true);

      // ZIP文件的名称
      String zipName = "$ZIP_FILE_PREFIX${fileTs(DateTime.now())}.zip";
      String zipPath = p.join(tempZipDir.path, zipName);

      // 导出数据库数据
      setState(() {
        _loadingMessage = '正在导出数据库...';
      });
      await _backupDbData(zipPath);

      // 检查生成的ZIP文件
      File zipFile = File(zipPath);
      if (!await zipFile.exists()) {
        throw Exception('备份文件创建失败，请重试');
      }

      // 显示文件大小
      int zipSizeBytes = await zipFile.length();
      setState(() {
        _totalFileSize = formatFileSize(zipSizeBytes);
      });

      // 移动临时文件到用户选择的位置
      setState(() {
        _loadingMessage = '正在保存备份文件...';
      });

      File destinationFile = File(p.join(selectedDirectory, zipName));
      // 如果目标文件已经存在，则先删除
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }

      // 复制文件到用户选择的位置
      await zipFile.copy(destinationFile.path);

      // 删除临时文件
      await zipFile.delete();

      setState(() {
        isLoading = false;
      });

      ToastUtils.showSuccess(
        "备份完成!\n已保存到: $selectedDirectory\n文件大小: $_totalFileSize",
      );
    } catch (e) {
      logger.e('备份操作出现错误: $e');
      setState(() {
        isLoading = false;
      });

      ToastUtils.showError("备份失败: ${e.toString()}");
    }
  }

  /// 备份数据库数据到指定文件路径
  Future<void> _backupDbData(String zipPath) async {
    try {
      // 导出数据库表到JSON文件
      Map<String, dynamic> exportResult = await _dbInit.exportDatabase();
      int exportedCount = exportResult['count'] as int;
      List<String> exportedFiles = exportResult['files'] as List<String>;
      String tempJsonsPath = exportResult['path'] as String;

      if (exportedCount == 0) {
        throw Exception('数据库导出失败，未找到任何数据');
      }

      setState(() {
        _fileCount = exportedCount;
        _loadingMessage = '正在压缩 $_fileCount 个文件...';
      });

      // 创建一个输出文件流
      final outputStream = OutputFileStream(zipPath);

      // 创建ZIP编码器
      final zipEncoder = ZipFileEncoder();
      zipEncoder.createWithStream(outputStream);

      // 遍历并添加所有导出的文件
      for (String filePath in exportedFiles) {
        File file = File(filePath);
        if (await file.exists()) {
          // 从文件路径提取文件名
          String fileName = p.basename(filePath);
          // 添加文件到ZIP
          await zipEncoder.addFile(file, fileName);
        }
      }

      // 关闭ZIP编码器
      await zipEncoder.close();

      // 压缩完成后，清空临时JSON文件夹
      await _deleteFilesInDirectory(tempJsonsPath);
    } catch (e) {
      logger.e('备份数据时出错: $e');
      throw Exception('备份数据时出错: $e');
    }
  }

  /// 删除指定文件夹下所有文件
  Future<void> _deleteFilesInDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (await directory.exists()) {
      await for (var file in directory.list()) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  }

  ///
  /// 数据库恢复：从备份文件恢复数据
  ///
  /// 1. 获取用户选择的备份文件
  /// 2. 验证文件格式
  /// 3. 备份当前数据库（防止恢复失败导致数据丢失）
  /// 4. 解压备份文件
  /// 5. 清空现有数据库
  /// 6. 导入JSON数据到数据库
  ///
  Future<void> _restoreDataFromBackup() async {
    if (!isPermissionGranted) {
      ToastUtils.showError("用户已禁止访问内部存储,无法进行数据恢复。\n如需启用，请到应用的权限管理中授权读写手机存储。");
      return;
    }

    File? file = await FilePickerHelper.pickAndSaveFile(
      fileType: CusFileType.custom,
      allowedExtensions: ['zip'],
    );

    if (file == null) {
      return;
    }

    if (isLoading) return;

    // 验证文件格式
    String fileName = p.basename(file.path);
    if (!fileName.startsWith(ZIP_FILE_PREFIX) ||
        !fileName.toLowerCase().endsWith('.zip')) {
      ToastUtils.showError(
        "选择的文件不是有效的备份文件，恢复已取消。\n备份文件应以 \"$ZIP_FILE_PREFIX\" 开头。",
      );
      return;
    }

    // 显示确认对话框
    bool? shouldProceed = await _showRestoreConfirmationDialog();
    if (shouldProceed != true) {
      return;
    }

    setState(() {
      isLoading = true;
      _loadingMessage = '正在准备恢复...';
    });

    try {
      // 创建临时目录用于解压
      Directory tempDir = await getTemporaryDirectory();
      String unzipPath = p.join(tempDir.path, ZIP_TEMP_DIR_AT_UNZIP);

      // 清空已有的解压目录
      Directory unzipDir = Directory(unzipPath);
      if (await unzipDir.exists()) {
        await unzipDir.delete(recursive: true);
      }
      await unzipDir.create(recursive: true);

      // 解压备份文件
      setState(() {
        _loadingMessage = '正在解压备份文件...';
      });

      // 使用extractFileToDisk替代手动解压，简化代码
      await extractFileToDisk(file.path, unzipPath);

      // 获取解压后的JSON文件
      List<File> jsonFiles =
          Directory(unzipPath)
              .listSync()
              .where(
                (entity) => entity is File && entity.path.endsWith('.json'),
              )
              .map((entity) => entity as File)
              .toList();

      if (jsonFiles.isEmpty) {
        throw Exception('备份文件中没有找到有效的数据文件');
      }

      setState(() {
        _fileCount = jsonFiles.length;
        _loadingMessage = '找到 $_fileCount 个数据文件，准备恢复...';
      });

      // 在恢复前先备份当前数据库
      setState(() {
        _loadingMessage = '正在备份当前数据...';
      });

      Directory restoreTempDir = await Directory(
        p.join(tempDir.path, ZIP_TEMP_DIR_AT_RESTORE),
      ).create(recursive: true);

      String autoBackupName = "$ZIP_FILE_PREFIX${fileTs(DateTime.now())}.zip";
      String autoBackupPath = p.join(restoreTempDir.path, autoBackupName);

      await _backupDbData(autoBackupPath);

      // 恢复旧数据之前，删除现有数据库
      setState(() {
        _loadingMessage = '正在清除现有数据...';
      });

      await _dbInit.deleteDB();

      // 导入JSON数据到数据库
      setState(() {
        _loadingMessage = '正在导入数据...';
      });

      await _importJsonFilesToDb(jsonFiles);

      // 清理操作
      setState(() {
        _loadingMessage = '正在清理临时文件...';
      });

      // 清理解压目录
      if (await unzipDir.exists()) {
        await unzipDir.delete(recursive: true);
      }

      // 清理自动备份（可选）
      File autoBackupFile = File(autoBackupPath);
      if (await autoBackupFile.exists()) {
        await autoBackupFile.delete();
      }

      setState(() {
        isLoading = false;
      });

      ToastUtils.showSuccess("恢复成功，已导入 $_fileCount 个数据文件");
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // 显示错误对话框
      if (mounted) {
        commonExceptionDialog(
          context,
          "恢复失败",
          "文件: ${file.path}\n\n错误信息: ${e.toString()}\n\n请确保选择了正确的备份文件，并重试。",
        );
      }
    }
  }

  /// 将JSON文件数据导入到数据库
  Future<void> _importJsonFilesToDb(List<File> jsonFiles) async {
    int importedFiles = 0;

    for (File file in jsonFiles) {
      // 获取文件名
      var filename = p.basename(file.path).toLowerCase();

      // 读取JSON文件内容
      String jsonData = await file.readAsString();

      try {
        // 解析JSON数据
        List jsonMapList = json.decode(jsonData);

        // 根据文件名导入不同类型的数据
        if (filename == "${DBDdl.tablePlatforms}.json") {
          await _dbHelper.savePlatformList(
            jsonMapList.map((e) => PlatformSpec.fromMap(e)).toList(),
          );
        } else if (filename == "${DBDdl.tableModels}.json") {
          await _dbHelper.saveModelList(
            jsonMapList.map((e) => ModelSpec.fromMap(e)).toList(),
          );
        } else if (filename == "${DBDdl.tableConversations}.json") {
          await _dbHelper.saveConversationList(
            jsonMapList.map((e) => Conversation.fromMap(e)).toList(),
          );
        } else if (filename == "${DBDdl.tableMessages}.json") {
          await _dbHelper.saveMessageList(
            jsonMapList.map((e) => ChatMessage.fromMap(e)).toList(),
          );
        }

        importedFiles++;

        setState(() {
          _loadingMessage = '正在导入数据... ($importedFiles/${jsonFiles.length})';
        });
      } catch (e) {
        logger.e('导入文件 $filename 时出错: $e');
        throw Exception('导入数据失败，文件格式可能已损坏: $filename');
      }
    }
  }

  /// 显示恢复确认对话框
  Future<bool?> _showRestoreConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("警告：覆写恢复"),
          content: const Text("恢复操作将完全覆盖现有数据！\n\n继续操作前，建议您先备份当前数据。\n\n确定要继续吗？"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("确认覆写", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("备份恢复"),
        actions: [
          IconButton(
            onPressed: () {
              commonMarkdwonHintDialog(context, "备份恢复说明", note);
            },
            icon: const Icon(Icons.info_outline),
            tooltip: '帮助',
          ),
        ],
      ),
      body:
          isLoading
              ? _buildLoadingView()
              : Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 40),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildBackupCard(),
                              const SizedBox(width: 20),
                              _buildRestoreCard(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildInfoSection(),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  /// 构建加载中视图
  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(size: 40, strokeWidth: 4),
            const SizedBox(height: 20),
            Text(
              _loadingMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_fileCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                "文件数: $_fileCount${_totalFileSize.isNotEmpty ? '   大小: $_totalFileSize' : ''}",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Icon(
          Icons.import_export,
          size: 48,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          "数据备份与恢复",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColorDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "保护您的数据安全，随时备份和恢复",
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBackupCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showBackupConfirmationDialog();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.backup, size: 40, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                "全量备份",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt, color: Colors.white),
                label: const Text(
                  "立即备份",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: () {
                  _showBackupConfirmationDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _restoreDataFromBackup,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.restore, size: 40, color: Colors.green),
              const SizedBox(height: 12),
              const Text(
                "覆写恢复",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text(
                  "选择文件",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _restoreDataFromBackup,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        const Text(
          "温馨提示",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "1. 定期备份可防止数据丢失\n"
          "2. 恢复操作将完全覆盖现有数据\n"
          "3. 备份文件请妥善保管",
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showBackupConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("全量备份"),
          content: const Text("确认导出所有数据到备份文件？"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.pop(context, false);
              },
              child: const Text("取消"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (!mounted) return;
                Navigator.pop(context, true);
              },
              child: const Text("确认备份"),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null && value) _exportAllData();
    });
  }
}
