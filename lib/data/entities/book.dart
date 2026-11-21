/// 书籍实体（对应 Book.kt，裁剪后的桌面版）
library;

class Book {
  String bookUrl; // 详情页 url（主键）
  String tocUrl; // 目录页 url
  String origin; // 书源 url（local 表示本地）
  String originName; // 书源名称
  String name;
  String author;
  String? kind;
  String? customTag;
  String? coverUrl;
  String? customCoverUrl;
  String? intro;
  String? customIntro;
  String? charset;
  int type; // 0 文本 8 本地 16 音频 ...
  int group;
  String? latestChapterTitle;
  int latestChapterTime;
  int lastCheckTime;
  int totalChapterNum;
  String? durChapterTitle;
  int durChapterIndex;
  int durChapterPos;
  int durChapterTime;
  String? wordCount;
  bool canUpdate;
  int order;

  Book({
    this.bookUrl = '',
    this.tocUrl = '',
    this.origin = 'loc_book',
    this.originName = '',
    this.name = '',
    this.author = '',
    this.kind,
    this.customTag,
    this.coverUrl,
    this.customCoverUrl,
    this.intro,
    this.customIntro,
    this.charset,
    this.type = 0,
    this.group = 0,
    this.latestChapterTitle,
    this.latestChapterTime = 0,
    this.lastCheckTime = 0,
    this.totalChapterNum = 0,
    this.durChapterTitle,
    this.durChapterIndex = 0,
    this.durChapterPos = 0,
    this.durChapterTime = 0,
    this.wordCount,
    this.canUpdate = true,
    this.order = 0,
  });

  bool get isLocal => origin == 'loc_book' || origin.isEmpty;

  String get displayCover => customCoverUrl ?? coverUrl ?? '';

  String get displayIntro => customIntro ?? intro ?? '';

  Map<String, dynamic> toJson() => {
        'bookUrl': bookUrl,
        'tocUrl': tocUrl,
        'origin': origin,
        'originName': originName,
        'name': name,
        'author': author,
        'kind': kind,
        'coverUrl': coverUrl,
        'intro': intro,
        'charset': charset,
        'type': type,
        'group': group,
        'latestChapterTitle': latestChapterTitle,
        'latestChapterTime': latestChapterTime,
        'lastCheckTime': lastCheckTime,
        'totalChapterNum': totalChapterNum,
        'durChapterTitle': durChapterTitle,
        'durChapterIndex': durChapterIndex,
        'durChapterPos': durChapterPos,
        'durChapterTime': durChapterTime,
        'wordCount': wordCount,
        'canUpdate': canUpdate,
        'order': order,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        bookUrl: json['bookUrl'] ?? '',
        tocUrl: json['tocUrl'] ?? '',
        origin: json['origin'] ?? 'loc_book',
        originName: json['originName'] ?? '',
        name: json['name'] ?? '',
        author: json['author'] ?? '',
        kind: json['kind'],
        coverUrl: json['coverUrl'],
        intro: json['intro'],
        charset: json['charset'],
        type: json['type'] ?? 0,
        group: json['group'] ?? 0,
        latestChapterTitle: json['latestChapterTitle'],
        latestChapterTime: json['latestChapterTime'] ?? 0,
        lastCheckTime: json['lastCheckTime'] ?? 0,
        totalChapterNum: json['totalChapterNum'] ?? 0,
        durChapterTitle: json['durChapterTitle'],
        durChapterIndex: json['durChapterIndex'] ?? 0,
        durChapterPos: json['durChapterPos'] ?? 0,
        durChapterTime: json['durChapterTime'] ?? 0,
        wordCount: json['wordCount'],
        canUpdate: json['canUpdate'] ?? true,
        order: json['order'] ?? 0,
      );
}

/// 章节实体（对应 BookChapter.kt）
class BookChapter {
  String url;
  String title;
  bool isVolume;
  String baseUrl;
  String bookUrl;
  int index;
  bool isVip;
  bool isPay;
  String? resourceUrl;
  String? tag;
  String? wordCount;
  String? variable;

  BookChapter({
    this.url = '',
    this.title = '',
    this.isVolume = false,
    this.baseUrl = '',
    this.bookUrl = '',
    this.index = 0,
    this.isVip = false,
    this.isPay = false,
    this.resourceUrl,
    this.tag,
    this.wordCount,
    this.variable,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'isVolume': isVolume,
        'baseUrl': baseUrl,
        'bookUrl': bookUrl,
        'index': index,
        'isVip': isVip,
        'isPay': isPay,
        'resourceUrl': resourceUrl,
        'tag': tag,
        'wordCount': wordCount,
        'variable': variable,
      };

  factory BookChapter.fromJson(Map<String, dynamic> json) => BookChapter(
        url: json['url'] ?? '',
        title: json['title'] ?? '',
        isVolume: json['isVolume'] ?? false,
        baseUrl: json['baseUrl'] ?? '',
        bookUrl: json['bookUrl'] ?? '',
        index: json['index'] ?? 0,
        isVip: json['isVip'] ?? false,
        isPay: json['isPay'] ?? false,
        resourceUrl: json['resourceUrl'],
        tag: json['tag'],
        wordCount: json['wordCount'],
        variable: json['variable'],
      );
}

/// 替换净化规则（对应 ReplaceRule.kt，裁剪）
class ReplaceRule {
  int? id;
  String name;
  String? group;
  String pattern; // 替换规则（正则或文本）
  String replacement;
  int order;
  bool enabled;
  bool regex; // 是否按正则处理
  String? scope; // 作用书源范围

  ReplaceRule({
    this.id,
    this.name = '',
    this.group,
    this.pattern = '',
    this.replacement = '',
    this.order = 0,
    this.enabled = true,
    this.regex = true,
    this.scope,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'pattern': pattern,
        'replacement': replacement,
        'order': order,
        'enabled': enabled,
        'regex': regex,
        'scope': scope,
      };

  factory ReplaceRule.fromJson(Map<String, dynamic> json) => ReplaceRule(
        id: json['id'],
        name: json['name'] ?? '',
        group: json['group'],
        pattern: json['pattern'] ?? '',
        replacement: json['replacement'] ?? '',
        order: json['order'] ?? 0,
        enabled: json['enabled'] ?? true,
        regex: json['regex'] ?? true,
        scope: json['scope'],
      );
}
