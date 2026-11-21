/// 书源规则实体（对应 BookSource.kt 及 rule/*.kt）
library;

import 'dart:convert';

/// 规则解析辅助：字段可能是 String / Map
String? _s(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is Map || v is List) return null;
  return v.toString();
}

/// 通用规则体：宽松解析，兼容字段值为 Map 的书源
class RuleFields {
  final Map<String, dynamic> raw;
  RuleFields(this.raw);

  String? operator [](String key) => _s(raw[key]);

  static RuleFields? fromJson(Object? json) {
    if (json == null) return null;
    if (json is String) {
      final s = json.trim();
      if (s.isEmpty) return null;
      // 存储的是 JSON 字符串，尝试解码为 Map
      if (s.startsWith('{')) {
        try {
          final v = jsonDecode(s);
          if (v is Map) return RuleFields(Map<String, dynamic>.from(v));
        } catch (_) {}
      }
      return RuleFields({'content': s});
    }
    if (json is Map) return RuleFields(Map<String, dynamic>.from(json));
    return null;
  }
}

/// 搜索规则
class SearchRule {
  String? checkKeyWord;
  String? bookList;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? bookUrl;
  String? coverUrl;
  String? wordCount;

  SearchRule({
    this.checkKeyWord,
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  SearchRule.fromFields(RuleFields f)
      : checkKeyWord = f['checkKeyWord'],
        bookList = f['bookList'],
        name = f['name'],
        author = f['author'],
        intro = f['intro'],
        kind = f['kind'],
        lastChapter = f['lastChapter'],
        updateTime = f['updateTime'],
        bookUrl = f['bookUrl'],
        coverUrl = f['coverUrl'],
        wordCount = f['wordCount'];

  factory SearchRule.fromJson(Object? json) {
    final f = RuleFields.fromJson(json);
    return f == null ? SearchRule() : SearchRule.fromFields(f);
  }

  Map<String, dynamic> toJson() => {
        if (checkKeyWord != null) 'checkKeyWord': checkKeyWord,
        if (bookList != null) 'bookList': bookList,
        if (name != null) 'name': name,
        if (author != null) 'author': author,
        if (intro != null) 'intro': intro,
        if (kind != null) 'kind': kind,
        if (lastChapter != null) 'lastChapter': lastChapter,
        if (updateTime != null) 'updateTime': updateTime,
        if (bookUrl != null) 'bookUrl': bookUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (wordCount != null) 'wordCount': wordCount,
      };
}

/// 发现规则
class ExploreRule {
  String? bookList;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? bookUrl;
  String? coverUrl;
  String? wordCount;

  ExploreRule({
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  ExploreRule.fromFields(RuleFields f)
      : bookList = f['bookList'],
        name = f['name'],
        author = f['author'],
        intro = f['intro'],
        kind = f['kind'],
        lastChapter = f['lastChapter'],
        updateTime = f['updateTime'],
        bookUrl = f['bookUrl'],
        coverUrl = f['coverUrl'],
        wordCount = f['wordCount'];

  factory ExploreRule.fromJson(Object? json) {
    final f = RuleFields.fromJson(json);
    return f == null ? ExploreRule() : ExploreRule.fromFields(f);
  }

  Map<String, dynamic> toJson() => {
        if (bookList != null) 'bookList': bookList,
        if (name != null) 'name': name,
        if (author != null) 'author': author,
        if (intro != null) 'intro': intro,
        if (kind != null) 'kind': kind,
        if (lastChapter != null) 'lastChapter': lastChapter,
        if (updateTime != null) 'updateTime': updateTime,
        if (bookUrl != null) 'bookUrl': bookUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (wordCount != null) 'wordCount': wordCount,
      };
}

/// 书籍详情页规则
class BookInfoRule {
  String? init;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? coverUrl;
  String? tocUrl;
  String? wordCount;
  String? canReName;
  String? downloadUrls;

  BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
    this.canReName,
    this.downloadUrls,
  });

  BookInfoRule.fromFields(RuleFields f)
      : init = f['init'],
        name = f['name'],
        author = f['author'],
        intro = f['intro'],
        kind = f['kind'],
        lastChapter = f['lastChapter'],
        updateTime = f['updateTime'],
        coverUrl = f['coverUrl'],
        tocUrl = f['tocUrl'],
        wordCount = f['wordCount'],
        canReName = f['canReName'],
        downloadUrls = f['downloadUrls'];

  factory BookInfoRule.fromJson(Object? json) {
    final f = RuleFields.fromJson(json);
    return f == null ? BookInfoRule() : BookInfoRule.fromFields(f);
  }

  Map<String, dynamic> toJson() => {
        if (init != null) 'init': init,
        if (name != null) 'name': name,
        if (author != null) 'author': author,
        if (intro != null) 'intro': intro,
        if (kind != null) 'kind': kind,
        if (lastChapter != null) 'lastChapter': lastChapter,
        if (updateTime != null) 'updateTime': updateTime,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (tocUrl != null) 'tocUrl': tocUrl,
        if (wordCount != null) 'wordCount': wordCount,
        if (canReName != null) 'canReName': canReName,
        if (downloadUrls != null) 'downloadUrls': downloadUrls,
      };
}

/// 目录规则
class TocRule {
  String? preUpdateJs;
  String? chapterList;
  String? chapterName;
  String? chapterUrl;
  String? formatJs;
  String? isVolume;
  String? isVip;
  String? isPay;
  String? updateTime;
  String? nextTocUrl;

  TocRule({
    this.preUpdateJs,
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.formatJs,
    this.isVolume,
    this.isVip,
    this.isPay,
    this.updateTime,
    this.nextTocUrl,
  });

  TocRule.fromFields(RuleFields f)
      : preUpdateJs = f['preUpdateJs'],
        chapterList = f['chapterList'],
        chapterName = f['chapterName'],
        chapterUrl = f['chapterUrl'],
        formatJs = f['formatJs'],
        isVolume = f['isVolume'],
        isVip = f['isVip'],
        isPay = f['isPay'],
        updateTime = f['updateTime'],
        nextTocUrl = f['nextTocUrl'];

  factory TocRule.fromJson(Object? json) {
    final f = RuleFields.fromJson(json);
    return f == null ? TocRule() : TocRule.fromFields(f);
  }

  Map<String, dynamic> toJson() => {
        if (preUpdateJs != null) 'preUpdateJs': preUpdateJs,
        if (chapterList != null) 'chapterList': chapterList,
        if (chapterName != null) 'chapterName': chapterName,
        if (chapterUrl != null) 'chapterUrl': chapterUrl,
        if (formatJs != null) 'formatJs': formatJs,
        if (isVolume != null) 'isVolume': isVolume,
        if (isVip != null) 'isVip': isVip,
        if (isPay != null) 'isPay': isPay,
        if (updateTime != null) 'updateTime': updateTime,
        if (nextTocUrl != null) 'nextTocUrl': nextTocUrl,
      };
}

/// 正文规则
class ContentRule {
  String? content;
  String? subContent;
  String? title;
  String? nextContentUrl;
  String? webJs;
  String? sourceRegex;
  String? replaceRegex;
  String? imageStyle;
  String? imageDecode;
  String? payAction;
  String? callBackJs;

  ContentRule({
    this.content,
    this.subContent,
    this.title,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.imageDecode,
    this.payAction,
    this.callBackJs,
  });

  ContentRule.fromFields(RuleFields f)
      : content = f['content'],
        subContent = f['subContent'],
        title = f['title'],
        nextContentUrl = f['nextContentUrl'],
        webJs = f['webJs'],
        sourceRegex = f['sourceRegex'],
        replaceRegex = f['replaceRegex'],
        imageStyle = f['imageStyle'],
        imageDecode = f['imageDecode'],
        payAction = f['payAction'],
        callBackJs = f['callBackJs'];

  factory ContentRule.fromJson(Object? json) {
    final f = RuleFields.fromJson(json);
    return f == null ? ContentRule() : ContentRule.fromFields(f);
  }

  Map<String, dynamic> toJson() => {
        if (content != null) 'content': content,
        if (subContent != null) 'subContent': subContent,
        if (title != null) 'title': title,
        if (nextContentUrl != null) 'nextContentUrl': nextContentUrl,
        if (webJs != null) 'webJs': webJs,
        if (sourceRegex != null) 'sourceRegex': sourceRegex,
        if (replaceRegex != null) 'replaceRegex': replaceRegex,
        if (imageStyle != null) 'imageStyle': imageStyle,
        if (imageDecode != null) 'imageDecode': imageDecode,
        if (payAction != null) 'payAction': payAction,
        if (callBackJs != null) 'callBackJs': callBackJs,
      };
}

/// 书源实体
class BookSource {
  String bookSourceUrl;
  String bookSourceName;
  String? bookSourceGroup;
  int bookSourceType; // 0 文本 1 音频 2 图片 3 文件 4 视频
  String? bookUrlPattern;
  int customOrder;
  bool enabled;
  bool enabledExplore;
  String? jsLib;
  bool? enabledCookieJar;
  String? concurrentRate;
  String? header;
  String? loginUrl;
  String? loginUi;
  String? loginCheckJs;
  String? coverDecodeJs;
  String? bookSourceComment;
  String? variableComment;
  int lastUpdateTime;
  int respondTime;
  int weight;
  String? exploreUrl;
  String? exploreScreen;
  String? searchUrl;
  String? ruleExploreRaw;
  String? ruleSearchRaw;
  String? ruleBookInfoRaw;
  String? ruleTocRaw;
  String? ruleContentRaw;
  String? variable;

  BookSource({
    this.bookSourceUrl = '',
    this.bookSourceName = '',
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.bookUrlPattern,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.exploreUrl,
    this.exploreScreen,
    this.searchUrl,
    this.ruleExploreRaw,
    this.ruleSearchRaw,
    this.ruleBookInfoRaw,
    this.ruleTocRaw,
    this.ruleContentRaw,
    this.variable,
  });

  String get tag => bookSourceName;
  String get key => bookSourceUrl;

  SearchRule get searchRule => SearchRule.fromJson(ruleSearchRaw);
  BookInfoRule get bookInfoRule => BookInfoRule.fromJson(ruleBookInfoRaw);
  TocRule get tocRule => TocRule.fromJson(ruleTocRaw);
  ContentRule get contentRule => ContentRule.fromJson(ruleContentRaw);
  ExploreRule get exploreRule => ExploreRule.fromJson(ruleExploreRaw);

  /// 解析请求头：支持 JSON 对象或直接 UA 字符串
  Map<String, String> get headerMap {
    final h = header?.trim() ?? '';
    if (h.isEmpty) return {};
    try {
      final v = jsonDecode(h);
      if (v is Map) {
        return v.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (_) {}
    return {'User-Agent': h};
  }

  factory BookSource.fromJson(Map<String, dynamic> json) {
    String? ruleJson(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is Map) return jsonEncode(v);
      if (v is String && v.trim().isEmpty) return null;
      return v.toString();
    }

    int toInt(Object? v, [int def = 0]) {
      if (v == null) return def;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? def;
    }

    return BookSource(
      bookSourceUrl: _s(json['bookSourceUrl']) ?? '',
      bookSourceName: _s(json['bookSourceName']) ?? '',
      bookSourceGroup: _s(json['bookSourceGroup']),
      bookSourceType: toInt(json['bookSourceType']),
      bookUrlPattern: _s(json['bookUrlPattern']),
      customOrder: toInt(json['customOrder']),
      enabled: json['enabled'] as bool? ?? true,
      enabledExplore: json['enabledExplore'] as bool? ?? true,
      jsLib: _s(json['jsLib']),
      enabledCookieJar: json['enabledCookieJar'] as bool? ?? true,
      concurrentRate: _s(json['concurrentRate']),
      header: _s(json['header']),
      loginUrl: _s(json['loginUrl']),
      loginUi: _s(json['loginUi']),
      loginCheckJs: _s(json['loginCheckJs']),
      coverDecodeJs: _s(json['coverDecodeJs']),
      bookSourceComment: _s(json['bookSourceComment']),
      variableComment: _s(json['variableComment']),
      lastUpdateTime: toInt(json['lastUpdateTime']),
      respondTime: toInt(json['respondTime'], 180000),
      weight: toInt(json['weight']),
      exploreUrl: _s(json['exploreUrl']),
      exploreScreen: _s(json['exploreScreen']),
      searchUrl: _s(json['searchUrl']),
      ruleExploreRaw: ruleJson('ruleExplore'),
      ruleSearchRaw: ruleJson('ruleSearch'),
      ruleBookInfoRaw: ruleJson('ruleBookInfo'),
      ruleTocRaw: ruleJson('ruleToc'),
      ruleContentRaw: ruleJson('ruleContent'),
      variable: _s(json['variable']),
    );
  }

  Map<String, dynamic> toJson() => {
        'bookSourceUrl': bookSourceUrl,
        'bookSourceName': bookSourceName,
        'bookSourceGroup': bookSourceGroup,
        'bookSourceType': bookSourceType,
        'bookUrlPattern': bookUrlPattern,
        'customOrder': customOrder,
        'enabled': enabled,
        'enabledExplore': enabledExplore,
        'jsLib': jsLib,
        'enabledCookieJar': enabledCookieJar,
        'concurrentRate': concurrentRate,
        'header': header,
        'loginUrl': loginUrl,
        'loginUi': loginUi,
        'loginCheckJs': loginCheckJs,
        'coverDecodeJs': coverDecodeJs,
        'bookSourceComment': bookSourceComment,
        'variableComment': variableComment,
        'lastUpdateTime': lastUpdateTime,
        'respondTime': respondTime,
        'weight': weight,
        'exploreUrl': exploreUrl,
        'exploreScreen': exploreScreen,
        'searchUrl': searchUrl,
        if (ruleExploreRaw != null) 'ruleExplore': _loose(ruleExploreRaw),
        if (ruleSearchRaw != null) 'ruleSearch': _loose(ruleSearchRaw),
        if (ruleBookInfoRaw != null) 'ruleBookInfo': _loose(ruleBookInfoRaw),
        if (ruleTocRaw != null) 'ruleToc': _loose(ruleTocRaw),
        if (ruleContentRaw != null) 'ruleContent': _loose(ruleContentRaw),
        'variable': variable,
      };

  static Object? _loose(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
}
