/// JS 引擎桥接：flutter_js (QuickJS) + java.* 对象桥
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:sync_http/sync_http.dart';

/// JS 执行上下文变量（put/get）
final Map<String, String> _jsVariables = {};

typedef BridgeFn = dynamic Function(List<dynamic> params);

class JsEngine {
  static JsEngine? _instance;
  static JsEngine get instance => _instance ??= JsEngine._();

  JavascriptRuntime? _runtime;
  final Map<String, BridgeFn> _functions = {};

  JsEngine._();

  JavascriptRuntime get runtime {
    if (_runtime == null) {
      _runtime = getJavascriptRuntime();
      _setupBridge();
    }
    return _runtime!;
  }

  void registerFunction(String name, BridgeFn fn) {
    _functions[name] = fn;
  }

  void _setupBridge() {
    runtime.onMessage('javaBridge', (args) {
      try {
        final map =
            args is Map ? args.cast<String, dynamic>() : <String, dynamic>{};
        final fn = map['fn'] as String?;
        final params = (map['params'] as List?)?.cast<dynamic>() ?? [];
        final f = _functions[fn];
        if (f == null) return 'Error: unknown fn $fn';
        final result = f(params);
        if (result == null) return '';
        if (result is String) return result;
        return jsonEncode(result);
      } catch (e) {
        return 'Error: $e';
      }
    });
    runtime.evaluate(_bridgeJs);
  }

  static const _bridgeJs = '''
  (function(global){
    function call(fn, params){
      var payload = JSON.stringify({fn: fn, params: params || []});
      return sendMessage('javaBridge', payload);
    }
    var java = {
      put: function(key, value){ return call('put', [String(key), String(value)]); },
      get: function(key){ return call('get', [String(key)]); },
      ajax: function(url){ return call('ajax', [String(url)]); },
      ajaxAll: function(urls){ return call('ajaxAll', [urls]); },
      getVariable: function(key){ return call('getVariable', [String(key)]); },
      setVariable: function(key, value){ return call('setVariable', [String(key), String(value)]); },
      encodeURI: function(str){ return encodeURIComponent(String(str)); },
      decodeURI: function(str){ return decodeURIComponent(String(str)); },
      encode: function(str){ return encodeURIComponent(String(str)); },
      decode: function(str){ return decodeURIComponent(String(str)); },
      base64Encode: function(str){ return call('base64Encode', [String(str)]); },
      base64Decode: function(str){ return call('base64Decode', [String(str)]); },
      md5Encode: function(str){ return call('md5Encode', [String(str)]); },
      timeFormat: function(time){
        var t = Number(time); var d = new Date(isNaN(t) ? Date.now() : t);
        var p = function(n){ return n < 10 ? '0' + n : '' + n; };
        return d.getFullYear() + '-' + p(d.getMonth()+1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
      },
      timeFormatUnix: function(){ return Math.floor(Date.now()/1000); },
      join: function(arr, sep){
        if (Array.isArray(arr)) return arr.map(String).join(sep === undefined ? ',' : sep);
        return String(arr);
      },
      random: function(min, max){ return Math.floor(Math.random()*(max-min+1))+min; },
      toUtf8: function(str){ return String(str); }
    };
    global.java = java;
    global.cookie = { get: function(k){ return call('get', ['cookie_'+k]); }, set: function(k,v){ call('put', ['cookie_'+k, String(v)]); } };
    global.cache = { get: function(k){ return call('get', ['cache_'+k]); }, put: function(k,v){ call('put', ['cache_'+k, String(v)]); } };
    global.cacheFile = global.cache;
  })(globalThis);
  ''';

  /// 执行 JS 代码片段，返回字符串结果
  Future<String> evalJs(String code, {Map<String, dynamic>? variables}) async {
    final rt = runtime;
    final buf = StringBuffer();
    buf.writeln('var result;');
    variables?.forEach((k, v) {
      final encoded = jsonEncode(v);
      buf.writeln('try { var $k = $encoded; } catch(e) { var $k = null; }');
    });
    buf.writeln('result = (function(){ $code })();');
    buf.writeln(
        '(typeof result === "object" && result !== null) ? JSON.stringify(result) : String(result === undefined || result === null ? "" : result)');
    final res = await rt.evaluateAsync(buf.toString());
    rt.executePendingJob();
    if (res.isError) {
      throw JsEvalException(res.stringResult);
    }
    return res.stringResult;
  }

  static void clearVariables() => _jsVariables.clear();
  static String? getVariable(String key) => _jsVariables[key];
  static void putVariable(String key, String value) =>
      _jsVariables[key] = value;
}

class JsEvalException implements Exception {
  final String message;
  JsEvalException(this.message);
  @override
  String toString() => 'JsEvalException: $message';
}

/// 同步 HTTP（供 JS 桥同步 ajax 使用）
String syncHttpGet(String url, {Map<String, String>? headers}) {
  try {
    final req = SyncHttpClient.getUrl(Uri.parse(url));
    headers?.forEach((k, v) => req.headers.add(k, v));
    final res = req.close();
    return res.body ?? '';
  } catch (e) {
    return 'Error: $e';
  }
}
