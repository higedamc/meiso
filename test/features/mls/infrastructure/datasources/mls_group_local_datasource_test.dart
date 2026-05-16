import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/features/mls/domain/entities/group_invitation.dart';
import 'package:meiso/features/mls/infrastructure/datasources/mls_group_local_datasource.dart';
import 'package:meiso/models/custom_list.dart';
import 'package:meiso/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MlsGroupLocalDataSource dataSource;
  late MockLocalStorageService mockLocalStorage;

  final invitation = GroupInvitation(
    groupId: 'group-1',
    groupName: 'Team',
    welcomeMessage: 'welcome',
    inviterPubkey: 'abcdef1234567890',
    createdAt: DateTime(2026, 1, 1),
    isPending: true,
  );

  setUp(() {
    mockLocalStorage = MockLocalStorageService();
    dataSource = MlsGroupLocalDataSource(mockLocalStorage);
  });

  group('MlsGroupLocalDataSource.saveInvitation', () {
    test('blockedGroupIds に含まれる招待は保存しない', () async {
      await dataSource.saveInvitation(
        invitation,
        blockedGroupIds: const {'group-1'},
      );

      verifyNever(() => mockLocalStorage.loadCustomLists());
      verifyNever(() => mockLocalStorage.saveCustomLists(any()));
    });

    test('blocked でない招待は custom list として保存する', () async {
      when(
        () => mockLocalStorage.loadCustomLists(),
      ).thenAnswer((_) async => <CustomList>[]);
      when(
        () => mockLocalStorage.saveCustomLists(any()),
      ).thenAnswer((_) async {});

      await dataSource.saveInvitation(invitation);

      final captured = verify(
        () => mockLocalStorage.saveCustomLists(captureAny()),
      ).captured;
      final savedLists = captured.single as List<CustomList>;

      expect(savedLists, hasLength(1));
      expect(savedLists.first.id, 'group-1');
      expect(savedLists.first.isGroup, true);
      expect(savedLists.first.isPendingInvitation, true);
    });
  });
}
