import 'dart:collection';

import 'package:charcode/charcode.dart';
import 'package:quiver/collection.dart';
import 'package:quiver/time.dart';
import 'package:timezone/timezone.dart';

final whitespaceRegEx = RegExp(r'\s+');

extension TzDateUtils on TZDateTime {
  TZDateTime copyWith({
    Location? location,
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
    bool? isUtc,
  }) {
    return TZDateTime(
      (isUtc ?? this.isUtc) ? UTC : location ?? this.location,
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
      millisecond ?? this.millisecond,
      microsecond ?? this.microsecond,
    );
  }
}

class CronExpression {
  static final lastRegEx = RegExp(r'^L(-[0-9]{1,2})?W?');
  static const int _serialVersionUID = 12423409423;

  static const int SECOND = 0;
  static const int MINUTE = 1;
  static const int HOUR = 2;
  static const int DAY_OF_MONTH = 3;
  static const int MONTH = 4;
  static const int DAY_OF_WEEK = 5;
  static const int YEAR = 6;
  static const int ALL_SPEC_INT = 99; // '*'
  static const int NO_SPEC_INT = 98; // '?'
  static const int ALL_SPEC = ALL_SPEC_INT;
  static const int NO_SPEC = NO_SPEC_INT;

  static final Map<String, int> monthMap = HashMap<String, int>.from({
    "JAN": 0,
    "FEB": 1,
    "MAR": 2,
    "APR": 3,
    "MAY": 4,
    "JUN": 5,
    "JUL": 6,
    "AUG": 7,
    "SEP": 8,
    "OCT": 9,
    "NOV": 10,
    "DEC": 11,
  });
  static final Map<String, int> dayMap = HashMap<String, int>.from({
    "SUN": 0,
    "MON": 1,
    "TUE": 2,
    "WED": 3,
    "THU": 4,
    "FRI": 5,
    "SAT": 6,
  });

  final String cronExpression;
  Location? timeZone;
  var seconds = TreeSet<int>();
  var minutes = TreeSet<int>();
  var hours = TreeSet<int>();
  var daysOfMonth = TreeSet<int>();
  var months = TreeSet<int>();
  var daysOfWeek = TreeSet<int>();
  var years = TreeSet<int>();

  bool lastdayOfWeek = false;
  int nthdayOfWeek = 0;
  bool lastdayOfMonth = false;
  bool nearestWeekday = false;
  int lastdayOffset = 0;
  bool expressionParsed = false;

  static final int MAX_YEAR = DateTime.now().year + 100;

  /**
     * Constructs a new <CODE>CronExpression</CODE> based on the specified 
     * parameter.
     * 
     * @param cronExpression String representation of the cron expression the
     *                       new object should represent
     * @throws java.text.ParseException
     *         if the string expression cannot be parsed into a valid 
     *         <CODE>CronExpression</CODE>
     */
  CronExpression(String cronExpression, {this.timeZone})
      : this.cronExpression = cronExpression.toUpperCase() {
    buildExpression(this.cronExpression);
  }

  /**
   * Constructs a new {@code CronExpression} as a copy of an existing
   * instance.
   * 
   * @param expression
   *            The existing cron expression to be copied
   */
  CronExpression.copy(CronExpression expression)
      : cronExpression = expression.cronExpression,
        timeZone = expression.timeZone {
    /*
        * We don't call the other constructor here since we need to swallow the
        * ParseException. We also elide some of the sanity checking as it is
        * not logically trippable.
        */
    try {
      buildExpression(cronExpression);
    } catch (ex) {
      throw AssertionError("Could not parse expression!");
    }
  }

  TZDateTime inputTime(TZDateTime date) {
    return TZDateTime.from(date, timeZone ?? local)
        .copyWith(millisecond: 0, microsecond: 0);
  }

  /**
     * Indicates whether the given date satisfies the cron expression. Note that
     * milliseconds are ignored, so two Dates falling on different milliseconds
     * of the same second will always have the same result here.
     * 
     * @param date the date to evaluate
     * @return a boolean indicating whether the given date satisfies the cron
     *         expression
     */
  bool isSatisfiedBy(TZDateTime date) {
    final testDateCal = inputTime(date);

    // TODO: Improve performance if just needing to check date
    TZDateTime? timeAfter = getTimeOrNext(testDateCal);

    return timeAfter == testDateCal;
  }

