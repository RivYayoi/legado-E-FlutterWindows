/// 规则引擎：对应 AnalyzeRule.kt + AnalyzeByJSoup.kt + AnalyzeByJSon.kt 的核心子集
/// 支持：JSoup 默认选择器(class./id./tag./text./索引/attr)、@CSS:、JSON($./@JSON:)、
/// @js:、{{js}}、&& 拼接、|| 备选、%% 交错、## 正则替换、@get/@put 变量
library;

import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:json_path/json_path.dart';

import '../data/entities/book.dart';
import '../data/entities/rules.dart';
import 'js_engine.dart';

/// 规则上下文数据
class RuleContext {
  Book? book;
  BookChapter? chapter;
  String? variableMap;
  Map<String, String> jsVariables = {};
}

class AnalyzeRule {
  dynamic body; // String / dom.Element / json(dynamic)
  String baseUrl;
  BookSource? source;
  final RuleContext context;
  final Map<String, String> _putVars = {};

  AnalyzeRule(this.body, {required this.baseUrl, this.source, RuleContext? ctx})
      : context = ctx ?? RuleContext();

  // ---------- 对外 API ----------

  /// 获取元素列表（书单/目录列表）
  Future<List<dynamic>> getElements(String ruleStr) async {
    if (ruleStr.trim().isEmpty) return [];
    final branches = _splitTop(ruleStr, '%%');
    if (branches.length > 1) {
      final result = <dynamic>[];
      for (final b in branches) {
        final elems = await _getElementsSingle(b.trim());
        result.addAll(elems);
      }
      return result;
    }
    return _getElementsSingle(ruleStr.trim());
  }

  Future<List<dynamic>> _getElementsSingle(String rule) async {
    // || 备选
    final alternatives = _splitTop(rule, '||');
    for (final alt in alternatives) {
      final r = alt.trim();
      if (r.isEmpty) continue;
      // && 拆分仅针对 jsoup 多选择器场景，元素级先按整体处理
      final elems = await _elementsByRule(r);
      if (elems.isNotEmpty) return elems;
    }
    return [];
  }

  Future<List<dynamic>> _elementsByRule(String rule) async {
    // js 规则
    if (rule.startsWith('@js:')) {
      final code = rule.substring(4);
      final result = await _evalJs(code);
      return _jsonToList(result);
    }
    // {{js}}
    final jsMatch = RegExp(r'^\{\{(.+)\}\}$', dotAll: true).firstMatch(rule);
    if (jsMatch != null) {
      final result = await _evalJs(jsMatch.group(1)!);
      return _jsonToList(result);
    }
    // JSON
    if (rule.startsWith(r'$.') || rule.startsWith('@JSON:')) {
      final jsonRule = rule.startsWith('@JSON:')
          ? rule.substring(7)
          : rule;
      return _jsonElementsByRule(jsonRule);
    }
    // CSS 显式
    if (rule.startsWith('@CSS:')) {
      return _cssElements(rule.substring(5));
    }
    // XPath 显式 / 隐式 —— 桌面版暂不支持，报错提示
    if (rule.startsWith('@XPath:') || rule.startsWith('@XPath') ||
        rule.startsWith('//')) {
      throw RuleException('暂不支持 XPath 规则: $rule');
    }
    // && 拆分（jsoup 支持多选择器拼接）
    final andParts = _splitTop(rule, '&&');
    if (andParts.length > 1) {
      final result = <dynamic>[];
      for (final p in andParts) {
        result.addAll(await _elementsByRule(p.trim()));
      }
      return result;
    }
    // 默认 JSoup
    return _jsoupElementsByRule(rule);
  }

  /// 获取字符串（书名/作者/正文等）
  Future<String> getString(String ruleStr) async {
    final result = await _getStringInternal(ruleStr, firstOnly: true);
    return result;
  }

  /// 获取字符串列表
  Future<List<String>> getStringList(String ruleStr) async {
    final result = await _getStringInternal(ruleStr, firstOnly: false);
    if (result.isEmpty) return [];
    // 尝试 json 数组解析
    if (result.startsWith('[')) {
      try {
        final arr = jsonDecode(result);
        if (arr is List) return arr.map((e) => e?.toString() ?? '').toList();
      } catch (_) {}
    }
    return result.split('\n').where((s) => s.trim().isNotEmpty).toList();
  }

