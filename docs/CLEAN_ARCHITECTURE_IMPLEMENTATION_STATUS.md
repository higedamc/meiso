# Clean Architecture 実装進捗状況

**最終更新**: 2025-11-13  
**現在のブランチ**: `refactor/clean-architecture`  
**ステータス**: 🔄 Phase 2実装中

---

## 📊 全体進捗

| Phase | 内容 | 予定工数 | 実工数 | ステータス | 完了日 |
|-------|------|---------|--------|-----------|--------|
| Phase 0 | 準備 | 1h | 1h | ✅ 完了 | 2025-11-12 |
| Phase 1 | Core層基盤 | 2-3h | 2h | ✅ 完了 | 2025-11-12 |
| Phase 2 | Todo Domain層 | 3-4h | 3h | ✅ 完了 | 2025-11-13 |
| Phase 3 | Todo Infrastructure層 | 4-5h | 3h | ✅ 完了 | 2025-11-13 |
| Phase 4 | Todo Application層 | 3-4h | - | ⏳ 未着手 | - |
| Phase 5-7 | Todo Presentation層 | 5-6h | - | ⏳ 未着手 | - |
| Phase 8 | 他機能展開 | 6-8h | - | ⏳ 未着手 | - |

**進捗率**: 40% → 目標: 100%

---

## ✅ Phase 1: Core層基盤（完了）

### 実装ファイル

```
lib/core/
├── common/
│   ├── failure.dart (82行) ✅
│   └── usecase.dart (27行) ✅
└── config/
    └── app_config.dart (40行) ✅
```

### 実装内容

1. **Failureベースクラス** (10種類)
   - NetworkFailure
   - AuthFailure
   - ServerFailure
   - CacheFailure
   - ValidationFailure
   - UnexpectedFailure
   - NostrFailure
   - AmberFailure
   - EncryptionFailure
   - DecryptionFailure

2. **UseCaseベースクラス**
   ```dart
   abstract class UseCase<Type, Params> {
     Future<Either<Failure, Type>> call(Params params);
   }
   ```

3. **AppConfig**
   - アプリ全体の設定定数

### テスト

```
test/core/common/
├── failure_test.dart (20テストケース) ✅
└── usecase_test.dart (11テストケース) ✅
```

---

## 🔄 Phase 2: Todo Domain層（実装中）

### 実装予定ファイル

```
lib/features/todo/domain/
├── entities/
│   ├── todo.dart
│   └── todo.freezed.dart
├── value_objects/
│   ├── todo_title.dart
│   └── todo_date.dart
├── repositories/
│   └── todo_repository.dart
└── errors/
    └── todo_errors.dart
```

### 実装内容

#### 1. Todoエンティティ

```dart
@Freezed(makeCollectionsUnmodifiable: false)
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required TodoTitle title,
    required bool completed,
    TodoDate? date,
    required int order,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? eventId,
    String? linkPreviewJson,
    String? recurrenceJson,
    String? parentRecurringId,
    String? customListId,
    required bool needsSync,
  }) = _Todo;
}
```

#### 2. Value Objects

**TodoTitle**:
```dart
class TodoTitle {
  const TodoTitle._(this.value);
  final String value;
  
  static Either<Failure, TodoTitle> create(String input) {
    if (input.isEmpty) {
      return const Left(ValidationFailure('タイトルを入力してください'));
    }
    if (input.length > 500) {
      return const Left(ValidationFailure('タイトルは500文字以内にしてください'));
    }
    return Right(TodoTitle._(input));
  }
  
  factory TodoTitle.unsafe(String value) => TodoTitle._(value);
}
```

**TodoDate**:
```dart
class TodoDate {
  const TodoDate(this.value);
  final DateTime value;
  
  factory TodoDate.dateOnly(DateTime date);
  factory TodoDate.today();
  factory TodoDate.tomorrow();
  
  bool get isToday;
  bool get isTomorrow;
}
```

#### 3. Repository Interface

```dart
abstract class TodoRepository {
  Future<Either<Failure, List<Todo>>> getAllTodos();
  Future<Either<Failure, Todo>> getTodoById(String id);
  Future<Either<Failure, Todo>> createTodo(Todo todo);
  Future<Either<Failure, Todo>> updateTodo(Todo todo);
  Future<Either<Failure, void>> deleteTodo(String id);
  Future<Either<Failure, List<Todo>>> syncFromNostr();
  Future<Either<Failure, void>> syncToNostr(Todo todo);
  Future<Either<Failure, void>> saveLocal(List<Todo> todos);
  Future<Either<Failure, List<Todo>>> loadLocal();
}
```

#### 4. Domain Errors

```dart
enum TodoError {
  notFound,
  alreadyExists,
  invalidTitle,
  syncFailed,
  encryptionFailed,
  decryptionFailed,
  recurringInstanceError,
  linkPreviewError,
}

class TodoFailure extends Failure {
  const TodoFailure(this.error) : super(_errorMessage(error));
  final TodoError error;
}
```

