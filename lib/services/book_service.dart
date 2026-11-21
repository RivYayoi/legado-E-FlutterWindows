/// 核心业务：书源搜索 / 详情 / 目录 / 正文
library;

import 'dart:async';
import 'dart:convert';

import '../data/app_database.dart';
import '../data/entities/book.dart';
import '../data/entities/rules.dart';
import '../engine/analyze_rule.dart';
import '../engine/analyze_url.dart';
import '../engine/js_engine.dart';
import 'http.dart';

class SearchResultItem {
  final Book book;
  final BookSource source;
  SearchResultItem(this.book, this.source);
}

class BookService {
  static final BookService instance = BookService._();
  BookService._();

  // ---------- 搜索 ----------

  /// 单书源搜索，返回结果或抛异常
  Future<List<Book>> searchInSource(BookSource source, String key) async {
    final searchRule = source.searchRule;
    if (source.searchUrl == null || source.searchUrl!.isEmpty) {
      throw RuleException('书源未配置搜索地址');
    }
    final analyzeUrl = AnalyzeUrl(source.searchUrl!,
        params: {'key': key, 'page': 1}, sourceHeader: source.header);
    final req = await analyzeUrl.build();
    final body = await HttpService.instance.requestText(req);
    final analyzer = AnalyzeRule(body, baseUrl: req.url, source: source);
    final elements = await analyzer.getElements(searchRule.bookList ?? '');
    final books = <Book>[];
    for (final el in elements) {
      final item = AnalyzeRule(el, baseUrl: req.url, source: source);
      final name = (await item.getString(searchRule.name ?? '')).trim();
      final bookUrl = (await item.getString(searchRule.bookUrl ?? '')).trim();
      if (name.isEmpty || bookUrl.isEmpty) continue;
      final author = (await item.getString(searchRule.author ?? '')).trim();
      final book = Book(
        bookUrl: _absUrl(req.url, bookUrl),
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
        name: name,
        author: author,
        kind: (await item.getString(searchRule.kind ?? '')).trim(),
        coverUrl: (await item.getString(searchRule.coverUrl ?? '')).trim(),
        intro: (await item.getString(searchRule.intro ?? '')).trim(),
        latestChapterTitle:
            (await item.getString(searchRule.lastChapter ?? '')).trim(),
        wordCount: (await item.getString(searchRule.wordCount ?? '')).trim(),
      );
      if (_matchBook(book, key)) books.add(book);
    }
    return books;
  }

  bool _matchBook(Book book, String key) {
    final k = key.toLowerCase().trim();
    if (k.isEmpty) return true;
    return book.name.toLowerCase().contains(k) ||
        book.author.toLowerCase().contains(k);
  }

  // ---------- 详情 ----------

  Future<Book> loadBookInfo(Book book, BookSource source) async {
    final rule = source.bookInfoRule;
    final analyzeUrl = AnalyzeUrl(book.bookUrl, sourceHeader: source.header);
    final req = await analyzeUrl.build();
    final body = await HttpService.instance.requestText(req);
    final analyzer = AnalyzeRule(body, baseUrl: req.url, source: source);

    Future<String> f(String? r) async =>
        r == null || r.trim().isEmpty ? '' : (await analyzer.getString(r)).trim();

    final name = await f(rule.name);
    if (name.isNotEmpty) book.name = name;
    final author = await f(rule.author);
    if (author.isNotEmpty) book.author = author;
    book.intro = await f(rule.intro);
    book.kind = await f(rule.kind);
    final cover = await f(rule.coverUrl);
    if (cover.isNotEmpty) book.coverUrl = cover;
    final lastChapter = await f(rule.lastChapter);
    if (lastChapter.isNotEmpty) book.latestChapterTitle = lastChapter;
    final tocUrl = await f(rule.tocUrl);
    book.tocUrl = tocUrl.isEmpty || tocUrl == '/' ? book.bookUrl : _absUrl(req.url, tocUrl);
    book.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
    return book;
  }

