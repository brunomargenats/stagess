import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:stagess_common/models/enterprises/enterprise_status.dart';
import 'package:stagess_common/models/enterprises/job.dart';
import 'package:stagess_common/models/generic/access_level.dart';
import 'package:stagess_common/models/school_boards/school.dart';
import 'package:stagess_common/services/job_data_file_service.dart';
import 'package:stagess_common_flutter/providers/auth_provider.dart';
import 'package:stagess_common_flutter/providers/internships_provider.dart';
import 'package:stagess_common_flutter/providers/students_provider.dart';
import 'package:stagess_common_flutter/providers/teachers_provider.dart';
import 'package:stagess_common_flutter/widgets/animated_expanding_card.dart';
import 'package:stagess_common_flutter/widgets/autocomplete_options_builder.dart';
import 'package:stagess_common_flutter/widgets/entity_picker_tile.dart';
import 'package:stagess_common_flutter/widgets/incidents_expansion_panel.dart';
import 'package:stagess_common_flutter/widgets/jobs_expansion_panels/comments_expansion_panel.dart';
import 'package:stagess_common_flutter/widgets/jobs_expansion_panels/photo_expansion_panel.dart';
import 'package:stagess_common_flutter/widgets/jobs_expansion_panels/supervision_expansion_panel.dart';

class EnterpriseJobListController {
  BuildContext context;

  String? enterpriseId;
  EnterpriseStatus enterpriseStatus;

  late Specialization? _specialization = _job.specializationOrNull;
  Specialization? get specialization => _specialization;

  final List<Specialization>? _specializationsWhiteList;
  final List<Specialization>? _specializationBlacklist;

  late final Map<String, int> _positionsOffered = _job.positionsOffered.map(
    (key, value) => MapEntry(key, value),
  );
  Map<String, int> _realPositionsOffered({required bool keepActiveStatus}) {
    final statuses =
        keepActiveStatus && enterpriseStatus != EnterpriseStatus.active
            ? _positionsOffered.map((key, value) => MapEntry(key, 0))
            : _positionsOffered.map((key, value) => MapEntry(key, value));
    return statuses;
  }

  final Map<String, int> _positionsOccupied = {};
  Map<String, int> get positionsOccupied =>
      enterpriseStatus == EnterpriseStatus.active ? _positionsOccupied : {};

  final EntityPickerController? _reservedForPickerController;
  String? get _reservedForSchoolId =>
      context.mounted && _reservedForPickerController?.selectionId != null
          ? TeachersProvider.of(
              context,
              listen: false,
            ).fromIdOrNull(_reservedForPickerController!.selectionId!)?.schoolId
          : null;

  final Job _job;
  EnterpriseJobListController({
    required this.context,
    required this.enterpriseStatus,
    this.enterpriseId,
    required Job? job,
    List<Specialization>? specializationWhiteList,
    List<Specialization>? specializationBlackList,
    EntityPickerController? reservedForPickerController,
  })  : _job = job?.copyWith() ?? Job.empty,
        _specializationsWhiteList = specializationWhiteList,
        _specializationBlacklist = specializationBlackList,
        _reservedForPickerController = reservedForPickerController {
    final students = StudentsProvider.of(context, listen: false);
    final internships = InternshipsProvider.of(context, listen: false);

    _positionsOccupied.clear();
    for (final intership in internships) {
      if (intership.currentContract?.jobId == _job.id && intership.isActive) {
        final schoolId = students
            .firstWhereOrNull(
              (student) => student.id == intership.studentId,
            )
            ?.schoolId;
        if (schoolId == null) continue;

        _positionsOccupied[schoolId] = (_positionsOccupied[schoolId] ?? 0) + 1;
      }
    }
  }

  Job get job => _job.copyWith(
        specialization: _specialization,
        reservedForId: _reservedForPickerController == null
            ? _job.reservedForId
            : (_reservedForPickerController?.selectionId ?? ''),
      );
}

class EnterpriseJobListTile extends StatefulWidget {
  const EnterpriseJobListTile({
    super.key,
    required this.controller,
    required this.schools,
    this.editMode = false,
    this.canChangeSpecialization = true,
    this.onRequestDelete,
    this.canChangeExpandedState = true,
    this.initialExpandedState = false,
    this.elevation = 10.0,
    this.specializationOnly = false,
    this.showHeader = true,
    this.jobPickerPadding,
    this.availabilityIsMandatory = false,
    this.showJobNameTitle = true,
    this.showExtended = false,
    this.onChangingImage,
  });

  final EnterpriseJobListController controller;
  final List<School>? schools;
  final bool editMode;
  final bool canChangeSpecialization;
  final Function()? onRequestDelete;
  final bool canChangeExpandedState;
  final bool initialExpandedState;
  final double elevation;
  final bool specializationOnly;
  final bool showHeader;
  final EdgeInsets? jobPickerPadding;
  final bool availabilityIsMandatory;
  final bool showJobNameTitle;
  final bool showExtended;
  final void Function(bool isDone)? onChangingImage;

