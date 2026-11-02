import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:stagess_common/models/persons/student.dart';
import 'package:stagess_common_flutter/providers/students_provider.dart';
import 'package:stagess_common_flutter/widgets/autocomplete_options_builder.dart';

class StudentPickerController {
  final String schoolBoardId;
  TextEditingController? _textController;

  final List<Student>? _studentWhiteList;

  Student? _selection;
  Student? get student => _selection;
  set student(Student? value) {
    _selection = value;
    _textController?.text = value?.fullName ?? '';
    _formKey.currentState?.didChange(value?.fullName);
  }

  StudentPickerController({
    required this.schoolBoardId,
    Student? initial,
    List<Student>? studentWhiteList,
  })  : _studentWhiteList = studentWhiteList,
        _selection = initial ?? Student.empty;

  final _formKey = GlobalKey<FormFieldState<String>>();

  void dispose() {
    // Since _textController is managed by the FormField, we don't need to
    // dispose of it here.
  }
}

class StudentPickerTile extends StatelessWidget {
  const StudentPickerTile({
    super.key,
    required this.controller,
    this.title,
    this.editMode = true,
    this.isMandatory = true,
    this.onSelected,
  });

  final StudentPickerController controller;
  final String? title;
  final bool editMode;
  final bool isMandatory;
  final Function(Student?)? onSelected;

  @override
  Widget build(BuildContext context) {
    return FormField<Student>(
      key: controller._formKey,
      initialValue: controller._selection,
      builder: (field) => _builder(context, field),
      enabled: editMode,
    );
  }

  Widget _builder(BuildContext context, FormFieldState<Student> state) {
    final students = [
      ...StudentsProvider.of(
        context,
        listen: true,
      ).where((student) => student.schoolBoardId == controller.schoolBoardId),
    ];
    if (controller._studentWhiteList != null) {
      students.retainWhere(
        (student) => controller._studentWhiteList!.contains(student),
      );
    }
    students.sort((a, b) => a.lastName.compareTo(b.lastName));

    void commitSelectionFromText(String? rawText) {
      final matchedStudent = students.firstWhereOrNull(
        (student) =>
            student.fullName.trim().toLowerCase() ==
            (rawText?.trim().toLowerCase() ?? ''),
      );
      if (matchedStudent == null) {
        controller._selection = Student.empty;
        state.didChange(Student.empty);
        return;
      }

      final hasChangedSelection = controller.student?.id != matchedStudent.id;
      controller.student = matchedStudent;
      state.didChange(matchedStudent);
      if (hasChangedSelection && onSelected != null) onSelected!(matchedStudent);
    }

    return Autocomplete<Student>(
      initialValue: TextEditingValue(
        text: controller._selection?.fullName ?? '',
      ),
      optionsBuilder: (textEditingValue) {
        final text = textEditingValue.text.trim();

        // Suggestions are computed here; selection state should not be mutated,
        // otherwise the parent widget rebuilds while the dropdown is opening and
        // Enter/click selection becomes inconsistent.
        if (text.isEmpty) return students;

        final normalizedText = text.toLowerCase();
        return students.where(
          (student) =>
              student.fullName.toLowerCase().contains(normalizedText) &&
              student.fullName.toLowerCase() != normalizedText,
        );
      },
      optionsViewBuilder: (context, onSelected, options) =>
          OptionsBuilderForAutocomplete(
        onSelected: onSelected,
        options: options,
        optionToString: (Student e) => e.fullName,
      ),
      onSelected: (item) {
        controller.student = item;
        if (onSelected != null) onSelected!(item);
      },
      fieldViewBuilder: (_, textController, focusNode, onSubmitted) {
        controller._textController = textController;

        return Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) commitSelectionFromText(textController.text);
          },
          child: TextFormField(
            controller: controller._textController,
            focusNode: focusNode,
            readOnly: false,
            enabled: editMode,
            style: const TextStyle(color: Colors.black),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => onSubmitted(),
            validator: (value) {
              if (isMandatory && (value?.trim().isEmpty ?? true)) {
                return 'Sélectionner un·e élève';
              }

              return validateExactAutocompleteOption<Student>(
                value: value,
                options: students,
                optionToString: (student) => student.fullName,
                errorMessage: 'Sélectionner un·e élève',
              );
            },
            decoration: InputDecoration(
              labelText:
                  title ?? '${isMandatory ? '* ' : ''}Sélectionner un·e élève',
              labelStyle: const TextStyle(color: Colors.black),
              errorText: state.errorText,
              suffixIcon: IconButton(
                onPressed: () {
                  if (focusNode.hasFocus) focusNode.previousFocus();
                  controller.student = Student.empty;
                  textController.clear();
                  state.didChange(Student.empty);
                },
                icon: const Icon(Icons.clear),
              ),
            ),
          ),
        );
      },
    );
  }
}
