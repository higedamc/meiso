import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/recurrence_pattern.dart';

/// リカーリングタスクの繰り返し設定ダイアログ
class RecurrenceSettingDialog extends StatefulWidget {
  const RecurrenceSettingDialog({
    this.initialPattern,
    super.key,
  });

  final RecurrencePattern? initialPattern;

  @override
  State<RecurrenceSettingDialog> createState() => _RecurrenceSettingDialogState();
}

class _RecurrenceSettingDialogState extends State<RecurrenceSettingDialog> {
  late RecurrenceType _type;
  late int _interval;
  late List<int> _weekdays;
  late int _dayOfMonth;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    
    if (widget.initialPattern != null) {
      _type = widget.initialPattern!.type;
      _interval = widget.initialPattern!.interval;
      _weekdays = List<int>.from(widget.initialPattern!.weekdays ?? []);
      _dayOfMonth = widget.initialPattern!.dayOfMonth ?? DateTime.now().day;
      _endDate = widget.initialPattern!.endDate;
    } else {
      _type = RecurrenceType.daily;
      _interval = 1;
      _weekdays = [];
      _dayOfMonth = DateTime.now().day;
      _endDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ヘッダー
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  color: AppTheme.primaryPurple,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '繰り返し設定',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 繰り返しタイプ選択
            Text(
              '繰り返し',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildTypeSelector(isDark),
            const SizedBox(height: 24),

            // 間隔設定
            Text(
              '間隔',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildIntervalSelector(isDark, theme),
            const SizedBox(height: 24),

            // タイプ別の詳細設定
            if (_type == RecurrenceType.weekly) ...[
              Text(
                '曜日',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildWeekdaySelector(isDark),
              const SizedBox(height: 24),
            ],

            if (_type == RecurrenceType.monthly) ...[
              Text(
                '日付',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildDayOfMonthSelector(isDark, theme),
              const SizedBox(height: 24),
            ],

            // 終了日設定
            _buildEndDateSetting(isDark, theme),
            const SizedBox(height: 24),

            // プレビュー
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCard.withOpacity(0.5)
                    : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPreviewText(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.initialPattern != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      '繰り返しを解除',
                      style: TextStyle(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canSave() ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecurrenceType.values.map((type) {
        final isSelected = _type == type;
        return ChoiceChip(
          label: Text(type.displayName),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _type = type;
              });
            }
          },
          selectedColor: AppTheme.primaryPurple.withOpacity(0.2),
          backgroundColor: isDark
              ? AppTheme.darkCard
              : AppTheme.lightCard,
          labelStyle: TextStyle(
            color: isSelected
                ? AppTheme.primaryPurple
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIntervalSelector(bool isDark, ThemeData theme) {
    final unitText = _type == RecurrenceType.daily
        ? '日'
        : _type == RecurrenceType.weekly
            ? '週'
            : _type == RecurrenceType.monthly
                ? 'ヶ月'
                : '';

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _interval > 1
                    ? () => setState(() => _interval--)
                    : null,
                iconSize: 20,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                child: Text(
                  '$_interval',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _interval < 99
                    ? () => setState(() => _interval++)
                    : null,
                iconSize: 20,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unitText,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector(bool isDark) {
    final weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final weekday = index + 1; // 1=月曜, 7=日曜
        final isSelected = _weekdays.contains(weekday);
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _weekdays.remove(weekday);
              } else {
                _weekdays.add(weekday);
                _weekdays.sort();
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryPurple
                  : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryPurple
                    : (isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                weekdayLabels[index],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayOfMonthSelector(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _dayOfMonth > 1
                    ? () => setState(() => _dayOfMonth--)
                    : null,
                iconSize: 20,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                child: Text(
                  '$_dayOfMonth',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _dayOfMonth < 31
                    ? () => setState(() => _dayOfMonth++)
                    : null,
                iconSize: 20,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '日',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildEndDateSetting(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '終了日',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _endDate != null,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _endDate = DateTime.now().add(const Duration(days: 30));
                  } else {
                    _endDate = null;
                  }
                });
              },
              activeColor: AppTheme.primaryPurple,
            ),
            Text(
              '終了日を設定',
              style: theme.textTheme.bodyMedium,
            ),
            if (_endDate != null) ...[
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}',
                ),
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _endDate = pickedDate;
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryPurple,
                  side: BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _getPreviewText() {
    final pattern = RecurrencePattern(
      type: _type,
      interval: _interval,
      weekdays: _type == RecurrenceType.weekly ? _weekdays : null,
      dayOfMonth: _type == RecurrenceType.monthly ? _dayOfMonth : null,
      endDate: _endDate,
    );
    
    return pattern.description;
  }

  bool _canSave() {
    if (_type == RecurrenceType.weekly && _weekdays.isEmpty) {
      return false;
    }
    return true;
  }

  void _save() {
    final pattern = RecurrencePattern(
      type: _type,
      interval: _interval,
      weekdays: _type == RecurrenceType.weekly ? (_weekdays.isEmpty ? null : _weekdays) : null,
      dayOfMonth: _type == RecurrenceType.monthly ? _dayOfMonth : null,
      endDate: _endDate,
    );
    
    Navigator.of(context).pop(pattern);
  }
}