  /**
     * Returns the next date/time <I>after</I> the given date/time which
     * satisfies the cron expression.
     * 
     * @param date the date/time at which to begin the search for the next valid
     *             date/time
     * @return the next valid date/time
     */
  TZDateTime? getNextValidTimeAfter(TZDateTime date) {
    // add one second, since we're computing the time *after* the given time
    TZDateTime afterTime = inputTime(date).add(aSecond);
    return getTimeOrNext(afterTime);
  }

  /**
     * Returns the time zone for which this <code>CronExpression</code> 
     * will be resolved.
     */
  Location getTimeZone() {
    timeZone ??= local;

    return timeZone!;
  }

  /**
     * Sets the time zone for which  this <code>CronExpression</code> 
     * will be resolved.
     */
  void setTimeZone(Location timeZone) {
    this.timeZone = timeZone;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CronExpression &&
            other.runtimeType == runtimeType &&
            other.cronExpression == cronExpression &&
            other.timeZone == timeZone;
  }

  @override
  int get hashCode {
    return "$cronExpression|$timeZone".hashCode;
  }

  /**
     * Returns the string representation of the <CODE>CronExpression</CODE>
     * 
     * @return a string representation of the <CODE>CronExpression</CODE>
     */
  @override
  String toString() {
    return cronExpression;
  }

  /**
     * Indicates whether the specified cron expression can be parsed into a 
     * valid cron expression
     * 
     * @param cronExpression the expression to evaluate
     * @return a boolean indicating whether the given expression is a valid cron
     *         expression
     */
  static bool isValidExpression(String cronExpression) {
    try {
      CronExpression(cronExpression);
    } catch (pe) {
      return false;
    }

    return true;
  }

  static void validateExpression(String cronExpression) {
    CronExpression(cronExpression);
  }

  ////////////////////////////////////////////////////////////////////////////
  //
  // Expression Parsing Functions
  //
  ////////////////////////////////////////////////////////////////////////////

  void buildExpression(String expression) {
    expressionParsed = true;

    try {
      final exprsTok = expression.split(whitespaceRegEx);
      // If missing seconds or minutes, set to '0'
      final count = exprsTok.length;
      int exprOn = count > 5 ? SECOND : 6 - count;
      for (int i = 0; i < exprOn; i++) {
        storeExpressionVals(0, '0', i);
      }

      for (final e in exprsTok) {
        if (exprOn > YEAR) {
          break;
        }
        final expr = e.trim();

        // throw an exception if L is used with other days of the month
        if (exprOn == DAY_OF_MONTH &&
            expr.contains('L') &&
            expr.length > 1 &&
            expr.contains(",")) {
          throw FormatException(
              "Support for specifying 'L' and 'LW' with other days of the month is not implemented",
              expression,
              -1);
        }
        // throw an exception if L is used with other days of the week
        if (exprOn == DAY_OF_WEEK &&
            expr.contains('L') &&
            expr.length > 1 &&
            expr.contains(",")) {
          throw FormatException(
              "Support for specifying 'L' with other days of the week is not implemented",
              expression,
              -1);
        }
        if (exprOn == DAY_OF_WEEK &&
            expr.indexOf('#') != -1 &&
            expr.indexOf('#', expr.indexOf('#') + 1) != -1) {
          throw FormatException(
              "Support for specifying multiple \"nth\" days is not implemented.",
              expression,
              -1);
        }

        final vTok = expr.split(",");
        for (final v in vTok) {
          storeExpressionVals(0, v, exprOn);
        }

        exprOn++;
      }

      if (exprOn <= DAY_OF_WEEK) {
        throw FormatException(
            "Unexpected end of expression.", expression.length);
      }

      if (exprOn <= YEAR) {
        storeExpressionVals(0, "*", YEAR);
      }

      // Copying the logic from the UnsupportedOperationException below
      bool dayOfMSpec = !daysOfMonth.contains(NO_SPEC);
      bool dayOfWSpec = !daysOfWeek.contains(NO_SPEC);

      if (!dayOfMSpec || dayOfWSpec) {
        if (!dayOfWSpec || dayOfMSpec) {
          throw FormatException(
              "Support for specifying both a day-of-week AND a day-of-month parameter is not implemented.",
              expression,
              0);
        }
      }
    } catch (e) {
      switch (e) {
        case FormatException fe:
          throw fe;
        default:
          throw FormatException(
              "Illegal cron expression format ($e)", expression, 0);
      }
    }
  }

