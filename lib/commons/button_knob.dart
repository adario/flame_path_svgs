import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

extension ButtonKnobsBuilder on KnobsBuilder {
  /// A knob that shows a button with the given [text] and returns the number
  /// of times it has been pressed, so that the use case can react to a press
  /// whenever the returned value changes.
  int button({required String label, required String text}) {
    return onKnobAdded(ButtonKnob(label: label, text: text)) ?? 0;
  }
}

class ButtonKnob extends Knob<int?> {
  ButtonKnob({required super.label, required this.text})
    : super(initialValue: 0);

  final String text;

  @override
  List<Field> get fields => [ButtonField(name: label, text: text)];

  @override
  int? valueFromQueryGroup(Map<String, String> group) {
    return valueOf(label, group);
  }
}

class ButtonField extends Field<int> {
  ButtonField({required super.name, required this.text})
    : super(
        initialValue: 0,
        defaultValue: 0,
        type: FieldType.intInput,
        codec: FieldCodec(
          toParam: (value) => value.toString(),
          toValue: (param) => param == null ? null : int.tryParse(param),
        ),
      );

  final String text;

  @override
  Widget toWidget(BuildContext context, String group, int? value) {
    return OutlinedButton(
      onPressed: () => updateField(context, group, (value ?? 0) + 1),
      child: Text(text),
    );
  }
}
