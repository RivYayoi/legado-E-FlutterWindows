/// 数据库层：sqflite_common_ffi（Windows 桌面）
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'entities/book.dart';
import 'entities/rules.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _db;
  static Database get db => _db!;

  static Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    _db = await databaseFactory.openDatabase(
      p.join(dir.path, 'legado_windows.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE book_sources (
              bookSourceUrl TEXT PRIMARY KEY,
              bookSourceName TEXT NOT NULL DEFAULT '',
              bookSourceGroup TEXT,
              bookSourceType INTEGER NOT NULL DEFAULT 0,
              bookUrlPattern TEXT,
              customOrder INTEGER NOT NULL DEFAULT 0,
              enabled INTEGER NOT NULL DEFAULT 1,
              enabledExplore INTEGER NOT NULL DEFAULT 1,
              jsLib TEXT,
              enabledCookieJar INTEGER NOT NULL DEFAULT 1,
              concurrentRate TEXT,
              header TEXT,
              loginUrl TEXT,
              loginUi TEXT,
              loginCheckJs TEXT,
              coverDecodeJs TEXT,
              bookSourceComment TEXT,
              variableComment TEXT,
              lastUpdateTime INTEGER NOT NULL DEFAULT 0,
              respondTime INTEGER NOT NULL DEFAULT 180000,
              weight INTEGER NOT NULL DEFAULT 0,
              exploreUrl TEXT,
              exploreScreen TEXT,
              searchUrl TEXT,
              ruleExplore TEXT,
              ruleSearch TEXT,
              ruleBookInfo TEXT,
              ruleToc TEXT,
              ruleContent TEXT,
              variable TEXT
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_sources_order ON book_sources(customOrder)');
          await db.execute('''
            CREATE TABLE books (
              bookUrl TEXT PRIMARY KEY,
              tocUrl TEXT NOT NULL DEFAULT '',
              origin TEXT NOT NULL DEFAULT 'loc_book',
              originName TEXT NOT NULL DEFAULT '',
              name TEXT NOT NULL DEFAULT '',
              author TEXT NOT NULL DEFAULT '',
              kind TEXT,
              customTag TEXT,
              coverUrl TEXT,
              customCoverUrl TEXT,
              intro TEXT,
              customIntro TEXT,
              charset TEXT,
              type INTEGER NOT NULL DEFAULT 0,
              groupId INTEGER NOT NULL DEFAULT 0,
              latestChapterTitle TEXT,
              latestChapterTime INTEGER NOT NULL DEFAULT 0,
              lastCheckTime INTEGER NOT NULL DEFAULT 0,
              totalChapterNum INTEGER NOT NULL DEFAULT 0,
              durChapterTitle TEXT,
              durChapterIndex INTEGER NOT NULL DEFAULT 0,
              durChapterPos INTEGER NOT NULL DEFAULT 0,
              durChapterTime INTEGER NOT NULL DEFAULT 0,
              wordCount TEXT,
              canUpdate INTEGER NOT NULL DEFAULT 1,
              sortOrder INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE chapters (
              url TEXT NOT NULL,
              bookUrl TEXT NOT NULL,
              title TEXT NOT NULL DEFAULT '',
              isVolume INTEGER NOT NULL DEFAULT 0,
              baseUrl TEXT NOT NULL DEFAULT '',
              chapterIndex INTEGER NOT NULL DEFAULT 0,
              isVip INTEGER NOT NULL DEFAULT 0,
              isPay INTEGER NOT NULL DEFAULT 0,
              resourceUrl TEXT,
              tag TEXT,
              wordCount TEXT,
              variable TEXT,
              PRIMARY KEY (url, bookUrl)
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_chapters_book ON chapters(bookUrl, chapterIndex)');
          await db.execute('''
            CREATE TABLE chapter_contents (
              bookUrl TEXT NOT NULL,
              chapterIndex INTEGER NOT NULL,
              content TEXT NOT NULL,
              updateTime INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (bookUrl, chapterIndex)
            )
          ''');
          await db.execute('''
            CREATE TABLE replace_rules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL DEFAULT '',
              groupName TEXT,
              pattern TEXT NOT NULL DEFAULT '',
              replacement TEXT NOT NULL DEFAULT '',
              sortOrder INTEGER NOT NULL DEFAULT 0,
              enabled INTEGER NOT NULL DEFAULT 1,
              regex INTEGER NOT NULL DEFAULT 1,
              scope TEXT
            )
          ''');
        },
      ),
    );
  }

  // ---------------- 书源 ----------------

  static BookSource _rowToSource(Map<String, Object?> r) => BookSource(
        bookSourceUrl: r['bookSourceUrl'] as String? ?? '',
        bookSourceName: r['bookSourceName'] as String? ?? '',
        bookSourceGroup: r['bookSourceGroup'] as String?,
        bookSourceType: r['bookSourceType'] as int? ?? 0,
        bookUrlPattern: r['bookUrlPattern'] as String?,
        customOrder: r['customOrder'] as int? ?? 0,
        enabled: (r['enabled'] as int? ?? 1) == 1,
        enabledExplore: (r['enabledExplore'] as int? ?? 1) == 1,
        jsLib: r['jsLib'] as String?,
        enabledCookieJar: (r['enabledCookieJar'] as int? ?? 1) == 1,
        concurrentRate: r['concurrentRate'] as String?,
        header: r['header'] as String?,
        loginUrl: r['loginUrl'] as String?,
        loginUi: r['loginUi'] as String?,
        loginCheckJs: r['loginCheckJs'] as String?,
        coverDecodeJs: r['coverDecodeJs'] as String?,
        bookSourceComment: r['bookSourceComment'] as String?,
        variableComment: r['variableComment'] as String?,
        lastUpdateTime: r['lastUpdateTime'] as int? ?? 0,
        respondTime: r['respondTime'] as int? ?? 180000,
        weight: r['weight'] as int? ?? 0,
        exploreUrl: r['exploreUrl'] as String?,
        exploreScreen: r['exploreScreen'] as String?,
        searchUrl: r['searchUrl'] as String?,
        ruleExploreRaw: r['ruleExplore'] as String?,
        ruleSearchRaw: r['ruleSearch'] as String?,
        ruleBookInfoRaw: r['ruleBookInfo'] as String?,
        ruleTocRaw: r['ruleToc'] as String?,
        ruleContentRaw: r['ruleContent'] as String?,
        variable: r['variable'] as String?,
      );

  static Map<String, Object?> _sourceToRow(BookSource s) => {
        'bookSourceUrl': s.bookSourceUrl,
        'bookSourceName': s.bookSourceName,
        'bookSourceGroup': s.bookSourceGroup,
        'bookSourceType': s.bookSourceType,
        'bookUrlPattern': s.bookUrlPattern,
        'customOrder': s.customOrder,
        'enabled': s.enabled ? 1 : 0,
        'enabledExplore': s.enabledExplore ? 1 : 0,
        'jsLib': s.jsLib,
        'enabledCookieJar': (s.enabledCookieJar ?? true) ? 1 : 0,
        'concurrentRate': s.concurrentRate,
        'header': s.header,
        'loginUrl': s.loginUrl,
        'loginUi': s.loginUi,
        'loginCheckJs': s.loginCheckJs,
        'coverDecodeJs': s.coverDecodeJs,
        'bookSourceComment': s.bookSourceComment,
        'variableComment': s.variableComment,
        'lastUpdateTime': s.lastUpdateTime,
        'respondTime': s.respondTime,
        'weight': s.weight,
        'exploreUrl': s.exploreUrl,
        'exploreScreen': s.exploreScreen,
        'searchUrl': s.searchUrl,
        'ruleExplore': s.ruleExploreRaw,
        'ruleSearch': s.ruleSearchRaw,
        'ruleBookInfo': s.ruleBookInfoRaw,
        'ruleToc': s.ruleTocRaw,
        'ruleContent': s.ruleContentRaw,
        'variable': s.variable,
      };

  static Future<void> saveSource(BookSource s) async {
    await db.insert('book_sources', _sourceToRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> saveSources(List<BookSource> list) async {
    final batch = db.batch();
    for (final s in list) {
      batch.insert('book_sources', _sourceToRow(s),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<BookSource>> getSources({bool? enabled}) async {
    final rows = await db.query('book_sources',
        where: enabled == null ? null : 'enabled = ?',
        whereArgs: enabled == null ? null : [enabled ? 1 : 0],
        orderBy: 'customOrder DESC, respondTime ASC');
    return rows.map(_rowToSource).toList();
  }

  static Future<BookSource?> getSource(String url) async {
    final rows =
        await db.query('book_sources', where: 'bookSourceUrl = ?', whereArgs: [url]);
    return rows.isEmpty ? null : _rowToSource(rows.first);
  }

  static Future<void> deleteSources(List<String> urls) async {
    await db.delete('book_sources',
        where: 'bookSourceUrl IN (${List.filled(urls.length, '?').join(',')})',
        whereArgs: urls);
  }

  // ---------------- 书籍 ----------------

  static Book _rowToBook(Map<String, Object?> r) => Book(
        bookUrl: r['bookUrl'] as String? ?? '',
        tocUrl: r['tocUrl'] as String? ?? '',
        origin: r['origin'] as String? ?? 'loc_book',
        originName: r['originName'] as String? ?? '',
        name: r['name'] as String? ?? '',
        author: r['author'] as String? ?? '',
        kind: r['kind'] as String?,
        customTag: r['customTag'] as String?,
        coverUrl: r['coverUrl'] as String?,
        customCoverUrl: r['customCoverUrl'] as String?,
        intro: r['intro'] as String?,
        customIntro: r['customIntro'] as String?,
        charset: r['charset'] as String?,
        type: r['type'] as int? ?? 0,
        group: r['groupId'] as int? ?? 0,
        latestChapterTitle: r['latestChapterTitle'] as String?,
        latestChapterTime: r['latestChapterTime'] as int? ?? 0,
        lastCheckTime: r['lastCheckTime'] as int? ?? 0,
        totalChapterNum: r['totalChapterNum'] as int? ?? 0,
        durChapterTitle: r['durChapterTitle'] as String?,
        durChapterIndex: r['durChapterIndex'] as int? ?? 0,
        durChapterPos: r['durChapterPos'] as int? ?? 0,
        durChapterTime: r['durChapterTime'] as int? ?? 0,
        wordCount: r['wordCount'] as String?,
        canUpdate: (r['canUpdate'] as int? ?? 1) == 1,
        order: r['sortOrder'] as int? ?? 0,
      );

  static Map<String, Object?> _bookToRow(Book b) => {
        'bookUrl': b.bookUrl,
        'tocUrl': b.tocUrl,
        'origin': b.origin,
        'originName': b.originName,
        'name': b.name,
        'author': b.author,
        'kind': b.kind,
        'customTag': b.customTag,
        'coverUrl': b.coverUrl,
        'customCoverUrl': b.customCoverUrl,
        'intro': b.intro,
        'customIntro': b.customIntro,
        'charset': b.charset,
        'type': b.type,
        'groupId': b.group,
        'latestChapterTitle': b.latestChapterTitle,
        'latestChapterTime': b.latestChapterTime,
        'lastCheckTime': b.lastCheckTime,
        'totalChapterNum': b.totalChapterNum,
        'durChapterTitle': b.durChapterTitle,
        'durChapterIndex': b.durChapterIndex,
        'durChapterPos': b.durChapterPos,
        'durChapterTime': b.durChapterTime,
        'wordCount': b.wordCount,
        'canUpdate': b.canUpdate ? 1 : 0,
        'sortOrder': b.order,
      };

  static Future<void> saveBook(Book b) async {
    await db.insert('books', _bookToRow(b),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Book>> getBooks() async {
    final rows =
        await db.query('books', orderBy: 'durChapterTime DESC, sortOrder ASC');
    return rows.map(_rowToBook).toList();
  }

  static Future<Book?> getBook(String bookUrl) async {
    final rows = await db.query('books', where: 'bookUrl = ?', whereArgs: [bookUrl]);
    return rows.isEmpty ? null : _rowToBook(rows.first);
  }

  static Future<void> deleteBook(String bookUrl) async {
    await db.delete('books', where: 'bookUrl = ?', whereArgs: [bookUrl]);
    await db.delete('chapters', where: 'bookUrl = ?', whereArgs: [bookUrl]);
    await db
        .delete('chapter_contents', where: 'bookUrl = ?', whereArgs: [bookUrl]);
  }

  static Future<void> updateReadProgress(
      String bookUrl, int chapterIndex, int pos, String? title) async {
    await db.update(
      'books',
      {
        'durChapterIndex': chapterIndex,
        'durChapterPos': pos,
        'durChapterTitle': title,
        'durChapterTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );
  }

  // ---------------- 章节 ----------------

  static Future<void> saveChapters(
      String bookUrl, List<BookChapter> chapters) async {
    final batch = db.batch();
    await db.delete('chapters', where: 'bookUrl = ?', whereArgs: [bookUrl]);
    for (final c in chapters) {
      batch.insert('chapters', {
        'url': c.url,
        'bookUrl': bookUrl,
        'title': c.title,
        'isVolume': c.isVolume ? 1 : 0,
        'baseUrl': c.baseUrl,
        'chapterIndex': c.index,
        'isVip': c.isVip ? 1 : 0,
        'isPay': c.isPay ? 1 : 0,
        'resourceUrl': c.resourceUrl,
        'tag': c.tag,
        'wordCount': c.wordCount,
        'variable': c.variable,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<BookChapter>> getChapters(String bookUrl) async {
    final rows = await db.query('chapters',
        where: 'bookUrl = ?',
        whereArgs: [bookUrl],
        orderBy: 'chapterIndex ASC');
    return rows.map((r) => BookChapter(
          url: r['url'] as String? ?? '',
          title: r['title'] as String? ?? '',
          isVolume: (r['isVolume'] as int? ?? 0) == 1,
          baseUrl: r['baseUrl'] as String? ?? '',
          bookUrl: r['bookUrl'] as String? ?? '',
          index: r['chapterIndex'] as int? ?? 0,
          isVip: (r['isVip'] as int? ?? 0) == 1,
          isPay: (r['isPay'] as int? ?? 0) == 1,
          resourceUrl: r['resourceUrl'] as String?,
          tag: r['tag'] as String?,
          wordCount: r['wordCount'] as String?,
          variable: r['variable'] as String?,
        )).toList();
  }

  // ---------------- 正文缓存 ----------------

  static Future<void> saveContent(
      String bookUrl, int index, String content) async {
    await db.insert(
      'chapter_contents',
      {
        'bookUrl': bookUrl,
        'chapterIndex': index,
        'content': content,
        'updateTime': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getContent(String bookUrl, int index) async {
    final rows = await db.query('chapter_contents',
        where: 'bookUrl = ? AND chapterIndex = ?',
        whereArgs: [bookUrl, index],
        limit: 1);
    return rows.isEmpty ? null : rows.first['content'] as String?;
  }

  // ---------------- 替换规则 ----------------

  static Future<List<ReplaceRule>> getReplaceRules({bool enabledOnly = true}) async {
    final rows = await db.query('replace_rules',
        where: enabledOnly ? 'enabled = 1' : null, orderBy: 'sortOrder ASC');
    return rows.map((r) => ReplaceRule(
          id: r['id'] as int?,
          name: r['name'] as String? ?? '',
          group: r['groupName'] as String?,
          pattern: r['pattern'] as String? ?? '',
          replacement: r['replacement'] as String? ?? '',
          order: r['sortOrder'] as int? ?? 0,
          enabled: (r['enabled'] as int? ?? 1) == 1,
          regex: (r['regex'] as int? ?? 1) == 1,
          scope: r['scope'] as String?,
        )).toList();
  }

  static Future<void> saveReplaceRule(ReplaceRule rule) async {
    await db.insert(
      'replace_rules',
      {
        if (rule.id != null) 'id': rule.id,
        'name': rule.name,
        'groupName': rule.group,
        'pattern': rule.pattern,
        'replacement': rule.replacement,
        'sortOrder': rule.order,
        'enabled': rule.enabled ? 1 : 0,
        'regex': rule.regex ? 1 : 0,
        'scope': rule.scope,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteReplaceRule(int id) async {
    await db.delete('replace_rules', where: 'id = ?', whereArgs: [id]);
  }

  /// 导出数据库文件路径
  static Future<String> exportDb() async {
    final dir = await getApplicationSupportDirectory();
    final src = File(p.join(dir.path, 'legado_windows.db'));
    return src.path;
  }
}