  int storeExpressionVals(int pos, String s, int type) {
    int incr = 0;
    int i = skipWhiteSpace(pos, s);
    if (i >= s.length) {
      return i;
    }
    var c = s[i];
    var char = c.codeUnitAt(0);

    switch (char) {
      // Parse Month or Day as 3 character string
      case >= $A && <= $Z when lastRegEx.firstMatch(s) == null:
        String sub = s.substring(i, i + 3);
        int sval = -1;
        int eval = -1;
        switch (type) {
          case MONTH:
            sval = getMonthNumber(sub) + 1;
            if (sval <= 0) {
              throw FormatException("Invalid Month value: '$sub'", s, i);
            }
            if (s.length > i + 3) {
              switch (s[i + 3]) {
                case '-':
                  i += 4;
                  sub = s.substring(i, i + 3);
                  eval = getMonthNumber(sub) + 1;
                  if (eval <= 0) {
                    throw FormatException("Invalid Month value: '$sub'", s, i);
                  }
              }
            }
          case DAY_OF_WEEK:
            sval = getDayOfWeekNumber(sub);
            if (sval < 0) {
              throw FormatException("Invalid Day-of-Week value: '$sub'", s, i);
            }
            if (s.length > i + 3) {
              switch (s[i + 3]) {
                case '-':
                  i += 4;
                  sub = s.substring(i, i + 3);
                  eval = getDayOfWeekNumber(sub);
                  if (eval < 0) {
                    throw FormatException(
                        "Invalid Day-of-Week value: '$sub'", s, i);
                  }
                case '#':
                  try {
                    i += 4;
                    nthdayOfWeek = int.parse(s.substring(i));
                    if (nthdayOfWeek < 1 || nthdayOfWeek > 5) {
                      throw Exception();
                    }
                  } catch (e) {
                    throw FormatException(
                        "A numeric value between 1 and 5 must follow the '#' option",
                        s,
                        i);
                  }
                case 'L':
                  lastdayOfWeek = true;
                  i++;
              }
            }
          default:
            throw FormatException(
                "Illegal characters for this position: '$sub'", s, i);
        }
        if (eval != -1) {
          incr = 1;
        }
        addToSet(sval, eval, incr, type);
        return (i + 3);
      case $question:
        i++;
        if ((i + 1) < s.length && (s[i] != ' ' && s[i + 1] != '\t')) {
          throw FormatException("Illegal character after '?': ${s[i]}", s, i);
        }
        if (type != DAY_OF_WEEK && type != DAY_OF_MONTH) {
          throw FormatException(
              "'?' can only be specified for Day-of-Month or Day-of-Week.",
              s,
              i);
        }
        if (type == DAY_OF_WEEK && !lastdayOfMonth) {
          int val = daysOfMonth.last;
          if (val == NO_SPEC_INT) {
            throw FormatException(
                "'?' can only be specified for Day-of-Month -OR- Day-of-Week.",
                s,
                i);
          }
        }

        addToSet(NO_SPEC_INT, -1, 0, type);
        return i;
      case $asterisk when (i + 1) >= s.length:
        addToSet(ALL_SPEC_INT, -1, incr, type);
        return i + 1;
      case $asterisk || $division:
        if (c == '*') {
          i++;
        }
        c = s[i];
        if (c == '/') {
          if ((i + 1) >= s.length || s[i + 1] == ' ' || s[i + 1] == '\t') {
            throw FormatException("'/' must be followed by an integer.", s, i);
          }
          // is an increment specified?
          i++;
          if (i >= s.length) {
            throw FormatException("Unexpected end of string.", s, i);
          }

          incr = getNumericValue(s, i);

          i++;
          if (incr > 10) {
            i++;
          }
          checkIncrementRange(incr, type, i);
        } else {
          incr = 1;
        }

        addToSet(ALL_SPEC_INT, -1, incr, type);
        return i;
      case $L:
        i++;
        switch (type) {
          case DAY_OF_WEEK:
            addToSet(7, 7, 0, type);
          case DAY_OF_MONTH:
            lastdayOfMonth = true;
            if (s.length > i) {
              c = s[i];
              if (c == '-') {
                ValueSet vs = getValue(0, s, i + 1);
                lastdayOffset = vs.value;
                if (lastdayOffset > 30) {
                  throw FormatException(
                      "Offset from last day must be <= 30", s, i + 1);
                }
                i = vs.pos;
              }
              if (s.length > i) {
                c = s[i];
                if (c == 'W') {
                  nearestWeekday = true;
                  i++;
                }
              }
            }
        }
        return i;
      case >= $0 && <= $9:
        int val = int.parse(c);
        i++;
        if (i >= s.length) {
          addToSet(val, -1, -1, type);
        } else {
          c = s[i];
          char = c.codeUnitAt(0);
          if (char >= $0 && char <= $9) {
            ValueSet vs = getValue(val, s, i);
            val = vs.value;
            i = vs.pos;
          }
          i = checkNext(i, s, val, type);
          return i;
        }
      default:
        throw FormatException("Unexpected character: $c", s, i);
    }

    return i;
  }

