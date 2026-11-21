/// 书源管理页
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http_dart;

import '../../data/app_database.dart';
import '../../data/entities/rules.dart';

class SourcePage extends StatefulWidget {
  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  List<BookSource> _sources = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sources = await AppDatabase.getSources(enabled: null);
    setState(() => _sources = sources);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? _sources
        : _sources
            .where((s) =>
                s.bookSourceName.contains(_filter) ||
                (s.bookSourceGroup ?? '').contains(_filter) ||
                s.bookSourceUrl.contains(_filter))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('书源管理 (${_sources.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.add_link), tooltip: '网络导入',
              onPressed: () => _importFromUrl()),
          IconButton(icon: const Icon(Icons.content_paste), tooltip: '剪贴板导入',
              onPressed: _importFromClipboard),
          IconButton(icon: const Icon(Icons.file_open), tooltip: '文件导入',
              onPressed: _importFromFile),
          IconButton(icon: const Icon(Icons.delete_sweep), tooltip: '清空全部',
              onPressed: () async {
            final ok = await showDialog<bool>(context: context,
                builder: (_) => AlertDialog(
                  title: const Text('清空书源'),
                  content: const Text('确定删除所有书源吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
                  ],
                ));
            if (ok == true) {
              await AppDatabase.deleteSources(_sources.map((s) => s.bookSourceUrl).toList());
              _load();
            }
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list),
                hintText: '按名称/分组/URL 过滤',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('暂无书源，请先导入（支持 Legado 书源 JSON）'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          s.enabled ? Icons.check_circle : Icons.cancel,
                          color: s.enabled ? Colors.green : Colors.grey,
                        ),
                        title: Text('${s.bookSourceName}  (${s.bookSourceType == 0 ? "文本" : "type${s.bookSourceType}"})'),
                        subtitle: Text(
                          '${s.bookSourceGroup ?? "未分组"}\n${s.bookSourceUrl}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: s.enabled,
                              onChanged: (v) async {
                                s.enabled = v;
                                await AppDatabase.saveSource(s);
                                _load();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                await AppDatabase.deleteSources([s.bookSourceUrl]);
                                _load();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromUrl() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('网络导入书源'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入书源 JSON 链接'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('导入')),
        ],
      ),
    );
    if (ok != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;
    try {
      final res = await http_dart.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      await _importText(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (e) {
      _snack('导入失败: $e');
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      _snack('剪贴板为空');
      return;
    }
    await _importText(text);
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json', 'txt']);
    if (result == null || result.files.isEmpty) return;
    try {
      final text = await File(result.files.single.path!).readAsString();
      await _importText(text);
    } catch (e) {
      _snack('读取文件失败: $e');
    }
  }

  Future<void> _importText(String text) async {
    final sources = _parseSources(text);
    if (sources.isEmpty) {
      _snack('未解析到书源（JSON 格式不正确）');
      return;
    }
    await AppDatabase.saveSources(sources);
    _snack('成功导入 ${sources.length} 个书源');
    _load();
  }

  List<BookSource> _parseSources(String text) {
    final result = <BookSource>[];
    // 剥离可能的注释行
    final cleaned = text
        .split('\n')
        .where((l) => !l.trim().startsWith('//'))
        .join('\n');
    try {
      final json = jsonDecode(cleaned);
      final list = json is List
          ? json
          : json is Map && json['bookSources'] is List
              ? json['bookSources']
              : [json];
      for (final item in list) {
        if (item is Map) {
          try {
            final src = BookSource.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)));
            if (src.bookSourceUrl.isNotEmpty) result.add(src);
          } catch (_) {}
        }
      }
    } catch (_) {}
    return result;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
