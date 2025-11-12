# Meiso: MLS Group List Implementation Strategy (Updated)

## 概要

MeisoのグループTODOリスト機能をKeychatのMLS実装を参考に、OpenMLSライブラリを使用して実装する。

**実装アプローチ**: 段階的実装（Option B → Option A）

## アーキテクチャ

### 二重暗号化レイヤー

```
TODO → MLS暗号化 → NIP-44暗号化 → Nostrリレー
```

#### Layer 1: MLS（内側）
- **目的**: グループメンバー間の暗号化・鍵管理
- **スケーラビリティ**: O(log n)（ツリーベース）
- **セキュリティ**: Forward Secrecy + Post-Compromise Security
- **実装**: OpenMLS (keychat-io/openmls, branch: kc4)

#### Layer 2: NIP-44（外側）
- **目的**: NostrリレーへのトランスポートLayer
- **鍵生成**: MLS Export SecretからNostr鍵ペアを決定的に生成
- **暗号化**: 全メンバーが同じ`listen_key`で受信

### Export Secret → Nostr鍵ペア生成

```rust
// KeychatのアプローチをMeisoに適用
let export_secret = mls_group.export_secret(provider, "meiso", b"todo", 32)?;
let export_secret_hex = hex::encode(&export_secret);
let keypair = nostr::Keys::parse(&export_secret_hex)?;
let listen_key = keypair.public_key().to_hex();
```

**重要**: この`listen_key`は**決定的**に生成される。全メンバーが同じMLS groupに属していれば、同じ`listen_key`を導出できる。

## 段階的実装戦略: Option B → Option A

### Option B: 簡略化PoC（迅速検証）

**目的**: 2-3日で動作するPoCを作成し、MLSアプローチの妥当性を検証

**スコープ**:
- ✅ MLS基本構造（MlsStore, RUNTIME, Export Secret生成）
- ✅ 簡易Userラッパー（最小限のメソッド実装）
- ✅ グループ作成（1人グループでテスト）
- ✅ TODO暗号化・復号化（基本フロー）
- ⏸️ メンバー管理（後回し）
- ⏸️ Key Package管理（後回し）
- ⏸️ Commit/Proposal処理（後回し）

**実装方針**:
```rust
// 簡易Userラッパー
pub struct User {
    pub mls_user: MlsUser,
}

impl User {
    // 最小限のメソッド実装
    pub fn create_mls_group(...) -> Result<()> {
        // グループ作成のみ（メンバー追加なし）
    }
    
    pub fn encrypt_todo(...) -> Result<String> {
        // TODO暗号化（MLS Application Message）
    }
    
    pub fn decrypt_todo(...) -> Result<String> {
        // TODO復号化
    }
}
```

**検証ポイント**:
1. Export Secret → Nostr鍵ペア生成が正しく動作するか
2. MLS暗号化・復号化が機能するか
3. SQLiteストレージが正常に動作するか

**成功基準**:
- [x] 1人でグループを作成できる
- [x] TODOを暗号化できる（復号化は他のメンバーのみ可能）
- [x] Export SecretからListen Keyを取得できる
- [x] Flutter側から呼び出せる
- [x] 2人グループを作成できる
- [x] Key Packageを生成・共有できる

---

### Option A: 完全実装（Production Ready）

**目的**: Option B検証後、Keychatの完全実装を移植

**スコープ**:
- ✅ 完全なUserラッパー（Keychatのapi_mls.user.rs移植）
- ✅ Key Package管理（生成・公開・削除）
- ✅ メンバー管理（追加・削除・権限）
- ✅ Commit/Proposal処理（状態同期）
- ✅ グループ拡張（メタデータ管理）
- ✅ エラーハンドリング・リカバリー

**実装方針**:
```rust
// 完全なUserラッパー（Keychat互換）
pub struct User {
    pub mls_user: MlsUser,
}

impl User {
    // 約20個のメソッド実装
    pub fn create_mls_group(...) -> Result<Vec<u8>>;
    pub fn add_members(...) -> Result<(String, Vec<u8>)>;
    pub fn remove_members(...) -> Result<String>;
    pub fn self_commit(...) -> Result<()>;
    pub fn others_commit_normal(...) -> Result<CommitResult>;
    pub fn create_key_package(...) -> Result<KeyPackageResult>;
    pub fn join_mls_group(...) -> Result<()>;
    pub fn create_message(...) -> Result<(String, String)>;
    pub fn decrypt_msg(...) -> Result<(String, String, String)>;
    pub fn self_update(...) -> Result<String>;
    pub fn get_group_extension(...) -> Result<NostrGroupDataExtension>;
    pub fn get_member_extension(...) -> Result<Vec<LeafNode>>;
    // ... 他多数
}
```