  // TODO: Allow larger increments but fallback to single value?
  void checkIncrementRange(int incr, int type, int idxPos) {
    // TODO: Check year against MAX_YEAR?
    if (type == YEAR) {
      return;
    }
    final max = getMax(type);
    if (incr > max) {
      throw FormatException("Increment > $max : $incr", incr, idxPos);
    }
  }

  int checkNext(int pos, String s, int val, int type) {
    int end = -1;
    int i = pos;

    if (i >= s.length) {
      addToSet(val, end, -1, type);
      return i;
    }

    var c = s[pos];
    var char = c.codeUnitAt(0);

    switch (c) {
      case 'L':
        if (type == DAY_OF_WEEK) {
          if (val < 0 || val > 7) {
            throw FormatException(
                "Day-of-Week values must be between 0 and 7", val, -1);
          }
          lastdayOfWeek = true;
        } else {
          throw FormatException("'L' option is not valid here. (pos=$i)", s, i);
        }
        TreeSet<int> set = getSet(type);
        set.add(val);
        i++;
        return i;
      case 'W':
        if (type == DAY_OF_MONTH) {
          nearestWeekday = true;
        } else {
          throw FormatException("'W' option is not valid here. (pos=$i)", s, i);
        }
        if (val > 31) {
          throw FormatException(
              "The 'W' option does not make sense with values larger than 31 (max number of days in a month)",
              val,
              i);
        }
        TreeSet<int> set = getSet(type);
        set.add(val);
        i++;
        return i;
      case '#':
        if (type != DAY_OF_WEEK) {
          throw FormatException("'#' option is not valid here. (pos=$i)", s, i);
        }
        i++;
        try {
          nthdayOfWeek = int.parse(s.substring(i));
          if (nthdayOfWeek < 1 || nthdayOfWeek > 5) {
            throw Exception();
          }
        } catch (e) {
          throw FormatException(
              "A numeric value between 1 and 5 must follow the '#' option",
              s,
              i);
        }

        TreeSet<int> set = getSet(type);
        set.add(val);
        i++;
        return i;
      case '-':
        i++;
        c = s[i];
        int v = int.parse(c);
        end = v;
        i++;
        if (i >= s.length) {
          addToSet(val, end, 1, type);
          return i;
        }
        c = s[i];
        char = c.codeUnitAt(0);
        if (char >= $0 && char <= $9) {
          ValueSet vs = getValue(v, s, i);
          end = vs.value;
          i = vs.pos;
        }
        if (i < s.length && ((c = s[i]) == '/')) {
          i++;
          c = s[i];
          int v2 = int.parse(c);
          i++;
          if (i >= s.length) {
            addToSet(val, end, v2, type);
            return i;
          }
          c = s[i];
          char = c.codeUnitAt(0);
          if (char >= $0 && char <= $9) {
            ValueSet vs = getValue(v2, s, i);
            int v3 = vs.value;
            addToSet(val, end, v3, type);
            i = vs.pos;
            return i;
          } else {
            addToSet(val, end, v2, type);
            return i;
          }
        } else {
          addToSet(val, end, 1, type);
          return i;
        }
      case '/':
        if ((i + 1) >= s.length || s[i + 1] == ' ' || s[i + 1] == '\t') {
          throw FormatException("'/' must be followed by an integer.", s, i);
        }

        i++;
        c = s[i];
        int v2 = int.parse(c);
        i++;
        if (i >= s.length) {
          checkIncrementRange(v2, type, i);
          addToSet(val, end, v2, type);
          return i;
        }
        c = s[i];
        char = c.codeUnitAt(0);
        if (char >= $0 && char <= $9) {
          ValueSet vs = getValue(v2, s, i);
          int v3 = vs.value;
          checkIncrementRange(v3, type, i);
          addToSet(val, end, v3, type);
          i = vs.pos;
          return i;
        } else {
          throw FormatException("Unexpected character '$c' after '/'", s, i);
        }
    }

    addToSet(val, end, 0, type);
    i++;
    return i;
  }