  // ---------- 目录 ----------

  Future<List<BookChapter>> loadChapters(Book book, BookSource source) async {
    final rule = source.tocRule;
    final tocUrl = book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl;
    final chapters = <BookChapter>[];
    var nextUrl = tocUrl;
    var guard = 0;
    while (nextUrl.isNotEmpty && guard < 50) {
      final analyzeUrl = AnalyzeUrl(nextUrl, sourceHeader: source.header);
      final req = await analyzeUrl.build();
      final body = await HttpService.instance.requestText(req);
      final analyzer = AnalyzeRule(body, baseUrl: req.url, source: source);
      final elements = await analyzer.getElements(rule.chapterList ?? '');
      for (final el in elements) {
        final item = AnalyzeRule(el, baseUrl: req.url, source: source);
        final title = (await item.getString(rule.chapterName ?? '')).trim();
        final url = (await item.getString(rule.chapterUrl ?? '')).trim();
        if (title.isEmpty || url.isEmpty) continue;
        final isVolume = rule.isVolume != null && rule.isVolume!.isNotEmpty
            ? (await item.getString(rule.isVolume!)).trim().isNotEmpty
            : title.startsWith('卷') || RegExp(r'^[ vol]+[一二三四五六七八九十\d]+[:：]?').hasMatch(title) && url.isEmpty;
        chapters.add(BookChapter(
          url: url.startsWith('http') ? url : _absUrl(req.url, url),
          title: title,
          isVolume: isVolume && url.isEmpty,
          baseUrl: req.url,
          bookUrl: book.bookUrl,
          index: chapters.length,
        ));
      }
      // 下一页目录
      if (rule.nextTocUrl != null && rule.nextTocUrl!.isNotEmpty) {
        final next = (await analyzer.getString(rule.nextTocUrl!)).trim();
        if (next.isEmpty || _absUrl(req.url, next) == nextUrl) break;
        nextUrl = _absUrl(req.url, next);
      } else {
        break;
      }
      guard++;
    }
    if (chapters.isEmpty) {
      throw RuleException('未解析到章节，请检查书源目录规则');
    }
    book.totalChapterNum = chapters.length;
    return chapters;
  }

  // ---------- 正文 ----------

  Future<String> loadContent(Book book, BookSource source, int index) async {
    final cached = await AppDatabase.getContent(book.bookUrl, index);
    if (cached != null) return cached;
    final chapters = await AppDatabase.getChapters(book.bookUrl);
    if (index >= chapters.length) return '';
    final chapter = chapters[index];
    final rule = source.contentRule;
    final contentParts = <String>[];
    var nextUrl = chapter.url;
    var guard = 0;
    while (nextUrl.isNotEmpty && guard < 30) {
      final analyzeUrl = AnalyzeUrl(nextUrl, sourceHeader: source.header);
      final req = await analyzeUrl.build();
      final body = await HttpService.instance.requestText(req);
      final analyzer = AnalyzeRule(body, baseUrl: req.url, source: source,
          ctx: RuleContext()
            ..book = book
            ..chapter = chapter);
      var content = await analyzer.getString(rule.content ?? '');
      // 书源内置替换
      content = await _applySourceReplace(content, rule.replaceRegex);
      contentParts.add(content);
      if (rule.nextContentUrl != null && rule.nextContentUrl!.isNotEmpty) {
        final next = (await analyzer.getString(rule.nextContentUrl!)).trim();
        if (next.isEmpty || _absUrl(req.url, next) == nextUrl) break;
        nextUrl = _absUrl(req.url, next);
      } else {
        break;
      }
      guard++;
    }
    var text = contentParts.join('\n');
    // 全局替换规则
    text = await applyReplaceRules(text, source);
    await AppDatabase.saveContent(book.bookUrl, index, text);
    return text;
  }