  Future<String> _getStringInternal(String ruleStr,
      {bool firstOnly = false}) async {
    if (ruleStr.trim().isEmpty) return '';
    String rule = ruleStr.trim();

    // ## 正则后处理
    String? regexPattern, regexReplacement;
    final hashParts = _splitRuleReplace(rule);
    if (hashParts.length >= 2) {
      rule = hashParts[0].trim();
      regexPattern = hashParts[1];
      regexReplacement = hashParts.length > 2 ? hashParts[2] : '';
    }

    String result = '';
    Future<String> evalSingle(String r) async {
      r = r.trim();
      if (r.isEmpty) return '';
      // @get:{key}
      final getMatch =
          RegExp(r'^@get:\{(.+?)\}$').firstMatch(r);
      if (getMatch != null) {
        return _putVars[getMatch.group(1)!] ?? '';
      }
      // @js:
      if (r.startsWith('@js:')) {
        return _evalJs(r.substring(4));
      }
      // {{js}}
      final jsMatch = RegExp(r'^\{\{(.+)\}\}$', dotAll: true).firstMatch(r);
      if (jsMatch != null) {
        return _evalJs(jsMatch.group(1)!);
      }
      // 字符串常量
      if (r.startsWith('"') && r.endsWith('"')) {
        return r.substring(1, r.length - 1);
      }
      if (r.startsWith('\'') && r.endsWith('\'')) {
        return r.substring(1, r.length - 1);
      }
      // 规则求值
      final val = await _valueByRule(r);
      return _toStr(val);
    }

    Future<String> evalBranches(String r) async {
      // || 备选
      final alts = _splitTop(r, '||');
      for (final alt in alts) {
        final s = await evalSingle(alt.trim());
        if (s.trim().isNotEmpty) return s;
      }
      return '';
    }

    // %% 交错合并
    final inter = _splitTop(rule, '%%');
    if (inter.length > 1) {
      final lists = <List<String>>[];
      for (final b in inter) {
        // && 拼接
        final andParts = _splitTop(b.trim(), '&&');
        final buf = <String>[];
        for (final p in andParts) {
          final s = await evalSingle(p.trim());
          buf.add(s);
        }
        final joined = buf.where((s) => s.isNotEmpty).join('\n');
        lists.add(joined.isEmpty ? [] : joined.split('\n'));
      }
      final maxLen = lists.map((l) => l.length).fold(0, (a, b) => a > b ? a : b);
      final lines = <String>[];
      for (var i = 0; i < maxLen; i++) {
        for (final l in lists) {
          if (i < l.length) lines.add(l[i]);
        }
      }
      result = lines.join('\n');
    } else {
      // && 拼接
      final andParts = _splitTop(rule, '&&');
      if (andParts.length > 1) {
        final buf = <String>[];
        for (final p in andParts) {
          final s = await evalSingle(p.trim());
          if (s.isNotEmpty) buf.add(s);
        }
        result = buf.join('\n');
      } else {
        result = await evalBranches(rule);
      }
    }

    // @put:{key:rule}
    final putMatch =
        RegExp(r'@put:\{(.+?):(.+?)\}$', dotAll: true).firstMatch(rule);
    if (putMatch != null) {
      final v = await evalSingle(putMatch.group(2)!);
      _putVars[putMatch.group(1)!] = v;
    }

    // 正则后处理
    if (regexPattern != null) {
      result = _regexReplace(result, regexPattern, regexReplacement ?? '');
    }
    return result;
  }

  // ---------- 分发求值 ----------

  Future<dynamic> _valueByRule(String rule) async {
    if (rule.startsWith(r'$.') || rule.startsWith('@JSON:')) {
      final jsonRule = rule.startsWith('@JSON:') ? rule.substring(7) : rule;
      return _jsonValue(jsonRule);
    }
    if (rule.startsWith('@CSS:')) {
      return _cssValue(rule.substring(5));
    }
    if (rule.startsWith('@XPath:') || rule.startsWith('//')) {
      throw RuleException('暂不支持 XPath 规则: $rule');
    }
    return _jsoupValue(rule);
  }

  // ---------- JSoup 实现 ----------

  dom.Element? _asElement() {
    if (body is dom.Element) return body as dom.Element;
    if (body is dom.Document) return (body as dom.Document).documentElement;
    if (body is String) {
      return html_parser.parse(body as String).documentElement;
    }
    return null;
  }

