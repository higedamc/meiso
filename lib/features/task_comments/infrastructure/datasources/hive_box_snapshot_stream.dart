import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

/// Emits [read] once on listen and again after every write to the box.
///
/// Written with an explicit controller instead of `async*` on purpose: an
/// `async*` body parked in `await for (… in box.watch())` only notices a
/// `cancel()` at its next `yield`, so cancelling it while the box is quiet
/// never completes and the generator keeps its Hive subscription until the
/// next unrelated write (measured in the #218 tests: `sub.cancel()` hung
/// until the 30 s timeout). Here `onCancel` drops the Hive subscription
/// synchronously, and a cancel that arrives while the box is still opening
/// is honoured too.
Stream<T> watchBoxSnapshot<T, B extends BoxBase<dynamic>>({
  required Future<B> Function() openBox,
  required T Function(B box) read,
}) {
  late StreamController<T> controller;
  StreamSubscription<BoxEvent>? boxSubscription;
  var cancelled = false;

  controller = StreamController<T>(
    onListen: () async {
      final B box;
      try {
        box = await openBox();
      } on Object catch (e, st) {
        if (!cancelled) {
          controller.addError(e, st);
          await controller.close();
        }
        return;
      }
      if (cancelled) {
        return;
      }
      controller.add(read(box));
      boxSubscription = box.watch().listen(
        (_) => controller.add(read(box)),
        onError: controller.addError,
        onDone: controller.close,
      );
    },
    onCancel: () {
      cancelled = true;
      final subscription = boxSubscription;
      boxSubscription = null;
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
