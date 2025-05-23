import 'package:sqflite/sqflite.dart';

import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/model_spec.dart';
import '../../models/platform_spec.dart';
import 'db_ddl.dart';
import 'db_init.dart';

///
/// 数据库操作
///
class DBHelper {
  // 单例模式
  static final DBHelper _dbBriefHelper = DBHelper._createInstance();
  // 构造函数，返回单例
  factory DBHelper() => _dbBriefHelper;

  // 命名的构造函数用于创建 DBHelper 的实例
  DBHelper._createInstance();

  // 获取数据库实例(每次操作都从 DBInit 获取，不缓存)
  Future<Database> get database async => DBInit().database;

  // 初始化预设平台数据
  Future<void> initPredefinedData() async {
    // 保存预定义的平台
    // await savePlatform(PlatformSpec.openAI());

    // 可以添加一些预设的模型数据
    // 例如：await saveModel(ModelSpec(...));
  }

  ///
  ///  Helper 的相关方法
  ///

  ///***********************************************/
  /// 2025-02-14 简洁版本的 自定义的LLM信息管理
  ///
  // 保存平台
  Future<void> savePlatform(PlatformSpec platform) async {
    final db = await database;
    await db.insert(
      DBDdl.tablePlatforms,
      platform.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Object?>> savePlatformList(List<PlatformSpec> platforms) async {
    var batch = (await database).batch();
    for (var item in platforms) {
      batch.insert(
        DBDdl.tablePlatforms,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return await batch.commit();
  }

  // 获取平台
  Future<PlatformSpec?> getPlatform(String id) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tablePlatforms,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return PlatformSpec.fromMap(maps.first);
  }

  // 获取所有平台
  Future<List<PlatformSpec>> getAllPlatforms() async {
    final db = await database;
    final maps = await db.query(DBDdl.tablePlatforms);
    return maps.map((map) => PlatformSpec.fromMap(map)).toList();
  }

  // 删除平台
  Future<void> deletePlatform(String id) async {
    // final db = await database;
    // await db.delete(DBDdl.tablePlatforms, where: 'id = ?', whereArgs: [id]);

    // 删除平台时，一并删除关联的模型
    var batch = (await database).batch();
    batch.delete(DBDdl.tablePlatforms, where: 'id = ?', whereArgs: [id]);
    batch.delete(DBDdl.tableModels, where: 'platform_id = ?', whereArgs: [id]);
    await batch.commit();
  }

  // ==================== 模型操作 ====================

  // 保存模型
  Future<void> saveModel(ModelSpec model) async {
    final db = await database;
    await db.insert(
      DBDdl.tableModels,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Object?>> saveModelList(List<ModelSpec> models) async {
    var batch = (await database).batch();
    for (var item in models) {
      batch.insert(
        DBDdl.tableModels,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return await batch.commit();
  }

  // 获取模型
  Future<ModelSpec?> getModel(String id) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableModels,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return ModelSpec.fromMap(maps.first);
  }

  // 获取平台下所有模型
  Future<List<ModelSpec>> getModelsByPlatform(String platformId) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableModels,
      where: 'platform_id = ?',
      whereArgs: [platformId],
    );
    return maps.map((map) => ModelSpec.fromMap(map)).toList();
  }

  // 获取特定类型的所有模型
  Future<List<ModelSpec>> getModelsByType(ModelType type) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableModels,
      where: 'type = ?',
      whereArgs: [type.toString().split('.').last],
    );
    return maps.map((map) => ModelSpec.fromMap(map)).toList();
  }

  // 获取所有模型
  Future<List<ModelSpec>> getAllModels() async {
    final db = await database;
    final maps = await db.query(DBDdl.tableModels, orderBy: 'updated_at DESC');
    return maps.map((map) => ModelSpec.fromMap(map)).toList();
  }

  // 删除模型
  Future<void> deleteModel(String id) async {
    final db = await database;
    await db.delete(DBDdl.tableModels, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 对话操作 ====================

  // 保存对话
  Future<void> saveConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      DBDdl.tableConversations,
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Object?>> saveConversationList(List<Conversation> cons) async {
    var batch = (await database).batch();
    for (var item in cons) {
      batch.insert(
        DBDdl.tableConversations,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return await batch.commit();
  }

  // 获取对话
  Future<Conversation?> getConversation(String id) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableConversations,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  // 获取所有对话
  Future<List<Conversation>> getAllConversations({
    ConversationState? state,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (state != null) {
      maps = await db.query(
        DBDdl.tableConversations,
        where: 'state = ?',
        whereArgs: [state.toString().split('.').last],
        orderBy: 'updated_at DESC',
      );
    } else {
      maps = await db.query(
        DBDdl.tableConversations,
        orderBy: 'updated_at DESC',
      );
    }

    return maps.map((map) => Conversation.fromMap(map)).toList();
  }

  // 获取模型的所有对话
  Future<List<Conversation>> getConversationsByModel(String modelId) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableConversations,
      where: 'model_id = ?',
      whereArgs: [modelId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Conversation.fromMap(map)).toList();
  }

  // 获取平台的所有对话
  Future<List<Conversation>> getConversationsByPlatform(
    String platformId,
  ) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableConversations,
      where: 'platform_id = ?',
      whereArgs: [platformId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Conversation.fromMap(map)).toList();
  }

  // 更新对话
  Future<void> updateConversation(Conversation conversation) async {
    final db = await database;
    await db.update(
      DBDdl.tableConversations,
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  // 删除对话
  Future<void> deleteConversation(String id) async {
    final db = await database;
    // 首先删除对话相关的所有消息
    await db.delete(
      DBDdl.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [id],
    );
    // 然后删除对话本身
    await db.delete(DBDdl.tableConversations, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 消息操作 ====================

  // 保存消息
  Future<void> saveMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      DBDdl.tableMessages,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 更新对话的消息计数
    final conversation = await getConversation(message.conversationId);
    if (conversation != null) {
      conversation.incrementMessageCount();

      // 更新最后消息预览
      if (message.hasContentType(ContentType.text)) {
        final text = message.getAllText();
        final preview =
            text.length > 100 ? '${text.substring(0, 97)}...' : text;
        conversation.updateLastMessagePreview(preview);
      }

      await updateConversation(conversation);
    }
  }

  // 保存消息列表(不知道这样行不行)
  Future<void> saveMessageList(List<ChatMessage> messages) async {
    for (var item in messages) {
      saveMessage(item);
    }
  }

  // 获取消息
  Future<ChatMessage?> getMessage(String id) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableMessages,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return ChatMessage.fromMap(maps.first);
  }

  // 获取对话的所有消息
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId,
  ) async {
    final db = await database;
    final maps = await db.query(
      DBDdl.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  // 删除消息
  Future<void> deleteMessage(String id) async {
    final db = await database;

    // 获取要删除的消息
    final message = await getMessage(id);
    if (message == null) return;

    // 删除消息
    await db.delete(DBDdl.tableMessages, where: 'id = ?', whereArgs: [id]);

    // 更新对话消息计数
    final conversation = await getConversation(message.conversationId);
    if (conversation != null && conversation.messageCount > 0) {
      conversation.messageCount--;
      await updateConversation(conversation);
    }
  }

  // 删除对话的所有消息
  Future<void> deleteMessagesForConversation(String conversationId) async {
    final db = await database;
    await db.delete(
      DBDdl.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    // 更新对话消息计数
    final conversation = await getConversation(conversationId);
    if (conversation != null) {
      conversation.messageCount = 0;
      conversation.lastMessagePreview = null;
      await updateConversation(conversation);
    }
  }
}
