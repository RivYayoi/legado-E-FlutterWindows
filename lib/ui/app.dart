/// 应用外壳 + 书架页
library;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/entities/book.dart';
import 'pages/reader_page.dart';
import 'pages/search_page.dart';
import 'pages/source_page.dart';

class LegadoApp extends StatelessWidget {
  const LegadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '阅读 - Windows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF219653)),
        useMaterial3: true,
        fontFamilyFallback: const ['Microsoft YaHei UI', 'SimSun'],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF219653), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await AppDatabase.getBooks();
    setState(() => _books = books);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BookshelfPage(books: _books, onChanged: _loadBooks, onOpen: _openBook),
      SearchPage(onChanged: _loadBooks),
      SourcePage(),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: false,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.book), label: Text('书架')),
              NavigationRailDestination(
                  icon: Icon(Icons.search), label: Text('搜索')),
              NavigationRailDestination(
                  icon: Icon(Icons.source), label: Text('书源')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }

  Future<void> _openBook(Book book) async {
    if (book.isLocal) return;
    final source = await AppDatabase.getSource(book.origin);
    if (source == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未找到书源: ${book.originName}')));
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderPage(book: book, source: source),
    ));
    _loadBooks();
  }
}

class BookshelfPage extends StatelessWidget {
  final List<Book> books;
  final VoidCallback onChanged;
  final Future<void> Function(Book) onOpen;

  const BookshelfPage(
      {super.key, required this.books, required this.onChanged, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('书架空空如也'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search),
              label: const Text('去搜索添加书籍'),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) => _BookCard(
        book: books[i],
        onOpen: () => onOpen(books[i]),
        onDelete: () => _confirmDelete(context, books[i]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('移出书架'),
        content: Text('确定移除《${book.name}》吗？（正文缓存将同时删除）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.deleteBook(book.bookUrl);
      onChanged();
    }
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _BookCard(
      {required this.book, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      onSecondaryTap: onDelete,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              width: double.infinity,
              child: book.displayCover.startsWith('http')
                  ? Image.network(book.displayCover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverFallback())
                  : _coverFallback(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            book.durChapterTitle ?? book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback() => Center(
        child: Text(book.name,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );
}
