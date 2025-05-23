import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'backup_and_restore/index.dart';
import 'platform_model_management/index.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    WidgetsFlutterBinding.ensureInitialized();

    final info = await PackageInfo.fromPlatform();

    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('平台与模型管理'),
            _buildPlatformModelManagementButton(),

            const Divider(),

            _buildSectionHeader('数据备份与恢复'),
            _buildDataManagementButton(),

            const Divider(),

            _buildSectionHeader('关于'),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 构建平台与模型管理按钮
  Widget _buildPlatformModelManagementButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PlatformModelManagementScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.settings_applications),
        label: const Text('平台与模型管理'),
      ),
    );
  }

  Widget _buildDataManagementButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BackupAndRestoreScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.import_export),
        label: const Text('数据备份与恢复'),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      children: [
        ListTile(
          title: Text(_packageInfo.appName),
          subtitle: Text(
            '版本: ${_packageInfo.version} (${_packageInfo.buildNumber})',
          ),
          leading: const Icon(Icons.info),
        ),
        ListTile(
          title: const Text('隐私政策'),
          leading: const Icon(Icons.privacy_tip),
          onTap: () {
            // TODO: 导航到隐私政策页面
          },
        ),
        ListTile(
          title: const Text('条款和条件'),
          leading: const Icon(Icons.description),
          onTap: () {
            // TODO: 导航到条款和条件页面
          },
        ),
        const SizedBox(height: 24),
        Text(
          '© ${DateTime.now().year} SuChat Tiny',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
