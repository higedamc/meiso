import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/models/todo.dart';
import 'package:meiso/utils/todo_delta_merge.dart';

Todo _todo(String id, {bool needsSync = false, String title = ''}) {
  final now = DateTime(2026, 1, 1);
  return Todo(
    id: id,
    title: title.isEmpty ? id : title,
    createdAt: now,
    updatedAt: now,
    needsSync: needsSync,
  );
}

void main() {
  group('preserveInFlightTodos', () {
    test('returns the snapshot unchanged when nothing is in flight', () {
      final result = preserveInFlightTodos(
        merged: [_todo('a'), _todo('b')],
        current: [_todo('a'), _todo('b')],
      );
      expect(result.map((t) => t.id), ['a', 'b']);
    });

    test('a locally added todo missing from the snapshot survives', () {
      final result = preserveInFlightTodos(
        merged: [_todo('a')],
        current: [_todo('a'), _todo('new', needsSync: true)],
      );
      expect(result.map((t) => t.id), containsAll(['a', 'new']));
      expect(result.firstWhere((t) => t.id == 'new').needsSync, isTrue);
    });

    test('a locally edited todo wins over the snapshot version', () {
      final result = preserveInFlightTodos(
        merged: [_todo('a', title: 'relay copy')],
        current: [_todo('a', needsSync: true, title: 'local edit')],
      );
      expect(result, hasLength(1));
      expect(result.single.title, 'local edit');
      expect(result.single.needsSync, isTrue);
    });

    test('synced local todos do not override the snapshot', () {
      // needsSync == false means the relay copy is authoritative: a todo
      // deleted on another device must not be resurrected here.
      final result = preserveInFlightTodos(
        merged: [_todo('a')],
        current: [_todo('a'), _todo('deleted-elsewhere')],
      );
      expect(result.map((t) => t.id), ['a']);
    });
  });
}
