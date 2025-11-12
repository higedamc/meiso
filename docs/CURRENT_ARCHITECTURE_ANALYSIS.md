# Meiso 現状アーキテクチャ分析

**作成日**: 2025-11-12  
**分析対象**: `refactor/clean-architecture`ブランチ

## 📊 コードベース概要

### ディレクトリ構造（現状）

```
lib/
├── main.dart
├── app_theme.dart
├── bridge_generated.dart/        # Rust FFI生成コード
├── l10n/                          # 多言語対応
├── models/                        # データモデル（freezed）
│   ├── todo.dart
│   ├── custom_list.dart
│   ├── app_settings.dart
│   ├── link_preview.dart
│   └── recurrence_pattern.dart
├── presentation/                  # 画面（Screen）
│   ├── home/
│   ├── list_detail/
│   ├── onboarding/
│   ├── planning_detail/
│   ├── settings/
│   └── someday/
├── providers/                     # Riverpod Providers
│   ├── todos_provider.dart        # 🚨 2497行の巨大ファイル
│   ├── custom_lists_provider.dart
│   ├── app_settings_provider.dart
│   ├── nostr_provider.dart
│   └── (他9ファイル)
├── services/                      # ビジネスロジック + インフラ層
│   ├── amber_service.dart
│   ├── local_storage_service.dart
│   ├── nostr_cache_service.dart
│   ├── nostr_subscription_service.dart
│   ├── link_preview_service.dart
│   ├── recurrence_parser.dart
│   ├── logger_service.dart
│   └── widget_service.dart
└── widgets/                       # 共通Widget
    ├── todo_item.dart
    ├── todo_column.dart
    ├── add_todo_field.dart
    └── (他10ファイル)
```

---

## 🔍 詳細分析

### 1. Providers層の肥大化

#### `todos_provider.dart` - 2497行

**問題点**:
- **責務の混在**: UI状態管理、ビジネスロジック、データアクセスが1ファイルに集約
- **テスト困難**: 密結合により単体テストが書きにくい
- **可読性低下**: 2400行以上のコードを追うのは困難
- **変更影響大**: 修正時のリグレッションリスクが高い

**主な機能**（すべて1クラスに混在）:
- Todo CRUD操作
- Nostr同期（バッチ同期、優先同期、マニュアル同期）
- Amber統合（署名、暗号化、復号化）
- リカーリングタスク処理
- リンクプレビュー統合
- 競合解決ロジック
- 並び替え・日付移動ロジック
- UI状態管理（AsyncValue）

**統計**:
```dart
// TodosNotifierクラスの概要
class TodosNotifier {
  // プライベートメソッド: 約50個
  // パブリックメソッド: 約15個
  // 行数: 2497行
  // 依存: 10+ サービス/プロバイダー
}
```

#### 他のProvider

| ファイル | 行数 | 責務 | 問題 |
|---------|------|------|------|
| `custom_lists_provider.dart` | ~800行 | カスタムリスト管理 | Todoと同様の肥大化 |
| `app_settings_provider.dart` | ~400行 | アプリ設定管理 | NIP-78同期ロジック混在 |
| `nostr_provider.dart` | ~600行 | Nostr接続管理 | リレー接続・再接続ロジック |

---

### 2. Services層の混在

#### 問題点
- **インフラとビジネスロジックの混在**: 同じファイルにHiveアクセスとビジネスルールが共存
- **再利用困難**: 他の機能から利用しにくい構造
- **テスト困難**: モック化が難しい

#### 具体例

**`local_storage_service.dart`**:
```dart
class LocalStorageService {
  // ✅ インフラ層の責務（適切）
  Future<List<Todo>> loadTodos();
  Future<void> saveTodos(List<Todo> todos);
  
  // ❌ ビジネスロジック（不適切、Provider層に依存）
  // -> この層に存在すべきでない
}
```

**`nostr_cache_service.dart`**:
```dart
class NostrCacheService {
  // ✅ キャッシュ管理（適切）
  Future<void> cacheEvent(String eventJson);
  
  // ⚠️ Rust API直接呼び出し（抽象化不足）
  final cacheInfo = await rust_api.createCacheInfo(...);
}
```

---

### 3. Models層の役割不明確

#### 問題点
- **ビジネスルールの欠如**: 単なるデータホルダー（Anemic Domain Model）
- **バリデーションなし**: タイトルの長さ制限などがModel側で保証されない
- **Value Object不在**: 日付やタイトルが単なるプリミティブ型

#### 具体例

**`todo.dart`**:
```dart
@Freezed()
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required String title,  // ❌ バリデーションなし
    @Default(false) bool completed,
    DateTime? date,         // ❌ 単なるDateTime、Value Objectではない
    // ...
  }) = _Todo;
}
```

**改善案（Value Object化）**:
```dart
class TodoTitle {
  const TodoTitle._(this.value);
  final String value;
  
  static Either<Failure, TodoTitle> create(String input) {
    if (input.isEmpty) return Left(ValidationFailure('タイトルを入力してください'));
    if (input.length > 500) return Left(ValidationFailure('タイトルは500文字以内'));
    return Right(TodoTitle._(input));
  }
}
```

---

### 4. Presentation層の構造

#### 問題点
- **Screen直結のProvider**: ViewModel不在
- **ビジネスロジックの混入**: Widget内でビジネスロジックを呼び出し
- **状態管理の複雑化**: AsyncValueの扱いが各Widgetに分散

#### 具体例

