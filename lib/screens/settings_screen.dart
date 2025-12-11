import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import '../version_data.dart'; 

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('无法打开链接');
      }
    } catch (e) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: Colors.blueAccent),
            SizedBox(width: 12),
            Text("联系开发者", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "如果您有任何建议或发现Bug，欢迎通过以下方式联系：",
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 20),
            
            // GitHub 卡片
            _buildContactCard(
              ctx, 
              title: "GitHub", 
              content: "github.com/Bamlax", 
              url: "https://github.com/Bamlax",
              icon: Icons.code, // 也可以换成 FontAwesome 图标如果引入了包
              color: Colors.black87
            ),
            
            const SizedBox(height: 12),
            
            // 邮箱 卡片
            _buildContactCard(
              ctx, 
              title: "Email", 
              content: "bamlax@163.com", 
              url: "mailto:bamlax@163.com", 
              icon: Icons.email_outlined,
              color: Colors.blue
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }

  // --- 新设计的联系人卡片组件 ---
  Widget _buildContactCard(
    BuildContext context, {
    required String title, 
    required String content, 
    required String url, 
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _launchUrl(context, url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // 左侧图标容器
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                
                // 中间文字
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500
                        )
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content, 
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // 右侧箭头
                Icon(Icons.arrow_outward_rounded, size: 18, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], //稍微给一点背景色，突出列表
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader("通用"),
          
          _buildSettingsTile(
            context,
            icon: Icons.info_outline_rounded,
            title: "关于 Renormind",
            subtitle: "版本记录与更新日志",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VersionHistoryPage()),
              );
            },
          ),
          
          const Divider(height: 1, indent: 60), // 分割线
          
          _buildSettingsTile(
            context,
            icon: Icons.person_outline_rounded,
            title: "开发者",
            subtitle: "Bamlax",
            onTap: () => _showDeveloperDialog(context),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
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
  
  // 封装通用的设置列表项，保持风格一致
  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[700], size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ]
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 版本记录详情页 (保持不变，稍微美化一下AppBar) ---
class VersionHistoryPage extends StatelessWidget {
  const VersionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("版本记录"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appVersionHistory.length,
        itemBuilder: (context, index) {
          final item = appVersionHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0, // 扁平化风格
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6)
                        ),
                        child: Text(
                          item.version,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      Text(
                        item.date,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...item.changes.map((change) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Expanded(child: Text(change, style: const TextStyle(height: 1.5, color: Colors.black87))),
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