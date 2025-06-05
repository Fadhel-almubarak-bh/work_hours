import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../../core/constants/currency_constants.dart';

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

class CurrencyTextField extends StatefulWidget {
  final String label;
  final double value;
  final Function(double) onChanged;
  final String? errorText;
  final String currency;

  const CurrencyTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    required this.currency,
  });

  @override
  State<CurrencyTextField> createState() => _CurrencyTextFieldState();
}

class _CurrencyTextFieldState extends State<CurrencyTextField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  String _formatNumber(double number) {
    // Remove trailing .0 if it's a whole number
    return number == number.roundToDouble() 
        ? number.round().toString() 
        : number.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNumber(widget.value));
  }

  @override
  void didUpdateWidget(CurrencyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_controller.text.contains('.')) {
      _controller.text = _formatNumber(widget.value);
    }
  }

  void _handleValueChange(String value) {
    final number = double.tryParse(value);
    if (number != null) {
      // Debounce the update to avoid too many saves
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        widget.onChanged(number);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        prefixText: '${widget.currency} ',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      controller: _controller,
      onChanged: _handleValueChange,
    );
  }
}

class HoursTextField extends StatefulWidget {
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
  State<HoursTextField> createState() => _HoursTextFieldState();
}

class _HoursTextFieldState extends State<HoursTextField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(HoursTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  void _handleValueChange(String value) {
    final number = int.tryParse(value);
    if (number != null) {
      // Debounce the update to avoid too many saves
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        widget.onChanged(number);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      controller: _controller,
      onChanged: _handleValueChange,
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

class PercentageTextField extends StatefulWidget {
  final String label;
  final double value;
  final Function(double) onChanged;
  final String? errorText;
  final bool isOvertime;

  const PercentageTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.isOvertime = false,
  });

  @override
  State<PercentageTextField> createState() => _PercentageTextFieldState();
}

class _PercentageTextFieldState extends State<PercentageTextField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;

  String _formatNumber(double number) {
    // Remove trailing .0 if it's a whole number
    return number == number.roundToDouble() 
        ? number.round().toString() 
        : number.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNumber(widget.value * 100));
  }

  @override
  void didUpdateWidget(PercentageTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_controller.text.contains('.')) {
      _controller.text = _formatNumber(widget.value * 100);
    }
  }

  void _handleValueChange(String value) {
    final number = double.tryParse(value);
    if (number != null) {
      // Convert percentage to decimal
      final decimalValue = number / 100;
      // Debounce the update to avoid too many saves
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        widget.onChanged(decimalValue);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      controller: _controller,
      onChanged: _handleValueChange,
    );
  }
}

class CurrencySelector extends StatefulWidget {
  final String value;
  final Function(String) onChanged;

  const CurrencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.value;
  }

  @override
  void didUpdateWidget(CurrencySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectedCurrency = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedCurrency,
      decoration: const InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
      ),
      items: CurrencyConstants.supportedCurrencies.map((currency) {
        return DropdownMenuItem(
          value: currency,
          child: Text(currency),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCurrency = value;
          });
          widget.onChanged(value);
        }
      },
    );
  }
}
