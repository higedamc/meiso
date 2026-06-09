// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MediaAttachment _$MediaAttachmentFromJson(Map<String, dynamic> json) {
  return _MediaAttachment.fromJson(json);
}

/// @nodoc
mixin _$MediaAttachment {
  String get url => throw _privateConstructorUsedError;
  String get sha256 => throw _privateConstructorUsedError;
  String? get mimeType => throw _privateConstructorUsedError;
  int? get size => throw _privateConstructorUsedError;
  String? get blurHash => throw _privateConstructorUsedError;

  /// Serializes this MediaAttachment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MediaAttachment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaAttachmentCopyWith<MediaAttachment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaAttachmentCopyWith<$Res> {
  factory $MediaAttachmentCopyWith(
    MediaAttachment value,
    $Res Function(MediaAttachment) then,
  ) = _$MediaAttachmentCopyWithImpl<$Res, MediaAttachment>;
  @useResult
  $Res call({
    String url,
    String sha256,
    String? mimeType,
    int? size,
    String? blurHash,
  });
}

/// @nodoc
class _$MediaAttachmentCopyWithImpl<$Res, $Val extends MediaAttachment>
    implements $MediaAttachmentCopyWith<$Res> {
  _$MediaAttachmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaAttachment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? sha256 = null,
    Object? mimeType = freezed,
    Object? size = freezed,
    Object? blurHash = freezed,
  }) {
    return _then(
      _value.copyWith(
            url: null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String,
            sha256: null == sha256
                ? _value.sha256
                : sha256 // ignore: cast_nullable_to_non_nullable
                      as String,
            mimeType: freezed == mimeType
                ? _value.mimeType
                : mimeType // ignore: cast_nullable_to_non_nullable
                      as String?,
            size: freezed == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int?,
            blurHash: freezed == blurHash
                ? _value.blurHash
                : blurHash // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MediaAttachmentImplCopyWith<$Res>
    implements $MediaAttachmentCopyWith<$Res> {
  factory _$$MediaAttachmentImplCopyWith(
    _$MediaAttachmentImpl value,
    $Res Function(_$MediaAttachmentImpl) then,
  ) = __$$MediaAttachmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String url,
    String sha256,
    String? mimeType,
    int? size,
    String? blurHash,
  });
}

/// @nodoc
class __$$MediaAttachmentImplCopyWithImpl<$Res>
    extends _$MediaAttachmentCopyWithImpl<$Res, _$MediaAttachmentImpl>
    implements _$$MediaAttachmentImplCopyWith<$Res> {
  __$$MediaAttachmentImplCopyWithImpl(
    _$MediaAttachmentImpl _value,
    $Res Function(_$MediaAttachmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MediaAttachment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? sha256 = null,
    Object? mimeType = freezed,
    Object? size = freezed,
    Object? blurHash = freezed,
  }) {
    return _then(
      _$MediaAttachmentImpl(
        url: null == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String,
        sha256: null == sha256
            ? _value.sha256
            : sha256 // ignore: cast_nullable_to_non_nullable
                  as String,
        mimeType: freezed == mimeType
            ? _value.mimeType
            : mimeType // ignore: cast_nullable_to_non_nullable
                  as String?,
        size: freezed == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int?,
        blurHash: freezed == blurHash
            ? _value.blurHash
            : blurHash // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaAttachmentImpl implements _MediaAttachment {
  const _$MediaAttachmentImpl({
    required this.url,
    required this.sha256,
    this.mimeType,
    this.size,
    this.blurHash,
  });

  factory _$MediaAttachmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaAttachmentImplFromJson(json);

  @override
  final String url;
  @override
  final String sha256;
  @override
  final String? mimeType;
  @override
  final int? size;
  @override
  final String? blurHash;

  @override
  String toString() {
    return 'MediaAttachment(url: $url, sha256: $sha256, mimeType: $mimeType, size: $size, blurHash: $blurHash)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaAttachmentImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.sha256, sha256) || other.sha256 == sha256) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.blurHash, blurHash) ||
                other.blurHash == blurHash));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, url, sha256, mimeType, size, blurHash);

  /// Create a copy of MediaAttachment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaAttachmentImplCopyWith<_$MediaAttachmentImpl> get copyWith =>
      __$$MediaAttachmentImplCopyWithImpl<_$MediaAttachmentImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaAttachmentImplToJson(this);
  }
}

abstract class _MediaAttachment implements MediaAttachment {
  const factory _MediaAttachment({
    required final String url,
    required final String sha256,
    final String? mimeType,
    final int? size,
    final String? blurHash,
  }) = _$MediaAttachmentImpl;

  factory _MediaAttachment.fromJson(Map<String, dynamic> json) =
      _$MediaAttachmentImpl.fromJson;

  @override
  String get url;
  @override
  String get sha256;
  @override
  String? get mimeType;
  @override
  int? get size;
  @override
  String? get blurHash;

  /// Create a copy of MediaAttachment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaAttachmentImplCopyWith<_$MediaAttachmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
