import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../bridge_generated.dart/api.dart' as rust_api;
import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/nostr_provider.dart';
import '../services/logger_service.dart';

/// メンバー選択シートを表示し、選択された npub のリストを返す。
/// キャンセル時は null。
Future<List<String>?> showMemberPicker(
  BuildContext context, {
  bool allowMultiple = true,
  Set<String> excludedNpubs = const {},
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => MemberPickerSheet(
      allowMultiple: allowMultiple,
      excludedNpubs: excludedNpubs,
    ),
  );
}

/// 自分の npub を QR コードで表示するダイアログ。
/// 対面でのメンバー追加（相手にスキャンしてもらう）用。
Future<void> showMyNpubQrDialog(BuildContext context, WidgetRef ref) async {
  var npub = ref.read(nostrPublicKeyProvider);
  if (npub == null || npub.isEmpty) {
    try {
      npub = await rust_api.getPublicKeyNpub();
    } on Exception catch (e) {
      AppLogger.error('❌ [MemberPicker] Failed to get own npub', error: e);
    }
  }
  if (npub == null || npub.isEmpty || !context.mounted) {
    return;
  }
  final resolvedNpub = npub;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      // NOTE: AlertDialog(content:) は IntrinsicWidth で子を計測するが、
      // QrImageView は内部で LayoutBuilder を使うため intrinsic 計測で
      // レイアウト例外となり何も描画されない。固定幅の Dialog を使う。
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My npub',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(data: resolvedNpub),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                resolvedNpub,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: resolvedNpub),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('COPY'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class MemberPickerSheet extends ConsumerStatefulWidget {
  const MemberPickerSheet({
    super.key,
    this.allowMultiple = true,
    this.excludedNpubs = const {},
  });

  final bool allowMultiple;
  final Set<String> excludedNpubs;

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _ContactEntry {
  const _ContactEntry({
    required this.npub,
    required this.pubkeyHex,
    this.displayName,
    this.picture,
    this.nip05,
  });

  final String npub;
  final String pubkeyHex;
  final String? displayName;
  final String? picture;
  final String? nip05;

  String get label =>
      displayName ?? '${npub.substring(0, 16)}...';
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  final TextEditingController _npubController = TextEditingController();
  final Set<String> _selected = {};

  List<_ContactEntry>? _contacts;
  bool _loadingContacts = false;
  String? _contactsError;

  @override
  void dispose() {
    _npubController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (_loadingContacts) {
      return;
    }
    setState(() {
      _loadingContacts = true;
      _contactsError = null;
    });
    try {
      final myPubkey = ref.read(publicKeyProvider);
      if (myPubkey == null || myPubkey.isEmpty) {
        throw Exception('public key not available');
      }
      final contactHexes =
          await rust_api.fetchContactList(pubkeyHex: myPubkey);
      if (contactHexes.isEmpty) {
        setState(() {
          _contacts = [];
          _loadingContacts = false;
        });
        return;
      }

      // プロフィール（kind:0）は取得失敗しても一覧自体は出す
      var profiles = <rust_api.ContactProfile>[];
      try {
        profiles =
            await rust_api.fetchProfilesMetadata(pubkeyHexes: contactHexes);
      } on Exception catch (e) {
        AppLogger.warning('⚠️ [MemberPicker] profile fetch failed: $e');
      }
      final profileByHex = {for (final p in profiles) p.pubkeyHex: p};

      final entries = <_ContactEntry>[];
      for (final hex in contactHexes) {
        String npub;
        try {
          npub = await rust_api.hexToNpub(hex: hex);
        } on Exception {
          continue;
        }
        if (widget.excludedNpubs.contains(npub)) {
          continue;
        }
        final profile = profileByHex[hex];
        entries.add(_ContactEntry(
          npub: npub,
          pubkeyHex: hex,
          displayName: profile?.displayName ?? profile?.name,
          picture: profile?.picture,
          nip05: profile?.nip05,
        ));
      }
      // 表示名のあるコンタクトを先頭に
      entries.sort((a, b) {
        final aNamed = a.displayName != null ? 0 : 1;
        final bNamed = b.displayName != null ? 0 : 1;
        if (aNamed != bNamed) {
          return aNamed.compareTo(bNamed);
        }
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _contacts = entries;
        _loadingContacts = false;
      });
    } on Exception catch (e) {
      AppLogger.error('❌ [MemberPicker] contact list fetch failed', error: e);
      if (!mounted) {
        return;
      }
      setState(() {
        _contactsError = 'Failed to load follow list';
        _loadingContacts = false;
      });
    }
  }

  Future<void> _scanQr() async {
    final npub = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (npub == null || !mounted) {
      return;
    }
    await _addNpub(npub);
  }

  Future<void> _addManual() async {
    await _addNpub(_npubController.text);
  }

  /// npub を検証して選択集合へ追加する。
  /// `nostr:npub1...` 形式も受理する（QR の一般的な表記）。
  Future<void> _addNpub(String raw) async {
    var npub = raw.trim();
    if (npub.startsWith('nostr:')) {
      npub = npub.substring('nostr:'.length);
    }
    if (npub.isEmpty) {
      return;
    }

    if (!npub.startsWith('npub1')) {
      _showError('Invalid npub');
      return;
    }
    // bech32 として実際にデコードできるか検証（入力は信頼しない）
    try {
      await rust_api.npubToHex(npub: npub);
    } on Exception {
      _showError('Invalid npub');
      return;
    }
    if (widget.excludedNpubs.contains(npub)) {
      _showError('Already a member');
      return;
    }

    final myNpub = ref.read(nostrPublicKeyProvider);
    if (npub == myNpub) {
      _showError('Cannot add yourself');
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      if (!widget.allowMultiple) {
        _selected.clear();
      }
      _selected.add(npub);
      _npubController.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _toggle(String npub) {
    setState(() {
      if (_selected.contains(npub)) {
        _selected.remove(npub);
      } else {
        if (!widget.allowMultiple) {
          _selected.clear();
        }
        _selected.add(npub);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD MEMBERS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // 手入力 + QR
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _npubController,
                    decoration: const InputDecoration(
                      labelText: 'npub',
                      hintText: 'npub1...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addManual(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Add npub',
                  onPressed: _addManual,
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR',
                  onPressed: _scanQr,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 選択済みチップ
            if (_selected.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selected.map((npub) {
                  final contact = _contacts
                      ?.where((c) => c.npub == npub)
                      .firstOrNull;
                  return InputChip(
                    label: Text(
                      contact?.label ?? '${npub.substring(0, 12)}...',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onDeleted: () => setState(() => _selected.remove(npub)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // フォローリスト
            Row(
              children: [
                Text(
                  'FROM FOLLOWS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_contacts == null && !_loadingContacts)
                  TextButton.icon(
                    onPressed: _loadContacts,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Load'),
                  ),
              ],
            ),
            Flexible(
              child: _buildContactsArea(colorScheme),
            ),
            const SizedBox(height: 12),

            // 確定
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  child: Text(
                    _selected.isEmpty
                        ? 'ADD'
                        : 'ADD (${_selected.length})',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsArea(ColorScheme colorScheme) {
    // プロフィール画像は Flutter 既定の HttpClient で取得され、リレー接続用の
    // SOCKS プロキシを経由しない。Tor モード時にアバターをフェッチすると実 IP が
    // 漏れるため、Tor が明示的に無効と確認できた場合のみネットワーク取得を許可する
    // （不明・ロード中は取得しない deny-by-default）。
    final allowNetworkAvatar = ref.watch(appSettingsProvider).maybeWhen(
          data: (settings) => settings.torMode == TorMode.disabled,
          orElse: () => false,
        );
    if (_loadingContacts) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_contactsError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _contactsError!,
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: _loadContacts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final contacts = _contacts;
    if (contacts == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Load your follow list to pick members.',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No follows found.',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final selected = _selected.contains(contact.npub);
        return CheckboxListTile(
          dense: true,
          value: selected,
          onChanged: (_) => _toggle(contact.npub),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: _buildAvatar(
            contact,
            colorScheme,
            allowNetwork: allowNetworkAvatar,
          ),
          title: Text(
            contact.label,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: contact.nip05 != null
              ? Text(
                  contact.nip05!,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        );
      },
    );
  }

  Widget _buildAvatar(
    _ContactEntry contact,
    ColorScheme colorScheme, {
    required bool allowNetwork,
  }) {
    final picture = contact.picture;
    if (allowNetwork && picture != null && picture.startsWith('https://')) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundImage: NetworkImage(picture),
        onForegroundImageError: (_, _) {},
        child: const Icon(Icons.person, size: 16),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.person, size: 16),
    );
  }
}

/// npub QR スキャン画面。スキャン成功時に npub 文字列を pop で返す。
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final barcode in capture.barcodes) {
      var value = barcode.rawValue?.trim() ?? '';
      if (value.startsWith('nostr:')) {
        value = value.substring('nostr:'.length);
      }
      if (value.startsWith('npub1')) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan npub QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // スキャン枠のガイド
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
