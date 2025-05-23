import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/common/toast_utils.dart';
import '../constants/constants.dart';

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    // Should each log print contain a timestamp
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

Future<void> launchStringUrl(String url) async {
  if (!await launchUrl(
    Uri.parse(url),
    // mode: LaunchMode.externalApplication,
    // mode: LaunchMode.inAppBrowserView,
    // browserConfiguration: const BrowserConfiguration(showTitle: true),
  )) {
    throw Exception('无法访问 $url');
  }
}

/// 格式化日期为最近的相对时间
String formatRecentDate(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      if (difference.inMinutes == 0) {
        return '刚刚';
      }
      return '${difference.inMinutes}分钟前';
    }
    return '${difference.inHours}小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}天前';
  } else {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)}';
  }
}

String _twoDigits(int n) {
  if (n >= 10) return '$n';
  return '0$n';
}

/// 格式化时间戳为带微秒的时间戳
/// fileTs => fileNameTimestamp
String fileTs(DateTime dateTime) {
  final formatted = DateFormat(constDatetimeSuffix).format(dateTime);
  final us = (dateTime.microsecondsSinceEpoch % 1000000).toString().padLeft(
    6,
    '0',
  );
  return '${formatted}_$us';
}

// 格式化文件大小
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// 只请求内部存储访问权限(菜品导入、备份还原)
Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    // 获取设备sdk版本
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    int sdkInt = androidInfo.version.sdkInt;

    if (sdkInt <= 32) {
      var storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } else {
      var storageStatus = await Permission.manageExternalStorage.request();
      return (storageStatus.isGranted);
    }
  } else if (Platform.isIOS) {
    Map<Permission, PermissionStatus> statuses =
        await [Permission.mediaLibrary, Permission.storage].request();
    return (statuses[Permission.mediaLibrary]!.isGranted &&
        statuses[Permission.storage]!.isGranted);
  } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    // 桌面应用根据系统权限来
    return true;
  } else {
    // 其他先不考虑
    return false;
  }
}

// 保存文生图的图片到本地
Future<String?> saveImageToLocal(
  String netImageUrl, {
  String? prefix,
  // 指定保存的名称，比如 xxx.png
  String? imageName,
  Directory? dlDir,
  // 是否显示保存提示
  bool showSaveHint = true,
}) async {
  // 首先获取设备外部存储管理权限
  if (!(await requestStoragePermission())) {
    ToastUtils.showError("未授权访问设备外部存储，无法保存图片");

    return null;
  }

  // 文生图片一般有一个随机的名称，就只使用它就好(可以避免同一个保存了多份)
  // 注意，像阿里云这种地址会带上过期日期token信息等参数内容，所以下载保存的文件名要过滤掉，只保留图片地址信息
  // 目前硅基流动、智谱等没有额外信息，问号分割后也不影响
  // 如果有指定保存的图片名称，则不用从url获取
  imageName ??= netImageUrl.split("?").first.split('/').last;

  dynamic closeToast;
  try {
    // 2024-09-14 支持自定义下载的文件夹
    var dir = dlDir ?? (await getImageGenDir());

    // 2024-08-17 直接保存文件到指定位置
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 传入的前缀有强制带上下划线
    final file = File('${dir.path}/${prefix ?? ""}$imageName');

    // 检查文件是否已存在
    if (await file.exists()) {
      ToastUtils.showToast('文件已存在于: $file');
      return file.path;
    }

    if (showSaveHint) {
      closeToast = ToastUtils.showLoading('【图片保存中...】');
    }

    var response = await Dio().get(
      netImageUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    await file.writeAsBytes(response.data);

    if (showSaveHint && closeToast != null) {
      closeToast();
      ToastUtils.showToast("图片已保存在手机下/${file.path.split("/0/").last}");
    }

    return file.path;
  } finally {
    if (showSaveHint && closeToast != null) {
      closeToast();
    }
  }

  // 用这个自定义的，阿里云地址会报403错误，原因不清楚
  // var respData = await HttpUtils.get(
  //   path: netImageUrl,
  //   showLoading: true,
  //   responseType: CusRespType.bytes,
  // );

  // await file.writeAsBytes(respData);
  // ToastUtils.showToast("图片已保存${file.path}");
}

/// 获取应用主目录
/// [subfolder] 可选的子目录名称
///
/// 返回的目录结构：
/// - Android (有权限): /storage/emulated/0/SuChatTiny[/subfolder]
/// - Android (无权限): /data/data/《packageName》/app_flutter/SuChatTiny[/subfolder]
/// - iOS: ~/Documents/SuChatTiny[/subfolder]
/// - 其他平台: 文档目录/SuChatTiny[/subfolder]
Future<Directory> getAppHomeDirectory({String? subfolder}) async {
  try {
    Directory baseDir;

    if (Platform.isAndroid) {
      // 尝试获取外部存储权限
      final hasPermission = await requestStoragePermission();

      if (hasPermission) {
        // 注意：直接使用硬编码路径在Android 10+可能不可靠
        baseDir = Directory('/storage/emulated/0/SuChatTiny');
      } else {
        ToastUtils.showError("未授权访问设备外部存储，数据将保存到应用文档目录");

        baseDir = await getApplicationDocumentsDirectory();
        baseDir = Directory(p.join(baseDir.path, 'SuChatTiny'));
      }
    } else {
      // 其他平台使用文档目录
      baseDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(p.join(baseDir.path, 'SuChatTiny'));
    }

    // 处理子目录
    if (subfolder != null && subfolder.trim().isNotEmpty) {
      baseDir = Directory(p.join(baseDir.path, subfolder));
    }

    // 确保目录存在
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    logger.i('getAppHomeDirectory 获取的目录: ${baseDir.path}');
    return baseDir;
  } catch (e) {
    logger.e('获取应用目录失败: $e');
    // 回退方案：使用临时目录
    final tempDir = await getTemporaryDirectory();
    return Directory(p.join(tempDir.path, 'SuChatTinyFallback'));
  }
}

/// 获取sqlite数据库文件保存的目录
Future<Directory> getSqliteDbDir() async {
  return getAppHomeDirectory(subfolder: "DB/sqlite_db");
}

// 数据备份时，数据库表导出为json文件，临时存放的地方
Future<Directory> getDbExportTempDir() async {
  return getAppHomeDirectory(subfolder: "DB/db_export_temp");
}

/// 使用file_picker选择文件时，保存文件的目录
/// 所有文件选择都放在同一个位置，重复时直接返回已存在的内容
Future<Directory> getFilePickerSaveDir() async {
  return getAppHomeDirectory(subfolder: "FILE_PICK/file_picker_files");
}

/// 使用image_picker选择文件时，保存文件的目录
/// 所有文件选择都放在同一个位置，重复时直接返回已存在的内容
Future<Directory> getImagePickerSaveDir() async {
  return getAppHomeDirectory(subfolder: "FILE_PICK/image_picker_files");
}

/// 图片生成时，图片文件保存的目录
Future<Directory> getImageGenDir() async {
  return getAppHomeDirectory(subfolder: "AI_GEN/images");
}

/// 使用dio下载文件时，保存文件的目录
Future<Directory> getDioDownloadDir() async {
  return getAppHomeDirectory(subfolder: "NET_DL/dio_download_files");
}

/// 语音输入时，录音文件保存的目录
Future<Directory> getBackupDir() async {
  return getAppHomeDirectory(subfolder: "BAKUP/backup_files");
}
