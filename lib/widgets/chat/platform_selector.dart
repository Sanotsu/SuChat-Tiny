import 'package:flutter/material.dart';

import '../../models/platform_spec.dart';

/// 平台选择器组件
class PlatformSelector extends StatelessWidget {
  /// 可选平台列表
  final List<PlatformSpec> platforms;

  /// 当前选中的平台
  final PlatformSpec? selectedPlatform;

  /// 平台变更回调
  final Function(PlatformSpec platform) onChanged;

  const PlatformSelector({
    super.key,
    required this.platforms,
    required this.selectedPlatform,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (platforms.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          child: Text('尚未添加平台'),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedPlatform?.id,
      decoration: const InputDecoration(
        labelText: '平台',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items:
          platforms.map((platform) {
            return DropdownMenuItem<String>(
              value: platform.id,
              child: Text(platform.name, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          final selected = platforms.firstWhere((p) => p.id == value);
          onChanged(selected);
        }
      },
    );
  }
}