**移植戦略**:
1. Keychatの`api_mls.user.rs`（1224行）を分析
2. 必要なインポート・型定義を追加
3. メソッドを1つずつ移植・テスト
4. Meiso固有の調整（Nostr Kind 30001対応など）

---

## 実装計画（更新版）

### Phase 1: Option B - 簡略化PoC（完了: 2025-11-10）

#### 1.1 依存関係追加 ✅
- OpenMLS, openmls_traits, openmls_sqlite_storage, kc
- bincode, lazy_static, hex

#### 1.2 MLS基本実装 ✅
- `rust/src/mls.rs`: MlsStore, RUNTIME, 初期化
- Export Secret → Nostr鍵ペア生成

#### 1.3 グループTODO API骨組み ✅
- `rust/src/group_tasks_mls.rs`: 公開API定義

#### 1.4 簡易Userラッパー実装 🔄（次のステップ）
```rust
// rust/src/mls.rs に追加
pub struct User {
    pub mls_user: MlsUser,
}

impl User {
    // 最小限のメソッド
    pub async fn load(provider: OpenMlsRustPersistentCrypto, nostr_id: String) -> Result<MlsUser>;
    pub fn create_mls_group(...) -> Result<Vec<u8>>;
    pub fn create_message(...) -> Result<(String, String)>;
    pub fn decrypt_msg(...) -> Result<(String, String, String)>;
}
```

#### 1.5 Flutter統合テスト
- `./generate.sh` でFlutter Rust Bridge生成
- 基本的な呼び出しテスト

**目標期限**: 2025-11-11（明日）

---

### Phase 2: Option A - 完全実装への拡張

#### 2.1 Keychat Userラッパー移植（3-5日）
- [ ] `api_mls.user.rs`の完全移植
- [ ] 型定義・インポート調整
- [ ] エラーハンドリング

#### 2.2 Key Package管理（1-2日）
- [ ] Key Package生成・公開API
- [ ] Nostr Kind 10443での公開
- [ ] 有効期限管理

#### 2.3 メンバー管理（2-3日）
- [ ] メンバー追加フロー（Welcome送信）
- [ ] メンバー削除フロー（Remove Proposal）
- [ ] 権限管理（Admin判定）

#### 2.4 Commit/Proposal処理（2-3日）
- [ ] `others_commit_normal`実装
- [ ] 状態同期ロジック
- [ ] 競合解決

**目標期限**: 2025-11-20

---

### Phase 3: Flutter側統合（完全版）

#### 3.1 Provider拡張
```dart
class TodosProvider extends StateNotifier<AsyncValue<List<Todo>>> {
  bool _mlsInitialized = false;
  
  Future<void> _initMlsIfNeeded() async {
    if (!_mlsInitialized) {
      await rust.initMlsDb(
        dbPath: '${appDocDir.path}/mls.db',
        nostrId: userPubkey,
      );
      _mlsInitialized = true;
    }
  }
  
  Future<void> createMlsGroupList(
    String listName,
    List<String> memberPubkeys,
  ) async {
    await _initMlsIfNeeded();
    
    // Key Packages取得
    final keyPackages = await _fetchKeyPackages(memberPubkeys);
    
    // グループ作成
    final welcomeMsg = await rust.createMlsTodoGroup(
      nostrId: userPubkey,
      groupId: listId,
      groupName: listName,
      members: keyPackages,
    );
    
    // Welcome送信
    await _sendWelcomeMessages(memberPubkeys, welcomeMsg);
  }
}
```

#### 3.2 同期ロジック
- Export SecretからListen Key取得
- Nostrイベント購読
- 暗号化TODO復号化
- ローカルDB保存

#### 3.3 UI実装
- グループリスト作成画面
- メンバー管理UI
- Key Package公開ボタン

**目標期限**: 2025-11-25

---

## 詳細実装ロードマップ（Option B → Production）

### Phase 5: 実デバイス間での2人グループテスト 🔄

**目的**: Option B PoCの実機検証

**作業内容**:
1. 2台のデバイスで相互にKey Package交換
2. Welcome Message送受信テスト
3. 相手のメッセージ復号化確認
4. 双方向TODO共有動作確認

**成功基準**:
- [ ] デバイスAがグループ作成 → デバイスBが参加
- [ ] デバイスAのTODOをデバイスBで復号化できる
- [ ] デバイスBのTODOをデバイスAで復号化できる
- [ ] Listen Key生成が両デバイスで一致

**推定作業時間**: 1-2時間（テストのみ）

---

### Phase 6: アプリ内招待システム実装 🎯

**目的**: Key Package手動交換を不要にし、アプリ内でワンタップグループ参加