### テスト

```
test/features/todo/domain/
├── entities/
│   └── todo_test.dart (69テストケース)
├── value_objects/
│   ├── todo_title_test.dart
│   └── todo_date_test.dart
└── errors/
    └── todo_errors_test.dart
```

---

## ✅ Phase 3: Todo Infrastructure層（完了）

### 実装ファイル

```
lib/features/todo/infrastructure/
├── repositories/
│   └── todo_repository_impl.dart (256行) ✅
├── datasources/
│   ├── todo_local_datasource.dart (198行) ✅
│   └── todo_remote_datasource.dart (57行) ✅ (スタブ)
```

### 実装内容

#### 1. TodoLocalDataSourceHive

HiveベースのローカルストレージDataSource実装。

**主要メソッド**:
- `loadAllTodos()` - すべてのTodoを読み込み
- `loadTodoById(id)` - 特定のTodoを取得
- `saveTodo(todo)` - Todoを保存
- `saveTodos(todos)` - 複数のTodoを一括保存
- `deleteTodo(id)` - Todoを削除
- `clear()` - 全削除

**特徴**:
- Freezed非対応の旧Todoモデルとの互換性
- Deep copyによる安全なMap変換
- エラーハンドリングと復元スキップ

#### 2. TodoRemoteDataSourceNostr

Nostrリレーとの通信を抽象化（Phase 4で実装予定）。

**定義されたインターフェース**:
- `fetchPersonalTodosFromNostr()` - パーソナルタスク取得
- `fetchGroupTodosFromNostr()` - グループタスク取得
- `syncPersonalTodoToNostr()` - パーソナルタスク送信
- `syncGroupTodoToNostr()` - グループタスク送信
- `deletePersonalTodoFromNostr()` - パーソナルタスク削除
- `deleteGroupTodoFromNostr()` - グループタスク削除

#### 3. TodoRepositoryImpl

Domain層のRepositoryインターフェースを実装。

**実装されたメソッド**:
- `getAllTodos()` - ローカルから全取得
- `getTodosByDate(date)` - 日付別取得（Someday含む）
- `getTodosByListId(listId)` - カスタムリスト別取得
- `getTodoById(id)` - ID指定取得
- `createTodo(todo)` - 作成（楽観的UI更新）
- `updateTodo(todo)` - 更新（楽観的UI更新）
- `deleteTodo(id)` - 削除
- `syncFromNostr()` - Nostr同期（取得）
- `syncToNostr(todo)` - Nostr同期（送信）
- `saveLocal(todos)` - ローカル保存
- `loadLocal()` - ローカル読み込み
- `reorderTodos(todos)` - 並び替え
- `moveTodo(id, newDate)` - 日付移動

**デザインパターン**:
- 楽観的UI更新（Optimistic UI Update）
- バックグラウンド同期（エラー無視）
- Either型によるエラーハンドリング

### テスト

```
test/features/todo/infrastructure/
├── datasources/
│   └── todo_local_datasource_test.dart (10テストケース) ✅
└── repositories/
    └── todo_repository_impl_test.dart (11テストケース) ✅
```

**テスト結果**: 21個のテストケース全てパス ✅

---

## ⏳ Phase 4: Todo Application層（未着手）

### 実装予定ファイル

```
lib/features/todo/application/usecases/
├── create_todo_usecase.dart
├── update_todo_usecase.dart
├── delete_todo_usecase.dart
├── toggle_todo_usecase.dart
├── reorder_todo_usecase.dart
├── move_todo_usecase.dart
├── sync_todos_usecase.dart
├── get_all_todos_usecase.dart
├── get_todo_by_id_usecase.dart
├── get_todos_by_date_usecase.dart
└── get_todos_by_list_usecase.dart
```

---

## ⏳ Phase 5-7: Todo Presentation層（未着手）

### 既存ファイル（使われていない）

```
lib/features/todo/presentation/
├── providers/
│   ├── todo_providers.dart (11行) ⚠️
│   └── todo_providers_compat.dart ⚠️
└── view_models/
    ├── todo_list_state.dart (21行) ⚠️
    └── todo_list_view_model.dart (169行) ⚠️
```

### 必要な作業

1. ViewModelの完全実装
2. Providerの配線
3. UI統合（旧Provider → ViewModel）
4. 互換レイヤーの削除

---

## 📚 関連ドキュメント

- [INCIDENT_CLEAN_ARCHITECTURE_ROLLBACK.md](./INCIDENT_CLEAN_ARCHITECTURE_ROLLBACK.md) - インシデント報告
- [REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md](./REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md) - 実装戦略
- [CLEAN_ARCHITECTURE_REFACTORING_PLAN.md](./CLEAN_ARCHITECTURE_REFACTORING_PLAN.md) - 詳細計画

---

**次のアクション**: Phase 2 Domain層の実装を完了させる

