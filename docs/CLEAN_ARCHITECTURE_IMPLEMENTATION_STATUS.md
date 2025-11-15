# Clean Architecture 実装進捗状況

**最終更新**: 2025-11-15  
**現在のブランチ**: `stag`  
**ステータス**: 🔄 Phase D.7実装準備中（MLS機能統合）  
**採用アプローチ**: ハイブリッド方式（既存Providerを保持しつつ段階的にClean Architecture化）

---

## 📊 全体進捗

| Phase | 内容 | 予定工数 | 実工数 | ステータス | 完了日 |
|-------|------|---------|--------|-----------|--------|
| Phase A | 即座実施（Phase 8要件） | 6.5h | 6h | ✅ 完了 | 2025-11-12 |
| Phase B | CRUD UseCases抽出 | 40.5h | 14h | ✅ 完了 | 2025-11-13 |
| Phase C | Repository層導入 | 80.5h | 32h | ✅ 完了 | 2025-11-14 |
| Phase D | MLS機能リファクタリング | 44h | 11h | 🔄 進行中 | - |
| Phase E | リスト削除機能 | 23.5h | - | ⏳ 未着手 | - |

**進捗率**: 75% → 目標: 100%

**重要**: 外部API（Provider）は不変のまま、内部をClean Architecture化する方針

---

## 🎯 採用アプローチ: ハイブリッド方式

### 方針
旧Provider（`todos_provider.dart`、`custom_lists_provider.dart`）を保持しつつ、内部を段階的にClean Architecture化。

### メリット
- ✅ 外部API不変 → UIの変更不要
- ✅ リグレッションリスク最小化
- ✅ 段階的実装が可能
- ✅ Phase 8（MLS機能）をそのまま保持

### 実装戦略
```
Provider（外部API）
  ↓ 内部で呼び出し
UseCase（ビジネスロジック）
  ↓
Repository（データアクセス抽象化）
  ↓
DataSource（Nostr、LocalStorage）
```

---

## ✅ Phase A: 即座実施（Phase 8要件）- 完了

**完了日**: 2025-11-12  
**実工数**: 6時間

### 実装内容
1. ✅ SyncLoadingOverlay表示条件修正（`isInitialSync`フラグ）
2. ✅ ExpandableCustomListModalテーマ対応
3. ✅ MLSグループリスト作成の動作確認

---

## ✅ Phase B: CRUD UseCases抽出 - 完了

**完了日**: 2025-11-13  
**実工数**: 14時間

### 実装済みUseCases

```
lib/features/todo/application/usecases/
├── create_todo_usecase.dart (74行)
├── update_todo_usecase.dart (69行)
└── delete_todo_usecase.dart (81行)
```

### 統合状況
- ✅ `todos_provider.dart`の`addTodo()` → `CreateTodoUseCase`
- ✅ `todos_provider.dart`の`updateTodo()` → `UpdateTodoUseCase`
- ✅ `todos_provider.dart`の`toggleTodo()` → `UpdateTodoUseCase`
- ✅ `todos_provider.dart`の`deleteTodo()` → `DeleteTodoUseCase`

### 動作確認
- ✅ Test 1: Todo追加（Today/Tomorrow/Someday）
- ✅ Test 2: Todo更新（タイトル変更、完了マーク）
- ✅ Test 3: Todo削除
- ✅ Test 4: カスタムリストへのTodo追加

---

## ✅ Phase C: Repository層導入 - 完了

**完了日**: 2025-11-14  
**実工数**: 32時間

### Phase C.1: CRUD Repository化（完了）

**実装内容**:
```
lib/features/todo/
├── domain/
│   └── repositories/
│       └── todo_repository.dart (93行)
└── infrastructure/
    ├── repositories/
    │   └── todo_repository_impl.dart (256行)
    └── providers/
        └── repository_providers.dart (28行)
```

**実装メソッド**:
- ✅ `loadTodosFromLocal()` - ローカルから全Todo取得
- ✅ `saveTodosToLocal()` - 全Todo保存
- ✅ `saveTodoToLocal()` - 単一Todo保存
- ✅ `deleteTodoFromLocal()` - 単一Todo削除

### Phase C.2: マイグレーション処理Repository化（完了）

**実装内容**:
- ✅ `checkKind30001Exists()` - 新形式データ存在確認
- ✅ `checkMigrationNeeded()` - マイグレーション必要性チェック
- ✅ `fetchOldTodosFromKind30078()` - 旧データ取得
- ✅ `deleteNostrEvents()` - Nostrイベント削除
- ✅ `setMigrationCompleted()` - マイグレーション完了フラグ

### Phase C.3: CustomListRepository実装（完了）

**実装内容**:
```
lib/features/custom_list/
├── domain/
│   ├── repositories/
│   │   └── custom_list_repository.dart (170行)
│   └── errors/
│       └── custom_list_errors.dart (74行)
└── infrastructure/
    ├── repositories/
    │   └── custom_list_repository_impl.dart (400行)
    └── providers/
        └── repository_providers.dart (20行)
```

**実装メソッド**:
- ✅ ローカルCRUD（4メソッド）
- ✅ 削除イベント同期（3メソッド）
- ✅ カスタムリスト名抽出（1メソッド）

---

## 🔄 Phase D: MLS機能リファクタリング - 進行中

**開始日**: 2025-11-14  
**実工数**: 11時間（進行中）

### Phase D.1: Domain層設計（完了）

**実装内容**:
```
lib/features/mls/
├── domain/
│   ├── entities/
│   │   ├── mls_group.dart (45行)
│   │   ├── group_invitation.dart (66行)
│   │   └── key_package.dart (58行)
│   ├── value_objects/
│   │   └── key_package_publish_policy.dart (117行)
│   ├── errors/
│   │   └── mls_errors.dart (160行)
│   └── repositories/
│       ├── key_package_repository.dart (93行)
│       └── mls_group_repository.dart (143行)
```