  int skipWhiteSpace(int i, String s) {
    for (; i < s.length && (s[i] == ' ' || s[i] == '\t'); i++) {}

    return i;
  }

  int findNextWhiteSpace(int i, String s) {
    for (; i < s.length && (s[i] != ' ' || s[i] != '\t'); i++) {}

    return i;
  }

  void addToSet(int val, int end, int incr, int type) {
    final set = getSet(type);
    final start = getStartAt(type);
    final stop = getStopAt(type);

    switch (type) {
      // check for year happens later
      case YEAR:
        break;
      case DAY_OF_MONTH:
      case DAY_OF_WEEK:
        if ((val < start || val > stop || end > stop) &&
            (val != ALL_SPEC_INT) &&
            (val != NO_SPEC_INT)) {
          throw FormatException(
              "${getName(type)} values must be between $start and $stop",
              val,
              -1);
        }
      default:
        if ((val < start || val > stop || end > stop) &&
            (val != ALL_SPEC_INT)) {
          throw FormatException(
              "${getName(type)} values must be between $start and $stop",
              val,
              -1);
        }
    }

    if ((incr == 0 || incr == -1) && val != ALL_SPEC_INT) {
      if (val != -1) {
        set.add(val);
      } else {
        set.add(NO_SPEC);
      }

      return;
    }

    int startAt = val;
    int stopAt = end;

    if (val == ALL_SPEC_INT && incr <= 0) {
      incr = 1;
      set.add(ALL_SPEC); // put in a marker, but also fill values
    }

    if (stopAt == -1) {
      stopAt = stop;
    }
    if (startAt == -1 || startAt == ALL_SPEC_INT) {
      startAt = start;
    }

    // if the end of the range is before the start, then we need to overflow into
    // the next day, month etc. This is done by adding the maximum amount for that
    // type, and using modulus max to determine the value being added.
    int max = -1;
    if (stopAt < startAt) {
      switch (type) {
        case YEAR:
          throw ArgumentError.value(
              val, 'val', "Start year must be less than stop year");
        default:
          max = getMax(type);
      }
      stopAt += max;
    }

    for (int i = startAt; i <= stopAt; i += incr) {
      if (max == -1) {
        // ie: there's no max to overflow over
        set.add(i);
      } else {
        // take the modulus to get the real value
        int i2 = i % max;

        // 1-indexed ranges should not include 0, and should include their max
        if (i2 == 0 &&
            (type == MONTH || type == DAY_OF_WEEK || type == DAY_OF_MONTH)) {
          i2 = max;
        }

        set.add(i2);
      }
    }
  }

