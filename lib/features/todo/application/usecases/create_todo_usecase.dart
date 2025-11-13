import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/common/usecase.dart';
import '../../../../core/common/failure.dart';
import '../../../../models/todo.dart';
import '../../../../models/link_preview.dart';
import '../../../../models/recurrence_pattern.dart';
import '../../../../services/recurrence_parser.dart';
import '../../../../services/link_preview_service.dart';
import '../../../../services/logger_service.dart';

/// CreateTodoUseCaseのパラメータ
class CreateTodoParams {
  final String title;
  final DateTime? date;
  final String? customListId;
  final Map<DateTime?, List<Todo>> currentTodos; // 現在のTodoリスト（order計算用）

  const CreateTodoParams({
    required this.title,
    required this.date,
    this.customListId,
    required this.currentTodos,
  });
}

/// 新しいTodoを作成するUseCase
/// 
/// 責務:
/// - タイトルのバリデーション
/// - 繰り返しパターンの自動検出
/// - URLの検出とリンクプレビュー準備
/// - Todoオブジェクトの生成
/// - orderの計算
class CreateTodoUseCase implements UseCase<Todo, CreateTodoParams> {
  final _uuid = const Uuid();

  @override
  Future<Either<Failure, Todo>> call(CreateTodoParams params) async {
    try {
      // バリデーション: 空タイトルチェック
      if (params.title.trim().isEmpty) {
        return const Left(ValidationFailure('タイトルが空です'));
      }

      AppLogger.info('🔧 CreateTodoUseCase: Creating todo with title "${params.title}"');

      // 繰り返しパターンを自動検出（TeuxDeux風）
      final parseResult = RecurrenceParser.parse(params.title, params.date);
      final cleanTitle = parseResult.cleanTitle;
      final autoRecurrence = parseResult.pattern;

      if (autoRecurrence != null) {
        AppLogger.info('🔄 自動検出: ${autoRecurrence.description}');
        AppLogger.debug('📝 クリーンタイトル: "$cleanTitle"');
      }

      // URLを検出してメタデータを取得（準備）
      final detectedUrl = LinkPreviewService.extractUrl(cleanTitle);
      AppLogger.debug('🔗 URL detected: $detectedUrl');

      // URLが検出された場合、即座にタイトルから削除
      String finalTitle = cleanTitle;
      LinkPreview? initialLinkPreview;

      if (detectedUrl != null) {
        // URLからドメイン名を抽出
        String domainName = detectedUrl;
        try {
          final uri = Uri.parse(detectedUrl);
          domainName = uri.host;
        } catch (e) {
          // パースエラー時はそのままURLを使用
        }

        finalTitle = LinkPreviewService.removeUrlFromText(cleanTitle, detectedUrl);
        // 空になった場合（URLのみの入力）はドメイン名を使用
        if (finalTitle.trim().isEmpty) {
          finalTitle = domainName;
        }

        // 一時的なリンクプレビューを作成（取得中を示す）
        initialLinkPreview = LinkPreview(
          url: detectedUrl,
          title: domainName, // ドメイン名を表示
          description: '読み込み中...', // 取得中を日本語で表示
          imageUrl: null,
        );

        AppLogger.debug('📋 Title after URL removal: "$finalTitle" (domain: $domainName)');
      }

      final now = DateTime.now();
      
      // 次のorder値を計算
      final nextOrder = _getNextOrder(params.currentTodos, params.date);

      // Todoオブジェクトを生成
      final newTodo = Todo(
        id: _uuid.v4(),
        title: finalTitle,
        completed: false,
        date: params.date,
        order: nextOrder,
        createdAt: now,
        updatedAt: now,
        customListId: params.customListId,
        recurrence: autoRecurrence, // 自動検出された繰り返しパターンを設定
        linkPreview: initialLinkPreview, // 一時的なリンクプレビューを設定
        needsSync: true, // 同期が必要
      );

      AppLogger.info('✅ Created new Todo object:');
      AppLogger.info('   - id: ${newTodo.id}');
      AppLogger.info('   - title: ${newTodo.title}');
      AppLogger.info('   - date: ${newTodo.date}');
      AppLogger.info('   - customListId: ${newTodo.customListId}');
      AppLogger.info('   - order: ${newTodo.order}');

      return Right(newTodo);
    } catch (e, stackTrace) {
      AppLogger.error('❌ CreateTodoUseCase failed: $e', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Todoの作成に失敗しました: $e'));
    }
  }

  /// 指定された日付の次のorder値を取得
  int _getNextOrder(Map<DateTime?, List<Todo>> todos, DateTime? date) {
    final list = todos[date];
    if (list == null || list.isEmpty) {
      return 0;
    }
    // 最大のorder値を取得して+1
    final maxOrder = list.map((t) => t.order).reduce((a, b) => a > b ? a : b);
    return maxOrder + 1;
  }
}

