# Meiso クリーンアーキテクチャ リファクタリング方針

**作成日**: 2025-11-13  
**現在のブランチ**: `refactor/clean-architecture`  
**Phase**: 8（MLS Beta）

---

## 📋 目次

1. [現状分析](#現状分析)
2. [問題点の整理](#問題点の整理)
3. [リファクタリング方針の選択肢](#リファクタリング方針の選択肢)
4. [推奨方針: ハイブリッドアプローチ](#推奨方針-ハイブリッドアプローチ)
5. [具体的な実装計画](#具体的な実装計画)
6. [タスク一覧](#タスク一覧)

---

## 📊 現状分析

### アーキテクチャの状態

#### ✅ 実装済み（完全動作）

**旧Provider構造** (`lib/providers/`)
- `todos_provider.dart` (3,592行)
  - 全TODO操作（CRUD、同期、MLS統合）
  - Amber/秘密鍵モード対応
  - グループタスク同期
  - Phase 8.1-8.4完全実装済み
- `custom_lists_provider.dart` (966行)
  - カスタムリスト管理
  - MLSグループリスト作成
  - 招待システム（Phase 6完全実装）
  - Key Package管理

**使用箇所**: 全てのUI（home_screen.dart、someday_screen.dart等）

#### ⚠️ 存在するが未使用

**features/ディレクトリ** (Clean Architecture構造)

```
lib/features/
├── todo/
│   └── presentation/
│       ├── providers/
│       │   ├── todo_providers.dart (新ViewModel用Provider)
│       │   └── todo_providers_compat.dart (互換レイヤー)
│       └── view_models/
│           ├── todo_list_view_model.dart (169行)
│           └── todo_list_state.dart
└── custom_list/
    └── presentation/
        ├── providers/
        │   ├── custom_list_providers.dart
        │   └── custom_list_providers_compat.dart
        └── view_models/
            ├── custom_list_view_model.dart (94行)
            └── custom_list_state.dart
```

**問題**: これらは**一切使われていない**
- UIは全て旧Providerを直接参照
- ViewModelは定義されているが呼び出しがない
- 互換レイヤーも使われていない

#### 📝 その他のファイル

**コアインターフェース** (`lib/core/common/`)
- `usecase.dart` - UseCase抽象クラス
- `failure.dart` - Failureベースクラス

**テストファイル** (`test/features/`)
- UseCaseテスト（多数実装済み）
- ViewModelテスト
- Entity/ValueObjectテスト

---

## ⚠️ 問題点の整理

### 1. コードパスの断絶

**現象**:
```dart
// lib/presentation/home/home_screen.dart
import '../../providers/todos_provider.dart';  // ✅ 旧Provider使用

final todosAsync = ref.watch(todosProvider);  // ✅ 動作する
```

```dart
// lib/features/todo/presentation/view_models/todo_list_view_model.dart
class TodoListViewModel extends StateNotifier<TodoListState> {
  // ✅ 定義されているが...
}
```

**問題**: UIから`TodoListViewModel`への参照が存在しない

### 2. 二重構造の存在

| 要素 | 旧構造 | 新構造（Clean Architecture） | 使用状況 |
|------|--------|------------------------------|----------|
| **Provider** | `lib/providers/` | `lib/features/*/presentation/providers/` | 旧のみ使用 |
| **ViewModel** | なし（直接Provider） | `lib/features/*/presentation/view_models/` | 未使用 |
| **ビジネスロジック** | Providerに内包 | UseCases（未実装） | なし |

### 3. Phase 8実装の所在

**MLSグループリスト作成（Phase 8.1-8.4）は全て旧Provider内に実装**:
- `custom_lists_provider.dart`: `createMlsGroupList()`
- `todos_provider.dart`: `syncGroupTodos()`
- Rust APIとの連携も旧Providerから

**新ViewModelには移植されていない**

### 4. SyncLoadingOverlayの表示条件

**ユーザー要件**:
> デバイスの初回ログイン時のみ起動し、他の場合は、クラウドインジケーターで表示

**現状**:
```dart
// 現在の実装（修正済み）
if (syncStatus.totalSteps == 0 && syncStatus.percentage == 0) {
  return const SizedBox.shrink();
}
// → 進捗がある場合は常に表示される（要件違反）
```

**Phase2本来の実装**:
```dart
if (syncStatus.currentPhase != '初回同期中') {
  return const SizedBox.shrink();
}
// → 初回同期時のみ表示（要件準拠）
```

---

## 🎯 リファクタリング方針の選択肢

### Option A: 完全移行（理想的だが高コスト）

**概要**: features/配下のViewModelを実際に使用するよう全面書き換え

**実装内容**:
```dart
// Before: 旧Provider直接参照
final todosAsync = ref.watch(todosProvider);

// After: 新ViewModel使用
final todoState = ref.watch(todoListViewModelProvider);
```

**メリット**:
- ✅ 真のクリーンアーキテクチャ実現
- ✅ テスタビリティ向上
- ✅ 責任分離が明確

**デメリット**:
- ❌ 全画面の書き換えが必要（20+ファイル）
- ❌ Phase 8実装（MLS）を全てViewModel側に移植
- ❌ 実装期間: 2-3週間
- ❌ リグレッションリスク大

**推定工数**: 80-120時間

---

### Option B: 現状維持（最小変更）

**概要**: 旧Providerを正式な実装とし、features/は削除または無効化

**実装内容**:
- 旧Provider構造をそのまま使用
- features/ディレクトリを削除 or `_archive/`に移動
- ドキュメントで「旧構造=正式実装」と明記

**メリット**:
- ✅ 変更が最小限
- ✅ Phase 8実装がそのまま使える
- ✅ リグレッションリスクなし
- ✅ 実装期間: 1日

**デメリット**:
- ❌ クリーンアーキテクチャの恩恵なし
- ❌ テスト可能性が低い
- ❌ 3,592行の巨大Providerが残る

**推定工数**: 4-8時間

---

### Option C: ハイブリッドアプローチ（推奨）

**概要**: 旧Providerを保持しつつ、内部を段階的にクリーンアーキテクチャ化

**実装内容**:

#### Phase 1: 内部リファクタリング（外部APIは不変）

```dart
// lib/providers/todos_provider.dart (外部API不変)
class TodosNotifier extends StateNotifier<AsyncValue<Map<DateTime?, List<Todo>>>> {
  // ✅ 既存のメソッド署名は変更しない
  Future<void> addTodo(Todo todo) async {
    // 内部でUseCaseを呼ぶ
    final result = await _createTodoUseCase(todo);
    result.fold(
      (failure) => _handleError(failure),
      (success) => _updateState(success),
    );
  }
  
  // ✅ 既存のビジネスロジックを徐々にUseCaseに抽出
  late final CreateTodoUseCase _createTodoUseCase;
}
```

#### Phase 2: Repository層の導入

```dart
// lib/repositories/todo_repository_impl.dart (新規)
class TodoRepositoryImpl implements TodoRepository {
  final TodoLocalDataSource _localDataSource;
  final NostrService _nostrService;
  
  @override
  Future<Either<Failure, Todo>> createTodo(Todo todo) async {
    // 既存のProvider内ロジックをここに移動
  }
}
```

#### Phase 3: UseCase層の導入

```dart
// lib/usecases/create_todo_usecase.dart (新規)
class CreateTodoUseCase implements UseCase<Todo, CreateTodoParams> {
  final TodoRepository repository;
  
  @override
  Future<Either<Failure, Todo>> call(CreateTodoParams params) {
    return repository.createTodo(params.todo);
  }
}
```

**メリット**:
- ✅ 外部APIは不変（UIの変更不要）
- ✅ 内部が段階的にクリーン化
- ✅ テスタビリティ向上
- ✅ Phase 8実装はそのまま動作
- ✅ リスク低、段階的実装可能

**デメリット**:
- ⚠️ 完全なクリーンアーキテクチャまでは時間がかかる
- ⚠️ 一時的に二重構造が残る

**推定工数**: 
- Phase 1: 40時間（2週間）
- Phase 2: 40時間（2週間）
- Phase 3: 40時間（2週間）
- **合計**: 120時間（6週間、段階的実装）

---

## 🎯 推奨方針: ハイブリッドアプローチ

### 理由

1. **Phase 8完了を優先**
   - MLSグループリスト作成機能が最優先
   - リファクタリングで既存機能を壊さない
   - Beta版リリース時期を遅らせない

2. **段階的な品質向上**
   - リスクを最小化
   - 各Phaseごとに動作確認
   - 必要に応じて中断・再開可能

3. **長期的な保守性**
   - 最終的にクリーンアーキテクチャへ到達
   - 途中段階でも品質向上の恩恵あり

### 実装順序

```
Phase 8完了（MLS Beta）
    ↓
Option C Phase 1（内部リファクタリング）← 今ここを推奨
    ↓
Phase 9（Gift Wrap実装）
    ↓
Option C Phase 2-3（Repository/UseCase導入）
    ↓
完全なクリーンアーキテクチャ
```

---

## 📋 具体的な実装計画

### 即座に実施すべき修正（優先度: 🔥 最高）

#### 1. SyncLoadingOverlayの表示条件修正

**ファイル**: `lib/widgets/sync_loading_overlay.dart`

**現在（要件違反）**:
```dart
// 進捗がある場合は常に表示（間違い）
if (syncStatus.totalSteps == 0 && syncStatus.percentage == 0) {
  return const SizedBox.shrink();
}
```

**修正後（要件準拠）**:
```dart
// 初回同期時のみ表示
if (syncStatus.currentPhase != '初回同期中') {
  return const SizedBox.shrink();
}

// 他の場合は通常のインジケーター（既存実装に任せる）
```

**工数**: 30分

---

#### 2. ExpandableCustomListModal背景色の確定

**ファイル**: `lib/widgets/expandable_custom_list_modal.dart`

**現状**: 修正済み（`theme.scaffoldBackgroundColor`使用）

**確認事項**:
- ライトモード: 白背景 ✅
- ダークモード: 黒背景 ✅
- グループリスト作成ボタン導線 ✅

**工数**: 完了済み

---

#### 3. MLSグループリスト作成の動作確認

**テストシナリオ**:

1. **SOMEDAY画面を開く**
   - 背景色が正しい（白 or 黒）
   - 真紫背景でない

2. **+ボタンをタップ**
   - "ADD LIST"ダイアログが表示される
   - "Personal List" と "Group List" の2つの選択肢

3. **"Group List"を選択**
   - `AddGroupListDialog`が開く
   - グループ名入力フィールド
   - メンバーnpub入力フィールド
   - Key Package取得ボタン

4. **MLSグループ作成**
   - npub入力 → Key Package取得
   - グループ名入力
   - CREATE GROUP実行
   - エラーなく完了

5. **作成されたグループリストの確認**
   - SOMEDAYリストに表示される
   - グループアイコン表示
   - タップでリスト詳細画面に遷移

**期待される結果**: 全てエラーなく動作

**工数**: 2-4時間（実機テスト含む）

---

### Option C Phase 1の実装（推奨、Phase 8完了後）

#### ステップ1: UseCaseの抽出（TodosProvider）

**ターゲット**: `addTodo()`, `updateTodo()`, `deleteTodo()`

**Before**:
```dart
// lib/providers/todos_provider.dart
Future<void> addTodo(Todo todo) async {
  // 150行のビジネスロジック
}
```

**After**:
```dart
// lib/providers/todos_provider.dart
Future<void> addTodo(Todo todo) async {
  final result = await _createTodoUseCase(CreateTodoParams(todo));
  result.fold(
    (failure) => _handleError(failure),
    (todos) => state = AsyncValue.data(todos),
  );
}

// lib/usecases/create_todo_usecase.dart (新規)
class CreateTodoUseCase implements UseCase<Map<DateTime?, List<Todo>>, CreateTodoParams> {
  final TodoRepository repository;
  
  @override
  Future<Either<Failure, Map<DateTime?, List<Todo>>>> call(CreateTodoParams params) {
    // 既存のロジックをここに移植
  }
}
```

**工数**: 20時間

---

#### ステップ2: Repository層の実装

**ファイル**: `lib/repositories/todo_repository_impl.dart` (新規)

**実装内容**:
```dart
class TodoRepositoryImpl implements TodoRepository {
  final LocalStorageService _localStorage;
  final NostrService _nostrService;
  final AmberService _amberService;
  
  @override
  Future<Either<Failure, Todo>> createTodo(Todo todo) async {
    try {
      // Providerから移植したロジック
      await _localStorage.saveTodo(todo);
      await _syncToNostr(todo);
      return Right(todo);
    } catch (e) {
      return Left(TodoFailure(e.toString()));
    }
  }
}
```

**工数**: 20時間

---

## 📝 タスク一覧

### 🔥 Phase A: 即座実施（Phase 8完了要件）

| タスク | ファイル | 工数 | 優先度 |
|--------|---------|------|--------|
| SyncLoadingOverlay表示条件修正 | `sync_loading_overlay.dart` | 0.5h | 🔥 最高 |
| MLSグループリスト作成の動作確認 | 複数 | 4h | 🔥 最高 |
| ドキュメント更新（本ファイル） | `REFACTOR_*.md` | 2h | 🔥 最高 |

**合計工数**: 6.5時間（1日）

---

### 🟡 Phase B: 内部リファクタリング（Option C Phase 1）

**開始条件**: Phase 8完了後

| タスク | 工数 | 説明 |
|--------|------|------|
| CreateTodoUseCase抽出 | 8h | `addTodo()`ロジックをUseCaseに |
| UpdateTodoUseCase抽出 | 8h | `updateTodo()`ロジックをUseCaseに |
| DeleteTodoUseCase抽出 | 4h | `deleteTodo()`ロジックをUseCaseに |
| SyncTodoUseCase抽出 | 12h | `syncFromNostr()`ロジックをUseCaseに |
| テスト実装 | 8h | 各UseCaseのユニットテスト |

**合計工数**: 40時間（2週間）

---

### 🟢 Phase C: Repository層導入（Option C Phase 2）

**開始条件**: Phase B完了後

| タスク | 工数 | 説明 |
|--------|------|------|
| TodoRepository interface定義 | 4h | Repository抽象化 |
| TodoRepositoryImpl実装 | 16h | 永続化・同期ロジック |
| CustomListRepository実装 | 12h | カスタムリスト管理 |
| テスト実装 | 8h | Repository層のテスト |

**合計工数**: 40時間（2週間）

---

## 🎯 完了条件

### Phase 8完了条件（現在の目標）

- ✅ SyncLoadingOverlayが初回ログイン時のみ表示される
- ✅ MLSグループリストが作成できる
- ✅ グループリスト作成ダイアログへの導線が存在する
- ✅ Phase 8.1-8.4の全機能が動作する

### Option C Phase 1完了条件（Phase 8後）

- ✅ 主要なUseCaseが抽出されている
- ✅ 既存機能が全て動作する（リグレッションなし）
- ✅ UseCaseのユニットテストが存在する
- ✅ コードカバレッジ60%以上

### Option C Phase 2完了条件（Phase 1後）

- ✅ Repository層が実装されている
- ✅ ProviderがRepository経由でデータアクセス
- ✅ テスタビリティが向上
- ✅ コードカバレッジ80%以上

---

## 📚 参考資料

### 関連ドキュメント

- [MLS Beta Roadmap](./MLS_BETA_ROADMAP.md) - Phase 8の詳細
- [Clean Architecture Refactoring Plan](./CLEAN_ARCHITECTURE_REFACTORING_PLAN.md) - 当初の計画
- [Current Architecture Analysis](./CURRENT_ARCHITECTURE_ANALYSIS.md) - 現状分析

### 外部リソース

- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Riverpod Best Practices](https://riverpod.dev/docs/concepts/providers)
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)

---

## 🤝 チームへの推奨事項

### 短期（今週）

1. **Phase A（即座実施）を完了させる**
   - SyncLoadingOverlay修正（30分）
   - MLSグループリスト作成テスト（4時間）

2. **Phase 8完了を宣言**
   - MLS Beta版としてリリース可能状態に

### 中期（2週間後〜）

3. **Phase 9（Gift Wrap）の実装開始**
   - メタデータプライバシー保護が最優先

4. **Option C Phase 1を並行実施**
   - 新機能実装のついでに内部リファクタリング
   - UseCase抽出を段階的に

### 長期（1-2ヶ月後）

5. **完全なクリーンアーキテクチャ化**
   - Option C Phase 2-3を完了
   - ドキュメント整備

---

## 📞 質問・相談

このドキュメントについて質問がある場合：

1. **技術的な質問**: Issueを作成
2. **方針の変更提案**: Pull Request
3. **緊急の相談**: チャットで直接連絡

---

**更新履歴**:
- 2025-11-13: 初版作成

