import 'package:qz_cron/qz_cron.dart';

final Map<int, String> monthMap = {
  1: "JAN",
  2: "FEB",
  3: "MAR",
  4: "APR",
  5: "MAY",
  6: "JUN",
  7: "JUL",
  8: "AUG",
  9: "SEP",
  10: "OCT",
  11: "NOV",
  12: "DEC",
};
final Map<int, String> dayMap = {
  0: "SUN",
  1: "MON",
  2: "TUE",
  3: "WED",
  4: "THU",
  5: "FRI",
  6: "SAT",
  7: "SUN",
};

final list = List.generate(60, (index) => index);
final strings = [
  "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ${list.skip(1).take(31).join(",")} ${list.skip(1).take(12).join(",")} ?",
  "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ? ${list.skip(1).take(12).join(",")} ${list.take(8).join(",")}",
  "${list.altjoin()} ${list.altjoin()} ${list.take(24).altjoin()} ${list.skip(1).take(31).altjoin()} ${list.skip(1).take(12).altjoin()} ?",
  "${list.altjoin()} ${list.altjoin()} ${list.take(24).altjoin()} ? ${list.skip(1).take(12).altjoin()} ${list.take(8).altjoin()}",
  // Strings:
  "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ${list.skip(1).take(31).join(",")} ${list.skip(1).take(12).map((e) => monthMap[e]).join(",")} ?",
  "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ? ${list.skip(1).take(12).map((e) => monthMap[e]).join(",")} ${list.take(8).map((e) => dayMap[e]).join(",")}",
  "${list.altjoin()} ${list.altjoin()} ${list.take(24).altjoin()} ${list.skip(1).take(31).altjoin()} ${list.skip(1).take(12).map((e) => monthMap[e]).altjoin()} ?",
  "${list.altjoin()} ${list.altjoin()} ${list.take(24).altjoin()} ? ${list.skip(1).take(12).map((e) => monthMap[e]).altjoin()} ${list.take(8).map((e) => dayMap[e]).altjoin()}",
  // TODO: Multiple L?
  // "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ${list.skip(1).take(31).ljoin(",")} ${list.skip(1).take(12).join(",")} ?",
  // "${list.join(",")} ${list.join(",")} ${list.take(24).join(",")} ? ${list.skip(1).take(12).join(",")} ${list.take(8).ljoin(",", true)}",
];

extension IntAltJoin<T> on Iterable<T> {
  String altjoin() {
    var result = "";
    var index = 0;
    for (var element in this) {
      result = index++ == 0
          ? "$element"
          : index % 2 == 0
              ? "$result-$element"
              : "$result,$element";
    }
    return result;
  }

  String ljoin([String separator = "", bool dow = false]) {
    String getString(Iterator<T> iterator) {
      final current = iterator.current;
      return dow ? "${current}L" : "L-${current}";
    }

    Iterator<T> iterator = this.iterator;
    if (!iterator.moveNext()) return "";
    var first = getString(iterator);
    if (!iterator.moveNext()) return first;
    var buffer = StringBuffer(first);
    if (separator.isEmpty) {
      do {
        buffer.write(getString(iterator));
      } while (iterator.moveNext());
    } else {
      do {
        buffer
          ..write(separator)
          ..write(getString(iterator));
      } while (iterator.moveNext());
    }
    return buffer.toString();
  }
}

void main() {
  CronExpression("* * ?");
  for (final str in strings) {
    test(str);
  }
}

int test(String str) {
  print(str);
  final watch = Stopwatch();
  for (var i = 0; i < 1000; i++) {
    watch.start();
    CronExpression(str);
    watch.stop();
  }
  final micros = watch.elapsedMicroseconds;
  print("Elapsed Microseconds: $micros");
  return micros;
}
