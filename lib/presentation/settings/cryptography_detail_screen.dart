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
                          AppLocalizations.of(context).cryptoArchPara1,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoArchSecurityModel,
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
                          AppLocalizations.of(context).cryptoArgon2Intro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoArgon2WhyTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoArgon2BruteForce,
                          AppLocalizations.of(context).cryptoArgon2BruteForceDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoArgon2SideChannel,
                          AppLocalizations.of(context).cryptoArgon2SideChannelDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoArgon2Standard,
                          AppLocalizations.of(context).cryptoArgon2StandardDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoArgon2Params,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          AppLocalizations.of(context).cryptoArgon2Reference,
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
                          AppLocalizations.of(context).cryptoAesIntro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoAesStrengthTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoAesStrengthDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoAesGcmAdvantagesTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAesAead,
                          AppLocalizations.of(context).cryptoAesAeadDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAesPerformance,
                          AppLocalizations.of(context).cryptoAesPerformanceDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAesPaddingResistance,
                          AppLocalizations.of(context).cryptoAesPaddingResistanceDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoAesParams,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          AppLocalizations.of(context).cryptoAesReference,
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
                          AppLocalizations.of(context).cryptoNip44Intro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoNip44MechanismTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoNip44MechanismDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoNip44Process,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoNip44UsageTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoNip44UsageDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildWarningBox(
                          context,
                          AppLocalizations.of(context).cryptoNip44SecurityTitle,
                          AppLocalizations.of(context).cryptoNip44SecurityDesc,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          AppLocalizations.of(context).cryptoNip44Reference,
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
                          AppLocalizations.of(context).cryptoEd25519Intro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoEd25519AdvantagesTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoEd25519Speed,
                          AppLocalizations.of(context).cryptoEd25519SpeedDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoEd25519Compact,
                          AppLocalizations.of(context).cryptoEd25519CompactDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoEd25519Deterministic,
                          AppLocalizations.of(context).cryptoEd25519DeterministicDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoEd25519SafeImpl,
                          AppLocalizations.of(context).cryptoEd25519SafeImplDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoEd25519NostrRoleTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoEd25519NostrRoleDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoEd25519SigningProcess,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          AppLocalizations.of(context).cryptoEd25519Reference,
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
                          AppLocalizations.of(context).cryptoAmberIntro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoAmberNcryptsecTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoAmberNcryptsecDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoAmberNcryptsecStructure,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoAmberBenefitsTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAmberIsolation,
                          AppLocalizations.of(context).cryptoAmberIsolationDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAmberBiometric,
                          AppLocalizations.of(context).cryptoAmberBiometricDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAmberAuditable,
                          AppLocalizations.of(context).cryptoAmberAuditableDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoAmberKeyReuse,
                          AppLocalizations.of(context).cryptoAmberKeyReuseDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoBox(
                          context,
                          AppLocalizations.of(context).cryptoAmberHardwareWalletTitle,
                          AppLocalizations.of(context).cryptoAmberHardwareWalletDesc,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkText(
                          context,
                          AppLocalizations.of(context).cryptoAmberReference,
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
                          AppLocalizations.of(context).cryptoSecureStorageIntro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoStorageWhyRustTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageMemorySafety,
                          AppLocalizations.of(context).cryptoStorageMemorySafetyDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageZeroCost,
                          AppLocalizations.of(context).cryptoStorageZeroCostDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageTypeSystem,
                          AppLocalizations.of(context).cryptoStorageTypeSystemDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoStorageImplTitle),
                        _buildParagraph(
                          context,
                          AppLocalizations.of(context).cryptoStorageImplDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildCodeBlock(
                          context,
                          AppLocalizations.of(context).cryptoStoragePath,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoStorageMemorySecurityTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageZeroize,
                          AppLocalizations.of(context).cryptoStorageZeroizeDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageStackAllocation,
                          AppLocalizations.of(context).cryptoStorageStackAllocationDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoStorageMemoryDump,
                          AppLocalizations.of(context).cryptoStorageMemoryDumpDesc,
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
                          AppLocalizations.of(context).cryptoThreatModelIntro,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoThreatWhatWeCanProtectTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatNetworkEavesdropping,
                          AppLocalizations.of(context).cryptoThreatNetworkEavesdroppingDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatMaliciousRelay,
                          AppLocalizations.of(context).cryptoThreatMaliciousRelayDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatBruteForce,
                          AppLocalizations.of(context).cryptoThreatBruteForceDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoThreatWhatWeCannotProtectTitle),
                        _buildWarningBox(
                          context,
                          AppLocalizations.of(context).cryptoThreatWarningTitle,
                          AppLocalizations.of(context).cryptoThreatWarningDesc,
                        ),
                        const SizedBox(height: 16),
                        _buildSubheading(context, AppLocalizations.of(context).cryptoThreatBestPracticesTitle),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatStrongPassword,
                          AppLocalizations.of(context).cryptoThreatStrongPasswordDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatDeviceEncryption,
                          AppLocalizations.of(context).cryptoThreatDeviceEncryptionDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatKeepOsUpdated,
                          AppLocalizations.of(context).cryptoThreatKeepOsUpdatedDesc,
                        ),
                        _buildBulletPoint(
                          context,
                          AppLocalizations.of(context).cryptoThreatRecommendAmber,
                          AppLocalizations.of(context).cryptoThreatRecommendAmberDesc,
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
          Text(
            AppLocalizations.of(context).cryptoTableOfContents,
            style: const TextStyle(
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

