import 'package:qz_cron/qz_cron.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tz;

import 'cron_equals_matcher.dart';

/**
 * Get the Quartz versions for which we should verify
 * serialization backwards compatibility.
 */
final VERSIONS = ["1.5.2"];

void main() {
  group('Quartz tests:', () {
    tz.initializeTimeZones();
    final EST_TIME_ZONE = getLocation("US/Eastern");
    final tzNow = TZDateTime.now(local);
    /**
     * Get the object to serialize when generating serialized file for future
     * tests, and against which to validate deserialized object.
     */
    Object getTargetObject() {
      CronExpression cronExpression = CronExpression("0 15 10 * * ? 2005");
      cronExpression.setTimeZone(EST_TIME_ZONE);

      return cronExpression;
    }

    final cronExpression = getTargetObject();

    setUp(() {
      // Additional setup goes here.
    });

    /*
      * Test method for 'org.quartz.CronExpression.isSatisfiedBy(Date)'.
      */
    test('Test isSatisfiedBy(Date)', () {
      final cronExpression = CronExpression("0 15 10 * * ? 2005");

      var cal = TZDateTime.local(2005, DateTime.june, 1, 10, 15, 0);
      expect(cronExpression.isSatisfiedBy(cal), isTrue);

      cal = cal.copyWith(year: 2006);
      expect(cronExpression.isSatisfiedBy(cal), isFalse);

      cal = TZDateTime.local(2005, DateTime.june, 1, 10, 16, 0);
      expect(cronExpression.isSatisfiedBy(cal), isFalse);

      cal = TZDateTime.local(2005, DateTime.june, 1, 10, 14, 0);
      expect(cronExpression.isSatisfiedBy(cal), isFalse);
    });

    test('Test LastDayOffset', () {
      var cronExpression = CronExpression("0 15 10 L-2 * ? 2010");

      var cal = TZDateTime.local(
          2010, DateTime.october, 29, 10, 15, 0); // last day - 2
      expect(cronExpression.isSatisfiedBy(cal), isTrue);

      cal = TZDateTime.local(2010, DateTime.october, 28, 10, 15, 0);
      expect(cronExpression.isSatisfiedBy(cal), isFalse);

      cronExpression = CronExpression("0 15 10 L-5W * ? 2010");

      cal = TZDateTime.local(
          2010, DateTime.october, 26, 10, 15, 0); // last day - 5
      expect(cronExpression.isSatisfiedBy(cal), isTrue);

      cronExpression = CronExpression("0 15 10 L-1 * ? 2010");

      cal = TZDateTime.local(
          2010, DateTime.october, 30, 10, 15, 0); // last day - 1
      expect(cronExpression.isSatisfiedBy(cal), isTrue);

      cronExpression = CronExpression("0 15 10 L-1W * ? 2010");

      cal = TZDateTime.local(2010, DateTime.october, 29, 10, 15,
          0); // nearest weekday to last day - 1 (29th is a friday in 2010)
      expect(cronExpression.isSatisfiedBy(cal), isTrue);
    });

    /*
    * QUARTZ-571: Showing that expressions with months correctly serialize.
    */
    // test('Test QUARTZ-571', () {
    //   final cronExpression = CronExpression("19 15 10 4 Apr ? ");

    //   final baos = new ByteArrayOutputStream();
    //   final oos = new ObjectOutputStream(baos);
    //   oos.writeObject(cronExpression);
    //   final bais = new ByteArrayInputStream(baos.toByteArray());
    //   final ois = new ObjectInputStream(bais);
    //   final newExpression = (CronExpression) ois.readObject();

    //   expect(newExpression, cronEquals(cronExpression));

    //   // if broken, this will throw an exception
    //   newExpression.getNextValidTimeAfter(tzNow);
    // });

/**
 * QTZ-259 : last day offset causes repeating fire time
 */
    test('Test QTZ-259', () {
      final cronExpression = CronExpression("0 0 0 L-2 * ? *");

      int i = 0;
      var pdate = cronExpression.getNextValidTimeAfter(tzNow);
      while (++i < 26) {
        final date = cronExpression.getNextValidTimeAfter(pdate!);
        print("fireTime: $date, previousFireTime: $pdate");
        expect(date, isNot(equals(pdate)),
            reason: "Next fire time is the same as previous fire time!");
        pdate = date;
      }
    });

/**
 * QTZ-259 : last day offset causes repeating fire time
 * 
 */
    test('Test QTZ-259LW', () {
      final cronExpression = CronExpression("0 0 0 LW * ? *");

      int i = 0;
      var pdate = cronExpression.getNextValidTimeAfter(tzNow);
      while (++i < 26) {
        final date = cronExpression.getNextValidTimeAfter(pdate!);
        print("fireTime: $date, previousFireTime: $pdate");
        expect(date, isNot(equals(pdate)),
            reason: "Next fire time is the same as previous fire time!");
        pdate = date;
      }
    });

/*
  * QUARTZ-574: Showing that storeExpressionVals correctly calculates the month number
  */
    test('Test QUARTZ-574', () {
      try {
        CronExpression("* * * * Foo ? ");
        fail("Expected ParseException did not fire for non-existent month");
      } on FormatException catch (pe) {
        expect(pe.message.startsWith("Invalid Month value:"), isTrue,
            reason: "Incorrect ParseException thrown");
      }

      try {
        CronExpression("* * * * Jan-Foo ? ");
        fail("Expected ParseException did not fire for non-existent month");
      } on FormatException catch (pe) {
        expect(pe.message.startsWith("Invalid Month value:"), isTrue,
            reason: "Incorrect ParseException thrown");
      }
    });

    test('Test QUARTZ-621', () {
      try {
        CronExpression("0 0 * * * *");
        fail(
            "Expected ParseException did not fire for wildcard day-of-month and day-of-week");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying both a day-of-week AND a day-of-month parameter is not implemented."),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
      try {
        CronExpression("0 0 * 4 * *");
        fail(
            "Expected ParseException did not fire for specified day-of-month and wildcard day-of-week");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying both a day-of-week AND a day-of-month parameter is not implemented."),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
      try {
        CronExpression("0 0 * * * 4");
        fail(
            "Expected ParseException did not fire for wildcard day-of-month and specified day-of-week");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying both a day-of-week AND a day-of-month parameter is not implemented."),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
    });

    test('Test QUARTZ-640', () {
      try {
        CronExpression("0 43 9 1,5,29,L * ?");
        fail(
            "Expected ParseException did not fire for L combined with other days of the month");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying 'L' and 'LW' with other days of the month is not implemented"),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
      try {
        CronExpression("0 43 9 ? * SAT,SUN,L");
        fail(
            "Expected ParseException did not fire for L combined with other days of the week");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying 'L' with other days of the week is not implemented"),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
      try {
        CronExpression("0 43 9 ? * 6,7,L");
        fail(
            "Expected ParseException did not fire for L combined with other days of the week");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "Support for specifying 'L' with other days of the week is not implemented"),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
      try {
        CronExpression("0 43 9 ? * 5L");
      } on FormatException catch (pe) {
        fail("Unexpected ParseException thrown for supported '5L' expression.");
      }
    });

    test('Test QUARTZ-96', () {
      try {
        CronExpression("0/5 * * 32W 1 ?");
        fail(
            "Expected ParseException did not fire for W with value larger than 31");
      } on FormatException catch (pe) {
        expect(
            pe.message.startsWith(
                "The 'W' option does not make sense with values larger than"),
            isTrue,
            reason: "Incorrect ParseException thrown");
      }
    });

    test('Test QUARTZ-395 CopyConstructorMustPreserveTimeZone', () {
      var nonDefault = getLocation("Europe/Brussels");
      if (nonDefault == local) {
        nonDefault = EST_TIME_ZONE;
      }
      final cronExpression = CronExpression("0 15 10 * * ? 2005");
      cronExpression.setTimeZone(nonDefault);

      final copyCronExpression = CronExpression.copy(cronExpression);
      expect(copyCronExpression.getTimeZone(), equals(nonDefault));
    });

// Issue #58
    test('Test #58 SecRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("/120 0 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 60 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0/120 0 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 60 : 120"));
      }

      // Test case 3
      try {
        CronExpression("/ 0 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0/ 0 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });

// Issue #58
    test('Test #58 MinRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("0 /120 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 60 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0 0/120 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 60 : 120"));
      }

      // Test case 3
      try {
        CronExpression("0 / 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0 0/ 8-18 ? * 2-6");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });

// Issue #58
    test('Test #58 HourRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("0 0 /120 ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 24 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0 0 0/120 ? * 2-6");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 24 : 120"));
      }

      // Test case 3
      try {
        CronExpression("0 0 / ? * 2-6");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0 0 0/ ? * 2-6");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });

// Issue #58
    test('Test #58 DayOfMonthRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("0 0 0 /120 * 2-6");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 31 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0 0 0 0/120 * 2-6");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 31 : 120"));
      }

      // Test case 3
      try {
        CronExpression("0 0 0 / * 2-6");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0 0 0 0/ * 2-6");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });

// Issue #58
    test('Test #58 MonthRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("0 0 0 ? /120 2-6");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 12 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0 0 0 ? 0/120 2-6");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 12 : 120"));
      }

      // Test case 3
      try {
        CronExpression("0 0 0 ? / 2-6");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0 0 0 ? 0/ 2-6");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });

// Issue #58
    test('Test #58 DayOfWeekRangeIntervalAfterSlash', () {
      // Test case 1
      try {
        CronExpression("0 0 0 ? * /120");
        fail("Cron did not validate bad range interval in '_blank/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 7 : 120"));
      }

      // Test case 2
      try {
        CronExpression("0 0 0 ? * 0/120");
        fail("Cron did not validate bad range interval in in '0/xxx' form");
      } on FormatException catch (e) {
        expect(e.message, equals("Increment > 7 : 120"));
      }

      // Test case 3
      try {
        CronExpression("0 0 0 ? * /");
        fail("Cron did not validate bad range interval in '_blank/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }

      // Test case 4
      try {
        CronExpression("0 0 0 ? * 0/");
        fail("Cron did not validate bad range interval in '0/_blank'");
      } on FormatException catch (e) {
        expect(e.message, equals("'/' must be followed by an integer."));
      }
    });
  });
}
