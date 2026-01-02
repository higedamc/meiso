import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../services/logger_service.dart';

class CryptographyDetailScreen extends StatelessWidget {
  const CryptographyDetailScreen({super.key});

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      AppLogger.debug('Error launching URL: $e');
      // エラーが発生してもアプリをクラッシュさせない
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // モダンなヘッダー
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.primaryPurple,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                AppLocalizations.of(context).cryptographyTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryPurple,
                      AppTheme.darkPurple,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.security,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),

          // コンテンツ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // イントロ
                  _buildIntroSection(context),
                  const SizedBox(height: 32),

                  // 目次
                  _buildTableOfContents(context),
                  const SizedBox(height: 40),

                  // セクション1: アーキテクチャ概要
                  _buildSection(
                    context,
                    id: 'architecture',
                    icon: Icons.architecture,
                    title: AppLocalizations.of(context).cryptoArchitectureTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Meisoは「Zero-Knowledge Architecture」を採用し、'
                          'あなたの秘密鍵やタスクデータをサーバーに一切送信しません。'
                          '全ての暗号化処理はあなたのデバイス上で実行されます。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'セキュリティモデル:\n'
                          '• エンドツーエンド暗号化 (E2EE)\n'
                          '• クライアントサイド暗号化\n'
                          '• サーバーは暗号化済みデータのみを保管\n'
                          '• 秘密鍵はあなただけが保有',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション2: Argon2id
                  _buildSection(
                    context,
                    id: 'argon2id',
                    icon: Icons.key,
                    title: AppLocalizations.of(context).cryptoArgon2idTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Argon2idは、2015年のPassword Hashing Competition (PHC)で優勝した、'
                          '最新かつ最強のパスワードハッシュアルゴリズムです。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'なぜArgon2idなのか？'),
                        _buildBulletPoint(
                          context,
                          '耐ブルートフォース攻撃',
                          '計算コストとメモリコストの両方を必要とするため、'
                          'GPUやASICによる並列攻撃に極めて強い耐性を持ちます。',
                        ),
                        _buildBulletPoint(
                          context,
                          'サイドチャネル攻撃への耐性',
                          'Argon2iのメモリアクセスパターンの予測不可能性と、'
                          'Argon2dの計算効率を組み合わせた「ハイブリッド型」です。',
                        ),
                        _buildBulletPoint(
                          context,
                          '業界標準',
                          'OWASP、NIST、CryptographyEngineering community推奨。'
                          'bcryptやPBKDF2を上回る次世代標準です。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'Meisoでの実装パラメータ:\n'
                          '• メモリコスト: 19 MiB (最適化済み)\n'
                          '• 反復回数: 2回\n'
                          '• 並列度: 1スレッド\n'
                          '• 出力長: 32バイト (256ビット)\n'
                          '• ソルト: ランダム生成 (16バイト)',
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          '📚 参考: Argon2 RFC 9106',
                          'https://datatracker.ietf.org/doc/html/rfc9106',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション3: AES-256-GCM
                  _buildSection(
                    context,
                    id: 'aes-gcm',
                    icon: Icons.lock,
                    title: AppLocalizations.of(context).cryptoAes256GcmTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'AES-256-GCMは、米国政府が機密情報の保護に使用する'
                          '「認証付き暗号化 (AEAD)」アルゴリズムです。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'AES-256の強度'),
                        _buildParagraph(
                          context,
                          'AES-256は2^256通りの鍵空間を持ち、現代のスーパーコンピュータでも'
                          '総当たり攻撃は事実上不可能です。量子コンピュータ時代でも'
                          '128ビットの有効セキュリティを維持します。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'GCMモードの利点'),
                        _buildBulletPoint(
                          context,
                          '認証付き暗号化 (AEAD)',
                          '暗号化と同時にメッセージ認証コード (MAC)を生成。'
                          'データの改ざん検知が可能です。',
                        ),
                        _buildBulletPoint(
                          context,
                          '高速処理',
                          '並列処理が可能で、最新のCPUのAES-NI命令により'
                          'ハードウェアアクセラレーションされます。',
                        ),
                        _buildBulletPoint(
                          context,
                          'パディング攻撃への耐性',
                          'ストリーム暗号モードのため、パディングオラクル攻撃の'
                          'リスクがありません。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'Meisoでの実装:\n'
                          '• 暗号化アルゴリズム: AES-256-GCM\n'
                          '• 鍵長: 256ビット (Argon2idから派生)\n'
                          '• ノンス: ランダム生成 (96ビット)\n'
                          '• タグ長: 128ビット (改ざん検知用)\n'
                          '• 用途: 秘密鍵の暗号化保存',
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          '📚 参考: NIST SP 800-38D (GCM)',
                          'https://csrc.nist.gov/publications/detail/sp/800-38d/final',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション4: NIP-44
                  _buildSection(
                    context,
                    id: 'nip44',
                    icon: Icons.message_outlined,
                    title: AppLocalizations.of(context).cryptoNip44Title,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'NIP-44は、Nostrプロトコルにおける暗号化メッセージの標準規格です。'
                          '楕円曲線暗号 (ECC) を使った安全なエンドツーエンド暗号化を提供します。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, '暗号化の仕組み'),
                        _buildParagraph(
                          context,
                          'NIP-44は、あなたの秘密鍵と受信者の公開鍵から「共有秘密 (shared secret)」を生成し、'
                          'それを使ってメッセージを暗号化します。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          '暗号化プロセス:\n'
                          '1. ECDH (Elliptic Curve Diffie-Hellman)\n'
                          '   → secp256k1曲線で共有秘密を生成\n\n'
                          '2. HMAC-SHA256による鍵派生 (HKDF)\n'
                          '   → 暗号化鍵とメッセージ認証鍵を生成\n\n'
                          '3. ChaCha20-Poly1305で暗号化\n'
                          '   → 高速かつ安全なAEAD暗号化\n\n'
                          '4. Base64エンコードして送信',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'Meisoでの利用'),
                        _buildParagraph(
                          context,
                          'Meisoでは、全てのTodoデータをNIP-44で暗号化してNostrリレーに保存します。'
                          'これにより、リレーサーバーはあなたのタスク内容を読み取ることができません。',
                        ),
                        const SizedBox(height: 16),
                        _buildWarningBox(
                          context,
                          '🔐 重要なセキュリティ特性',
                          '• リレーサーバーは暗号文しか見えません\n'
                          '• あなた自身の秘密鍵がないと復号化できません\n'
                          '• 前方秘匿性 (Forward Secrecy) は提供されません\n'
                          '• 秘密鍵が漏洩すると過去の全メッセージが復号化されます',
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          '📚 参考: NIP-44 仕様',
                          'https://github.com/nostr-protocol/nips/blob/master/44.md',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション5: Ed25519
                  _buildSection(
                    context,
                    id: 'ed25519',
                    icon: Icons.draw,
                    title: AppLocalizations.of(context).cryptoEd25519Title,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Ed25519は、楕円曲線暗号 (ECC) に基づく最新の署名アルゴリズムです。'
                          'Bitcoin、SSH、TLS 1.3など、最新のセキュリティプロトコルで広く採用されています。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'Ed25519の優位性'),
                        _buildBulletPoint(
                          context,
                          '高速',
                          'RSA-2048の10倍以上の速度で署名・検証が可能。'
                          'モバイルデバイスでも高速動作します。',
                        ),
                        _buildBulletPoint(
                          context,
                          'コンパクト',
                          '公開鍵: 32バイト、秘密鍵: 32バイト、署名: 64バイト。'
                          'RSAの1/8のサイズで同等以上のセキュリティ。',
                        ),
                        _buildBulletPoint(
                          context,
                          '決定論的',
                          '同じメッセージに対して常に同じ署名を生成。'
                          '乱数生成器の脆弱性リスクがありません。',
                        ),
                        _buildBulletPoint(
                          context,
                          '実装が安全',
                          'サイドチャネル攻撃に対する耐性が設計段階から組み込まれています。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'Nostrでの役割'),
                        _buildParagraph(
                          context,
                          'Nostrでは、全てのイベント (メッセージ、Todo、プロフィール更新など)に'
                          'Ed25519署名が付けられます。これにより、イベントの作成者の真正性と、'
                          'データの完全性が保証されます。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'Nostr署名プロセス:\n'
                          '1. イベントをJSON形式でシリアライズ\n'
                          '2. SHA-256でハッシュ化\n'
                          '3. Ed25519秘密鍵で署名\n'
                          '4. 署名をイベントに添付して送信',
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          '📚 参考: RFC 8032 (EdDSA)',
                          'https://datatracker.ietf.org/doc/html/rfc8032',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション6: Amber統合
                  _buildSection(
                    context,
                    id: 'amber',
                    icon: Icons.smartphone,
                    title: AppLocalizations.of(context).cryptoAmberIntegrationTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Amberは、Nostr秘密鍵を安全に管理するための専用アプリです。'
                          '秘密鍵を他のアプリと共有せず、署名リクエストのみを処理します。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'ncryptsec形式'),
                        _buildParagraph(
                          context,
                          'Amberは、秘密鍵を「ncryptsec」形式で保存します。'
                          'これは、AES-256-CBCで暗号化された秘密鍵を含むBech32エンコードされた文字列です。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'ncryptsec構造:\n'
                          'ncryptsec1... ← Bech32プレフィックス\n'
                          '├─ バージョン (1バイト)\n'
                          '├─ ソルト (16バイト)\n'
                          '├─ ノンス/IV (16バイト)\n'
                          '├─ 暗号化された秘密鍵 (32バイト)\n'
                          '└─ 改ざん検知用タグ',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'Amberモードのメリット'),
                        _buildBulletPoint(
                          context,
                          '秘密鍵の隔離',
                          'Meisoは秘密鍵を保持せず、署名が必要な時だけAmberに依頼します。',
                        ),
                        _buildBulletPoint(
                          context,
                          '生体認証',
                          'Amberで署名時に指紋認証やPINを要求できます。',
                        ),
                        _buildBulletPoint(
                          context,
                          '監査可能',
                          'Amberアプリで全ての署名リクエストを確認・承認できます。',
                        ),
                        _buildBulletPoint(
                          context,
                          '鍵の再利用',
                          '1つの秘密鍵を複数のNostrアプリで安全に共有できます。',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoBox(
                          context,
                          '💡 ハードウェアウォレットとの類似性',
                          'Amberは、Bitcoinのハードウェアウォレット (Ledger、Trezor) と'
                          '同じ「秘密鍵を外部に出さない」アーキテクチャを採用しています。',
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          '🔗 Amber on GitHub',
                          'https://github.com/greenart7c3/Amber',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション7: セキュアストレージ
                  _buildSection(
                    context,
                    id: 'storage',
                    icon: Icons.storage,
                    title: AppLocalizations.of(context).cryptoSecureStorageTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Meisoの秘密鍵管理は、全てRustで実装されています。'
                          'Rustは、メモリ安全性が言語レベルで保証された、セキュアなシステムプログラミング言語です。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'なぜRust？'),
                        _buildBulletPoint(
                          context,
                          'メモリ安全性',
                          'バッファオーバーフロー、Use-after-free、データ競合などの'
                          'メモリ関連の脆弱性が原理的に発生しません。',
                        ),
                        _buildBulletPoint(
                          context,
                          'ゼロコスト抽象化',
                          '高レベルなコードを書きながら、C/C++と同等のパフォーマンスを実現。',
                        ),
                        _buildBulletPoint(
                          context,
                          '強力な型システム',
                          'Option型やResult型により、エラーハンドリングが強制されます。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'ストレージの実装'),
                        _buildParagraph(
                          context,
                          'Meisoは、暗号化された秘密鍵をFlutterの「ApplicationSupportDirectory」に保存します。'
                          'このディレクトリは、OSによって他のアプリからアクセスできないよう保護されています。',
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          'ストレージパス (Android):\n'
                          '/data/data/com.example.meiso/files/encrypted_key.bin\n\n'
                          'ファイル内容:\n'
                          '• JSON形式\n'
                          '• フィールド: salt, nonce, ciphertext\n'
                          '• 全て Base64 エンコード済み',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'メモリセキュリティ'),
                        _buildBulletPoint(
                          context,
                          'Zeroize',
                          '秘密鍵を使用後、メモリから安全に消去します。',
                        ),
                        _buildBulletPoint(
                          context,
                          'スタック割り当て',
                          '秘密鍵をヒープではなくスタックに配置し、寿命を最小化。',
                        ),
                        _buildBulletPoint(
                          context,
                          'メモリダンプ対策',
                          'デバッグビルドでもRustコードは最適化され、機密データが残りにくい。',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // セクション8: 脅威モデル
                  _buildSection(
                    context,
                    id: 'threat-model',
                    icon: Icons.warning_amber,
                    title: AppLocalizations.of(context).cryptoThreatModelTitle,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParagraph(
                          context,
                          'Meisoは非常に強力な暗号技術を使用していますが、'
                          '完璧なセキュリティは存在しません。以下の脅威を理解してください。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, '保護できること'),
                        _buildBulletPoint(
                          context,
                          'ネットワーク盗聴',
                          'TLS + E2EE暗号化により、通信経路での盗聴は無効化されます。',
                        ),
                        _buildBulletPoint(
                          context,
                          'リレーサーバーの悪意',
                          'リレーは暗号化されたデータしか見えません。',
                        ),
                        _buildBulletPoint(
                          context,
                          'ブルートフォース攻撃',
                          'Argon2id + AES-256により、現実的な時間での解読は不可能。',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, '保護できないこと'),
                        _buildWarningBox(
                          context,
                          '⚠️ 以下の脅威には注意が必要です',
                          '• デバイスの物理的な盗難 + パスワード漏洩\n'
                          '• キーロガーやスクリーンキャプチャマルウェア\n'
                          '• ルート化/Jailbreak済みデバイス\n'
                          '• OSやファームウェアの脆弱性\n'
                          '• ソーシャルエンジニアリング攻撃\n'
                          '• 量子コンピュータによる将来的な脅威 (RSA/ECCの破綻)',
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, 'ベストプラクティス'),
                        _buildBulletPoint(
                          context,
                          '強力なパスワード',
                          '20文字以上のランダムなパスワードを使用してください。',
                        ),
                        _buildBulletPoint(
                          context,
                          'デバイスの暗号化',
                          'Android/iOSのフルディスク暗号化を有効にしてください。',
                        ),
                        _buildBulletPoint(
                          context,
                          'OSを最新に保つ',
                          'セキュリティパッチを定期的に適用してください。',
                        ),
                        _buildBulletPoint(
                          context,
                          'Amberモードの推奨',
                          'より高いセキュリティが必要な場合は、Amberモードを使用してください。',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // フッター
                  _buildFooter(context),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).cryptographyIntroTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).cryptographyIntroDescription,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _buildTableOfContents(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📖 目次',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkPurple,
            ),
          ),
          const SizedBox(height: 16),
          _buildTocItem(context, '1. アーキテクチャ概要'),
          _buildTocItem(context, '2. Argon2id - パスワード派生関数'),
          _buildTocItem(context, '3. AES-256-GCM - 暗号化アルゴリズム'),
          _buildTocItem(context, '4. NIP-44 - Nostr暗号化規格'),
          _buildTocItem(context, '5. Ed25519 - デジタル署名'),
          _buildTocItem(context, '6. Amber統合 - ハードウェアウォレット的セキュリティ'),
          _buildTocItem(context, '7. セキュアストレージ - Rust実装'),
          _buildTocItem(context, '8. 脅威モデルと制限事項'),
        ],
      ),
    );
  }

  Widget _buildTocItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_right,
            size: 20,
            color: AppTheme.primaryPurple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryPurple,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkPurple,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        content,
      ],
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.7,
            color: Colors.grey.shade800,
          ),
    );
  }

  Widget _buildSubheading(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkPurple,
          ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primaryPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: Colors.grey.shade800,
                    ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Colors.grey.shade800,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildLinkText(BuildContext context, String text, String url) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppTheme.primaryPurple,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
      ),
    );
  }

  Widget _buildWarningBox(BuildContext context, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryPurple.withOpacity(0.1),
            AppTheme.darkPurple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔒 セキュリティに関する質問や報告',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkPurple,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'セキュリティ上の問題を発見した場合は、'
            'GitHubのIssueまたはNostr (DM) でご報告ください。',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.code, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              Text(
                'すべてのコードはオープンソースです',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

