import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/tools.dart';
import 'db_ddl.dart';

/// 数据库中一下基本内容
class DBInitConfig {
  // 数据库名称和版本
  static String databaseName = "embedded_suchat_tiny.db";
  static const int databaseVersion = 1;
  // 表前缀
  static const String tablePerfix = "suchat_tiny_";
}

/// 数据库初始化与基本操作类
class DBInit {
  ///
  /// 数据库初始化相关
  ///

  // 单例模式
  static final DBInit _dbInit = DBInit._createInstance();
  // 构造函数，返回单例
  factory DBInit() => _dbInit;
  // 数据库实例
  static Database? _database;

  // 创建sqlite的db文件成功后，记录该地址，以便删除时使用。
  var dbFilePath = "";

  // 命名的构造函数用于创建 DBHelper 的实例
  DBInit._createInstance();

  // 获取数据库实例
  Future<Database> get database async => _database ??= await initializeDB();

  // 初始化数据库
  Future<Database> initializeDB() async {
    // 如果是桌面端（Windows/Linux/macOS），初始化 FFI
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 在任何平台操作之前首先初始化FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi; // 设置全局 databaseFactory

      // 针对Linux平台的特殊处理
      if (Platform.isLinux) {
        try {
          // 尝试使用自定义库路径
          var options = OpenDatabaseOptions(readOnly: true);
          // 可以尝试不同路径的SQLite库文件
          final List<String> possiblePaths = [
            'libsqlite3.so',
            '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
            '/usr/lib/libsqlite3.so',
          ];

          // 尝试所有可能的库路径
          for (var path in possiblePaths) {
            try {
              logger.i("尝试加载SQLite库: $path");
              await databaseFactoryFfi.openDatabase(
                ":memory:",
                options: options,
              );
              break; // 如果成功，跳出循环
            } catch (e) {
              logger.e("无法加载 $path: $e");
              // 继续尝试下一个路径
            }
          }
        } catch (e) {
          logger.e("初始化SQLite FFI时出错: $e");
        }
      }
    }

    // 自定义的sqlite数据库文件保存的目录
    Directory directory = await getSqliteDbDir();
    String path = "${directory.path}/${DBInitConfig.databaseName}";

    logger.i("初始化 DB sqlite数据库存放的地址：$path");

    // 在给定路径上打开/创建数据库
    var db = await openDatabase(
      path,
      version: DBInitConfig.databaseVersion,
      onCreate: _createDb,
    );

    dbFilePath = path;
    return db;
  }

  // 创建数据库相关表
  void _createDb(Database db, int newVersion) async {
    logger.i("开始创建表 _createDb...");

    await db.transaction((txn) async {
      txn.execute(DBDdl.ddlForConversations);
      txn.execute(DBDdl.ddlForMessages);
      txn.execute(DBDdl.ddlForModels);
      txn.execute(DBDdl.ddlForPlatforms);
    });
  }

  // 关闭数据库
  Future<bool> closeDB() async {
    Database db = await database;

    logger.i("db.isOpen ${db.isOpen}");
    await db.close();
    logger.i("db.isOpen ${db.isOpen}");

    // 删除db或者关闭db都需要重置db为null，
    // 否则后续会保留之前的连接，以致出现类似错误：Unhandled Exception: DatabaseException(database_closed 5)
    _database = null;

    // 如果已经关闭了，返回ture
    return !db.isOpen;
  }

  // 删除sqlite的db文件（初始化数据库操作中那个path的值）
  Future<void> deleteDB() async {
    logger.i("开始删除內嵌的 sqlite db文件，db文件地址：$dbFilePath");

    // 先关闭数据库连接
    if (_database != null) {
      await closeDB();
    }

    // 检查文件是否存在
    if (await File(dbFilePath).exists()) {
      try {
        // 删除数据库文件
        await deleteDatabase(dbFilePath);
        logger.i("数据库文件删除成功");
      } catch (e) {
        logger.e("删除数据库文件出错: $e");
        throw Exception("无法删除数据库文件: $e");
      }
    } else {
      logger.i("数据库文件不存在，无需删除");
    }

    // 重置数据库实例
    _database = null;
  }

  // 显示db中已有的table，默认的和自建立的
  Future<List<String>> showTableNameList() async {
    Database db = await database;
    var tableNames = (await db.query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    )).map((row) => row['name'] as String).toList(growable: false);

    logger.i("DB中拥有的表名:------------");
    logger.i(tableNames.toString());
    return tableNames;
  }

  /// 导出所有数据库表到JSON文件
  ///
  /// 返回：导出的文件数量和文件列表
  Future<Map<String, dynamic>> exportDatabase() async {
    try {
      // 创建或检索 db_export 文件夹
      // var tempDir = await getDbExportTempDir();

      // 创建或检索 db_export 文件夹
      // 上面那个文件夹用户可以看到，还是放在临时文件夹，卸载后可清除
      var tempDir = await Directory(
        p.join((await getApplicationCacheDirectory()).path, 'db_export'),
      ).create(recursive: true);

      // 清空目标文件夹
      await _clearDirectory(tempDir.path);

      // 打开数据库
      Database db = await database;

      // 获取所有表名
      List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      // 导出文件列表和计数
      List<String> exportedFiles = [];
      int exportedCount = 0;

      // 遍历所有表
      for (Map<String, dynamic> table in tables) {
        String tableName = table['name'];

        // 不是自建的表，不导出
        if (!tableName.startsWith(DBInitConfig.tablePerfix)) {
          continue;
        }

        String tempFilePath = p.join(tempDir.path, '$tableName.json');

        try {
          // 查询表中所有数据
          List<Map<String, dynamic>> result = await db.query(tableName);

          // 将结果转换为JSON字符串
          String jsonStr = jsonEncode(result);

          // 创建临时导出文件
          File tempFile = File(tempFilePath);

          // 将JSON字符串写入临时文件
          await tempFile.writeAsString(jsonStr);

          exportedFiles.add(tempFilePath);
          exportedCount++;

          logger.i('表 $tableName 已成功导出');
        } catch (e) {
          logger.i('导出表 $tableName 失败: $e');
          // 不中断整个导出过程，继续下一个表
        }
      }

      if (exportedCount == 0) {
        throw Exception('未导出任何数据，请检查数据库是否包含数据');
      }

      logger.i('成功导出 $exportedCount 个表的数据');
      return {
        'count': exportedCount,
        'files': exportedFiles,
        'path': tempDir.path,
      };
    } catch (e) {
      logger.e('导出数据库时出错: $e');
      throw Exception('导出数据失败: $e');
    }
  }

  /// 清空指定文件夹中的所有文件
  Future<void> _clearDirectory(String dirPath) async {
    final directory = Directory(dirPath);
    if (await directory.exists()) {
      await for (var entity in directory.list()) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (e) {
          logger.e('清空目录文件时出错: $e');
          // 继续处理下一个文件
        }
      }
    }
  }
}
