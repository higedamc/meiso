import 'package:freezed_annotation/freezed_annotation.dart';

part 'link_preview.freezed.dart';
part 'link_preview.g.dart';

/// URLメタデータのプレビュー情報
@freezed
class LinkPreview with _$LinkPreview {
  const factory LinkPreview({
    /// 元のURL
    required String url,
    
    /// ページタイトル（Open Graph title / Twitter Card title / HTML title）
    String? title,
    
    /// ページ説明文（Open Graph description / Twitter Card description / meta description）
    String? description,
    
    /// サムネイル画像URL（Open Graph image / Twitter Card image）
    String? imageUrl,
    
    /// ファビコンURL
    String? faviconUrl,
  }) = _LinkPreview;

  factory LinkPreview.fromJson(Map<String, dynamic> json) =>
      _$LinkPreviewFromJson(json);
}