  Future<String> _applySourceReplace(String content, String? replaceRegex) async {
    if (replaceRegex == null || replaceRegex.isEmpty) return content;
    var text = content;
    // 多条 ## 规则以 \n 分割，每条: pattern##replacement 或 pattern
    for (final line in replaceRegex.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final parts = l.split('##');
      try {
        final re = RegExp(parts[0], multiLine: true);
        final rep = parts.length > 1 ? parts[1] : '';
        text = text.replaceAllMapped(re, (m) {
          var r = rep;
          for (var i = 1; i <= m.groupCount; i++) {
            r = r.replaceAll('\$$i', m.group(i) ?? '');
          }
          return r;
        });
      } catch (_) {}
    }
    return text;
  }

  Future<String> applyReplaceRules(String text, BookSource? source) async {
    final rules = await AppDatabase.getReplaceRules();
    var result = text;
    for (final rule in rules) {
      if (!rule.enabled || rule.pattern.isEmpty) continue;
      // scope 简单匹配
      if (rule.scope != null && rule.scope!.isNotEmpty) {
        if (source != null && !rule.scope!.contains(source.bookSourceUrl) &&
            !rule.scope!.contains('all')) {
          continue;
        }
      }
      try {
        final re = RegExp(rule.pattern, multiLine: true);
        result = result.replaceAllMapped(re, (m) {
          var r = rule.replacement;
          for (var i = 1; i <= m.groupCount; i++) {
            r = r.replaceAll('\$$i', m.group(i) ?? '');
          }
          return r;
        });
      } catch (_) {}
    }
    return result;
  }

  // ---------- 添加书架 ----------

  Future<Book> addToShelf(Book searchBook, BookSource source) async {
    // 已在书架？
    final existing = await AppDatabase.getBook(searchBook.bookUrl);
    if (existing != null) return existing;
    final info = await loadBookInfo(searchBook, source);
    final chapters = await loadChapters(info, source);
    await AppDatabase.saveBook(info);
    await AppDatabase.saveChapters(info.bookUrl, chapters);
    return info;
  }

  // ---------- JS 注册 ----------

  void registerJsBridge() {
    JsEngine.instance.registerFunction('put', (params) {
      if (params.length >= 2) {
        JsEngine.putVariable(params[0].toString(), params[1].toString());
      }
      return '';
    });
    JsEngine.instance.registerFunction('get', (params) {
      if (params.isEmpty) return '';
      return JsEngine.getVariable(params[0].toString()) ?? '';
    });
    JsEngine.instance.registerFunction('getVariable', (params) {
      return params.isEmpty ? '' : JsEngine.getVariable(params[0].toString()) ?? '';
    });
    JsEngine.instance.registerFunction('setVariable', (params) {
      if (params.length >= 2) {
        JsEngine.putVariable(params[0].toString(), params[1].toString());
      }
      return '';
    });
    JsEngine.instance.registerFunction('base64Encode', (params) {
      if (params.isEmpty) return '';
      return base64.encode(utf8.encode(params[0].toString()));
    });
    JsEngine.instance.registerFunction('base64Decode', (params) {
      if (params.isEmpty) return '';
      return utf8.decode(base64.decode(params[0].toString()), allowMalformed: true);
    });
    JsEngine.instance.registerFunction('md5Encode', (params) => params.isEmpty ? '' : _md5(params[0].toString()));
    JsEngine.instance.registerFunction('ajax', (params) async {
      if (params.isEmpty) return '';
      final url = params[0].toString();
      final req = AnalyzedRequest(url, UrlOption());
      return HttpService.instance.requestText(req);
    });
  }

  static String _md5(String input) {
    // 简易占位：如需 md5 建议引入 crypto 包
    return input.hashCode.toString();
  }
}

String _absUrl(String baseUrl, String url) {
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  try {
    return Uri.parse(baseUrl).resolve(u).toString();
  } catch (_) {
    return u;
  }
}
