import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/list_name.dart';

part 'custom_list.freezed.dart';

/// カスタムリストのドメインエンティティ
///
/// SOMEDAYページで使用されるカスタムリスト
/// Nostrに同期される（リスト名のみ）
@freezed
class CustomList with _$CustomList {
  const factory CustomList({
    /// リストID（リスト名から決定的に生成）
    required String id,
    
    /// リスト名（大文字）
    required ListName name,
    
    /// 並び順
    required int order,
    
    /// 作成日時
    required DateTime createdAt,
    
    /// 更新日時
    required DateTime updatedAt,
  }) = _CustomList;
  
  const CustomList._();
  
  /// リスト名から決定的なIDを生成（NIP-51準拠）
  /// 
  /// 例:
  /// - "BRAIN DUMP" → "brain-dump"
  /// - "Grocery List" → "grocery-list"  
  /// - "TO BUY!!!" → "to-buy"
  /// 
  /// ⚠️ 日本語や特殊文字は削除されます：
  /// - "買い物リスト" → "" (空文字列)
  /// - "Groceryリスト" → "grocery"
  /// 
  /// 空文字列になった場合は、"unnamed-list"を返します
  static String generateIdFromName(String name) {
    final id = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // 特殊文字を削除（日本語も削除される）
        .replaceAll(RegExp(r'\s+'), '-')     // スペースをハイフンに
        .replaceAll(RegExp(r'-+'), '-')      // 連続するハイフンを1つに
        .replaceAll(RegExp(r'^-|-$'), '');   // 先頭・末尾のハイフンを削除
    
    // 空文字列の場合はフォールバック
    if (id.isEmpty) {
      return 'unnamed-list';
    }
    
    return id;
  }
}

