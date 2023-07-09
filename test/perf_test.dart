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
final hour = list.take(24);
final month = list.skip(1).take(12);
final monStr = month.map((e) => monthMap[e]);
final dom = list.skip(1).take(31);
final dow = list.take(8);
final dowStr = dow.map((e) => dayMap[e]);

final strings = [
  "${list.join(",")} ${list.join(",")} ${hour.join(",")} ${dom.join(",")} ${month.join(",")} ?",
  "${list.join(",")} ${list.join(",")} ${hour.join(",")} ? ${month.join(",")} ${dow.join(",")}",
  "${list.altjoin()} ${list.altjoin()} ${hour.altjoin()} ${dom.altjoin()} ${month.altjoin()} ?",
  "${list.altjoin()} ${list.altjoin()} ${hour.altjoin()} ? ${month.altjoin()} ${dow.altjoin()}",
  // Strings:
  "${list.join(",")} ${list.join(",")} ${hour.join(",")} ${dom.join(",")} ${monStr.join(",")} ?",
  "${list.join(",")} ${list.join(",")} ${hour.join(",")} ? ${monStr.join(",")} ${dowStr.join(",")}",
  "${list.altjoin()} ${list.altjoin()} ${hour.altjoin()} ${dom.altjoin()} ${monStr.altjoin()} ?",
  "${list.altjoin()} ${list.altjoin()} ${hour.altjoin()} ? ${monStr.altjoin()} ${dowStr.altjoin()}",
  // TODO: Multiple L?
  // "${list.join(",")} ${list.join(",")} ${hour.join(",")} ${dom.ljoin(",")} ${month.join(",")} ?",
  // "${list.join(",")} ${list.join(",")} ${hour.join(",")} ? ${month.join(",")} ${dow.ljoin(",", true)}",
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
