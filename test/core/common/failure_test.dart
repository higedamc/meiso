import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';

void main() {
  group('Failure', () {
    test('NetworkFailure has correct default message', () {
      const failure = NetworkFailure();
      expect(failure.message, 'ネットワークエラーが発生しました');
    });

    test('NetworkFailure accepts custom message', () {
      const failure = NetworkFailure('カスタムメッセージ');
      expect(failure.message, 'カスタムメッセージ');
    });

    test('AuthFailure has correct default message', () {
      const failure = AuthFailure();
      expect(failure.message, '認証に失敗しました');
    });

    test('ServerFailure has correct default message', () {
      const failure = ServerFailure();
      expect(failure.message, 'サーバーエラーが発生しました');
    });

    test('CacheFailure has correct default message', () {
      const failure = CacheFailure();
      expect(failure.message, 'キャッシュエラーが発生しました');
    });

    test('ValidationFailure requires message', () {
      const failure = ValidationFailure('バリデーションエラー');
      expect(failure.message, 'バリデーションエラー');
    });

    test('UnexpectedFailure has correct default message', () {
      const failure = UnexpectedFailure();
      expect(failure.message, '予期しないエラーが発生しました');
    });

    test('NostrFailure has correct default message', () {
      const failure = NostrFailure();
      expect(failure.message, 'Nostrエラーが発生しました');
    });

    test('AmberFailure has correct default message', () {
      const failure = AmberFailure();
      expect(failure.message, 'Amberエラーが発生しました');
    });

    test('EncryptionFailure has correct default message', () {
      const failure = EncryptionFailure();
      expect(failure.message, '暗号化に失敗しました');
    });

    test('DecryptionFailure has correct default message', () {
      const failure = DecryptionFailure();
      expect(failure.message, '復号化に失敗しました');
    });

    test('Failure toString returns message', () {
      const failure = NetworkFailure('テストメッセージ');
      expect(failure.toString(), 'テストメッセージ');
    });

    test('Failures with same message are equal', () {
      const failure1 = NetworkFailure('同じメッセージ');
      const failure2 = NetworkFailure('同じメッセージ');
      expect(failure1, equals(failure2));
    });

    test('Failures with different messages are not equal', () {
      const failure1 = NetworkFailure('メッセージ1');
      const failure2 = NetworkFailure('メッセージ2');
      expect(failure1, isNot(equals(failure2)));
    });

    test('Different failure types with same message are not equal', () {
      const failure1 = NetworkFailure('同じメッセージ');
      const failure2 = ServerFailure('同じメッセージ');
      expect(failure1, isNot(equals(failure2)));
    });

    test('Failure hashCode is based on message', () {
      const failure1 = NetworkFailure('メッセージ');
      const failure2 = NetworkFailure('メッセージ');
      expect(failure1.hashCode, equals(failure2.hashCode));
    });
  });
}

