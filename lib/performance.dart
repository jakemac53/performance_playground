import 'dart:async';

main() async {
  var zone = performanceTrackingZone();
  Zone subZone;
  // await zone.run(() async {
  //   await new Future.delayed(new Duration(seconds: 1));
  //   loopFor(500000);
  //   subZone = performanceTrackingZone();
  //   await subZone.run(() async {
  //     await new Future.delayed(new Duration(seconds: 1));
  //     loopFor(4000000);
  //     await new Future.delayed(new Duration(seconds: 1));
  //   });
  // });

  await zone.run(() {
    return new Future(() {}).then((_) {
      var w1 = new Stopwatch()..start();
      loopFor(500000);
      print('parent: ${w1.elapsed}');
      subZone = performanceTrackingZone();
      w1.stop();
      print('parent: ${w1.elapsed}');
      return subZone.run(() {
        return new Future(() {}).then((_) {
          var w2 = new Stopwatch()..start();
          loopFor(4000000);
          w2.stop();
          print('child: ${w2.elapsed}');
          return new Future(() {});
        });
      });
    });
  });

  // zone.run(() {
  //   loopFor(500000);
  //   subZone = performanceTrackingZone();
  //   subZone.run(() {
  //     loopFor(4000000);
  //   });
  // });
  print('child: ${subZone[PerformanceTracker.zoneKey].elapsed}');
  print('parent: ${zone[PerformanceTracker.zoneKey].elapsed}');
}

void loopFor(int numTimes) {
  for (var i = 0; i < numTimes; i++) {
    if (i % 100000 == 0) print(i);
  }
}

Zone performanceTrackingZone() {
  var specification = new ZoneSpecification(
    scheduleMicrotask: (self, parent, zone, callback) {
      var wrapped = () {
        var nextZone = zone;
        PerformanceTracker tracker;
        while (tracker == null) {
          if (nextZone == Zone.root) {
            throw 'Unable to find a performance tracking zone!';
          }
          tracker = nextZone[PerformanceTracker.zoneKey] as PerformanceTracker;
          nextZone = nextZone.parent;
        }
        tracker.start();
        try {
          callback();
        } finally {
          tracker.stop();
        }
      };
      parent.scheduleMicrotask(zone, wrapped);
    },
    run: <R>(Zone self, ZoneDelegate parent, Zone zone, R callback()) {
      var watch = new Stopwatch()..start();
      var nextZone = zone;
      PerformanceTracker tracker;
      while (tracker == null) {
        if (nextZone == Zone.root) {
          throw 'Unable to find a performance tracking zone!';
        }
        tracker = nextZone[PerformanceTracker.zoneKey] as PerformanceTracker;
        nextZone = nextZone.parent;
      }
      var selfTracker = self[PerformanceTracker.zoneKey] as PerformanceTracker;
      var wasRunning = selfTracker.isRunning;
      if (wasRunning) selfTracker.stop();
      tracker.start();
      print('run setup: ${watch.elapsed}');
      try {
        return parent.run(zone, callback);
      } finally {
        tracker.stop();
        if (wasRunning) selfTracker.start();
        watch.stop();
        print('run finished: ${watch.elapsed}');
      }
    },
    runUnary: <R, T>(Zone self, ZoneDelegate parent, Zone zone, R callback(T _),
        T arg) {
      var nextZone = zone;
      PerformanceTracker tracker;
      while (tracker == null) {
        if (nextZone == Zone.root) {
          throw 'Unable to find a performance tracking zone!';
        }
        tracker = nextZone[PerformanceTracker.zoneKey] as PerformanceTracker;
        nextZone = nextZone.parent;
      }
      tracker.start();
      try {
        return parent.runUnary(zone, callback, arg);
      } finally {
        tracker.stop();
      }
    },
    runBinary: <R, T1, T2>(Zone self, ZoneDelegate parent, Zone zone,
        R callback(T1 _, T2 __), T1 arg1, T2 arg2) {
      var nextZone = zone;
      PerformanceTracker tracker;
      while (tracker == null) {
        if (nextZone == Zone.root) {
          throw 'Unable to find a performance tracking zone!';
        }
        tracker = nextZone[PerformanceTracker.zoneKey] as PerformanceTracker;
        nextZone = nextZone.parent;
      }
      tracker.start();
      try {
        return parent.runBinary(zone, callback, arg1, arg2);
      } finally {
        tracker.stop();
      }
    },
  );
  var tracker = new PerformanceTracker();
  var zone = Zone.current.fork(
      specification: specification,
      zoneValues: {PerformanceTracker.zoneKey: tracker});
  return zone;
}

class PerformanceTracker {
  static const zoneKey = #PerformanceTracker;

  final _watch = new Stopwatch();

  Duration get elapsed => _watch.elapsed;

  bool get isRunning => _watch.isRunning;

  void start() {
    _watch.start();
  }

  void stop() {
    _watch.stop();
  }
}