  Future<List<dynamic>> _jsoupElementsByRule(String rule) async {
    final root = _asElement();
    if (root == null) return [];
    final analyzer = _JsoupSelector(rule);
    var elements = <dom.Element>[root];
    for (final step in analyzer.steps) {
      if (elements.isEmpty) return [];
      final next = <dom.Element>[];
      if (step.isAttr) {
        // attr 步骤终止链，后续 attr 由取值阶段处理
        break;
      }
      for (final el in elements) {
        next.addAll(_selectElements(el, step));
      }
      elements = next;
    }
    return elements;
  }

  List<dom.Element> _selectElements(
      dom.Element root, _SelectorStep step) {
    List<dom.Element> found;
    switch (step.type) {
      case 'class':
        found = root.querySelectorAll('.${step.value}');
        break;
      case 'id':
        found = root.querySelectorAll('#${step.value}');
        break;
      case 'tag':
        found = root.querySelectorAll(step.value);
        break;
      case 'text':
        final needle = step.value;
        found = root.querySelectorAll('*')
            .where((e) => e.text.contains(needle))
            .toList();
        break;
      default:
        found = [];
    }
    // 索引
    if (step.index != null) {
      final idx = step.index!;
      final pos = idx < 0 ? found.length + idx : idx;
      if (pos < 0 || pos >= found.length) return [];
      found = [found[pos]];
    }
    // 排除自身包含结果（query 全局会重复父元素）——保持简单
    return found;
  }

  Future<dynamic> _jsoupValue(String rule) async {
    final root = _asElement();
    if (root == null) return '';
    final analyzer = _JsoupSelector(rule);
    var elements = <dom.Element>[root];
    String? attr;
    for (final step in analyzer.steps) {
      if (step.isAttr) {
        attr = step.value;
        break;
      }
      final next = <dom.Element>[];
      for (final el in elements) {
        next.addAll(_selectElements(el, step));
      }
      elements = next;
    }
    if (elements.isEmpty) return '';
    if (elements.length == 1 && elements.first == root && attr == null) {
      return '';
    }
    if (attr == null) {
      return elements.map((e) => e.text.trim()).join('\n');
    }
    final vals = elements.map((e) => _extractAttr(e, attr!)).toList();
    final vals1 = vals.where((v) => v.isNotEmpty).toList();
    if (attr == 'text' || attr == 'html' || attr == 'all' || attr == 'textNodes') {
      return vals.join('\n');
    }
    return vals1.isEmpty ? '' : vals1.first;
  }

