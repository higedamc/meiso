# Clean Architectureリファクタリング・インシデント報告

**発生日**: 2025-11-12  
**報告日**: 2025-11-13  
**ステータス**: ✅ 対応方針決定、再実装開始

---

## 📋 インシデント概要

Clean Architectureリファクタリング作業中に、作業ブランチの間違いとPhase 8（MLSグループリスト）との統合競合により、**Domain/Infrastructure/Application層（40ファイル以上）を削除**してしまった。

---

## 🔍 詳細タイムライン

### 2025-11-12 23:36 - コミット `8e2e573`

**操作**: Clean Architecture実装を全削除

```bash
commit 8e2e5730b0e146229bb873615718ad4b63150a49
Author: Kohei Otani
Date:   Wed Nov 12 23:36:06 2025 +0900

    fix: Clean Architecture互換レイヤーを削除し旧Providerに完全復帰
    
    - features/ディレクトリを全削除
    - 全ファイルで旧Providerへの参照に戻す
    - feature/amber-group-list-phase2の実装を保持
```

**削除されたファイル（40ファイル以上）**:
```
features/todo/
├── domain/ (5ファイル)
├── infrastructure/ (2ファイル)
└── application/ (7ファイル以上)

features/custom_list/
├── domain/ (5ファイル)
├── infrastructure/ (2ファイル)
└── application/ (6ファイル)

features/settings/
├── domain/ (3ファイル)
├── infrastructure/ (3ファイル)
├── application/ (10ファイル)
└── presentation/ (5ファイル)
```

### 2025-11-12 23:46 - コミット `d72c5bd`

**操作**: Presentation層（ViewModel）のみ復元

```bash
commit d72c5bd5794478503f5dc7fe06737a22d8e4b03b
Author: Kohei Otani
Date:   Wed Nov 12 23:46:58 2025 +0900

    feat: Clean Architectureリファクタリング完全実装
    
    - TodoListViewModel/State実装（同期タイマー付き）
    - CustomListViewModel/State実装（デフォルトリスト作成付き）
    - 互換レイヤー（compat providers）実装
```

**復元されたファイル（10ファイルのみ）**:
```
features/todo/presentation/
├── providers/ (2ファイル)
└── view_models/ (3ファイル)

features/custom_list/presentation/
├── providers/ (2ファイル)
└── view_models/ (3ファイル)
```

---

## 🎯 根本原因分析

### 1. 作業ブランチの間違い

Oracleの証言:
> 途中で作業ブランチを間違っていたことに気づき

- 当初は`CLEAN_ARCHITECTURE_REFACTORING_PLAN.md`に基づき実装
- 途中で別ブランチ（`feature/amber-group-list-phase2`）との競合が発生
- ブランチ切り替えや統合の過程で実装が失われた

### 2. Phase 8（MLS）優先判断

- Phase 8（MLSグループリスト作成）が最優先タスクだった
- Clean Architecture実装とPhase 8実装が競合
- **Phase 8を守るために、Clean Architecture実装を削除する判断**

### 3. コンパイルエラー/動作不良

推測される技術的問題:
- 互換レイヤーのインターフェース不一致
- UIとViewModel間の状態同期エラー
- Nostr同期ロジックの重複実行
- タイプミスや参照エラー

---

## 📊 実際の進捗状況（2025-11-13判明）

### ドキュメント vs 実装の乖離

**CLEAN_ARCHITECTURE_REFACTORING_PLAN.md**:
```
| Phase 1 | Core層基盤 | ✅ 完了 |
| Phase 2 | Todo Domain | ✅ 完了 |
| Phase 3 | Todo Infrastructure | ✅ 完了 |
| Phase 4 | Todo Application | ✅ 完了 |
| Phase 5 | Todo Presentation | ✅ 完了 |
| Phase 6 | Provider統合 | ✅ 完了 |
| Phase 7 | UI統合・ViewModels | ✅ 完了 |
| Phase 8 | 他機能展開 | ✅ 完了 |
```

**実際の実装状況**:
```
| Phase 1 | Core層基盤 | ✅ 完了 |
| Phase 2 | Todo Domain | ❌ 削除済み |
| Phase 3 | Todo Infrastructure | ❌ 削除済み |
| Phase 4 | Todo Application | ❌ 完了 |
| Phase 5-7 | Todo Presentation | ⚠️ 存在するが未使用 |
| Phase 8 | 他機能展開 | ❌ 削除済み（旧Providerに実装） |
```

