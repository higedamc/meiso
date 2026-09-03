import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/models/custom_list.dart';
import 'package:meiso/widgets/todo_edit_screen.dart';

void main() {
  group('resolveEffectiveListId', () {
    test('呼び出し側の customListId を優先する', () {
      expect(
        resolveEffectiveListId(explicitListId: 'explicit', todoListId: 'todo'),
        'explicit',
      );
    });

    test('呼び出し側が null なら todo 自身の customListId にフォールバックする', () {
      expect(
        resolveEffectiveListId(explicitListId: null, todoListId: 'todo'),
        'todo',
      );
    });

    test('両方 null なら null', () {
      expect(
        resolveEffectiveListId(explicitListId: null, todoListId: null),
        isNull,
      );
    });
  });

  group('resolveIsGroupContext', () {
    CustomList sharedList({String id = 'list-1'}) => CustomList(
      id: id,
      name: 'Shared',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isGroup: true,
      protocolVersion: CustomListHelpers.protocolSharedV1,
    );

    CustomList mlsList({String id = 'list-2'}) => CustomList(
      id: id,
      name: 'MLS',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isGroup: true,
      protocolVersion: CustomListHelpers.protocolMlsV1,
    );

    CustomList personalList({String id = 'list-3'}) => CustomList(
      id: id,
      name: 'Personal',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('shared-v1 の共有リストのタスク → true(タスク行から開いた既存タスク編集を再現)', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: 'list-1',
        customLists: [sharedList(), personalList()],
      );
      expect(result, isTrue);
    });

    test('個人リストのタスク → false', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: 'list-3',
        customLists: [sharedList(), personalList()],
      );
      expect(result, isFalse);
    });

    test('mls-v1 のグループリストのタスク → false(グループ鍵が無いので個人経路に fail-closed)', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: 'list-2',
        customLists: [mlsList()],
      );
      expect(result, isFalse);
    });

    test('リストが見つからない → false(fail-closed)', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: 'missing-list',
        customLists: [sharedList(), personalList()],
      );
      expect(result, isFalse);
    });

    test('effectiveListId が null → false(fail-closed、CustomList 一覧を見るまでもない)', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: null,
        customLists: [sharedList()],
      );
      expect(result, isFalse);
    });

    test('customLists が未ロード(null)→ false(fail-closed)', () {
      final result = resolveIsGroupContext(
        isGroupList: false,
        effectiveListId: 'list-1',
        customLists: null,
      );
      expect(result, isFalse);
    });

    test('widget.isGroupList が既に true なら CustomList 一覧を見ずに true'
        '(新規追加フロー / mls-v1 / gw17-v1 の既存挙動を変えない)', () {
      final result = resolveIsGroupContext(
        isGroupList: true,
        effectiveListId: null,
        customLists: null,
      );
      expect(result, isTrue);
    });
  });
}
