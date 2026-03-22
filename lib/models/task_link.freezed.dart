// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TaskLink _$TaskLinkFromJson(Map<String, dynamic> json) {
  return _TaskLink.fromJson(json);
}

/// @nodoc
mixin _$TaskLink {
  String get targetTaskId => throw _privateConstructorUsedError;
  TaskLinkType get linkType => throw _privateConstructorUsedError;

  /// Serializes this TaskLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskLinkCopyWith<TaskLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskLinkCopyWith<$Res> {
  factory $TaskLinkCopyWith(TaskLink value, $Res Function(TaskLink) then) =
      _$TaskLinkCopyWithImpl<$Res, TaskLink>;
  @useResult
  $Res call({String targetTaskId, TaskLinkType linkType});
}

/// @nodoc
class _$TaskLinkCopyWithImpl<$Res, $Val extends TaskLink>
    implements $TaskLinkCopyWith<$Res> {
  _$TaskLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? targetTaskId = null, Object? linkType = null}) {
    return _then(
      _value.copyWith(
            targetTaskId: null == targetTaskId
                ? _value.targetTaskId
                : targetTaskId // ignore: cast_nullable_to_non_nullable
                      as String,
            linkType: null == linkType
                ? _value.linkType
                : linkType // ignore: cast_nullable_to_non_nullable
                      as TaskLinkType,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskLinkImplCopyWith<$Res>
    implements $TaskLinkCopyWith<$Res> {
  factory _$$TaskLinkImplCopyWith(
    _$TaskLinkImpl value,
    $Res Function(_$TaskLinkImpl) then,
  ) = __$$TaskLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String targetTaskId, TaskLinkType linkType});
}

/// @nodoc
class __$$TaskLinkImplCopyWithImpl<$Res>
    extends _$TaskLinkCopyWithImpl<$Res, _$TaskLinkImpl>
    implements _$$TaskLinkImplCopyWith<$Res> {
  __$$TaskLinkImplCopyWithImpl(
    _$TaskLinkImpl _value,
    $Res Function(_$TaskLinkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? targetTaskId = null, Object? linkType = null}) {
    return _then(
      _$TaskLinkImpl(
        targetTaskId: null == targetTaskId
            ? _value.targetTaskId
            : targetTaskId // ignore: cast_nullable_to_non_nullable
                  as String,
        linkType: null == linkType
            ? _value.linkType
            : linkType // ignore: cast_nullable_to_non_nullable
                  as TaskLinkType,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskLinkImpl implements _TaskLink {
  const _$TaskLinkImpl({required this.targetTaskId, required this.linkType});

  factory _$TaskLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskLinkImplFromJson(json);

  @override
  final String targetTaskId;
  @override
  final TaskLinkType linkType;

  @override
  String toString() {
    return 'TaskLink(targetTaskId: $targetTaskId, linkType: $linkType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskLinkImpl &&
            (identical(other.targetTaskId, targetTaskId) ||
                other.targetTaskId == targetTaskId) &&
            (identical(other.linkType, linkType) ||
                other.linkType == linkType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, targetTaskId, linkType);

  /// Create a copy of TaskLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskLinkImplCopyWith<_$TaskLinkImpl> get copyWith =>
      __$$TaskLinkImplCopyWithImpl<_$TaskLinkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskLinkImplToJson(this);
  }
}

abstract class _TaskLink implements TaskLink {
  const factory _TaskLink({
    required final String targetTaskId,
    required final TaskLinkType linkType,
  }) = _$TaskLinkImpl;

  factory _TaskLink.fromJson(Map<String, dynamic> json) =
      _$TaskLinkImpl.fromJson;

  @override
  String get targetTaskId;
  @override
  TaskLinkType get linkType;

  /// Create a copy of TaskLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskLinkImplCopyWith<_$TaskLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
