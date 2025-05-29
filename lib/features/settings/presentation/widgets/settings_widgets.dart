import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class CurrencyTextField extends StatelessWidget {
  final String label;
  final double value;
  final Function(double) onChanged;
  final String? errorText;

  const CurrencyTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixText: '\$ ',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      controller: TextEditingController(
        text: value.toStringAsFixed(2),
      ),
      onChanged: (value) {
        final number = double.tryParse(value);
        if (number != null) {
          onChanged(number);
        }
      },
    );
  }
}

class HoursTextField extends StatelessWidget {
  final String label;
  final int value;
  final Function(int) onChanged;
  final String? errorText;

  const HoursTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      controller: TextEditingController(
        text: value.toString(),
      ),
      onChanged: (value) {
        final number = int.tryParse(value);
        if (number != null) {
          onChanged(number);
        }
      },
    );
  }
}

class WorkDaysSelector extends StatelessWidget {
  final List<bool> workDays;
  final Function(List<bool>) onChanged;

  const WorkDaysSelector({
    super.key,
    required this.workDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: List.generate(7, (index) {
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return FilterChip(
          label: Text(dayNames[index]),
          selected: workDays[index],
          onSelected: (selected) {
            final newWorkDays = List<bool>.from(workDays);
            newWorkDays[index] = selected;
            onChanged(newWorkDays);
          },
        );
      }),
    );
  }
}

class PercentageSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool isOvertime;

  const PercentageSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isOvertime = false,
  });

  @override
  Widget build(BuildContext context) {
    // For overtime, we need to handle values > 1.0
    final displayValue = isOvertime ? value : value.clamp(0.0, 1.0);
    final maxValue = isOvertime ? 2.0 : 1.0;
    final divisions = isOvertime ? 200 : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: displayValue,
                min: 0.0,
                max: maxValue,
                divisions: divisions,
                label: '${(displayValue * 100).round()}%',
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                '${(displayValue * 100).round()}%',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CurrencySelector extends StatelessWidget {
  final String value;
  final Function(String) onChanged;

  const CurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];
    
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
      ),
      items: currencies.map((currency) {
        return DropdownMenuItem(
          value: currency,
          child: Text(currency),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
