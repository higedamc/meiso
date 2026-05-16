import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meiso/core/common/failure.dart';
import 'package:meiso/features/mls/application/usecases/sync_group_invitations_usecase.dart';
import 'package:meiso/features/mls/domain/entities/group_invitation.dart';
import 'package:meiso/features/mls/domain/repositories/mls_group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMlsGroupRepository extends Mock implements MlsGroupRepository {}

void main() {
  late SyncGroupInvitationsUseCase usecase;
  late MockMlsGroupRepository mockRepository;

  final invitation = GroupInvitation(
    groupId: 'group-1',
    groupName: 'Team',
    welcomeMessage: 'welcome',
    inviterPubkey: 'abcdef1234567890',
    createdAt: DateTime(2026, 1, 1),
    isPending: true,
  );

  setUpAll(() {
    registerFallbackValue(invitation);
    registerFallbackValue(<String>{});
  });

  setUp(() {
    mockRepository = MockMlsGroupRepository();
    usecase = SyncGroupInvitationsUseCase(mockRepository);
  });

  group('SyncGroupInvitationsUseCase', () {
    test('deletedGroupIds に含まれる招待は保存しない', () async {
      when(
        () => mockRepository.syncGroupInvitations(
          recipientPublicKey: 'pubkey-1',
        ),
      ).thenAnswer((_) async => Right([invitation]));

      final result = await usecase(
        const SyncGroupInvitationsParams(
          recipientPublicKey: 'pubkey-1',
          deletedGroupIds: {'group-1'},
        ),
      );

      expect(result.isRight(), true);
      verifyNever(
        () => mockRepository.loadMlsGroupFromLocal(
          groupId: any(named: 'groupId'),
        ),
      );
      verifyNever(
        () => mockRepository.saveInvitationToLocal(
          any(),
          blockedGroupIds: any(named: 'blockedGroupIds'),
        ),
      );
    });

    test('削除対象でない招待は保存する', () async {
      when(
        () => mockRepository.syncGroupInvitations(
          recipientPublicKey: 'pubkey-1',
        ),
      ).thenAnswer((_) async => Right([invitation]));
      when(
        () => mockRepository.loadMlsGroupFromLocal(groupId: 'group-1'),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRepository.saveInvitationToLocal(
          invitation,
          blockedGroupIds: any(named: 'blockedGroupIds'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await usecase(
        const SyncGroupInvitationsParams(
          recipientPublicKey: 'pubkey-1',
        ),
      );

      expect(result.isRight(), true);
      verify(
        () => mockRepository.loadMlsGroupFromLocal(groupId: 'group-1'),
      ).called(1);
      verify(
        () => mockRepository.saveInvitationToLocal(
          invitation,
          blockedGroupIds: any(named: 'blockedGroupIds'),
        ),
      ).called(1);
    });
  });
}
