/// AnalyzeUrl：URL 规则解析（对应 AnalyzeUrl.kt 的核心子集）
/// 支持格式：
///   url,{"method":"POST","body":"...","headers":{...},"charset":"gbk","type":"..."}
///   变量：{{key}} / {{page}} / {{searchKey}} / searchKey / searchPage / {{js}}
library;

import 'dart:convert';

import 'js_engine.dart';

class UrlOption {
  String method = 'GET';
  String? body;
  Map<String, String> headers = {};
  String? charset;
  String? type; // 内容类型提示
  int? retry;
  String? webView;

  Map<String, dynamic> toJson() => {
        'method': method,
        if (body != null) 'body': body,
        if (headers.isNotEmpty) 'headers': headers,
        if (charset != null) 'charset': charset,
        if (type != null) 'type': type,
      };
}

class AnalyzedRequest {
  final String url;
  final UrlOption option;
  AnalyzedRequest(this.url, this.option);
}

class AnalyzeUrl {
  final String ruleStr;
  final Map<String, dynamic> params; // key/page 等运行参数
  final String? baseUrl;
  final String? sourceHeader;

  AnalyzeUrl(this.ruleStr,
      {Map<String, dynamic>? params, this.baseUrl, this.sourceHeader})
      : params = params ?? {};

  /// 解析出最终请求
  Future<AnalyzedRequest> analyze() async {
    var rule = ruleStr.trim();
    if (rule.isEmpty) throw ArgumentError('url rule is empty');

    // @js:
    if (rule.startsWith('@js:')) {
      final result = await _evalJs(rule.substring(4));
      final s = result.trim();
      if (s.startsWith('http')) {
        rule = s;
      } else {
        final json = jsonDecode(s);
        if (json is Map) {
          final url = json['url']?.toString() ?? '';
          final opt = _parseOption(json);
          return AnalyzedRequest(_fillParamsLegacy(url), opt);
        }
        rule = s;
      }
    }
    return _buildFrom(await _fillParamsAsync(rule));
  }

  int _findOptionSplit(String rule) {
    // 找顶层逗号后跟 { 的位置
    var depth = 0;
    var inQuote = '';
    for (var i = 0; i < rule.length; i++) {
      final ch = rule[i];
      if (inQuote.isNotEmpty) {
        if (ch == inQuote && (i == 0 || rule[i - 1] != '\\')) inQuote = '';
        continue;
      }
      if (ch == '"' || ch == '\'') {
        inQuote = ch;
        continue;
      }
      if (ch == '{' || ch == '[' || ch == '(') depth++;
      if (ch == '}' || ch == ']' || ch == ')') depth--;
      if (depth == 0 && ch == ',' && i + 1 < rule.length) {
        var j = i + 1;
        while (j < rule.length && (rule[j] == ' ' || rule[j] == '\n')) {
          j++;
        }
        if (j < rule.length && rule[j] == '{') return i;
      }
    }
    return -1;
  }

  UrlOption _parseOption(Map<dynamic, dynamic> json) {
    final opt = UrlOption();
    opt.method = (json['method']?.toString() ?? 'GET').toUpperCase();
    opt.body = json['body']?.toString();
    opt.charset = json['charset']?.toString();
    opt.type = json['type']?.toString();
    opt.retry = json['retry'] is int ? json['retry'] as int : null;
    final headers = json['headers'];
    if (headers is Map) {
      headers.forEach((k, v) => opt.headers[k.toString()] = v?.toString() ?? '');
    } else if (headers is String && headers.trim().startsWith('{')) {
      try {
        final h = jsonDecode(headers);
        if (h is Map) h.forEach((k, v) => opt.headers[k.toString()] = v?.toString() ?? '');
      } catch (_) {}
    }
    if (opt.body != null && opt.method == 'POST') {
      opt.headers.putIfAbsent(
          'Content-Type', () => 'application/x-www-form-urlencoded');
    }
    return opt;
  }

  Future<String> _evalJs(String code) async {
    final vars = <String, dynamic>{
      ...params,
      'key': params['key'] ?? '',
      'page': params['page'] ?? 1,
      'searchKey': params['key'] ?? '',
      'searchPage': params['page'] ?? 1,
      if (baseUrl != null) 'baseUrl': baseUrl,
    };
    return JsEngine.instance.evalJs(code, variables: vars);
  }

  /// 先求值所有 {{js}}（异步），再返回最终请求 —— 供外部统一 await
  Future<AnalyzedRequest> build() async {
    var rule = ruleStr.trim();
    if (rule.startsWith('@js:')) {
      // 在 analyze() 中处理
      return analyze();
    }
    // 预填充 {{...}}
    final filled = await _fillParamsAsync(rule);
    return _buildFrom(filled);
  }

  Future<String> _fillParamsAsync(String input) async {
    if (!input.contains('{{')) return _fillParamsLegacy(input);
    final matches =
        RegExp(r'\{\{(.+?)\}\}', dotAll: true).allMatches(input).toList();
    if (matches.isEmpty) return _fillParamsLegacy(input);
    var result = input;
    for (final m in matches.reversed) {
      final expr = m.group(1)!.trim();
      String val;
      if (RegExp(r'^[a-zA-Z_]\w*$').hasMatch(expr) &&
          (params.containsKey(expr) || expr == 'key' || expr == 'page')) {
        val = _paramValue(expr);
      } else {
        val = await _evalJs(expr);
      }
      result = result.substring(0, m.start) + val + result.substring(m.end);
    }
    return _fillParamsLegacy(result);
  }

  String _paramValue(String name) {
    switch (name) {
      case 'key':
      case 'searchKey':
        return params['key']?.toString() ?? '';
      case 'page':
      case 'searchPage':
        return params['page']?.toString() ?? '1';
      default:
        return params[name]?.toString() ?? '';
    }
  }

  String _fillParamsLegacy(String input) {
    return input
        .replaceAll('searchPage', params['page']?.toString() ?? '1')
        .replaceAll('searchKey', params['key']?.toString() ?? '')
        .replaceAll('{{key}}', params['key']?.toString() ?? '')
        .replaceAll('{{page}}', params['page']?.toString() ?? '1');
  }

  Future<AnalyzedRequest> _buildFrom(String filledRule) async {
    String url = filledRule;
    UrlOption option = UrlOption();
    final splitIdx = _findOptionSplit(filledRule);
    if (splitIdx > 0) {
      url = filledRule.substring(0, splitIdx).trim();
      final optStr = filledRule.substring(splitIdx + 1).trim();
      try {
        final json = jsonDecode(optStr);
        if (json is Map) {
          option = _parseOption(json);
          // body 中的变量也要填充
          if (option.body != null) {
            option.body = await _fillParamsAsync(option.body!);
          }
        }
      } catch (_) {
        url = filledRule;
      }
    }
    if (sourceHeader != null && sourceHeader!.trim().isNotEmpty) {
      try {
        final json = jsonDecode(sourceHeader!);
        if (json is Map) {
          final defaults =
              json.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
          final headers = <String, String>{...defaults};
          headers.removeWhere((k, _) => option.headers.containsKey(k));
          option.headers = {...headers, ...option.headers};
        }
      } catch (_) {
        option.headers.putIfAbsent('User-Agent', () => sourceHeader!);
      }
    }
    option.headers.putIfAbsent(
        'User-Agent',
        () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
    // url 绝对化
    if (baseUrl != null &&
        !url.startsWith('http://') &&
        !url.startsWith('https://')) {
      try {
        url = Uri.parse(baseUrl!).resolve(url).toString();
      } catch (_) {}
    }
    return AnalyzedRequest(url, option);
  }
}