**重要な設計**:
- ✅ MLS Protocol準拠（RFC 9420）
- ✅ Key Package有効期限: 7日間
- ✅ 推奨更新閾値: 3日間
- ✅ Forward Secrecy確保

### Phase D.2: UseCases実装（完了）

**実装内容**:
```
lib/features/mls/application/usecases/
├── create_mls_group_usecase.dart (87行)
├── send_group_invitation_usecase.dart (104行)
└── auto_publish_key_package_usecase.dart (135行)
```

### Phase D.3: 招待同期UseCases（完了）

**実装内容**:
```
lib/features/mls/application/usecases/
├── sync_group_invitations_usecase.dart (88行)
└── accept_group_invitation_usecase.dart (135行)
```

### Phase D.5: Provider統合（完了）

**統合箇所**:
- ✅ `main.dart` - Key Package自動公開
- ✅ `someday_screen.dart` - 招待受諾
- ✅ `custom_lists_provider.dart` - グループ作成・招待送信・招待同期
- ✅ `list_detail_screen.dart` - グループタスク同期有効化

### Phase D.7: 初回ログイン時Key Package公開（準備中）

**実装方針**:
- 🔄 Amberモードのみ実装（Phase D.7）
- ⏸️ 秘密鍵生成ログインは Phase D.8 に延期

**目標**: MLS_BETA_ROADMAP.md Phase 8.1完了条件を満たす

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

## ✅ Phase 2: Todo Domain層（完了）

**完了日**: 2025-11-13  
**実工数**: 3時間

### 実装ファイル

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

## ✅ Phase 4: Todo Application層（完了 - Phase B）

**完了日**: 2025-11-13  
**実装方針**: 既存Provider内で段階的にUseCase化

### 実装済みUseCases

```
lib/features/todo/application/usecases/
├── create_todo_usecase.dart (74行) ✅
├── update_todo_usecase.dart (69行) ✅
└── delete_todo_usecase.dart (81行) ✅
```

### 実装済みProviders

```
lib/features/todo/application/providers/
└── usecase_providers.dart (29行) ✅
```

### 未実装UseCases（Phase E以降）

以下のUseCaseは既存Provider内に残存（将来的に抽出予定）:
- ⏳ `ReorderTodoUseCase` - 並び替え
- ⏳ `MoveTodoUseCase` - 日付間移動
- ⏳ `SyncTodosUseCase` - Nostr同期（複雑なため後回し）
- ⏳ `GenerateRecurringInstancesUseCase` - リカーリングタスク

---

## ⏸️ Phase 5-7: Presentation層（延期）

**方針変更**: ハイブリッドアプローチ採用により、Presentation層の全面書き換えは不要

### 既存ViewModel（未使用）

```
lib/features/todo/presentation/
├── providers/
│   ├── todo_providers.dart (11行) ⚠️ 未使用
│   └── todo_providers_compat.dart ⚠️ 未使用
└── view_models/
    ├── todo_list_state.dart (21行) ⚠️ 未使用
    └── todo_list_view_model.dart (169行) ⚠️ 未使用
```

### 現状
- 旧Provider（`lib/providers/todos_provider.dart`）を継続使用
- 内部でUseCaseを呼び出す方式を採用
- UI層の変更は不要

### 将来的な方針
- ViewModelへの完全移行は Phase F 以降で検討
- 当面は既存Provider + UseCase方式を維持

---

## 📊 実装済み機能サマリー

### ✅ 完全実装（Clean Architecture準拠）

| 機能 | Domain | Infrastructure | Application | Provider統合 |
|------|--------|----------------|-------------|-------------|
| **Core基盤** | ✅ | ✅ | ✅ | ✅ |
| **Todo CRUD** | ✅ | ✅ | ✅ | ✅ |
| **CustomList CRUD** | ✅ | ✅ | - | ✅ |
| **マイグレーション** | ✅ | ✅ | - | ✅ |
| **MLS（グループ作成）** | ✅ | ⏳ | ✅ | ✅ |
| **MLS（招待同期）** | ✅ | ⏳ | ✅ | ✅ |
| **Key Package管理** | ✅ | ⏳ | ✅ | 🔄 |

### ⏳ 既存Provider内に残存

以下の機能は旧Provider内に実装されており、将来的にUseCase化予定：

- Nostr同期（`syncFromNostr()`、437行）
- グループTodo同期
- リカーリングタスク処理
- 並び替え・移動処理

---

## 🎯 次のステップ

### 優先度 🔥 Critical
- **Phase D.7**: 初回ログイン時のKey Package自動公開（Amberモード）
  - MLS_BETA_ROADMAP.md Phase 8.1完了に必須
  - 実工数: 3時間

### 優先度 🟡 Medium
- **Phase E**: 個人リスト削除機能（Kind: 5送信）
  - 実工数: 23.5時間
  
### 優先度 🟢 Low
- **Phase F**: 残存UseCasesの抽出
  - リカーリングタスク
  - 並び替え・移動
  - 実工数: 15時間

---

## 📚 関連ドキュメント

- [REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md](./REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md) - 実装戦略（全体方針）
- [MLS_BETA_ROADMAP.md](./MLS_BETA_ROADMAP.md) - MLS機能ロードマップ
- [INCIDENT_CLEAN_ARCHITECTURE_ROLLBACK.md](./_archive/INCIDENT_CLEAN_ARCHITECTURE_ROLLBACK.md) - インシデント報告（アーカイブ）

---

**最終更新**: 2025-11-15  
**次のアクション**: Phase D.7実装準備（初回ログイン時Key Package公開）

