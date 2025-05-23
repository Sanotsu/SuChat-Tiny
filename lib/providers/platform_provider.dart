import 'package:flutter/material.dart';

import '../core/storage/db_helper.dart';
import '../core/storage/secure_storage.dart';
import '../models/platform_spec.dart';

/// 平台提供者，管理平台信息
class PlatformProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  final SecureStorageHelper _secureStorage = SecureStorageHelper();

  List<PlatformSpec> _platforms = [];
  PlatformSpec? _selectedPlatform;

  /// 获取所有平台
  List<PlatformSpec> get platforms => _platforms;

  /// 获取选中的平台
  PlatformSpec? get selectedPlatform => _selectedPlatform;

  /// 加载所有平台
  Future<void> loadPlatforms() async {
    _platforms = await _dbHelper.getAllPlatforms();

    if (_platforms.isNotEmpty) {
      if (_selectedPlatform == null) {
        _selectedPlatform = _platforms.first;
      } else {
        // 确保选中的平台在列表中
        final platformExists = _platforms.any(
          (p) => p.id == _selectedPlatform!.id,
        );
        if (!platformExists) {
          _selectedPlatform = _platforms.first;
        }
      }
    }

    notifyListeners();
  }

  /// 根据ID获取平台
  Future<PlatformSpec?> getPlatformById(String platformId) async {
    return await _dbHelper.getPlatform(platformId);
  }

  /// 选择平台
  void selectPlatform(PlatformSpec platform) {
    if (_selectedPlatform?.id != platform.id) {
      _selectedPlatform = platform;
      notifyListeners();
    }
  }

  /// 添加/更新平台
  Future<void> savePlatform(PlatformSpec platform) async {
    await _dbHelper.savePlatform(platform);
    await loadPlatforms();
  }

  /// 删除平台
  Future<void> deletePlatform(String platformId) async {
    await _dbHelper.deletePlatform(platformId);

    // 如果删除的是当前选中的平台，重置选中的平台
    if (_selectedPlatform?.id == platformId) {
      _selectedPlatform = _platforms.isNotEmpty ? _platforms.first : null;
    }

    await loadPlatforms();
  }

  /// 保存平台API密钥
  Future<void> saveApiKey(String platformId, String apiKey) async {
    await _secureStorage.saveApiKey(platformId, apiKey);
  }

  /// 获取平台API密钥
  Future<String?> getApiKey(String platformId) async {
    return await _secureStorage.getApiKey(platformId);
  }

  /// 检查平台API密钥是否存在
  Future<bool> hasApiKey(String platformId) async {
    return await _secureStorage.hasApiKey(platformId);
  }

  /// 保存平台组织ID
  Future<void> saveOrgId(String platformId, String orgId) async {
    await _secureStorage.saveOrgId(platformId, orgId);
  }

  /// 获取平台组织ID
  Future<String?> getOrgId(String platformId) async {
    return await _secureStorage.getOrgId(platformId);
  }

  /// 根据平台ID获取平台名称（同步方法）
  String? getPlatformName(String platformId) {
    try {
      final platform = platforms.firstWhere((p) => p.id == platformId);
      return platform.name;
    } catch (e) {
      return null;
    }
  }
}
