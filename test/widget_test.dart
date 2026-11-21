import 'package:flutter_test/flutter_test.dart';

import 'package:legado_windows/data/entities/rules.dart';

void main() {
  test('BookSource fromJson/toJson roundtrip', () {
    final json = {
      'bookSourceUrl': 'https://example.com',
      'bookSourceName': '测试书源',
      'bookSourceGroup': '测试',
      'enabled': true,
      'searchUrl': 'https://example.com/search?q={{key}}',
      'ruleSearch': {
        'bookList': 'class.result',
        'name': 'tag.h3@text',
        'bookUrl': 'tag.a@href',
      },
    };
    final source = BookSource.fromJson(json);
    expect(source.bookSourceName, '测试书源');
    expect(source.searchUrl, 'https://example.com/search?q={{key}}');
    expect(source.searchRule.bookList, 'class.result');
    expect(source.searchRule.name, 'tag.h3@text');
    final out = source.toJson();
    expect(out['searchUrl'], source.searchUrl);
    final again = BookSource.fromJson(out);
    expect(again.bookSourceUrl, source.bookSourceUrl);
  });
}
