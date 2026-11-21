/// 多源搜索页
library;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/entities/book.dart';
import '../../data/entities/rules.dart';
import '../../services/book_service.dart';

class SearchPage extends StatefulWidget {
  final VoidCallback onChanged;
  const SearchPage({super.key, required this.onChanged});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final Map<int, _SourceSearchState> _states = {};
  List<BookSource> _sources = [];
  bool _searching = false;
  int _finished = 0;
  final List<_ResultGroup> _results = [];
  static const _concurrency = 8;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await AppDatabase.getSources(enabled: true);
    setState(() => _sources = sources);
  }

  Future<void> _search() async {
    final key = _controller.text.trim();
    if (key.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _results.clear();
      _states.clear();
      _finished = 0;
    });
    final sources = _sources;
    for (var i = 0; i < sources.length; i++) {
      _states[i] = _SourceSearchState();
    }
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < sources.length) {
        final idx = cursor++;
        final source = sources[idx];
        _states[idx]?.status = _SearchStatus.loading;
        if (mounted) setState(() {});
        try {
          final books = await BookService.instance.searchInSource(source, key);
          _states[idx]?.status = _SearchStatus.done;
          _states[idx]?.resultCount = books.length;
          if (books.isNotEmpty) {
            _results.add(_ResultGroup(source, books));
            if (mounted) setState(() {});
          }
        } catch (e) {
          _states[idx]?.status = _SearchStatus.error;
          _states[idx]?.error = e.toString();
        }
        _finished++;
        if (mounted) setState(() {});
      }
    }

    await Future.wait(
        List.generate(_concurrency.clamp(1, sources.length), (_) => worker()));
    _searching = false;
    if (mounted) setState(() {});
  }

  Future<void> _addToShelf(_ResultGroup group, Book book) async {
    try {
      _snack('正在解析《${book.name}》详情与目录...');
      await BookService.instance.addToShelf(book, group.source);
      widget.onChanged();
      _snack('已加入书架');
    } catch (e) {
      _snack('加入书架失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: '搜索书名或作者（${_sources.length} 个启用书源）',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text('$_finished/${_sources.length}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          IconButton(
            icon: _searching
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: _searching
                  ? const Text('正在搜索...')
                  : const Text('输入关键字开始搜索'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final group = _results[i];
                return _SourceResultCard(
                  group: group,
                  onAdd: (b) => _addToShelf(group, b),
                );
              },
            ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

enum _SearchStatus { idle, loading, done, error }

class _SourceSearchState {
  _SearchStatus status = _SearchStatus.idle;
  int resultCount = 0;
  String? error;
}

class _ResultGroup {
  final BookSource source;
  final List<Book> books;
  _ResultGroup(this.source, this.books);
}

class _SourceResultCard extends StatelessWidget {
  final _ResultGroup group;
  final void Function(Book) onAdd;

  const _SourceResultCard({required this.group, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              '${group.source.bookSourceName} · ${group.books.length} 条结果',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          ...group.books.map((b) => ListTile(
                dense: true,
                leading: Container(
                  width: 42,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (b.displayCover.startsWith('http'))
                      ? Image.network(b.displayCover, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.book, size: 20))
                      : const Icon(Icons.book, size: 20),
                ),
                title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${b.author}  ${b.kind ?? ""}\n${b.intro ?? ""}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '加入书架',
                  onPressed: () => onAdd(b),
                ),
              )),
        ],
      ),
    );
  }
}
