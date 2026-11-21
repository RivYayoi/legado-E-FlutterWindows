/// HTTP 服务：dio + 字符集处理
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';

import '../engine/analyze_url.dart';

class HttpService {
  static final HttpService instance = HttpService._();

  late final Dio dio;

  HttpService._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (s) => s != null && s < 400 || s == 404,
    ));
    dio.interceptors.add(LogInterceptor(responseBody: false, request: false));
  }

  /// 请求并返回解码后的文本
  Future<String> requestText(AnalyzedRequest req) async {
    final res = await requestRaw(req);
    return decodeBody(res, req.option.charset);
  }

  Future<Response<List<int>>> requestRaw(AnalyzedRequest req) async {
    final method = req.option.method;
    final data = method == 'POST' || method == 'PUT' ? req.option.body : null;
    final res = await dio.request<List<int>>(
      req.url,
      data: data,
      options: Options(
        method: method,
        headers: req.option.headers,
        responseType: ResponseType.bytes,
      ),
    );
    return res;
  }

  static String decodeBody(Response<List<int>> res, String? charset) {
    final bytes = res.data ?? <int>[];
    if (bytes.isEmpty) return '';
    final cs =
        (charset ?? _detectCharset(bytes, res) ?? 'utf-8').trim().toLowerCase();
    try {
      switch (cs) {
        case 'gbk':
        case 'gb2312':
        case 'gb18030':
          return gbk.decode(bytes);
        case 'utf-8':
        case 'utf8':
          return utf8.decode(bytes, allowMalformed: true);
        case 'big5':
          return gbk.decode(bytes); // big5 简化处理
        default:
          return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String? _detectCharset(List<int> bytes, Response res) {
    // 从 content-type
    final ct = res.headers.value('content-type');
    if (ct != null) {
      final m = RegExp(r'charset=([\w-]+)').firstMatch(ct);
      if (m != null) return m.group(1);
    }
    // 从 html meta
    final head = utf8.decode(bytes.take(2048).toList(), allowMalformed: true);
    final m = RegExp(
            r'<meta[^>]+charset\s*=\s*["' ']?\s*([\w-]+)',
            caseSensitive: false)
        .firstMatch(head);
    return m?.group(1);
  }
}
