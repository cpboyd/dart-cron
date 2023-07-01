import 'package:qz_cron/qz_cron.dart';
import 'package:test/test.dart';

import 'feature_matcher.dart';

/// A matcher that matches the cron expressions.
Matcher cronEquals(CronExpression expected) => _CronEqualsMatcher(expected);

/// A special equality matcher for cron expressions.
class _CronEqualsMatcher extends FeatureMatcher<CronExpression> {
  final CronExpression _value;

  const _CronEqualsMatcher(this._value);

  @override
  bool typedMatches(CronExpression item, Map matchState) => _value == item;

  @override
  Description describe(Description description) =>
      description.addDescriptionOf(_value.cronExpression);

  @override
  Description describeTypedMismatch(CronExpression item,
      Description mismatchDescription, Map matchState, bool verbose) {
    var buff = StringBuffer();
    buff.write('is different.');
    var escapedItem = escape(item.toString());
    var escapedValue = escape(_value.toString());
    var minLength = escapedItem.length < escapedValue.length
        ? escapedItem.length
        : escapedValue.length;
    var start = 0;
    for (; start < minLength; start++) {
      if (escapedValue.codeUnitAt(start) != escapedItem.codeUnitAt(start)) {
        break;
      }
    }
    if (start == minLength) {
      if (escapedValue.length < escapedItem.length) {
        buff.write(' Both strings start the same, but the actual value also'
            ' has the following trailing characters: ');
        _writeTrailing(buff, escapedItem, escapedValue.length);
      } else {
        buff.write(' Both strings start the same, but the actual value is'
            ' missing the following trailing characters: ');
        _writeTrailing(buff, escapedValue, escapedItem.length);
      }
    } else {
      buff.write('\nExpected: ');
      _writeLeading(buff, escapedValue, start);
      _writeTrailing(buff, escapedValue, start);
      buff.write('\n  Actual: ');
      _writeLeading(buff, escapedItem, start);
      _writeTrailing(buff, escapedItem, start);
      buff.write('\n          ');
      for (var i = start > 10 ? 14 : start; i > 0; i--) {
        buff.write(' ');
      }
      buff.write('^\n Differ at offset $start');
    }

    return mismatchDescription.add(buff.toString());
  }

  static void _writeLeading(StringBuffer buff, String s, int start) {
    if (start > 10) {
      buff.write('... ');
      buff.write(s.substring(start - 10, start));
    } else {
      buff.write(s.substring(0, start));
    }
  }

  static void _writeTrailing(StringBuffer buff, String s, int start) {
    if (start + 10 > s.length) {
      buff.write(s.substring(start));
    } else {
      buff.write(s.substring(start, start + 10));
      buff.write(' ...');
    }
  }
}
