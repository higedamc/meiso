import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meiso/l10n/app_localizations.dart';
import '../../app_theme.dart';
import '../../providers/nostr_provider.dart';
import '../../services/logger_service.dart';
import '../../bridge_generated.dart/api.dart' as rust_api;

/// Phase 2.5A: MLSバックアップダイアログ
/// 
/// Key PackageをエクスポートまたはインポートするためのUIを提供。
/// アプリ再インストール後も既存のMLSグループに再参加できるようにする。
Future<void> showMlsBackupDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _MlsBackupDialog(ref: ref),
  );
}

class _MlsBackupDialog extends StatefulWidget {
  const _MlsBackupDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_MlsBackupDialog> createState() => _MlsBackupDialogState();
}

class _MlsBackupDialogState extends State<_MlsBackupDialog> {
  String _statusMessage = '';
  bool _isProcessing = false;

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context);
    
    setState(() {
      _isProcessing = true;
      _statusMessage = l10n.exportingBackup;
    });

    try {
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        setState(() {
          _statusMessage = '❌ ユーザー公開鍵が取得できません';
          _isProcessing = false;
        });
        return;
      }

      // MLS DBパスを取得
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/mls.db';

      AppLogger.info('[Phase 2.5A] Exporting MLS database from: $dbPath');

      // MLS DBをエクスポート
      final base64Data = await rust_api.exportMlsDatabaseAsBase64(
        dbPath: dbPath,
      );

      AppLogger.info('[Phase 2.5A] Export successful: ${base64Data.length} chars');

      // クリップボードにコピー
      await Clipboard.setData(ClipboardData(text: base64Data));

      setState(() {
        _statusMessage = '${l10n.backupCopiedToClipboard}\n\n'
            '文字数: ${base64Data.length}';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.clipboardCopied),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, st) {
      AppLogger.error('[Phase 2.5A] Export failed', error: e, stackTrace: st);

      setState(() {
        _statusMessage = l10n.exportFailed(e.toString());
        _isProcessing = false;
      });
    }
  }

  Future<void> _importBackup() async {
    final l10n = AppLocalizations.of(context);
    
    // クリップボードから読み込み
    final clipboardData = await Clipboard.getData('text/plain');
    final base64Data = clipboardData?.text;

    if (base64Data == null || base64Data.isEmpty) {
      setState(() {
        _statusMessage = l10n.noBackupDataInClipboard;
      });
      return;
    }

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 確認'),
        content: Text(l10n.confirmImportBackup),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: Text(l10n.importButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = l10n.importingBackup;
    });

    try {
      final nostrService = widget.ref.read(nostrServiceProvider);
      final userPubkey = await nostrService.getPublicKey();

      if (userPubkey == null) {
        setState(() {
          _statusMessage = '❌ ユーザー公開鍵が取得できません';
          _isProcessing = false;
        });
        return;
      }

      // MLS DBパスを取得
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/mls.db';

      AppLogger.info('[Phase 2.5A] Importing MLS database to: $dbPath');
      AppLogger.info('[Phase 2.5A] Backup data length: ${base64Data.length} chars');

      // MLS DBをインポート
      final result = await rust_api.importMlsDatabaseFromBase64(
        dbPath: dbPath,
        base64Data: base64Data,
        nostrId: userPubkey,
      );

      AppLogger.info('[Phase 2.5A] Import successful: $result');

      setState(() {
        _statusMessage = '${l10n.backupImportedRestart}\n\n$result';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.importCompletedRestart),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.error('[Phase 2.5A] Import failed', error: e, stackTrace: st);

      setState(() {
        _statusMessage = l10n.importFailed(e.toString());
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.backup, color: AppTheme.primaryPurple),
          const SizedBox(width: 8),
          Text(l10n.mlsGroupBackupTitle),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mlsBackupDescription,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.startsWith('✅')
                      ? Colors.green.shade50
                      : _statusMessage.startsWith('❌')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.closeButton),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _exportBackup,
          icon: const Icon(Icons.download, size: 18),
          label: Text(l10n.exportButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _importBackup,
          icon: const Icon(Icons.upload, size: 18),
          label: Text(l10n.importButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