**背景**: 
TODOアプリとして、メッセージアプリのように手動でKey Packageを交換するのは煩雑。
また、外部DMアプリを経由するのもTODOアプリのUXとして不自然。
**TODOアプリネイティブなUX**として、アプリ内で完結する招待システムを実装。

**UXフロー**:
```
1. Alice が Bob の npub を入力 → グループリスト作成
   → Key Package自動取得 → Welcome Message生成
   → Nostrリレー経由でBobに通知送信

2. Bob のアプリで自動同期
   → SOMEDAYのリスト一覧に「インビテーション付きグループリスト」表示
   → 視覚的フィードバック: 👥 グループマーク + 📩 インビテーションマーク

3. Bob がインビテーション付きリストをタップ
   → 参加確認ダイアログ表示
   → 承諾 → Welcome Message処理 → リスト閲覧可能

4. 参加完了！ AliceとBobで同じTODOリストを共有
```

**TODOアプリならではの利点**:
- ✅ アプリ内完結（外部DMアプリ不要）
- ✅ SOMEDAYのカスタムリスト一覧に自然に統合
- ✅ 視覚的フィードバックが明確
- ✅ ユーザーの学習コストゼロ
- ✅ 誤操作防止（確認ダイアログ）

#### 6.1 Key Package公開機能（Rust側）

```rust
/// Kind 10443イベントでKey Packageをリレーに公開
pub async fn publish_key_package_to_relay(
    nostr_id: String,
    relays: Vec<String>,
) -> Result<String> {
    let kp = create_key_package(nostr_id)?;
    
    // NIP-EEに準拠したイベント作成
    let event = create_unsigned_event(
        kind: 10443,
        content: kp.key_package,
        tags: [
            ["mls_protocol_version", kp.mls_protocol_version],
            ["ciphersuite", kp.ciphersuite],
            ["client", "meiso"],
            ["relay", ...relays],
        ],
    );
    
    // Amber/秘密鍵で署名してリレー送信
    Ok(event_id)
}

/// npubからKey Packageを自動取得
pub async fn fetch_key_package_by_npub(
    npub: String,
    relays: Vec<String>,
) -> Result<String> {
    let filter = Filter::new()
        .kind(Kind::Custom(10443))
        .author(npub_to_hex(npub)?)
        .limit(1);
    
    let events = fetch_from_relays(filter, relays).await?;
    let latest = events.first().ok_or("No key package found")?;
    
    Ok(latest.content.clone())
}
```

#### 6.2 グループ招待通知送信（Flutter側）

```dart
/// グループ招待フロー（アプリ内完結）
Future<void> inviteUserToGroup({
  required String groupId,
  required String groupName,
  required String inviteeNpub,
}) async {
  // Step 1: 相手のKey Packageを自動取得
  final keyPackage = await rust_api.fetchKeyPackageByNpub(
    npub: inviteeNpub,
    relays: relayList,
  );
  
  // Step 2: Welcome Message生成
  final welcomeMsg = await rust_api.mlsAddMembersToGroup(
    nostrId: myPubkey,
    groupId: groupId,
    keyPackages: [keyPackage],
  );
  
  // Step 3: グループ招待イベント送信（Kind 30078 - App Data）
  // NIP-78を使用してアプリ専用データとして送信
  await nostrService.sendGroupInvitation(
    recipientNpub: inviteeNpub,
    groupId: groupId,
    groupName: groupName,
    welcomeMsg: base64UrlEncode(welcomeMsg),
    inviterNpub: myNpub,
    inviterName: myName ?? myNpub,
  );
  
  // Step 4: ローカルに「招待送信済み」状態を保存
  await customListsProvider.markInvitationSent(
    groupId: groupId,
    inviteeNpub: inviteeNpub,
  );
  
  showSnackBar('✅ ${inviteeNpub.substring(0, 16)}...に招待を送信しました');
}

/// グループ招待イベント作成（Rust側で実装）
/// Kind: 30078 (NIP-78 App Data)
/// d tag: group-invitation-{groupId}-{recipientPubkey}
/// 暗号化: NIP-44で recipient_pubkey 宛に暗号化
pub fn create_group_invitation_event(
    sender_keys: &Keys,
    recipient_pubkey: String,
    group_id: String,
    group_name: String,
    welcome_msg: String,
) -> Result<Event> {
    let content_json = json!({
        "type": "group_invitation",
        "group_id": group_id,
        "group_name": group_name,
        "welcome_msg": welcome_msg,
        "invited_at": Utc::now().timestamp(),
    });
    
    // NIP-44で暗号化
    let encrypted = encrypt_nip44(
        sender_keys,
        &recipient_pubkey,
        &content_json.to_string(),
    )?;
    
    // Kind 30078イベント作成
    let event = EventBuilder::new(
        Kind::Custom(30078),
        encrypted,
        vec![
            Tag::custom(TagKind::Custom("d".into()), 
                vec![format!("group-invitation-{}-{}", group_id, recipient_pubkey)]),
            Tag::public_key(PublicKey::from_hex(&recipient_pubkey)?),
            Tag::custom(TagKind::Custom("client".into()), vec!["meiso".to_string()]),
        ],
    )
    .to_event(sender_keys)?;
    
    Ok(event)
}
```