**実際の進捗**: **約20%**（Phase 1 + Phase A完了のみ）

---

## 🛡️ 保護された実装

### 旧Provider構造（完全動作中）

幸いにも、以下の旧実装は削除されず、**完全に機能している**:

```
lib/providers/
├── todos_provider.dart (3,594行) ✅
│   - 全CRUD操作
│   - Nostr同期（NIP-44暗号化）
│   - MLS統合（グループタスク同期）
│   - Amber/秘密鍵モード
│   - バッチ同期タイマー
│   - 繰り返しタスク
│   - リンクプレビュー
│
└── custom_lists_provider.dart (966行) ✅
    - カスタムリスト管理
    - MLSグループリスト作成（Phase 8.1-8.4）
    - Key Package管理
    - 招待システム
```

**Phase 8の全機能も含めて完全実装済み**

---

## ✅ 対応方針（2025-11-13決定）

### Oracleの決定

> なるほど。３の長期アクションを選択しましょう。リファクタリング前提で完全にclean architectureに置き換える予定なので、悩む必要はありません。
> 
> 進捗状況の要約表におけるPhase 2 to Phase 7まで実装してしまいましょう。

### 実装計画

**方針**: 削除された層を全て再実装し、完全なClean Architectureへ移行

**スケジュール**:
```
Phase 2: Todo Domain層        → 3-4時間（即座実施）
Phase 3: Todo Infrastructure層 → 4-5時間
Phase 4: Todo Application層    → 3-4時間
Phase 5-7: Todo Presentation層 → 5-6時間
合計: 15-19時間（2-3日）
```

**完了条件**:
1. ✅ Domain/Infrastructure/Application層が完全実装
2. ✅ ViewModelが実際に使用される
3. ✅ UIが新アーキテクチャ経由でデータアクセス
4. ✅ 既存機能が全て動作（リグレッションなし）
5. ✅ テストが全てパス

---

## 📚 学んだ教訓

### 1. ブランチ管理の重要性

**問題**:
- 作業ブランチを間違えた
- 複数の大規模変更（Clean Architecture + Phase 8）を同時進行

**対策**:
- ブランチ切り替え前に必ず`git status`確認
- 大規模リファクタリングは専用ブランチで隔離
- 並行する大規模変更は避ける

### 2. 段階的コミットの重要性

**問題**:
- 大量のファイルを一度に削除（40ファイル以上）
- ロールバックポイントが不明確

**対策**:
- 各Phase完了ごとにコミット
- コミットメッセージに具体的な変更内容を記載
- 削除操作は特に慎重に

### 3. ドキュメント vs 実装の同期

**問題**:
- ドキュメントは「Phase 1-8完了」だが、実装は約20%
- 進捗状況の誤認

**対策**:
- コミット後に必ずドキュメント更新
- 定期的なコードベースレビュー
- 進捗確認時は実際のファイル存在を確認

### 4. テストの重要性

**問題**:
- 20個のテストファイルが存在するが、実装コードがないため実行不可能
- リグレッション検知ができない

**対策**:
- テスト駆動開発（TDD）の徹底
- CI/CDでの自動テスト実行
- テスト失敗時はコミット不可

---

## 🚀 今後のアクション

### 短期（今週）

1. ✅ インシデント報告書作成（本ドキュメント）
2. 🔄 Phase 2-7の再実装
3. 🔄 テストの復元と実行確認
4. 🔄 ドキュメント更新

### 中期（2週間後）

1. Phase 8機能のClean Architecture化
2. Settings機能のClean Architecture化
3. コードカバレッジ80%達成

### 長期（1ヶ月後）

1. 旧Provider完全削除
2. Phase 9（Gift Wrap）実装
3. プロダクションリリース

---

## 📞 関連ドキュメント

- [REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md](./REFACTOR_CLEAN_ARCHITECTURE_STRATEGY.md) - 正確な現状分析
- [CLEAN_ARCHITECTURE_REFACTORING_PLAN.md](./CLEAN_ARCHITECTURE_REFACTORING_PLAN.md) - 当初の計画（進捗は不正確）
- [MLS_BETA_ROADMAP.md](./MLS_BETA_ROADMAP.md) - Phase 8詳細

---

**作成日**: 2025-11-13  
**最終更新**: 2025-11-13  
**ステータス**: ✅ 対応方針決定、Phase 2実装開始