  @override
  State<EnterpriseJobListTile> createState() => _EnterpriseJobListTileState();
}

class _EnterpriseJobListTileState extends State<EnterpriseJobListTile> {
  Job get job => widget.controller.job;

  @override
  void initState() {
    super.initState();
    widget.controller._reservedForPickerController?.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  void _updatePositions(String schoolId, int newCount) {
    setState(() => widget.controller._positionsOffered[schoolId] = newCount);
  }

  @override
  void dispose() {
    widget.controller._reservedForPickerController?.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = AuthProvider.of(context, listen: false);

    final schools = widget.schools?.where(
          (school) =>
              (authProvider.databaseAccessLevel >=
                      AccessLevel.schoolBoardAdmin ||
                  school.id == authProvider.schoolId) &&
              (widget.controller._reservedForSchoolId == null ||
                  widget.controller._reservedForSchoolId == school.id),
        ) ??
        [];

    final showJobPicker = widget.showJobNameTitle ||
        (widget.editMode && widget.controller._specialization == null);
    final showEditModeDetailsPlaceholder = widget.editMode &&
        widget.controller._specialization != null &&
        !widget.showExtended;

    return AnimatedExpandingCard(
      elevation: widget.elevation,
      canChangeExpandedState: widget.canChangeExpandedState,
      initialExpandedState: widget.initialExpandedState,
      header: (ctx, isExpanded) => widget.showHeader
          ? Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.controller._specialization?.idWithName ??
                              'Aucun métier sélectionné (Veuillez sélectionner un plus bas)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (widget.editMode && widget.onRequestDelete != null)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: widget.onRequestDelete,
                        ),
                    ],
                  ),
                  SizedBox(height: 4.0),
                  if (widget.controller._reservedForPickerController != null)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: widget.editMode ? 20 : 12,
                      ),
                      child: _buildReservedFor(),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    widget.editMode
                        ? '* Indiquer le nombre de places de stages disponibles :'
                        : 'Nombre de places de stages disponibles :',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...schools.sorted((a, b) => a.name.compareTo(b.name)).map(
                        (school) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 2.0,
                          ),
                          child: _buildAvailability(school: school),
                        ),
                      ),
                  if (widget.canChangeExpandedState) const SizedBox(height: 8),
                ],
              ),
            )
          : const SizedBox.shrink(),
      child: Padding(
        padding: widget.jobPickerPadding ??
            const EdgeInsets.only(left: 24.0, top: 12.0, right: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showJobPicker)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildJobPicker(),
              ),
            if (!widget.specializationOnly)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                  ),
                  if (showEditModeDetailsPlaceholder)
                    Text(
                      '*Les détails du métier seront affichés ici*',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  const SizedBox(height: 8),
                  if (!widget.showHeader)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.editMode
                              ? '* Indiquer le nombre de places de stages disponibles :'
                              : 'Nombre de places de stages disponibles :',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        ...schools.map(
                          (school) => _buildAvailability(school: school),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  if (widget.showExtended)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Détails du métier',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _buildMoreDetails(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Specialization> get _availableSpecialization {
    // Make a copy of the available specializations
    List<Specialization> out = [
      ...(widget.controller._specializationsWhiteList ??
          ActivitySectorsService.allSpecializations),
    ];
    out.sort((a, b) => a.name.compareTo(b.name)); // Sort them by name
    return out;
  }

  Autocomplete<Specialization> _buildJobPicker() {
    return Autocomplete<Specialization>(
      displayStringForOption: (specialization) => specialization.idWithName,
      optionsBuilder: (textEditingValue) {
        final text = textEditingValue.text.trim();

        // Suggestions are computed here; selection state should not be mutated,
        // otherwise the parent widget rebuilds while the dropdown is opening and
        // Enter/click selection becomes inconsistent.
        if (text.isEmpty) return _availableSpecialization;

        final normalizedText = text.toLowerCase();
        return _availableSpecialization
            .where(
              (s) => s.idWithName.toLowerCase().contains(normalizedText) &&
                  s.idWithName.toLowerCase() != normalizedText,
            )
            .toList();
      },
      optionsViewBuilder: (context, onSelected, options) =>
          OptionsBuilderForAutocomplete(
        onSelected: onSelected,
        options: options,
        optionToString: (Specialization e) => e.idWithName,
      ),
      onSelected: (specialization) {
        widget.controller._specialization = specialization;
        setState(() {});
        // Don't need to unfocus here - the Focus widget will handle validation on blur
      },
      initialValue: TextEditingValue(
        text: widget.controller._specialization?.idWithName ?? '',
      ),
      fieldViewBuilder: (_, controller, focusNode, onSubmitted) {
        if (_availableSpecialization.length == 1) {
          widget.controller._specialization = _availableSpecialization[0];
          controller.text = widget.controller._specialization!.idWithName;
        }

        void commitSelectionFromText(String? rawText) {
          final matchedSpecialization = _availableSpecialization.firstWhereOrNull(
            (specialization) =>
                specialization.idWithName.trim().toLowerCase() ==
                (rawText?.trim().toLowerCase() ?? ''),
          );
          if (matchedSpecialization == null) {
            widget.controller._specialization = null;
            setState(() {});
            return;
          }

          widget.controller._specialization = matchedSpecialization;
          setState(() {});
        }

        return Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) commitSelectionFromText(controller.text);
          },
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            readOnly: false,
            enabled: widget.editMode &&
                _availableSpecialization.length != 1 &&
                widget.canChangeSpecialization,
            style: const TextStyle(color: Colors.black),
            autovalidateMode: AutovalidateMode.onUnfocus,
            onFieldSubmitted: (_) => onSubmitted(),
            validator: (value) {
              if (widget.controller._specialization == null) {
                return 'Sélectionner un métier.';
              }
              if (widget.controller._specializationBlacklist?.contains(
                    widget.controller._specialization,
                  ) ??
                  false) {
                return 'Ce métier existe déjà pour cette entreprise.';
              }

              return validateExactAutocompleteOption<Specialization>(
                value: value,
                options: _availableSpecialization,
                optionToString: (specialization) => specialization.idWithName,
                errorMessage: 'Sélectionner un métier.',
              );
            },
            decoration: InputDecoration(
              labelText: '* Métier semi-spécialisé',
              labelStyle: const TextStyle(color: Colors.black),
              hintText: 'Saisir nom ou n° de métier',
              suffixIcon: _availableSpecialization.length == 1
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        if (focusNode.hasFocus) focusNode.previousFocus();
                        widget.controller._specialization = null;
                        controller.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  int _positionOffered(String schoolId) {
    return widget.controller
            ._realPositionsOffered(keepActiveStatus: true)[schoolId] ??
        0;
  }

  int _positionOccupied(String schoolId) {
    return widget.controller.positionsOccupied[schoolId] ?? 0;
  }

  int _positionRemaining(String schoolId) =>
      _positionOffered(schoolId) - _positionOccupied(schoolId);

  Widget _buildAvailability({required School school}) {
    final positionsRemaining = _positionRemaining(school.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              width: widget.editMode ? 140 : 75,
              child: widget.editMode
                  ? FormField(
                      validator: (value) => widget.availabilityIsMandatory &&
                              _positionOffered(school.id) == 0
                          ? 'Ajouter au moins une place.'
                          : null,
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _positionOffered(school.id) == 0
                                    ? null
                                    : () => _updatePositions(
                                          school.id,
                                          _positionOffered(school.id) - 1,
                                        ),
                                icon: Icon(
                                  Icons.remove,
                                  color: _positionOffered(school.id) == 0
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$positionsRemaining / ${_positionOffered(school.id)}',
                                ),
                              ),
                              IconButton(
                                onPressed: widget.controller.enterpriseStatus ==
                                        EnterpriseStatus.active
                                    ? () => _updatePositions(
                                          school.id,
                                          _positionOffered(school.id) + 1,
                                        )
                                    : null,
                                icon: Icon(
                                  Icons.add,
                                  color: widget.controller.enterpriseStatus ==
                                          EnterpriseStatus.active
                                      ? Colors.black
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (state.hasError)
                            Text(
                              state.errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    )
                  : Text(
                      '$positionsRemaining / ${_positionOffered(school.id)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
            Text(school.name),
          ],
        ),
      ],
    );
  }

  Widget _buildReservedFor() {
    return Padding(
      padding: const EdgeInsets.only(right: 36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.editMode
                ? 'Indiquer si les stages pour ce métier sont accessibles à tous les '
                    'enseignants ou s\'ils sont réservés à un.e enseignant.e '
                : 'Stages pour ce métier sont accessibles à :',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: widget.editMode
                ? EntityPickerTile(
                    title: widget.editMode ? null : '',
                    controller: widget.controller._reservedForPickerController!,
                    editMode: widget.editMode,
                  )
                : Text(
                    widget.controller._reservedForPickerController!.selection ??
                        'Tous les enseignant\u00b7e\u00b7s',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreDetails() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IncidentsExpansionPanel(
            enterpriseId: widget.controller.enterpriseId, job: job),
        const SizedBox(height: 12),
        SupervisionExpansionPanel(job: job),
        const SizedBox(height: 12),
        PhotoExpansionPanel(
          enterpriseId: widget.controller.enterpriseId,
          job: job,
          onChangingImage: widget.onChangingImage,
        ),
        const SizedBox(height: 12),
        CommentsExpansionPanel(
            enterpriseId: widget.controller.enterpriseId, job: job)
      ],
    );
  }
}
