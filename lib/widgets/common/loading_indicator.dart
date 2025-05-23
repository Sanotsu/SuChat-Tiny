import 'package:flutter/material.dart';

/// 通用加载指示器组件
class LoadingIndicator extends StatelessWidget {
  /// 指示器大小
  final double size;

  /// 指示器颜色，如果未指定则使用主题的主色调
  final Color? color;

  /// 线条宽度
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
