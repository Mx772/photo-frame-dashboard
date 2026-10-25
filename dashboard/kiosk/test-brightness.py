#!/usr/bin/env python3
"""Run the actual brightness schedule parser against table cases.

Requires Python 3 and a JDK on PATH. No Android device, SDK or third-party packages.
This checks the schedule logic only, not how Android applies window brightness.
"""
from pathlib import Path
import subprocess
import tempfile


SOURCE = Path(__file__).resolve().parent / "src/com/wesbos/homehq/MainActivity.java"
text = SOURCE.read_text(encoding="utf-8")
start = text.index("  // BEGIN brightness schedule")
end = text.index("  // END brightness schedule", start)
methods = text[start:end]

HARNESS = r'''
package com.wesbos.homehq;
import java.util.Arrays;

public class BrightnessHarness {
__METHODS__

  static int failures;

  static void at(String name, String schedule, int h, int m, int expected) {
    int got = brightnessAt(schedule, h * 60 + m);
    report(name + " @" + h + ":" + m, got == expected, "expected " + expected + ", got " + got);
  }

  static void invalid(String name, String schedule) {
    boolean bad = !validBrightnessSchedule(schedule) && brightnessAt(schedule, 720) == -1;
    report("invalid: " + name, bad, "accepted \"" + schedule + "\"");
  }

  static void valid(String name, String schedule) {
    report("valid: " + name, validBrightnessSchedule(schedule), "rejected \"" + schedule + "\"");
  }

  static void report(String name, boolean ok, String why) {
    if (ok) System.out.println("PASS " + name);
    else { System.out.println("FAIL " + name + " (" + why + ")"); failures++; }
  }

  public static void main(String[] args) {
    at("single entry", "07:00=40", 3, 0, 40);
    at("single entry", "07:00=40", 7, 0, 40);
    at("single entry", "07:00=40", 23, 59, 40);
    String two = "07:00=100,22:00=10";
    at("two, before first (wraps to last)", two, 6, 59, 10);
    at("two, at first", two, 7, 0, 100);
    at("two, between", two, 12, 30, 100);
    at("two, at second", two, 22, 0, 10);
    at("two, after last", two, 23, 59, 10);
    at("midnight wrap", two, 0, 0, 10);
    String unsorted = "22:00=10,07:00=100,13:00=60";
    at("unsorted, morning", unsorted, 8, 0, 100);
    at("unsorted, afternoon", unsorted, 13, 0, 60);
    at("unsorted, night", unsorted, 22, 30, 10);
    at("unsorted, wrap", unsorted, 5, 0, 10);
    String spaced = "  7:00 = 100 , 22:00= 10  ";
    at("whitespace", spaced, 8, 0, 100);
    at("whitespace", spaced, 23, 0, 10);
    at("1-digit hour", "7:30=55,9:05=20", 8, 0, 55);
    at("1-digit hour", "7:30=55,9:05=20", 9, 5, 20);
    at("boundary 00:00 and P=1", "00:00=1,23:59=100", 0, 0, 1);
    at("boundary 23:59 and P=100", "00:00=1,23:59=100", 23, 59, 100);
    at("boundary just before 23:59", "00:00=1,23:59=100", 23, 58, 1);

    at("empty is -1", "", 12, 0, -1);
    at("off is -1", "off", 12, 0, -1);
    at("null is -1", null, 12, 0, -1);
    valid("two entries", two);
    valid("whitespace", spaced);
    invalid("empty", "");
    invalid("off", "off");
    invalid("null", null);
    invalid("empty entry", "07:00=100,,22:00=10");
    invalid("trailing comma", "07:00=100,");
    invalid("hour 24", "24:00=50");
    invalid("minute 60", "12:60=50");
    invalid("1-digit minute", "7:5=50");
    invalid("P=0", "07:00=0");
    invalid("P=101", "07:00=101");
    invalid("P non-numeric", "07:00=high");
    invalid("P negative", "07:00=-5");
    invalid("P signed", "07:00=+5");
    invalid("time non-numeric", "ab:cd=50");
    invalid("duplicate time", "07:00=50,7:00=60");
    invalid("missing =", "07:00");
    invalid("two =", "07:00=50=60");
    invalid("missing time", "=50");
    invalid("missing percent", "07:00=");
    invalid("3-digit hour", "007:00=50");

    if (failures > 0) System.exit(1);
  }
}
'''

with tempfile.TemporaryDirectory(prefix="homehq-brightness-") as directory:
    root = Path(directory)
    java = root / "BrightnessHarness.java"
    java.write_text(HARNESS.replace("__METHODS__", methods), encoding="utf-8")
    subprocess.run(["javac", "--release", "8", "-d", str(root), str(java)],
                   check=True, timeout=30)
    subprocess.run(["java", "-cp", str(root), "com.wesbos.homehq.BrightnessHarness"],
                   check=True, timeout=30)
