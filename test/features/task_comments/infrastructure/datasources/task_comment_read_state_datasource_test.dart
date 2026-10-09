import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meiso/features/task_comments/infrastructure/datasources/task_comment_read_state_datasource.dart';

void main() {
  late Directory tempDir;
  late Box<int> box;
  late TaskCommentReadStateDataSourceHive dataSource;
  var seq = 0;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('task_comment_read_state');
    Hive.init(tempDir.path);
    seq++;
    box = await Hive.openBox<int>('task_comment_read_state_$seq');
    dataSource = TaskCommentReadStateDataSourceHive(box: box);
  });

  tearDown(() async {
    if (box.isOpen) {
      await dataSource.close();
    }
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('markRead stores the watermark per task', () async {
    await dataSource.markRead(taskId: 't1', receivedAtMillis: 100);
    await dataSource.markRead(taskId: 't2', receivedAtMillis: 200);

    expect(await dataSource.loadWatermarks(), {'t1': 100, 't2': 200});
  });

  test('markRead only moves forward', () async {
    await dataSource.markRead(taskId: 't1', receivedAtMillis: 500);
    await dataSource.markRead(taskId: 't1', receivedAtMillis: 300);
    expect(await dataSource.loadWatermarks(), {'t1': 500});

    await dataSource.markRead(taskId: 't1', receivedAtMillis: 700);
    expect(await dataSource.loadWatermarks(), {'t1': 700});
  });

  test('watchWatermarks emits the current map and then every change', () async {
    await dataSource.markRead(taskId: 't1', receivedAtMillis: 1);

    final emissions = <Map<String, int>>[];
    final sub = dataSource.watchWatermarks().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, [
      {'t1': 1},
    ]);

    await dataSource.markRead(taskId: 't2', receivedAtMillis: 2);
    await pumpEventQueue();
    expect(emissions.last, {'t1': 1, 't2': 2});

    await sub.cancel();
  });

  test('wipe closes the box and deletes its file from disk', () async {
    await dataSource.markRead(taskId: 't1', receivedAtMillis: 1);
    final name = box.name;
    expect(await Hive.boxExists(name), isTrue);

    await dataSource.wipe();

    expect(box.isOpen, isFalse);
    expect(await Hive.boxExists(name), isFalse);
    final leftovers = tempDir
        .listSync()
        .where((f) => f.path.contains(name))
        .toList();
    expect(leftovers, isEmpty);
  });
}
