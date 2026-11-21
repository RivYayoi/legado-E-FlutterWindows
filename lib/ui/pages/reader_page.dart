/// 阅读器页面
library;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/entities/book.dart';
import '../../data/entities/rules.dart';
import '../../services/book_service.dart';

class ReaderPage extends StatefulWidget {
  final Book book;
  final BookSource source;

  const ReaderPage({super.key, required this.book, required this.source});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  List<BookChapter> _chapters = [];
  String _content = '';
  bool _loading = true;
  String? _error;
  double _fontSize = 18;
  bool _tocOpen = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChapters().then((_) => _loadContent());
  }

  Future<void> _loadChapters() async {
    _chapters = await AppDatabase.getChapters(widget.book.bookUrl);
    if (_chapters.isEmpty) {
      // 尝试重新加载目录
      try {
        _chapters = await BookService.instance
            .loadChapters(widget.book, widget.source);
        await AppDatabase.saveChapters(widget.book.bookUrl, _chapters);
      } catch (e) {
        _error = e.toString();
      }
    }
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final idx = widget.book.durChapterIndex;
      final content = await BookService.instance
          .loadContent(widget.book, widget.source, idx);
      _content = content;
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    if (mounted) setState(() {});
    // 保存进度
    await AppDatabase.updateReadProgress(
      widget.book.bookUrl,
      widget.book.durChapterIndex,
      widget.book.durChapterPos,
      widget.book.durChapterTitle ?? _chapterTitle(widget.book.durChapterIndex),
    );
  }

  String _chapterTitle(int index) =>
      index < _chapters.length ? _chapters[index].title : '';

  Future<void> _goto(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    widget.book.durChapterIndex = index;
    widget.book.durChapterPos = 0;
    await _loadContent();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_chapterTitle(widget.book.durChapterIndex)}  (${widget.book.durChapterIndex + 1}/${_chapters.length})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.list), tooltip: '目录',
              onPressed: () => setState(() => _tocOpen = !_tocOpen)),
          PopupMenuButton<double>(
            icon: const Icon(Icons.format_size),
            tooltip: '字号',
            onSelected: (v) => setState(() => _fontSize = v),
            itemBuilder: (_) => [14.0, 16.0, 18.0, 20.0, 22.0, 26.0]
                .map((v) => PopupMenuItem(value: v, child: Text('字号 $v')))
                .toList(),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: scheme.surface,
              child: _buildContent(context),
            ),
          ),
          if (_tocOpen)
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  AppBar(title: Text('目录 (${_chapters.length})'),
                      automaticallyImplyLeading: false,
                      titleTextStyle: const TextStyle(fontSize: 14)),
                  Expanded(
                    child: _chapters.isEmpty
                        ? const Center(child: Text('无章节'))
                        : ListView.builder(
                            itemCount: _chapters.length,
                            itemBuilder: (context, i) => ListTile(
                              dense: true,
                              selected: i == widget.book.durChapterIndex,
                              title: Text(
                                _chapters[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: i == widget.book.durChapterIndex
                                      ? scheme.primary
                                      : null,
                                ),
                              ),
                              onTap: () => _goto(i),
                            ),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 48,
        child: Row(
          children: [
            TextButton(
              onPressed: widget.book.durChapterIndex > 0
                  ? () => _goto(widget.book.durChapterIndex - 1)
                  : null,
              child: const Text('上一章'),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.book.durChapterIndex < _chapters.length - 1
                  ? () => _goto(widget.book.durChapterIndex + 1)
                  : null,
              child: const Text('下一章'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, maxLines: 8, overflow: TextOverflow.ellipsis),
            ),
            FilledButton(onPressed: _loadContent, child: const Text('重试')),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: SelectableText(
        _content,
        style: TextStyle(
          fontSize: _fontSize,
          height: 1.8,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
