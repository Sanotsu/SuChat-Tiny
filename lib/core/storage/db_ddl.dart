import 'db_init.dart';

class DBDdl {
  /// 平台表
  static const tablePlatforms = '${DBInitConfig.tablePerfix}platforms';
  // 2025-05-21 添加平台表的唯一约束，避免重复添加相同平台
  // ON CONFLICT ROLLBACK - 回滚当前事务
  // ON CONFLICT ABORT - 中止当前 SQL 语句
  // ON CONFLICT FAIL - 失败但不回滚
  // ON CONFLICT IGNORE - 忽略冲突行
  // ON CONFLICT REPLACE - 替换现有行
  static const String ddlForPlatforms = """
     CREATE TABLE $tablePlatforms (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      base_url TEXT NOT NULL,
      api_version TEXT,
      description TEXT,
      api_key_header TEXT,
      org_id_header TEXT,
      is_openai_compatible INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      extra_headers TEXT,
      extra_attributes TEXT,
      UNIQUE (name, type, base_url) ON CONFLICT REPLACE
    )
    """;

  /// 模型表
  static const tableModels = '${DBInitConfig.tablePerfix}models';
  static const String ddlForModels = """
      CREATE TABLE $tableModels (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      type TEXT NOT NULL,
      platform_id TEXT NOT NULL,
      version TEXT,
      context_window INTEGER,
      input_price_per_k REAL,
      output_price_per_k REAL,
      supports_streaming INTEGER NOT NULL,
      supports_function_calling INTEGER NOT NULL,
      supports_vision INTEGER NOT NULL,
      max_output_tokens INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      extra_attributes TEXT,
      FOREIGN KEY (platform_id) REFERENCES $tablePlatforms (id)
    )
    """;

  /// 对话表
  static const tableConversations = '${DBInitConfig.tablePerfix}conversations';
  static const String ddlForConversations = """
    CREATE TABLE $tableConversations (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      state TEXT NOT NULL,
      model_id TEXT NOT NULL,
      platform_id TEXT NOT NULL,
      system_prompt TEXT,
      message_count INTEGER NOT NULL,
      last_message_preview TEXT,
      metadata TEXT,
      tags TEXT,
      FOREIGN KEY (model_id) REFERENCES $tableModels (id),
      FOREIGN KEY (platform_id) REFERENCES $tablePlatforms (id)
    )
    """;

  /// 消息表
  static const tableMessages = '${DBInitConfig.tablePerfix}messages';
  static const String ddlForMessages = """
    CREATE TABLE $tableMessages (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      conversation_id TEXT NOT NULL,
      function_call TEXT,
      tool_calls TEXT,
      name TEXT,
      is_final INTEGER NOT NULL,
      extra_attributes TEXT,
      metadata TEXT,
      FOREIGN KEY (conversation_id) REFERENCES $tableConversations (id)
    )
    """;
}
