import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';

/// リモート画像の取得を Tor モード時に抑止するためのゲート。
///
/// Flutter 既定の画像ローダーはリレー接続用の SOCKS プロキシを経由しないため、
/// Tor 有効時にリモート画像を取得すると実 IP が漏れる。[remoteContentFetchAllowedProvider]
/// が許可を返した場合のみ [allowed] を構築し、それ以外（Tor 有効・設定ロード中・
/// 不明）は [blocked] を表示する（deny-by-default）。
class RemoteImageGate extends ConsumerWidget {
  const RemoteImageGate({
    required this.allowed,
    required this.blocked,
    super.key,
  });

  /// リモート取得が許可された場合に表示する実画像ウィジェット。
  final WidgetBuilder allowed;

  /// 取得が抑止された場合に表示する代替（プレースホルダ）。
  final WidgetBuilder blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowNetwork = ref.watch(remoteContentFetchAllowedProvider);
    return allowNetwork ? allowed(context) : blocked(context);
  }
}
