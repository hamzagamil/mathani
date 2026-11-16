import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mathani_icons.dart';

/// A whole number in [min]..[max]: minus and plus, or typed directly. A typed number outside the
/// bounds is brought into them by [onChanged]'s caller.
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 1,
    this.hint,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String? hint;
  final ValueChanged<int> onChanged;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late final _text = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(NumberStepper old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_text.text) != widget.value) _text.text = '${widget.value}';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(MathaniIcons.minus),
          tooltip: '${widget.label} −',
          onPressed: widget.value > widget.min ? () => widget.onChanged(widget.value - 1) : null,
        ),
        Expanded(
          child: TextField(
            controller: _text,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
            onSubmitted: (s) => widget.onChanged(int.tryParse(s) ?? widget.value),
            onTapOutside: (_) {
              widget.onChanged(int.tryParse(_text.text) ?? widget.value);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        IconButton(
          icon: const Icon(MathaniIcons.plus),
          tooltip: '${widget.label} +',
          onPressed: widget.value < widget.max ? () => widget.onChanged(widget.value + 1) : null,
        ),
      ],
    );
  }
}
