import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 依然保留，万一用户长按复制
import 'package:url_launcher/url_launcher.dart'; // 引入跳转插件
import '../version_data.dart'; 

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // --- 新增：核心跳转逻辑 ---
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('无法打开链接');
      }
    } catch (e) {
      // 如果跳转失败（比如没有浏览器或邮件客户端），则回退到复制到剪贴板
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法打开应用，已将内容复制到剪贴板")),
        );
        Clipboard.setData(ClipboardData(text: urlString.replaceAll('mailto:', '')));
      }
    }
  }

  void _showDeveloperDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code, color: Colors.blue),
            SizedBox(width: 8),
            Text("联系开发者"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("如果您有任何建议或发现Bug，欢迎联系："),
            const SizedBox(height: 20),
            // GitHub 跳转
            _buildContactItem(
              ctx, 
              "GitHub", 
              "https://github.com/Bamlax", 
              Icons.link,
              isUrl: true
            ),
            const SizedBox(height: 10),
            // 邮箱跳转 (使用 mailto: 协议)
            _buildContactItem(
              ctx, 
              "Email", 
              "mailto:bamlax@163.com", 
              Icons.email,
              displayText: "bamlax@163.com" // 显示时不显示 mailto: 前缀
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, 
    String label, 
    String content, 
    IconData icon, 
    {bool isUrl = false, String? displayText}
  ) {
    return InkWell(
      onTap: () => _launchUrl(context, content),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(
                    displayText ?? content, 
                    style: const TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w500,
                      color: Colors.blue, // 变成蓝色表示可点击
                      decoration: TextDecoration.underline, // 加下划线
                      decorationColor: Colors.blue,
                    )
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey), // 图标改成“打开”
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader("通用"),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("关于 Renormind"),
            subtitle: const Text("版本记录与更新日志"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VersionHistoryPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("开发者"),
            subtitle: const Text("Bamlax"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showDeveloperDialog(context),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              // 这里可以改成动态获取，或者手动维护
              "Renormind ${appVersionHistory.first.version}", 
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

// --- 版本记录详情页 (保持不变) ---
class VersionHistoryPage extends StatelessWidget {
  const VersionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("版本记录"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appVersionHistory.length,
        itemBuilder: (context, index) {
          final item = appVersionHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.version,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        item.date,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...item.changes.map((change) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(change, style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}