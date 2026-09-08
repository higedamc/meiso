// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cashu_proof.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CashuProofImpl _$$CashuProofImplFromJson(Map<String, dynamic> json) =>
    _$CashuProofImpl(
      id: json['id'] as String,
      amount: (json['amount'] as num).toInt(),
      secret: json['secret'] as String,
      C: json['C'] as String,
      mintUrl: json['mintUrl'] as String,
    );

Map<String, dynamic> _$$CashuProofImplToJson(_$CashuProofImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'secret': instance.secret,
      'C': instance.C,
      'mintUrl': instance.mintUrl,
    };
