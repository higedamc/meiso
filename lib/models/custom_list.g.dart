// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CustomListImpl _$$CustomListImplFromJson(Map<String, dynamic> json) =>
    _$CustomListImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isGroup: json['isGroup'] as bool? ?? false,
      isMlsGroup: json['isMlsGroup'] as bool? ?? false,
      groupMembers:
          (json['groupMembers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPendingInvitation: json['isPendingInvitation'] as bool? ?? false,
      inviterNpub: json['inviterNpub'] as String?,
      inviterName: json['inviterName'] as String?,
      welcomeMsg: json['welcomeMsg'] as String?,
    );

Map<String, dynamic> _$$CustomListImplToJson(_$CustomListImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'order': instance.order,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isGroup': instance.isGroup,
      'isMlsGroup': instance.isMlsGroup,
      'groupMembers': instance.groupMembers,
      'isPendingInvitation': instance.isPendingInvitation,
      'inviterNpub': instance.inviterNpub,
      'inviterName': instance.inviterName,
      'welcomeMsg': instance.welcomeMsg,
    };
