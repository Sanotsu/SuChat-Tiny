import 'package:flutter/material.dart';

import '../core/storage/db_helper.dart';
import '../models/model_spec.dart';

/// 模型提供者，管理模型信息
class ModelProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();

  List<ModelSpec> _models = [];
  ModelSpec? _selectedModel;
  bool _isModelsLoaded = false;

  /// 获取所有模型
  List<ModelSpec> get models => _models;

  /// 获取选中的模型
  ModelSpec? get selectedModel => _selectedModel;

  /// 模型是否已加载
  bool get isModelsLoaded => _isModelsLoaded;

  /// 加载所有模型
  Future<void> loadModels() async {
    _models = await _dbHelper.getAllModels();
    _isModelsLoaded = true;

    if (_models.isNotEmpty) {
      if (_selectedModel == null) {
        _selectedModel = _models.first;
      } else {
        // 确保选中的模型在列表中
        final modelExists = _models.any((m) => m.id == _selectedModel!.id);
        if (!modelExists) {
          _selectedModel = _models.first;
        }
      }
    }

    notifyListeners();
  }

  /// 根据平台加载模型
  Future<void> loadModelsByPlatform(String platformId) async {
    _models = await _dbHelper.getModelsByPlatform(platformId);
    _isModelsLoaded = true;

    if (_models.isNotEmpty) {
      // 如果当前选择的模型不在这个平台下，重新选择
      final modelExists =
          _selectedModel != null &&
          _models.any((m) => m.id == _selectedModel!.id);

      if (!modelExists) {
        _selectedModel = _models.first;
      }
    } else {
      _selectedModel = null;
    }

    notifyListeners();
  }

  /// 重置加载状态
  void resetLoadState() {
    _isModelsLoaded = false;
    notifyListeners();
  }

  /// 选择模型
  void selectModel(ModelSpec model) {
    if (_selectedModel?.id != model.id) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  /// 添加/更新模型
  Future<void> saveModel(ModelSpec model) async {
    await _dbHelper.saveModel(model);
    await loadModels();
  }

  /// 删除模型
  Future<void> deleteModel(String modelId) async {
    await _dbHelper.deleteModel(modelId);

    // 如果删除的是当前选中的模型，重置选中的模型
    if (_selectedModel?.id == modelId) {
      _selectedModel = _models.isNotEmpty ? _models.first : null;
    }

    await loadModels();
  }

  /// 根据类型获取模型
  Future<List<ModelSpec>> getModelsByType(ModelType type) async {
    return await _dbHelper.getModelsByType(type);
  }
}