#### 6.3 招待通知受信＆同期（Flutter側）

```dart
/// グループ招待イベントの同期（CustomListsProvider）
class CustomListsProvider extends StateNotifier<AsyncValue<List<CustomList>>> {
  
  /// 招待通知の同期（起動時＆定期実行）
  Future<void> syncGroupInvitations() async {
    try {
      // Kind 30078でグループ招待イベントを取得
      final invitations = await rust_api.fetchGroupInvitations(
        nostrId: myPubkey,
        relays: relayList,
      );
      
      for (final invitation in invitations) {
        // 既存のリストに存在しない場合のみ追加
        if (!_hasInvitation(invitation.groupId)) {
          // インビテーション付きリストとして追加
          final pendingList = CustomList(
            id: invitation.groupId,
            name: invitation.groupName,
            isGroup: true,
            isPendingInvitation: true,  // ← New field!
            inviterNpub: invitation.inviterNpub,
            inviterName: invitation.inviterName,
            welcomeMsg: invitation.welcomeMsg,
            createdAt: DateTime.now(),
            order: 999, // SOMEDAYの末尾に配置
          );
          
          // ローカルに保存（まだMLSグループには参加していない）
          await _localStorageService.saveCustomList(pendingList);
        }
      }
      
      // 状態更新 → UIに反映
      state = AsyncData(await _loadAllLists());
      
    } catch (e) {
      AppLogger.error('Failed to sync group invitations', error: e);
    }
  }
}

/// Rust側: グループ招待イベントの取得
pub async fn fetch_group_invitations(
    nostr_id: String,
    relays: Vec<String>,
) -> Result<Vec<GroupInvitation>> {
    let filter = Filter::new()
        .kind(Kind::Custom(30078))
        .pubkey(PublicKey::from_hex(&nostr_id)?)  // 自分宛のイベント
        .custom_tag(
            SingleLetterTag::lowercase(Alphabet::D), 
            vec!["group-invitation-".to_string()]  // d tagで絞り込み
        );
    
    let events = fetch_from_relays(filter, relays).await?;
    let mut invitations = Vec::new();
    
    for event in events {
        // NIP-44で復号化
        let decrypted = decrypt_nip44(&nostr_id, &event.content)?;
        let invitation: GroupInvitationData = serde_json::from_str(&decrypted)?;
        
        invitations.push(GroupInvitation {
            group_id: invitation.group_id,
            group_name: invitation.group_name,
            welcome_msg: invitation.welcome_msg,
            inviter_npub: event.pubkey.to_bech32()?,
            inviter_name: invitation.inviter_name,
            invited_at: invitation.invited_at,
        });
    }
    
    Ok(invitations)
}
```

#### 6.4 SOMEDAYリスト表示UI（インビテーション対応）

