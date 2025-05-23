import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/tools.dart';
import 'toast_utils.dart';

/// 轮播图交互类型
enum CarouselType {
  none, // 无动作 - 单纯的轮播展示,点击图片无动作
  dialog, // 类型1 - 点击弹窗显示单张图片预览
  page, // 类型2 - 点击跳转新页面显示单张图片预览
  gallery, // 类型3 - 点击弹窗显示图片画廊(默认)
}

///
/// 构建图片轮播组件
///
Widget buildImageCarouselSlider(
  List<String> imageList, {
  bool showPlaceholder = true, // 无图片时是否显示占位图
  CarouselType type = CarouselType.gallery, // 轮播图交互类型
  double? aspectRatio,
  Directory? downloadDir, // 长按下载目录
}) {
  final items = _buildCarouselItems(
    imageList,
    // 除非指定不显示图片，否则没有图片也显示一张占位图片
    showPlaceholder: showPlaceholder,
    type: type,
    downloadDir: downloadDir,
  );

  return CarouselSlider(
    options: CarouselOptions(
      autoPlay: true, // 自动播放
      enlargeCenterPage: true, // 居中图片放大
      aspectRatio: aspectRatio ?? 16 / 9, // 图片宽高比
      viewportFraction: 1, // 图片占屏幕宽度的比例
      // 只有一张图片时不滚动
      enableInfiniteScroll: imageList.length > 1,
    ),
    items: items,
  );
}

/// 构建轮播图子项
List<Widget>? _buildCarouselItems(
  List<String> imageList, {
  required bool showPlaceholder,
  required CarouselType type,
  Directory? downloadDir,
}) {
  if (!showPlaceholder && imageList.isEmpty) return null;

  final effectiveImages = imageList.isEmpty ? [placeholderImageUrl] : imageList;

  return effectiveImages.map((imageUrl) {
    return Builder(
      builder:
          (context) => _buildCarouselItem(
            context,
            imageUrl,
            imageList,
            type: type,
            downloadDir: downloadDir,
          ),
    );
  }).toList();
}

/// 构建单个轮播图项
Widget _buildCarouselItem(
  BuildContext context,
  String imageUrl,
  List<String> imageList, {
  required CarouselType type,
  Directory? downloadDir,
}) {
  return GestureDetector(
    onTap: () => _handleImageTap(context, imageUrl, imageList, type),
    onLongPress: () => _handleImageLongPress(imageUrl, downloadDir),
    child: buildNetworkOrFileImage(imageUrl),
  );
}

/// 处理图片点击事件
void _handleImageTap(
  BuildContext context,
  String imageUrl,
  List<String> imageList,
  CarouselType type,
) {
  switch (type) {
    case CarouselType.dialog:
      showDialog(
        context: context,
        builder: (_) => _buildPhotoDialog(getImageProvider(imageUrl)),
      );
      break;
    case CarouselType.page:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _buildPhotoView(getImageProvider(imageUrl)),
        ),
      );
      break;
    case CarouselType.gallery:
      showDialog(
        context: context,
        builder: (_) => _buildPhotoGalleryDialog(imageList),
      );
      break;
    case CarouselType.none:
      break;
  }
}

/// 处理图片长按事件
Future<void> _handleImageLongPress(
  String imageUrl,
  Directory? downloadDir,
) async {
  if (imageUrl.startsWith("/storage/")) {
    ToastUtils.showInfo("图片已存在于$imageUrl", duration: Duration(seconds: 3));
    return;
  }
  await saveImageToLocal(imageUrl, dlDir: downloadDir);
}

/// 构建图片弹窗对话框（相册和单个图片预览都有用到）
Widget _buildPhotoDialog(ImageProvider imageProvider) {
  return Dialog(
    backgroundColor: Colors.transparent,
    child: _buildPhotoView(imageProvider),
  );
}

/// 构建图片画廊弹窗
Widget _buildPhotoGalleryDialog(List<String> imageList) {
  // 这个弹窗默认是无法全屏的，上下左右会留点空，点击这些空隙可以关闭弹窗
  return Dialog(
    backgroundColor: Colors.transparent,
    child: PhotoViewGallery.builder(
      itemCount: imageList.length,
      builder:
          (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: getImageProvider(imageList[index]),
            errorBuilder: (_, __, ___) => const Icon(Icons.error),
          ),
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      loadingBuilder:
          (_, __) => const Center(child: CircularProgressIndicator()),
    ),
  );
}

/// 构建图片查看视图
Widget _buildPhotoView(
  ImageProvider imageProvider, {
  bool enableRotation = true,
}) {
  return PhotoView(
    imageProvider: imageProvider,
    // 设置图片背景为透明
    backgroundDecoration: const BoxDecoration(color: Colors.transparent),
    // 可以旋转
    enableRotation: enableRotation,
    // 缩放的最大最小限制
    minScale: PhotoViewComputedScale.contained * 0.8,
    maxScale: PhotoViewComputedScale.covered * 2,
    errorBuilder: (_, __, ___) => const Icon(Icons.error),
  );
}

/// 获取图片提供者(暂时这3种)
ImageProvider getImageProvider(String imageUrl) {
  if (imageUrl.startsWith('http')) {
    return CachedNetworkImageProvider(imageUrl);
  } else if (imageUrl.startsWith('assets')) {
    return AssetImage(imageUrl);
  } else {
    return FileImage(File(imageUrl));
  }
}

/// 构建网络或本地图片组件
Widget buildNetworkOrFileImage(String imageUrl, {BoxFit? fit}) {
  if (imageUrl.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      // progressIndicatorBuilder: (context, url, progress) => Center(
      //   child: CircularProgressIndicator(
      //     value: progress.progress,
      //   ),
      // ),

      /// placeholder 和 progressIndicatorBuilder 只能2选1
      placeholder:
          (_, __) => const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          ),
      errorWidget: (_, __, ___) => const Icon(Icons.error, size: 36),
    );
  } else {
    return Image(
      image: getImageProvider(imageUrl),
      fit: fit,
      errorBuilder:
          (_, __, ___) =>
              Image.asset(placeholderImageUrl, fit: BoxFit.scaleDown),
    );
  }
}

///
/// 构建图片预览组件
/// 只有base64的字符串或者文件格式
///
Widget buildImageView(
  dynamic image,
  BuildContext context, {
  bool isFileUrl = false,
  String imagePlaceholder = "请选择图片",
  String imageErrorHint = "图片异常",
}) {
  // 如果没有图片数据，直接返回文提示
  if (image == null) {
    return Center(child: Text(imagePlaceholder));
  }

  final imageProvider = _getImageProviderForPreview(image, isFileUrl);

  return GridTile(
    child: GestureDetector(
      onTap:
          () => showDialog(
            context: context,
            builder: (_) => _buildPhotoDialog(imageProvider),
          ),
      child: RepaintBoundary(
        child: Center(
          child: Image(
            image: imageProvider,
            fit: BoxFit.scaleDown,
            errorBuilder: (_, __, ___) => _buildErrorWidget(imageErrorHint),
          ),
        ),
      ),
    ),
  );
}

/// 获取预览图片的提供者,只有base64的字符串或者文件格式
ImageProvider _getImageProviderForPreview(dynamic image, bool isFileUrl) {
  if (image is String && !isFileUrl) {
    return MemoryImage(base64Decode(image));
  } else if (image is String && isFileUrl) {
    return FileImage(File(image));
  } else {
    return FileImage(image as File);
  }
}

/// 构建错误提示组件
Widget _buildErrorWidget(String errorHint) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red),
          Text(errorHint, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
  );
}
