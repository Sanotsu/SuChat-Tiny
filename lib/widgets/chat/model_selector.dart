import 'package:flutter/material.dart';

import '../../models/model_spec.dart';

/// 模型选择器组件
class ModelSelector extends StatelessWidget {
  /// 可选模型列表
  final List<ModelSpec> models;

  /// 当前选中的模型
  final ModelSpec? selectedModel;

  /// 模型变更回调
  final Function(ModelSpec model) onChanged;

  const ModelSelector({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Text('尚未添加模型'),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedModel?.id,
      decoration: const InputDecoration(
        labelText: '模型',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items:
          models.map((model) {
            return DropdownMenuItem<String>(
              value: model.id,
              child: Text(model.name, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          final selected = models.firstWhere((m) => m.id == value);
          onChanged(selected);
        }
      },
    );
  }
}