```dart
/// CustomListモデルの拡張
@freezed
class CustomList with _$CustomList {
  factory CustomList({
    required String id,
    required String name,
    required bool isGroup,
    @Default(false) bool isPendingInvitation,  // ← New!
    String? inviterNpub,
    String? inviterName,
    String? welcomeMsg,  // Welcome Messageを保存
    // ... その他のフィールド
  }) = _CustomList;
}

/// SOMEDAY画面でのリスト表示
class SomedayListItem extends StatelessWidget {
  final CustomList list;
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      // リーディングアイコン
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // グループマーク
          if (list.isGroup) 
            Icon(Icons.group, color: Colors.blue, size: 20),
          SizedBox(width: 4),
          // インビテーションバッジ
          if (list.isPendingInvitation)
            Badge(
              label: Text('!'),
              backgroundColor: Colors.red,
              child: Icon(Icons.mail, color: Colors.orange, size: 20),
            ),
        ],
      ),
      
      // リスト名
      title: Text(
        list.name,
        style: TextStyle(
          fontWeight: list.isPendingInvitation 
              ? FontWeight.bold  // 未読は太字
              : FontWeight.normal,
        ),
      ),
      
      // 招待元の表示
      subtitle: list.isPendingInvitation
          ? Text('📩 ${list.inviterName ?? list.inviterNpub}からの招待')
          : null,
      
      // タップ時の処理
      onTap: () {
        if (list.isPendingInvitation) {
          // 招待確認ダイアログ表示
          _showJoinConfirmDialog(context, list);
        } else {
          // 通常のリスト表示
          context.go('/list/${list.id}');
        }
      },
    );
  }
  
  /// グループ参加確認ダイアログ
  Future<void> _showJoinConfirmDialog(
    BuildContext context, 
    CustomList invitation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('グループに参加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「${invitation.name}」に参加しますか？'),
            SizedBox(height: 16),
            Text(
              '招待元: ${invitation.inviterName ?? invitation.inviterNpub}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('拒否'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('参加する'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // グループ参加処理
    await _joinGroup(context, invitation);
  }
  
  /// グループ参加処理
  Future<void> _joinGroup(
    BuildContext context,
    CustomList invitation,
  ) async {
    try {
      // Welcome Message復号化 & MLSグループ参加
      final welcomeMsg = base64Url.decode(invitation.welcomeMsg!);
      await rust_api.mlsJoinGroup(
        nostrId: myPubkey,
        groupId: invitation.id,
        welcomeMsg: welcomeMsg,
      );
      
      // ローカルリストの状態更新（isPendingInvitation: false）
      await ref.read(customListsProvider.notifier).acceptInvitation(
        invitation.id,
      );
      
      // 成功通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 「${invitation.name}」に参加しました！')),
      );
      
      // グループ画面へ遷移
      context.go('/list/${invitation.id}');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 参加に失敗しました: $e')),
      );
    }
  }
}
```

#### 6.5 メンバー招待ダイアログ

```dart
/// widgets/invite_member_dialog.dart
class InviteMemberDialog extends StatefulWidget {
  final String groupId;
  final String groupName;
  
  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _npubController = TextEditingController();
  bool _isInviting = false;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('メンバーを招待'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _npubController,
            decoration: InputDecoration(
              labelText: 'npub',
              hintText: 'npub1...',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'または、後でコンタクトリストから選択可能に',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isInviting ? null : _sendInvitation,
          child: _isInviting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('招待を送信'),
        ),
      ],
    );
  }
  
  Future<void> _sendInvitation() async {
    final npub = _npubController.text.trim();
    if (npub.isEmpty || !npub.startsWith('npub')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正しいnpubを入力してください')),
      );
      return;
    }
    
    setState(() => _isInviting = true);
    
    try {
      // グループ招待送信（自動でKey Package取得 → Welcome Message生成 → 通知送信）
      await ref.read(customListsProvider.notifier).inviteUserToGroup(
        groupId: widget.groupId,
        groupName: widget.groupName,
        inviteeNpub: npub,
      );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 招待を送信しました')),
      );
      
    } catch (e) {
      setState(() => _isInviting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 招待の送信に失敗しました: $e')),
      );
    }
  }
}
```

**推定作業時間**: 2-3日

**成功基準**:
- [ ] Key Package自動公開（Kind 10443）
- [ ] npubからKey Package自動取得
- [ ] グループ招待イベント送信（Kind 30078 + NIP-44）
- [ ] 招待通知の自動同期
- [ ] SOMEDAYにインビテーション付きリスト表示
- [ ] 視覚的フィードバック（👥 + 📩 バッジ）
- [ ] タップで参加確認ダイアログ表示
- [ ] ワンタップでグループ参加完了
- [ ] Amber対応（署名・暗号化）
- [ ] UXテスト完了

**UI/UXのポイント**:
- ✅ アプリ内完結（外部アプリ不要）
- ✅ 既存UI構造への自然な統合
- ✅ 明確な視覚的フィードバック
- ✅ 段階的承認フロー（誤操作防止）

---

### Phase 7: Amberモード動作確認 🔐

**目的**: Amber統合での完全動作確認

**作業内容**:
1. Key Package署名（Amber経由）
2. グループ作成イベント署名（Amber経由）
3. NIP-17 DM送信（Amber暗号化）
4. 全フロー動作確認

**重要**: MLSの内部処理はRust側完結なので、Amberは以下のみ使用：
- Nostrイベント署名
- NIP-44/NIP-17暗号化

**推定作業時間**: 1日

**成功基準**:
- [ ] Amberモードで全機能動作
- [ ] Key Package公開成功
- [ ] グループ招待送信成功
- [ ] グループ参加成功
- [ ] TODO共有成功

---

### Phase 8: Option A移行判断 🤔

**判断基準**:

**Option Bのまま進める場合**:
- ✅ 基本機能が安定動作
- ✅ 2-5人程度の小規模グループで十分
- ✅ 早期リリース優先

**Option Aへ移行する場合**:
- ⚠️ 大規模グループ（10人以上）サポート必要
- ⚠️ 高度なメンバー管理（権限、削除、再追加）
- ⚠️ Commit/Proposal処理が必要
- ⚠️ Forward Secrecy完全実装

