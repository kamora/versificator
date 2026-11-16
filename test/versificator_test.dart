import 'package:flutter_test/flutter_test.dart';
import 'package:versificator/versificator.dart';

void main() {
  Update? evaluate(Map<String, dynamic>? data, {String installed = '5.0.0', String? postponed}) =>
      Versificator.evaluate(data, installed, postponed);

  test('requires an update when the installed version is older than required', () {
    expect(evaluate({'required': '5.0.1', 'recommended': '5.2.0'}), (version: '5.0.1', required: true));
    expect(evaluate({'required': '5.1.0'}, installed: '5.0.9'), (version: '5.1.0', required: true));
    expect(evaluate({'required': '6.0.0'}, installed: '5.10.10'), (version: '6.0.0', required: true));
  });

  test('recommends an update when the installed version is older than recommended only', () {
    expect(evaluate({'required': '4.2.0', 'recommended': '5.1.0'}), (version: '5.1.0', required: false));
    expect(evaluate({'recommended': '5.0.10'}, installed: '5.0.9'), (version: '5.0.10', required: false));
  });

  test('asks for nothing when the installed version is current', () {
    expect(evaluate({'required': '5.0.0', 'recommended': '5.0.0'}), isNull);
    expect(evaluate({'required': '4.2.0', 'recommended': '4.2.0'}), isNull);
    expect(evaluate({}), isNull);
    expect(evaluate(null), isNull);
  });

  test('a postponed recommendation is offered again only for a later version', () {
    expect(evaluate({'recommended': '5.1.0'}, postponed: '5.1.0'), isNull);
    expect(evaluate({'recommended': '5.1.0'}, postponed: '5.2.0'), isNull);
    expect(evaluate({'recommended': '5.2.0'}, postponed: '5.1.0'), (version: '5.2.0', required: false));
    expect(evaluate({'recommended': '5.1.0'}, postponed: 'junk'), (version: '5.1.0', required: false));
  });

  test('a postponed version never holds back a required update', () {
    expect(evaluate({'required': '5.1.0', 'recommended': '5.1.0'}, postponed: '5.1.0'), (
      version: '5.1.0',
      required: true,
    ));
  });

  test('malformed fields ask for nothing', () {
    expect(evaluate({'required': 6, 'recommended': true}), isNull);
    expect(evaluate({'required': '6', 'recommended': '6.0'}), isNull);
    expect(evaluate({'required': '6.0.0.1', 'recommended': 'six'}), isNull);
    expect(evaluate({'required': 'x.y.z', 'recommended': '5.1.0'}), (version: '5.1.0', required: false));
    expect(evaluate({'required': '6.0.0'}, installed: 'dev'), isNull);
  });
}