  String getName(int type) {
    switch (type) {
      case SECOND:
        return 'Second';
      case MINUTE:
        return 'Minute';
      case HOUR:
        return 'Hour';
      case DAY_OF_MONTH:
        return 'Day of month';
      case MONTH:
        return 'Month';
      case DAY_OF_WEEK:
        return 'Day-of-Week';
      case YEAR:
        return 'Year';
      default:
        throw UnsupportedError("Unknown type: $type");
    }
  }

  int getStopAt(int type) {
    switch (type) {
      case HOUR:
        return 23;
      case DAY_OF_MONTH:
        return 31;
      case MONTH:
        return 12;
      case DAY_OF_WEEK:
        return 7;
      case YEAR:
        return MAX_YEAR;
      default:
        return 59;
    }
  }

  int getStartAt(int type) {
    switch (type) {
      case DAY_OF_MONTH || MONTH:
        return 1;
      case YEAR:
        return 1970;
      default:
        return 0;
    }
  }

  int getMax(int type) {
    switch (type) {
      case SECOND || MINUTE:
        return 60;
      case HOUR:
        return 24;
      case MONTH:
        return 12;
      case DAY_OF_WEEK:
        return 7;
      case DAY_OF_MONTH:
        return 31;
      default:
        throw ArgumentError.value(type, 'type', "Unexpected type encountered");
    }
  }

  TreeSet<int> getSet(int type) {
    switch (type) {
      case SECOND:
        return seconds;
      case MINUTE:
        return minutes;
      case HOUR:
        return hours;
      case DAY_OF_MONTH:
        return daysOfMonth;
      case MONTH:
        return months;
      case DAY_OF_WEEK:
        return daysOfWeek;
      case YEAR:
        return years;
      default:
        throw UnsupportedError("Unknown type: $type");
    }
  }

  ValueSet getValue(int v, String s, int i) {
    var c = s[i];
    var char = c.codeUnitAt(0);
    var s1 = StringBuffer(v);
    while (char >= $0 && char <= $9) {
      s1.write(c);
      i++;
      if (i >= s.length) {
        break;
      }
      c = s[i];
      char = c.codeUnitAt(0);
    }
    return ValueSet(
      pos: (i < s.length) ? i : i + 1,
      value: int.parse(s1.toString()),
    );
  }

  int getNumericValue(String s, int i) {
    int endOfVal = findNextWhiteSpace(i, s);
    String val = s.substring(i, endOfVal);
    return int.parse(val);
  }

  int getMonthNumber(String s) {
    return monthMap[s] ?? -1;
  }

  int getDayOfWeekNumber(String s) {
    return dayMap[s] ?? -1;
  }

  ////////////////////////////////////////////////////////////////////////////
  //
  // Computation Functions
  //
  ////////////////////////////////////////////////////////////////////////////