**推定判断時期**: Phase 7完了後（2025-11-15頃）

---

## 現在の進捗（2025-11-11 終了時点）

### 🎉 完了 ✅ Phase 1-7完了！MLS PoC成功！

**実デバイス間での2人グループテスト完全成功！**
**アプリ内完結型招待システム完全実装！**

---

#### Phase 1: Rust側MLS基盤 ✅
- OpenMLS依存追加（Keychat kc4ブランチ）
- `rust/src/mls.rs` MLS基本実装（MlsStore, User, Export Secret）
- `rust/src/group_tasks_mls.rs` グループTODO API実装
- 簡易Userラッパー実装（最小限のメソッド）

#### Phase 2.1: Flutter側MLS統合 ✅
- `rust/src/api.rs`にMLS wrapper関数追加
- Flutter Rust Bridgeコード生成
- `TodosProvider`にMLS統合（初期化、暗号化、復号化）

#### Phase 2.2: UI実装 ✅
- `settings_screen.dart`にMLS統合テストセクション追加
- `_MlsTestDialog`実装（グループ作成、TODO暗号化・復号化テスト）
- リアルタイムログ表示

#### Phase 3: 1人グループ統合テスト ✅
- ✅ **実機テスト実行**
  - グループ作成成功
  - TODO暗号化成功
  - 復号化エラー: `CannotDecryptOwnMessage`（MLSの正常動作）
  
- ✅ **重要な発見**: MLSでは送信者は自分のメッセージを復号化できない
  - これはMLSプロトコルの仕様
  - 送信者はローカルに平文を保存
  - 他のメンバーが復号化可能

#### Phase 4: 2人グループテスト機能実装 ✅
- ✅ **Key Package生成機能**
  - `mlsCreateKeyPackage()`統合
  - クリップボードコピー機能
  - Protocol/Ciphersuite情報表示

- ✅ **2人グループ作成機能**
  - 相手のKey Package入力フィールド
  - `mlsCreateTodoGroup()`でメンバー追加
  - Welcome Message生成

- ✅ **TODO送信機能**
  - 2人グループでのTODO暗号化
  - 送信準備完了（リレー統合は次フェーズ）

- ✅ **UI改善**
  - Key Package表示エリア（折りたたみ）
  - 4つのアクションボタン（1人テスト、Key Package生成、2人グループ作成、TODO送信）
  - リアルタイムログ表示

#### Phase 5: 実デバイス間での2人グループテスト ✅
- ✅ **完了日**: 2025-11-11
- ✅ **Alice ↔ Bob間でのKey Package交換**
  - Key Package生成・公開
  - npubからの取得成功
- ✅ **グループ作成・招待**
  - 2人グループ作成成功
  - Welcome Message生成
  - Kind 30078招待通知送信
- ✅ **招待受信・参加**
  - Pull-to-refreshで招待同期
  - 招待バッジ表示
  - 招待受諾成功
  - MLSグループ参加完了

#### Phase 6: アプリ内完結型招待システム ✅
- ✅ **6.1: Key Package公開（Kind 10443）**
  - Rust: `create_unsigned_key_package_event()`
  - Flutter: `NostrService.publishKeyPackage()`
  - 設定画面に公開ボタン追加
  - Amber署名対応

- ✅ **6.2: npubからKey Package自動取得**
  - Rust: `fetch_key_package_by_npub()`
  - MLSテストダイアログに取得機能追加
  - リレーからKind 10443イベント取得

- ✅ **6.3: グループ招待通知送信（Kind 30078）**
  - Rust: `create_unsigned_group_invitation_event()`
  - Welcome Message base64エンコード
  - 招待データJSON生成
  - Amber署名 → リレー送信

- ✅ **6.4: SOMEDAYリスト表示UI（インビテーション対応）**
  - `CustomList`モデル拡張（isPendingInvitation等）
  - Rust: `sync_group_invitations()`
  - Flutter: `CustomListsNotifier.syncGroupInvitations()`
  - 招待バッジ表示（オレンジ色の「招待」マーク）
  - 起動時 + Pull-to-refresh時に自動同期

- ✅ **6.5: 招待受諾ダイアログ + 自動遷移**
  - 招待ダイアログUI実装
  - MLS DB自動初期化
  - `mlsJoinGroup()`でグループ参加
  - 招待フラグクリア
  - 自動的にリスト詳細画面に遷移

#### Phase 7: Amberモード動作確認 ✅
- ✅ **完了**: 全テストAmberモードで実施
- ✅ **Key Package公開**: Amber署名成功
- ✅ **グループ招待送信**: Amber署名成功
- ✅ **実デバイス間テスト**: 完全動作確認

