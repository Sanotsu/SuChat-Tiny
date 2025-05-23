import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/custom_widgets/selectable_adapter.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../core/utils/tools.dart';
import 'custom_code_field.dart';

/// 优化的Markdown渲染工具类
///
/// 提供缓存机制和智能组件加载，优化性能
class CustomMarkdownRenderer {
  // 私有构造函数，防止直接实例化
  CustomMarkdownRenderer._();

  // 单例实例
  static final CustomMarkdownRenderer _instance = CustomMarkdownRenderer._();

  // 获取单例
  static CustomMarkdownRenderer get instance => _instance;

  // Markdown缓存 - 使用LRU缓存策略
  final Map<String, Widget> _markdownCache = {};

  // 缓存大小限制
  static const int _maxCacheSize = 200;

  // 预定义的所有组件列表
  static final List<MarkdownComponent> _allComponents = [
    CodeBlockMd(),
    NewLines(),
    BlockQuote(),
    ImageMd(),
    ATagMd(),
    TableMd(),
    HTag(),
    UnOrderedList(),
    OrderedList(),
    RadioButtonMd(),
    CheckBoxMd(),
    HrLine(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
    IndentMd(),
  ];

  // 预定义的所有内联组件
  static final List<MarkdownComponent> _allInlineComponents = [
    ImageMd(),
    ATagMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
  ];

  /// 渲染Markdown内容
  ///
  /// [text] 要渲染的Markdown文本
  /// [selectable] 是否可选择文本(默认不可选)
  /// [textStyle] 文本样式
  Widget render(String text, {TextStyle? textStyle, bool selectable = false}) {
    if (text.isEmpty) return const SizedBox.shrink();

    // 检查缓存中是否存在
    final cacheKey = '${selectable}_$text';
    final cachedWidget = _markdownCache[cacheKey];
    if (cachedWidget != null) return cachedWidget;

    return _buildMarkdownWidget(text, textStyle, selectable, cacheKey);
  }

  // 构建Markdown小部件
  Widget _buildMarkdownWidget(
    String text,
    TextStyle? textStyle,
    bool selectable,
    String cacheKey,
  ) {
    try {
      final widget = _buildGptMarkdown(text, textStyle, selectable);
      _addToCache(cacheKey, widget);
      return widget;
    } catch (e) {
      logger.e('Markdown渲染错误: $e');
      return _buildFallbackMarkdown(text, textStyle, selectable, cacheKey);
    }
  }

  // 主要的 GPT Markdown渲染器
  Widget _buildGptMarkdown(String text, TextStyle? textStyle, bool selectable) {
    return Builder(
      builder: (context) {
        // 2025-04-23 我在21日提出issue (https://github.com/Infinitix-LLC/gpt_markdown/issues/56)，23日作者就修复了.
        // 表格中使用$$...$$、\[...\]包裹的LaTeX可以正常显示不抛错了，但是所有(不管是否表格内)使用 $...$ 还是无法正常显示
        // 所以需要再处理一次，检测到$...$包裹的LaTeX公式，替换为使用单行$...$来包裹
        text = convertDollarToParenthesesLatex(text);

        // print("处理后的text:\n $text");

        final child = GptMarkdown(
          text,
          style:
              textStyle ??
              TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          onLinkTab: (url, title) {
            logger.i('链接点击: $url, 标题: $title');
            launchStringUrl(url);
          },
          highlightBuilder: _buildHighlight,
          latexWorkaround: _processLatexText,
          imageBuilder: _buildImage,
          latexBuilder:
              (context, tex, textStyle, inline) =>
                  _buildLatex(context, tex, textStyle, inline),
          sourceTagBuilder: _buildSourceTag,
          linkBuilder: _buildLink,
          codeBuilder: _buildCode,
          // codeBuilder: (context, name, code, closed) {
          //   return Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: 16),
          //     child: Text(
          //       code.trim(),
          //       style: TextStyle(
          //         fontFamily: 'JetBrains Mono',
          //         fontSize: 14,
          //         height: 1.5,
          //         color: Theme.of(context).colorScheme.onSurface,
          //       ),
          //     ),
          //   );
          // },
          components: _allComponents,
          inlineComponents: _allInlineComponents,
        );

        return selectable ? SelectionArea(child: child) : child;
      },
    );
  }

  // 备用渲染器
  Widget _buildFallbackMarkdown(
    String text,
    TextStyle? textStyle,
    bool selectable,
    String cacheKey,
  ) {
    logger.e('使用备用渲染器 MarkdownBody 渲染Markdown内容');
    final widget = MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: textStyle,
        tableColumnWidth: const IntrinsicColumnWidth(),
      ),
    );
    _addToCache(cacheKey, widget);
    return widget;
  }

  // 高亮文本构建器
  Widget _buildHighlight(BuildContext context, String text, TextStyle style) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: style.fontSize != null ? style.fontSize! * 0.9 : 13.5,
          height: style.height,
        ),
      ),
    );
  }

  // LaTeX文本处理
  String _processLatexText(String tex) {
    final stack = <String>[];
    tex = tex.splitMapJoin(
      RegExp(r"\\text\{|\{|\}|\_"),
      onMatch: (p) {
        final input = p[0] ?? "";
        if (input == r"\text{") {
          stack.add(input);
        }
        if (stack.isNotEmpty) {
          if (input == r"{") {
            stack.add(input);
          }
          if (input == r"}") {
            stack.removeLast();
          }
          if (input == r"_") {
            return r"\_";
          }
        }
        return input;
      },
    );
    return tex.replaceAllMapped(RegExp(r"align\*"), (match) => "aligned");
  }

  // 图片构建器
  Widget _buildImage(BuildContext context, String url) {
    return Image.network(
      url,
      width: 100,
      height: 100,
      errorBuilder:
          (context, error, stackTrace) => Icon(
            Icons.error,
            size: 24,
            color: Theme.of(context).colorScheme.error,
          ),
    );
  }

  // LaTeX构建器
  Widget _buildLatex(
    BuildContext context,
    String tex,
    TextStyle? textStyle,
    bool inline,
  ) {
    if (tex.contains(r"\begin{tabular}")) {
      return _buildLatexTable(tex);
    }

    final controller = ScrollController();

    final child =
        inline
            ? Math.tex(tex, textStyle: textStyle)
            : Padding(
              padding: EdgeInsets.all(8),
              child: Scrollbar(
                controller: controller,
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(tex, textStyle: textStyle),
                ),
              ),
            );

    return InkWell(
      onTap: () => logger.e("LaTeX content: $tex"),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableAdapter(selectedText: tex, child: child),
      ),
    );
  }

  Widget _buildLatexTable(String tex) {
    final tableString =
        "|${(RegExp(r"^\\begin\{tabular\}\{.*?\}(.*?)\\end\{tabular\}$", multiLine: true, dotAll: true).firstMatch(tex)?[1] ?? "").trim()}|";

    final processedString = tableString
        .replaceAll(r"\\", "|\n|")
        .replaceAll(r"\hline", "")
        .replaceAll(RegExp(r"(?<!\\)&"), "|");

    final tableStringList = processedString.split("\n")..insert(1, "|---|");
    return GptMarkdown(tableStringList.join("\n"));
  }

  // 源标签构建器
  Widget _buildSourceTag(
    BuildContext context,
    String string,
    TextStyle textStyle,
  ) {
    final value = (int.tryParse(string) ?? -1) + 1;
    return SizedBox(
      height: 20,
      width: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            "$value",
            style: textStyle.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // 链接构建器
  Widget _buildLink(
    BuildContext context,
    String label,
    String path,
    TextStyle style,
  ) {
    return Text(
      label,
      style: style.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }

  // 代码块构建器
  Widget _buildCode(
    BuildContext context,
    String name,
    String code,
    bool closed,
  ) {
    return CustomCodeField(name: name, codes: code);
  }

  /// 添加到缓存
  void _addToCache(String key, Widget widget) {
    if (_markdownCache.length >= _maxCacheSize) {
      _markdownCache.remove(_markdownCache.keys.first);
    }
    _markdownCache[key] = widget;
  }

  /// 清除全部缓存
  void clearCache() {
    _markdownCache.clear();
  }

  /// 从缓存中移除特定项
  void removeFromCache(String text) {
    _markdownCache.remove(text);
    _markdownCache.remove('true_$text');
    _markdownCache.remove('false_$text');
  }

  /// 获取当前缓存大小
  int get cacheSize => _markdownCache.length;
}

/// 向后兼容的API，调用单例的render方法
Widget buildCusMarkdown(String text, {TextStyle? textStyle}) =>
    CustomMarkdownRenderer.instance.render(text, textStyle: textStyle);

/// 将所有使用$...$包裹的单行LaTeX语法替换为\(...\)包裹
String convertDollarToParenthesesLatex(String text) {
  // 匹配单个美元符号包裹的LaTeX公式：$...$
  // 注意: 确保不匹配 $$...$$ 和 \$
  final inlineLatexPattern = RegExp(
    r'(?<!\$)(?<!\\)\$(?!\$)(.*?)(?<!\\)\$(?!\$)', // 确保前后不是$，也不是\$
    multiLine: true,
  );

  // 替换为统一格式
  return text.replaceAllMapped(inlineLatexPattern, (match) {
    String? formulaContent = match.group(1);
    if (formulaContent == null) return match.group(0) ?? '';
    return '\\($formulaContent\\)';
  });
}
