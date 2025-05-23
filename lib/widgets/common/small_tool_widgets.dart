// 调用外部浏览器打开url
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// 强制收起键盘
unfocusHandle() {
  // 这个不一定有用，比如下面原本键盘弹出来了，跳到历史记录页面，回来之后还是弹出来的
  // FocusScope.of(context).unfocus();

  FocusManager.instance.primaryFocus?.unfocus();
}

// 异常弹窗
commonExceptionDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("确定"),
          ),
        ],
      );
    },
  );
}

commonMarkdwonHintDialog(
  BuildContext context,
  String title,
  String message, {
  double? msgFontSize,
}) async {
  unfocusHandle();
  // 强行停200毫秒(100还不够)，密码键盘未收起来就显示弹窗出现布局溢出的问题
  await Future.delayed(const Duration(milliseconds: 200));

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (context) {
      // 获取屏幕尺寸
      final size = MediaQuery.of(context).size;
      // 计算显示最大宽度
      final maxWidth = size.width;

      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            child: GptMarkdown(
              message,
              style: TextStyle(fontSize: msgFontSize),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("确定"),
          ),
        ],
      );
    },
  );
}