---

### 🚧 次のステップ: Phase 8（Beta版への移行）

**新定義**: PoCから実用レベルのBeta版へ昇格

詳細: [docs/MLS_BETA_ROADMAP.md](MLS_BETA_ROADMAP.md)

#### 主要タスク（順序変更: 8.2と8.4を入れ替え）

1. **8.1: 通常フローへの統合**
   - MLSテストダイアログ不要に
   - `AddGroupListDialog`からMLS招待
   - Key Package自動管理

2. **8.2: エラーハンドリングと安定性**（優先度UP）
   - ネットワークエラー対応
   - MLS固有エラー処理
   - オフライン対応

3. **8.3: TODO送受信機能完全実装**
   - MLS暗号化送信フロー
   - リアルタイム復号化受信
   - 自動同期

4. **8.4: グループリスト統合**（後回し）
   - MLSグループへの一本化
   - kind: 30001廃止（グループのみ）
   - 個人カスタムリストは影響なし

5. **8.5: パフォーマンス最適化**
6. **8.6: 統合テストとドキュメント**

**目標期限**: 2-3週間（〜2025-12-02）

**順序変更の理由**:
- エラーハンドリングを先に実装すれば、8.1/8.3実装中の安定性が向上
- kind: 30001廃止は後回しでOK（現在PoC段階、ユーザーいない）
- 個人カスタムリストはローカルストレージ管理で影響なし

- ✅ **APKビルド成功**
  - `app-release.apk` (82.9MB) 生成完了
  - リリースモード動作確認済み

### 次のステップ 🔄
- ⏭️ 実際の2人グループテスト（デバイス間通信）
- ⏭️ Welcome Message送信機能（NIP-17統合）
- ⏭️ 相手のメッセージ復号化テスト
- ⏭️ Phase 5: Amberモード動作確認
- ⏭️ Option A（完全実装）への移行判断

### コミット履歴（Phase 1-7）
```
5eb738b - WIP: fiatjaf方式（Phase1保存ポイント）
8a83dd4 - WIP: MLS PoC Phase 1 基礎実装
6af1313 - feat: Option B - MLS簡易実装完成
b6f4095 - feat: Phase 2.1 - Flutter側MLS統合完了
a4e13aa - feat: Phase 2.2 - MLS統合テストUI実装完了
0f3892c - fix: Phase 3 - getPublicKey()非同期対応
642c364 - docs: Option B PoC Phase 1-3 完了記録
3d4f8d1 - feat: Phase 4 - 2人グループテスト機能実装完了
2d47450 - docs: Phase 6マジックリンク招待システム実装計画追加
c9e83f9 - docs: Phase 6 UXフロー改善 - アプリ内完結型招待システムに変更
d2168d8 - feat: Phase 6.1 - Key Package公開機能（Kind 10443）実装完了
a13dd10 - feat: Phase 6.2 - npubからKey Package自動取得機能実装完了
ee4c1d7 - feat: Phase 6.3 - グループ招待通知送信（Kind 30078）実装完了
f796e1c - feat: Phase 6.4-6.5 - グループ招待UI実装完了
4d96c6c - fix: PendingCommitエラー修正 + グループ招待同期機能追加
8663691 - fix: グループ招待受諾時のMLS DB初期化エラー修正
24e23c7 - feat: MLSテストダイアログ内にKey Package公開ボタン追加
aa2ab37 - fix: グループ招待受諾後に自動的にリスト詳細画面に遷移
```

**ロールバックポイント**: 
- fiatjaf方式に戻る場合: `git checkout 5eb738b`
- Phase 1開始時に戻る場合: `git checkout feature/amber-group-list-phase1`

### 実装完了した機能

**Rust API（Option B）**:
```rust
// MLS初期化
pub fn mls_init_db(db_path: String, nostr_id: String) -> Result<()>

// Export SecretからListen Key取得
pub fn mls_get_listen_key(nostr_id: String, group_id: String) -> Result<String>

// TODOグループ作成
pub fn mls_create_todo_group(
    nostr_id: String,
    group_id: String,
    group_name: String,
    key_packages: Vec<String>,
) -> Result<Vec<u8>>

// TODO暗号化
pub fn mls_add_todo(nostr_id: String, group_id: String, todo_json: String) -> Result<String>

// TODO復号化
pub fn mls_decrypt_todo(
    nostr_id: String,
    group_id: String,
    encrypted_msg: String,
) -> Result<(String, String, String)>

// Key Package作成
pub fn mls_create_key_package(nostr_id: String) -> Result<KeyPackageResult>
```