  TZDateTime? getTimeOrNext(TZDateTime dateTime) {
    // Computation is based on Gregorian year only.

    final cleanTime = inputTime(dateTime);
    // CronTrigger does not deal with milliseconds
    TZDateTime cl = cleanTime;

    bool gotOne = false;
    // loop until we've computed the next time, or we've past the endTime
    while (!gotOne) {
      //if (endTime != null && cl.getTime().after(endTime)) return null;
      if (cl.year > 2999) {
        // prevent endless loop...
        return null;
      }

      Iterable<int> st;
      int t = 0;

      int sec = cl.second;
      int min = cl.minute;

      // get second.................................................
      st = seconds.where((x) => x >= sec);
      if (st.isNotEmpty) {
        sec = st.first;
      } else {
        sec = seconds.first;
        min++;
        cl = cl.copyWith(minute: min);
      }
      cl = cl.copyWith(second: sec);

      min = cl.minute;
      int hr = cl.hour;
      t = -1;

      // get minute.................................................
      st = minutes.where((x) => x >= min);
      if (st.isNotEmpty) {
        t = min;
        min = st.first;
      } else {
        min = minutes.first;
        hr++;
      }
      if (min != t) {
        cl = cl.copyWith(second: 0, minute: min, hour: hr);
        continue;
      }
      cl = cl.copyWith(minute: min);

      hr = cl.hour;
      int day = cl.day;
      t = -1;

      // get hour...................................................
      st = hours.where((x) => x >= hr);
      if (st.isNotEmpty) {
        t = hr;
        hr = st.first;
      } else {
        hr = hours.first;
        day++;
      }
      if (hr != t) {
        cl = cl.copyWith(second: 0, minute: 0, hour: hr, day: day);
        continue;
      }
      cl = cl.copyWith(hour: hr);

      day = cl.day;
      int mon = cl.month;
      t = -1;
      int tmon = mon;

      // get day...................................................
      bool dayOfMSpec = !daysOfMonth.contains(NO_SPEC);
      bool dayOfWSpec = !daysOfWeek.contains(NO_SPEC);
      if (dayOfMSpec && !dayOfWSpec) {
        // get day by day of month rule
        st = daysOfMonth.where((x) => x >= day);
        if (lastdayOfMonth) {
          if (!nearestWeekday) {
            t = day;
            day = getLastDayOfMonth(mon, cl.year);
            day -= lastdayOffset;
            if (t > day) {
              mon++;
              if (mon > 12) {
                mon = 1;
                tmon = 3333; // ensure test of mon != tmon further below fails
                cl = cl.copyWith(year: cl.year + 1);
              }
              day = 1;
            }
          } else {
            t = day;
            day = getLastDayOfMonth(mon, cl.year);
            day -= lastdayOffset;

            TZDateTime tcal = cl.copyWith(
                second: 0,
                minute: 0,
                hour: 0,
                day: day,
                month: mon,
                year: cl.year);

            int ldom = getLastDayOfMonth(mon, cl.year);
            int dow = tcal.weekday;

            if (dow == DateTime.saturday && day == 1) {
              day += 2;
            } else if (dow == DateTime.saturday) {
              day -= 1;
            } else if (dow == DateTime.sunday && day == ldom) {
              day -= 2;
            } else if (dow == DateTime.sunday) {
              day += 1;
            }

            tcal = cl.copyWith(
                second: sec, minute: min, hour: hr, day: day, month: mon);
            if (tcal.isBefore(cleanTime)) {
              day = 1;
              mon++;
            }
          }
        } else if (nearestWeekday) {
          t = day;
          day = daysOfMonth.first;

          TZDateTime tcal = cl.copyWith(
              second: 0,
              minute: 0,
              hour: 0,
              day: day,
              month: mon,
              year: cl.year);

          int ldom = getLastDayOfMonth(mon, cl.year);
          int dow = tcal.weekday;

          if (dow == DateTime.saturday && day == 1) {
            day += 2;
          } else if (dow == DateTime.saturday) {
            day -= 1;
          } else if (dow == DateTime.sunday && day == ldom) {
            day -= 2;
          } else if (dow == DateTime.sunday) {
            day += 1;
          }

          tcal = cl.copyWith(
              second: sec, minute: min, hour: hr, day: day, month: mon);
          if (tcal.isBefore(cleanTime)) {
            day = daysOfMonth.first;
            mon++;
          }
        } else if (st.isNotEmpty) {
          t = day;
          day = st.first;
          // make sure we don't over-run a short month, such as february
          int lastDay = getLastDayOfMonth(mon, cl.year);
          if (day > lastDay) {
            day = daysOfMonth.first;
            mon++;
          }
        } else {
          day = daysOfMonth.first;
          mon++;
        }

        if (day != t || mon != tmon) {
          cl = cl.copyWith(second: 0, minute: 0, hour: 0, day: day, month: mon);
          continue;
        }
      } else if (dayOfWSpec && !dayOfMSpec) {
        // get day by day of week rule
        if (lastdayOfWeek) {
          // are we looking for the last XXX day of
          // the month?
          int dow = daysOfWeek.first; // desired
          // d-o-w
          int cDow = cl.weekday; // current d-o-w
          int daysToAdd = 0;
          if (cDow < dow) {
            daysToAdd = dow - cDow;
          }
          if (cDow > dow) {
            daysToAdd = dow + (7 - cDow);
          }

          int lDay = getLastDayOfMonth(mon, cl.year);

          if (day + daysToAdd > lDay) {
            // did we already miss the
            // last one?
            cl = cl.copyWith(
                second: 0, minute: 0, hour: 0, day: 1, month: mon + 1);
            // +1 here because we are promoting the month
            continue;
          }

          // find date of last occurrence of this day in this month...
          while ((day + daysToAdd + 7) <= lDay) {
            daysToAdd += 7;
          }

          day += daysToAdd;

          if (daysToAdd > 0) {
            cl = cl.copyWith(
                second: 0, minute: 0, hour: 0, day: day, month: mon);
            continue;
          }
        } else if (nthdayOfWeek != 0) {
          // are we looking for the Nth XXX day in the month?
          int dow = daysOfWeek.first; // desired
          // d-o-w
          int cDow = cl.weekday; // current d-o-w
          int daysToAdd = 0;
          if (cDow < dow) {
            daysToAdd = dow - cDow;
          } else if (cDow > dow) {
            daysToAdd = dow + (7 - cDow);
          }

          bool dayShifted = false;
          if (daysToAdd > 0) {
            dayShifted = true;
          }

          day += daysToAdd;
          int weekOfMonth = (day / 7).floor();
          if (day % 7 > 0) {
            weekOfMonth++;
          }

          daysToAdd = (nthdayOfWeek - weekOfMonth) * 7;
          day += daysToAdd;
          if (daysToAdd < 0 || day > getLastDayOfMonth(mon, cl.year)) {
            cl = cl.copyWith(
                second: 0, minute: 0, hour: 0, day: 1, month: mon + 1);
            // +1 here because we are promoting the month
            continue;
          } else if (daysToAdd > 0 || dayShifted) {
            cl = cl.copyWith(
                second: 0, minute: 0, hour: 0, day: day, month: mon);
            continue;
          }
        } else {
          int cDow = cl.weekday; // current d-o-w
          int dow = daysOfWeek.first; // desired
          // d-o-w
          st = daysOfWeek.where((x) => x >= cDow);
          if (st.isNotEmpty) {
            dow = st.first;
          }

          int daysToAdd = 0;
          if (cDow < dow) {
            daysToAdd = dow - cDow;
          }
          if (cDow > dow) {
            daysToAdd = dow + (7 - cDow);
          }

          int lDay = getLastDayOfMonth(mon, cl.year);

          if (day + daysToAdd > lDay) {
            // will we pass the end of
            // the month?
            cl = cl.copyWith(
                second: 0, minute: 0, hour: 0, day: 1, month: mon + 1);
            // +1 here because we are promoting the month
            continue;
          } else if (daysToAdd > 0) {
            // are we swithing days?
            cl = cl.copyWith(
                second: 0,
                minute: 0,
                hour: 0,
                day: day + daysToAdd,
                month: mon);
            continue;
          }
        }
      } else {
        // dayOfWSpec && !dayOfMSpec
        throw UnimplementedError(
            "Support for specifying both a day-of-week AND a day-of-month parameter is not implemented.");
      }
      cl = cl.copyWith(day: day);

      mon = cl.month;
      int year = cl.year;
      t = -1;

      // test for expressions that never generate a valid fire date,
      // but keep looping...
      if (year > MAX_YEAR) {
        return null;
      }

      // get month...................................................
      st = months.where((x) => x >= mon);
      if (st.isNotEmpty) {
        t = mon;
        mon = st.first;
      } else {
        mon = months.first;
        year++;
      }
      if (mon != t) {
        cl = cl.copyWith(
            second: 0, minute: 0, hour: 0, day: 1, month: mon, year: year);
        continue;
      }
      cl = cl.copyWith(month: mon);

      year = cl.year;
      t = -1;

      // get year...................................................
      st = years.where((x) => x >= year);
      if (st.isNotEmpty) {
        t = year;
        year = st.first;
      } else {
        return null; // ran out of years...
      }

      if (year != t) {
        cl = cl.copyWith(
            second: 0, minute: 0, hour: 0, day: 1, month: 1, year: year);
        continue;
      }
      cl = cl.copyWith(year: year);

      gotOne = true;
    } // while( !done )

    return cl;
  }

  int getLastDayOfMonth(int month, int year) {
    return daysInMonth(year, month);
  }
}

class ValueSet {
  const ValueSet({
    required this.value,
    required this.pos,
  });

  final int value;
  final int pos;
}