  String _extractAttr(dom.Element e, String attr) {
    switch (attr) {
      case 'text':
        return e.text.trim();
      case 'ownText':
        return e.nodes
            .whereType<dom.Text>()
            .map((t) => t.text.trim())
            .where((t) => t.isNotEmpty)
            .join(' ');
      case 'textNodes':
        return e.nodes
            .whereType<dom.Text>()
            .map((t) => t.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n');
      case 'html':
      case 'innerHtml':
        return e.innerHtml;
      case 'all':
      case 'outerHtml':
        return e.outerHtml;
      case 'children':
        return e.children.map((c) => c.outerHtml).join('\n');
      case 'href':
      case 'src':
      case 'content':
        final v = e.attributes[attr];
        return v == null ? '' : _absUrl(baseUrl, v);
      default:
        return e.attributes[attr] ?? '';
    }
  }

  List<dynamic> _cssElements(String rule) {
    // @CSS:selector@attr
    final parts = _splitCssRule(rule);
    final root = _asElement();
    if (root == null) return [];
    var found = root.querySelectorAll(parts.selector);
    if (parts.index != null) {
      final idx = parts.index!;
      final pos = idx < 0 ? found.length + idx : idx;
      found = (pos >= 0 && pos < found.length) ? [found[pos]] : [];
    }
    return found;
  }

  Future<dynamic> _cssValue(String rule) async {
    final parts = _splitCssRule(rule);
    final elements = _cssElements(rule);
    if (elements.isEmpty) return '';
    final attr = parts.attr ?? 'text';
    return elements.map((e) => _extractAttr(e, attr)).join('\n');
  }

  // ---------- JSON 实现 ----------

  dynamic _jsonRoot() {
    if (body is String) {
      final s = (body as String).trim();
      return jsonDecode(s);
    }
    return body;
  }

  List<dynamic> _jsonToList(String result) {
    final s = result.trim();
    if (s.isEmpty) return [];
    try {
      final v = jsonDecode(s);
      if (v is List) return v;
      if (v is Map) {
        // 尝试取数组字段
        for (final e in v.values) {
          if (e is List && e.isNotEmpty) return e;
        }
        return [v];
      }
    } catch (_) {}
    return [s];
  }

  Future<List<dynamic>> _jsonElementsByRule(String rule) async {
    final root = _jsonRoot();
    try {
      final path = JsonPath(_fixJsonPath(rule));
      final matches = path.read(root).toList();
      return matches.map((m) => m.value).toList();
    } catch (e) {
      throw RuleException('JSON 规则错误: $rule ($e)');
    }
  }

  Future<dynamic> _jsonValue(String rule) async {
    final root = _jsonRoot();
    try {
      final path = JsonPath(_fixJsonPath(rule));
      final matches = path.read(root).toList();
      if (matches.isEmpty) return '';
      if (matches.length == 1) return matches.first.value;
      return matches.map((m) => _toStr(m.value)).join('\n');
    } catch (e) {
      throw RuleException('JSON 规则错误: $rule ($e)');
    }
  }

  String _fixJsonPath(String rule) {
    var r = rule;
    // @get:{key} 替换
    r = r.replaceAllMapped(RegExp(r'@get:\{(.+?)\}'),
        (m) => _putVars[m.group(1)!] ?? '');
    return r;
  }

  // ---------- JS ----------

  Future<String> _evalJs(String code) async {
    // 预置变量
    final vars = <String, dynamic>{
      'baseUrl': baseUrl,
      'result': body is String ? body : _toStr(body),
      if (source != null) 'source': source!.toJson(),
      if (context.book != null) 'book': context.book!.toJson(),
      if (context.chapter != null) 'chapter': context.chapter!.toJson(),
      ...context.jsVariables,
      ..._putVars,
    };
    return JsEngine.instance.evalJs(code, variables: vars);
  }

  // ---------- 工具 ----------

  /// 顶层分割（忽略引号与括号内）
  static List<String> _splitTop(String rule, String sep) {
    final parts = <String>[];
    var depth = 0;
    var inQuote = '';
    final buf = StringBuffer();
    for (var i = 0; i < rule.length; i++) {
      final ch = rule[i];
      if (inQuote.isNotEmpty) {
        buf.write(ch);
        if (ch == inQuote) inQuote = '';
        continue;
      }
      if (ch == '"' || ch == '\'') {
        inQuote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '(' || ch == '[' || ch == '{') depth++;
      if (ch == ')' || ch == ']' || ch == '}') depth--;
      if (depth == 0 && rule.startsWith(sep, i)) {
        parts.add(buf.toString());
        buf.clear();
        i += sep.length - 1;
        continue;
      }
      buf.write(ch);
    }
    parts.add(buf.toString());
    return parts;
  }

  /// ## 正则替换规则分割
  static List<String> _splitRuleReplace(String rule) {
    // 找到 ##（非转义）
    final idx = _findRuleReplacePos(rule);
    if (idx < 0) return [rule];
    final rest = rule.substring(idx + 2);
    final secondIdx = _findRuleReplacePos(rest, allowFirst: true);
    if (secondIdx < 0) return [rule.substring(0, idx), rest];
    return [
      rule.substring(0, idx),
      rest.substring(0, secondIdx),
      rest.substring(secondIdx + 2)
    ];
  }

  static int _findRuleReplacePos(String rule, {bool allowFirst = false}) {
    var depth = 0;
    var inQuote = '';
    for (var i = 0; i < rule.length; i++) {
      final ch = rule[i];
      if (inQuote.isNotEmpty) {
        if (ch == inQuote) inQuote = '';
        continue;
      }
      if (ch == '"' || ch == '\'') {
        inQuote = ch;
        continue;
      }
      if (ch == '\\') {
        i++;
        continue;
      }
      if (ch == '{') depth++;
      if (ch == '}') depth--;
      if (depth == 0 && rule.startsWith('##', i)) {
        return i;
      }
    }
    return -1;
  }

  static String _regexReplace(String input, String pattern, String replacement) {
    try {
      final re = RegExp(pattern, multiLine: true);
      final rep = replacement
          .replaceAll(r'$$', r'$')
          .replaceAllMapped(RegExp(r'\$(\d+)'), (m) => '\$${m.group(1)}');
      return input.replaceAllMapped(re, (m) {
        var r = rep;
        for (var i = 1; i <= m.groupCount; i++) {
          r = r.replaceAll('\$$i', m.group(i) ?? '');
        }
        return r;
      });
    } catch (_) {
      return input;
    }
  }

  static String _toStr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    if (v is List || v is Map) return jsonEncode(v);
    return v.toString();
  }