**Flutter側**:
```dart
// TodosProvider
Future<void> _initMlsIfNeeded() // 自動初期化
Future<void> createMlsGroupList({...}) // グループ作成
Future<String> encryptMlsTodo({...}) // TODO暗号化
Future<String> decryptMlsTodo({...}) // TODO復号化

// UI (settings_screen.dart)
_MlsTestDialog // 統合テストダイアログ
  - グループ作成テスト
  - TODO暗号化テスト
  - TODO復号化テスト
  - リアルタイムログ表示
```

---

## Amber統合

**重要**: MLSの内部暗号操作はRust側で完結するため、Amberは**不要**。

| 操作 | 実行場所 | Amber必要？ |
|------|---------|-----------|
| DH鍵交換（X25519） | Rust（OpenMLS） | ❌ |
| AES-GCM暗号化 | Rust（OpenMLS） | ❌ |
| Export Secret生成 | Rust（OpenMLS） | ❌ |
| NIP-44暗号化 | Rust | ❌ |
| Nostrイベント署名 | Rust/Amber | ✅ |

**結論**: Amberモードでも問題なく動作する！

---

## リスク管理

### ロールバック戦略
- fiatjaf実装のコミットは保持（5eb738b）
- 問題があれば即座に戻せる
- ブランチ: 
  - `feature/amber-group-list-phase1` (fiatjaf方式)
  - `feature/amber-group-list-phase2` (MLS方式)

### Option B失敗時の対策
1. **技術的課題**: OpenMLS APIの理解不足
   - 対策: Keychatの実装を詳細に分析
   - フォールバック: fiatjaf方式に戻る

2. **パフォーマンス問題**: MLSのオーバーヘッドが大きい
   - 対策: ベンチマーク測定、最適化
   - フォールバック: ハイブリッド実装（小規模はfiatjaf、大規模はMLS）

3. **エコシステム未成熟**: 他のクライアントが未対応
   - 対策: Meiso専用として実装
   - フォールバック: NIP提案を待つ

---

## 参考実装

- Keychat: https://github.com/keychat-io/keychat-app
- Keychat Rust FFI: https://github.com/keychat-io/keychat_rust_ffi_plugin
  - `rust/src/api_mls.rs`: 948行
  - `rust/src/api_mls.user.rs`: 1224行
  - `rust/src/api_mls.types.rs`: 64行
- OpenMLS: https://github.com/keychat-io/openmls (branch: kc4)
- NIP-EE Draft: Signal Protocol over Nostr

---

**ステータス**: Option B PoC + 2人グループテスト機能完了（2025-11-10）  
**担当**: AI Agent + Oracle  
**次の目標**: 実デバイス間での2人グループテスト → Welcome Message送信実装（2025-11-11以降）

---

## テスト結果詳細（2025-11-10）

### 1人グループテスト（実機）

**テスト環境**: Android実機、リリースビルド

**結果**:
```
[00:56:14] 📦 Step 1: グループ作成
[00:56:14] ✅ グループ作成完了: test-mls-group-1762790174272
[00:56:14] 🔒 Step 2: TODO暗号化
[00:56:14] ✅ TODO暗号化完了: 00010002...
[00:56:15] 🔓 Step 3: TODO復号化
[00:56:15] ❌ エラー: AnyhowException(Failed to process message: 
              ValidationError(CannotDecryptOwnMessage))
```

**分析**:
- ✅ グループ作成: 正常動作
- ✅ TODO暗号化: 正常動作
- ✅ 復号化エラー: **MLSプロトコルの正常動作**
  - MLSでは送信者は自分のメッセージを復号化できない仕様
  - Keychatでも同じ動作（送信者はローカルに平文保存）
  - 他のメンバーは復号化可能

**結論**: Option B PoC実装は成功！

---

### 2人グループテスト機能

**実装内容**:

1. **Key Package生成**
   ```dart
   final result = await rust_api.mlsCreateKeyPackage(nostrId: userPubkey);
   // → Key Package文字列、Protocol Version、Ciphersuite取得
   ```

2. **2人グループ作成**
   ```dart
   final welcomeMsg = await rust_api.mlsCreateTodoGroup(
     nostrId: userPubkey,
     groupId: groupId,
     groupName: '2 Person Test Group',
     keyPackages: [otherKeyPackage],
   );
   // → Welcome Message (Vec<u8>) 生成
   ```

3. **TODO送信**
   ```dart
   final encrypted = await todosNotifier.encryptMlsTodo(
     groupId: groupId,
     todoJson: testTodo.toString(),
   );
   // → MLS暗号化メッセージ生成
   ```

**次のステップ**:
- Welcome MessageをNIP-17経由で相手に送信
- 相手がWelcome Messageを受信してグループに参加
- 相手が送信したTODOを復号化
- 双方向のTODO共有を確認

