import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/link_preview.dart';
import '../services/logger_service.dart';

/// URLからメタデータを取得してLinkPreviewを生成するサービス
class LinkPreviewService {
  /// URLの正規表現パターン
  /// https:// または http:// で始まるURLを検出
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// テキスト内からURLを検出
  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// テキストからURLを除去
  /// 
  /// 例: "Check https://github.com later" → "Check later"
  static String removeUrlFromText(String text, String url) {
    // まず指定されたURLを削除
    String result = text.replaceAll(url, '');
    
    // 念のため、正規表現でも全てのURLを削除
    result = result.replaceAll(_urlRegex, '');
    
    // 複数スペースを1つに、前後の空白を削除
    result = result
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return result;
  }

  /// URLからメタデータを取得してLinkPreviewを生成
  /// 
  /// Open Graph、Twitter Card、通常のHTMLメタタグからデータを取得します
  /// タイムアウト: 10秒
  static Future<LinkPreview?> fetchLinkPreview(String url) async {
    try {
      AppLogger.debug(' Fetching link preview for: $url');
      
      // URLの正規化
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        AppLogger.warning(' Invalid URL scheme: ${uri.scheme}');
        return null;
      }

      // HTTPリクエスト（タイムアウト10秒）
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.warning(' HTTP error: ${response.statusCode}');
        return null;
      }

      // HTMLをパース
      final document = html_parser.parse(
        utf8.decode(response.bodyBytes),
      );

      // メタデータを抽出
      final title = _extractTitle(document, uri);
      final description = _extractDescription(document);
      final imageUrl = _extractImageUrl(document, uri);
      final faviconUrl = _extractFaviconUrl(document, uri);

      AppLogger.info(' Link preview fetched:');
      AppLogger.debug('   Title: $title');
      AppLogger.debug('   Image: $imageUrl');
      AppLogger.debug('   Favicon: $faviconUrl');

      return LinkPreview(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        faviconUrl: faviconUrl,
      );
    } catch (e) {
      AppLogger.error(' Failed to fetch link preview: $e');
      return null;
    }
  }

  /// タイトルを抽出（優先順: og:title > twitter:title > <title>）
  static String? _extractTitle(Document document, Uri uri) {
    // Open Graph title
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (ogTitle != null && ogTitle.isNotEmpty) return ogTitle;

    // Twitter Card title
    final twitterTitle = document
        .querySelector('meta[name="twitter:title"]')
        ?.attributes['content'];
    if (twitterTitle != null && twitterTitle.isNotEmpty) return twitterTitle;

    // HTML title
    final htmlTitle = document.querySelector('title')?.text;
    if (htmlTitle != null && htmlTitle.isNotEmpty) return htmlTitle;

    // フォールバック: ドメイン名
    return uri.host;
  }

  /// 説明文を抽出（優先順: og:description > twitter:description > meta description）
  static String? _extractDescription(Document document) {
    // Open Graph description
    final ogDescription = document
        .querySelector('meta[property="og:description"]')
        ?.attributes['content'];
    if (ogDescription != null && ogDescription.isNotEmpty) {
      return ogDescription;
    }

    // Twitter Card description
    final twitterDescription = document
        .querySelector('meta[name="twitter:description"]')
        ?.attributes['content'];
    if (twitterDescription != null && twitterDescription.isNotEmpty) {
      return twitterDescription;
    }

    // HTML meta description
    final metaDescription = document
        .querySelector('meta[name="description"]')
        ?.attributes['content'];
    if (metaDescription != null && metaDescription.isNotEmpty) {
      return metaDescription;
    }

    return null;
  }

  /// 画像URLを抽出（優先順: og:image > twitter:image）
  static String? _extractImageUrl(Document document, Uri uri) {
    String? imageUrl;

    // Open Graph image
    imageUrl = document
        .querySelector('meta[property="og:image"]')
        ?.attributes['content'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _resolveUrl(imageUrl, uri);
    }

    // Twitter Card image
    imageUrl = document
        .querySelector('meta[name="twitter:image"]')
        ?.attributes['content'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _resolveUrl(imageUrl, uri);
    }

    return null;
  }

  /// ファビコンURLを抽出
  static String? _extractFaviconUrl(Document document, Uri uri) {
    // <link rel="icon"> を探す
    final iconLink = document.querySelector('link[rel~="icon"]');
    final href = iconLink?.attributes['href'];
    
    if (href != null && href.isNotEmpty) {
      return _resolveUrl(href, uri);
    }

    // フォールバック: /favicon.ico
    return '${uri.scheme}://${uri.host}/favicon.ico';
  }

  /// 相対URLを絶対URLに変換
  static String _resolveUrl(String url, Uri baseUri) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    if (url.startsWith('//')) {
      return '${baseUri.scheme}:$url';
    }
    
    if (url.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}$url';
    }
    
    return '${baseUri.scheme}://${baseUri.host}/${baseUri.path}/$url';
  }
}

