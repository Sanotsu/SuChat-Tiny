import 'dart:async';
import 'dart:io';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/storage/db_helper.dart';
import 'core/utils/tools.dart';
import 'providers/conversation_provider.dart';
import 'providers/model_provider.dart';
import 'providers/platform_provider.dart';
import 'screens/chat/chat_screen.dart';
import 'widgets/common/toast_utils.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  AppCatchError().run();
}

//全局异常的捕捉
class AppCatchError {
  run() {
    ///Flutter 框架异常
    FlutterError.onError = (FlutterErrorDetails details) async {
      ///线上环境 todo
      if (kReleaseMode) {
        Zone.current.handleUncaughtError(details.exception, details.stack!);
      } else {
        //开发期间 print
        FlutterError.dumpErrorToConsole(details);
      }
    };

    runZonedGuarded(() {
      //受保护的代码块
      WidgetsFlutterBinding.ensureInitialized();

      // 仅在移动端限制垂直方向
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }

      // 继续初始化
      initApp();
    }, (error, stack) => catchError(error, stack));
  }

  void initApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化数据库
    final dbHelper = DBHelper();
    await dbHelper.initPredefinedData();

    runApp(const SuChatApp());
  }

  ///对搜集的 异常进行处理  上报等等
  catchError(Object error, StackTrace stack) async {
    //是否是 Release版本
    debugPrint("AppCatchError>>>>>>>>>> [ kReleaseMode ] $kReleaseMode");
    debugPrint('AppCatchError>>>>>>>>>> [ Message ] $error');
    logger.e(error);
    debugPrint('AppCatchError>>>>>>>>>> [ Stack ] \n$stack');

    // 弹窗提醒用户
    ToastUtils.showError(
      error.toString(),
      duration: const Duration(seconds: 5),
    );

    // 一些错误处理，比如token失效这里退出到登录页面之类的
    if (error.toString().toLowerCase().contains("invalid")) {
      debugPrint(error.toString());
    }
  }
}

/// 生命周期事件处理器
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? detached;

  LifecycleEventHandler({this.detached});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        if (detached != null) {
          await detached!();
        }
        break;
      default:
        break;
    }
  }
}

class SuChatApp extends StatelessWidget {
  const SuChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlatformProvider()),
        ChangeNotifierProvider(create: (_) => ModelProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: AppConfig.appName,

        debugShowCheckedModeBanner: false,
        // 应用导航的观察者，导航有变化的时候可以做一些事？
        // navigatorObservers: [routeObserver],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        // 初始化的locale
        locale: const Locale('zh', 'CN'),

        /// 默认的主题
        theme: AppConfig.getLightTheme(),
        darkTheme: AppConfig.getDarkTheme(),
        themeMode: ThemeMode.system,

        home: const MainScreen(),

        builder: (context, child) {
          // //1. call BotToastInit
          child = BotToastInit()(context, child);
          return child;
        },

        // 2. registered route observer
        navigatorObservers: [BotToastNavigatorObserver()],
      ),
    );
  }
}

/// 主页面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 记录上次点击返回键的时间
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();

    // 加载平台和模型数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final platformProvider = Provider.of<PlatformProvider>(
      context,
      listen: false,
    );
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    await platformProvider.loadPlatforms();
    await modelProvider.loadModels();
    await conversationProvider.loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 点击返回键时暂停返回
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        // 获取当前时间
        final now = DateTime.now();

        // 判断是否在3秒内连续按了两次返回键
        if (_lastPressedAt != null &&
            now.difference(_lastPressedAt!).inSeconds < 2) {
          // 第二次按返回键，退出应用
          SystemNavigator.pop();
          return;
        } else {
          // 第一次按返回键，更新时间并显示提示
          _lastPressedAt = now;
          ToastUtils.showInfo('再按一次退出应用', align: Alignment.center);
        }
      },
      child: Scaffold(body: const ChatScreen()),
    );
  }
}