  static String _absUrl(String baseUrl, String url) {
    final u = url.trim();
    if (u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('data:')) {
      return u;
    }
    try {
      return Uri.parse(baseUrl).resolve(u).toString();
    } catch (_) {
      return u;
    }
  }
}

/// CSS 规则解析结果
class _CssParts {
  final String selector;
  final String? attr;
  final int? index;
  _CssParts(this.selector, this.attr, this.index);
}

_CssParts _splitCssRule(String rule) {
  var r = rule;
  int? index;
  // 尾部索引 [n]
  final idxMatch = RegExp(r'\[(-?\d+)\]$').firstMatch(r);
  if (idxMatch != null) {
    index = int.tryParse(idxMatch.group(1)!);
    r = r.substring(0, idxMatch.start);
  }
  // 最后一个 @ 为 attr 分隔（避免 url 中的 @ 误判：简化处理）
  final atIdx = r.lastIndexOf('@');
  if (atIdx > 0) {
    final attr = r.substring(atIdx + 1).trim();
    if (_isAttrToken(attr)) {
      return _CssParts(r.substring(0, atIdx).trim(), attr, index);
    }
  }
  return _CssParts(r.trim(), null, index);
}

bool _isAttrToken(String s) {
  const tokens = {
    'text', 'ownText', 'textNodes', 'html', 'all', 'children', 'innerHtml',
    'outerHtml', 'href', 'src', 'content', 'title', 'alt', 'value', 'id',
    'class', 'data-src', 'data-original', 'target'
  };
  return tokens.contains(s) || s.startsWith('attr.');
}

/// JSoup 默认选择器解析：如 class.bookbox@tag.h3@tag.a@text
class _JsoupSelector {
  final List<_SelectorStep> steps;
  _JsoupSelector(String rule) : steps = _parse(rule);

  static List<_SelectorStep> _parse(String rule) {
    final steps = <_SelectorStep>[];
    // 以 @ 分割，首个片段可能以 . 分割出 type.value
    final segs = _splitJsoup(rule);
    for (final seg in segs) {
      final s = seg.trim();
      if (s.isEmpty) continue;
      if (s.startsWith('!') && RegExp(r'^!\d+$').hasMatch(s)) {
        // !0 = 最后一个
        steps.add(_SelectorStep(
            'index', '', -(int.parse(s.substring(1)) + 1)));
        continue;
      }
      // attr token?
      if (_isAttrToken(s) || s.startsWith('attr.')) {
        final attr = s.startsWith('attr.') ? s.substring(5) : s;
        steps.add(_SelectorStep.attr(attr));
        continue;
      }
      // class./id./tag./text. 前缀
      final m = RegExp(r'^(class|id|tag|text)\.(.+)$', dotAll: true).firstMatch(s);
      if (m != null) {
        var value = m.group(2)!;
        int? index;
        // 尾部 .N 索引
        final idxMatch = RegExp(r'\.(-?\d+)$').firstMatch(value);
        if (idxMatch != null &&
            value.substring(idxMatch.start + 1).isNotEmpty &&
            _looksIndex(value.substring(idxMatch.start + 1))) {
          index = int.tryParse(idxMatch.group(1)!);
          value = value.substring(0, idxMatch.start);
        }
        steps.add(_SelectorStep(m.group(1)!, value, index));
        continue;
      }
      // 纯索引
      if (RegExp(r'^-?\d+$').hasMatch(s)) {
        final n = int.parse(s);
        steps.add(_SelectorStep(
            'index', '', n < 0 ? n : n));
        continue;
      }
      // 其他当 tag
      steps.add(_SelectorStep('tag', s, null));
    }
    return steps;
  }

  static bool _looksIndex(String s) => RegExp(r'^\d+$').hasMatch(s);

  static List<String> _splitJsoup(String rule) {
    // 规则本身不该包含引号，直接 @ 分割
    return rule.split('@');
  }
}

class _SelectorStep {
  final String type; // class/id/tag/text/index/attr
  final String value;
  final int? index;
  final bool isAttr;
  _SelectorStep(this.type, this.value, this.index) : isAttr = type == 'index';
  _SelectorStep.attr(this.value)
      : type = 'attr',
        index = null,
        isAttr = true;
}

class RuleException implements Exception {
  final String message;
  RuleException(this.message);
  @override
  String toString() => message;
}

/// 便捷函数：解析 HTML
dom.Document parseHtml(String html) => html_parser.parse(html);