**`home_screen.dart`**:
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsyncValue = ref.watch(todosProvider);  // ❌ 直接Provider参照
    
    return todosAsyncValue.when(
      data: (groupedTodos) {
        // ❌ UI層でビジネスロジック（日付フィルタリング等）
        final todayTodos = groupedTodos[DateTime.now()];
        // ...
      },
      loading: () => LoadingWidget(),
      error: (e, s) => ErrorWidget(e),
    );
  }
}
```

**改善案（ViewModel導入）**:
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todosViewModelProvider);  // ✅ ViewModel経由
    
    if (state.isLoading) return LoadingWidget();
    if (state.errorMessage != null) return ErrorWidget(state.errorMessage);
    
    final todayTodos = state.todayTodos;  // ✅ ViewModel側でフィルタリング済み
    // ...
  }
}
```

---

### 5. 依存関係の分析

#### 現在の依存グラフ

```
┌─────────────────┐
│  Presentation   │
│   (Screens)     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│   Providers     │ ← 🚨 肥大化（2400行）
│ (TodosProvider) │
└────────┬────────┘
         │
         ↓
┌─────────────────┐      ┌─────────────────┐
│    Services     │ ←──→ │     Models      │
│  (ビジネス +    │      │  (データのみ)   │
│   インフラ)     │      │                 │
└────────┬────────┘      └─────────────────┘
         │
         ↓
┌─────────────────┐
│   Rust API      │
│   Hive/Nostr    │
└─────────────────┘
```

**問題**:
- 層の責務が不明確
- 双方向依存が存在
- テストしにくい構造

#### 目標の依存グラフ（Clean Architecture）

```
┌─────────────────┐
│  Presentation   │
│  (ViewModel)    │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Application    │
│   (UseCase)     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│     Domain      │ ← 🎯 中心（安定）
│  (Entity, Repo) │
└────────┬────────┘
         ↑
         │
┌────────┴────────┐
│ Infrastructure  │
│ (RepositoryImpl)│
└─────────────────┘
```

**メリット**:
- 単方向依存（上位層 → 下位層）
- Domain層が独立（テストしやすい）
- 責務の明確化

---

## 📈 メトリクス

### コード量

| カテゴリ | ファイル数 | 推定行数 |
|---------|-----------|---------|
| Models | 5 | ~500行 |
| Providers | 13 | ~6000行 |
| Services | 8 | ~2000行 |
| Presentation | 18 | ~3000行 |
| Widgets | 13 | ~2000行 |
| **合計** | **57** | **~13500行** |

### 問題の優先度

| 問題 | 深刻度 | 影響範囲 | 対応優先度 |
|------|--------|----------|-----------|
| TodosProviderの肥大化 | 🔴 高 | Todo機能全体 | 最優先 |
| Services層の混在 | 🟠 中 | 全機能 | 高 |
| Models層の貧弱さ | 🟡 中 | 全機能 | 中 |
| Presentation層の構造 | 🟡 中 | UI全体 | 中 |

---

## 🎯 リファクタリングの必要性

### なぜ今リファクタリングすべきか？

1. **保守性の限界**
   - 2400行のファイルは誰も全体を把握できない
   - 変更時のリグレッションリスクが極めて高い
   - 新メンバーのオンボーディングが困難

2. **拡張性の欠如**
   - 新機能追加時に既存コードへの影響が大きすぎる
   - 機能間の依存が複雑で、影響範囲の予測が困難

3. **テスタビリティの欠如**
   - 単体テストが書けない（書きにくい）
   - E2Eテストのみに依存せざるを得ない

4. **技術的負債の蓄積**
   - 将来的な大規模リファクタリングがより困難に
   - 今なら段階的移行が可能

### リファクタリングしない場合のリスク

- ✗ バグ修正が困難化（影響範囲の特定が難しい）
- ✗ 開発速度の低下（コード理解に時間がかかる）
- ✗ チームスケールの限界（新メンバーが貢献できない）
- ✗ 技術的負債の雪だるま式増加

---

## 💡 改善方向性

### Phase 1: Core層整備
→ Either型、UseCase、Failureの基盤構築

### Phase 2-5: Todo機能のクリーンアーキテクチャ化
→ 2400行の`TodosProvider`を以下に分割:
- Domain: Entity, Repository Interface, Errors
- Application: 7-10個のUseCase（Create, Update, Delete, Toggle, Sync等）
- Infrastructure: RepositoryImpl, DataSources
- Presentation: ViewModel, State

### Phase 6: 他機能への展開
→ CustomList, Settings等も同様のパターンで移行

### Phase 7: テスト・ドキュメント
→ 各層の単体テスト、実装ガイドライン

---

## 📚 参考データ

### 現在の技術スタック

```yaml
dependencies:
  flutter_riverpod: ^2.6.1  # ✅ そのまま活用
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  hive: ^2.2.3
  flutter_rust_bridge: ^2.0.0
  # dartz: なし（独自Either型を実装予定）
```

### Meisoの特徴的な機能

1. **Nostr統合**
   - NIP-44暗号化（end-to-end）
   - NIP-78（Application-specific data）
   - リレー同期・接続管理

2. **Amber統合**
   - 署名（NIP-55）
   - 暗号化・復号化（NIP-44）
   - Intent連携（Android）

3. **Rust連携**
   - Flutter Rust Bridge
   - 暗号処理の高速化
   - Nostr鍵管理（Argon2id + AES-256-GCM）

---

## ✅ 次のステップ

1. ✅ 現状分析完了
2. ✅ リファクタリング計画策定完了（`CLEAN_ARCHITECTURE_REFACTORING_PLAN.md`）
3. 🔄 Oracleとのレビュー・合意
4. 🚀 Phase 1開始

---

**作成日**: 2025-11-12  
**最終更新**: 2025-11-12  
**ステータス**: ✅ 分析完了 → 🔄 Oracleレビュー待ち

