import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/widgets/form_builder_fields/extended_date_range_form_field/form_builder_extended_date_range_picker.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';
import 'package:paperless_mobile/features/labels/tags/view/widgets/tags_form_field.dart';
import 'package:paperless_mobile/features/labels/view/widgets/label_form_field.dart';
import 'package:paperless_mobile/generated/l10n.dart';

import 'text_query_form_field.dart';

class DocumentFilterForm extends StatefulWidget {
  static const fkCorrespondent = DocumentModel.correspondentKey;
  static const fkDocumentType = DocumentModel.documentTypeKey;
  static const fkStoragePath = DocumentModel.storagePathKey;
  static const fkQuery = "query";
  static const fkCreatedAt = DocumentModel.createdKey;
  static const fkAddedAt = DocumentModel.addedKey;

  static DocumentFilter assembleFilter(
      GlobalKey<FormBuilderState> formKey, DocumentFilter initialFilter) {
    formKey.currentState?.save();
    final v = formKey.currentState!.value;
    return DocumentFilter(
      correspondent:
          v[DocumentFilterForm.fkCorrespondent] as IdQueryParameter? ??
              DocumentFilter.initial.correspondent,
      documentType: v[DocumentFilterForm.fkDocumentType] as IdQueryParameter? ??
          DocumentFilter.initial.documentType,
      storagePath: v[DocumentFilterForm.fkStoragePath] as IdQueryParameter? ??
          DocumentFilter.initial.storagePath,
      tags:
          v[DocumentModel.tagsKey] as TagsQuery? ?? DocumentFilter.initial.tags,
      query: v[DocumentFilterForm.fkQuery] as TextQuery? ??
          DocumentFilter.initial.query,
      created: (v[DocumentFilterForm.fkCreatedAt] as DateRangeQuery),
      added: (v[DocumentFilterForm.fkAddedAt] as DateRangeQuery),
      asnQuery: initialFilter.asnQuery,
      page: 1,
      pageSize: initialFilter.pageSize,
      sortField: initialFilter.sortField,
      sortOrder: initialFilter.sortOrder,
    );
  }

  final Widget? header;
  final GlobalKey<FormBuilderState> formKey;
  final DocumentFilter initialFilter;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  const DocumentFilterForm({
    super.key,
    this.header,
    required this.formKey,
    required this.initialFilter,
    this.scrollController,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  });

  @override
  State<DocumentFilterForm> createState() => _DocumentFilterFormState();
}

class _DocumentFilterFormState extends State<DocumentFilterForm> {
  late bool _allowOnlyExtendedQuery;

  @override
  void initState() {
    super.initState();
    _allowOnlyExtendedQuery = widget.initialFilter.forceExtendedQuery;
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: widget.formKey,
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          if (widget.header != null) widget.header!,
          ..._buildFormFieldList(),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 32,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormFieldList() {
    return [
      _buildQueryFormField(),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          S.of(context).documentFilterAdvancedLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      FormBuilderExtendedDateRangePicker(
        name: DocumentFilterForm.fkCreatedAt,
        initialValue: widget.initialFilter.created,
        labelText: S.of(context).documentCreatedPropertyLabel,
        onChanged: (_) {
          _checkQueryConstraints();
        },
      ),
      FormBuilderExtendedDateRangePicker(
        name: DocumentFilterForm.fkAddedAt,
        initialValue: widget.initialFilter.added,
        labelText: S.of(context).documentAddedPropertyLabel,
        onChanged: (_) {
          _checkQueryConstraints();
        },
      ),
      _buildCorrespondentFormField(),
      _buildDocumentTypeFormField(),
      _buildStoragePathFormField(),
      _buildTagsFormField(),
    ]
        .map((w) => SliverPadding(
              padding: widget.padding,
              sliver: SliverToBoxAdapter(child: w),
            ))
        .toList();
  }

  void _checkQueryConstraints() {
    final filter =
        DocumentFilterForm.assembleFilter(widget.formKey, widget.initialFilter);
    if (filter.forceExtendedQuery) {
      setState(() => _allowOnlyExtendedQuery = true);
      final queryField =
          widget.formKey.currentState?.fields[DocumentFilterForm.fkQuery];
      queryField?.didChange(
        (queryField.value as TextQuery?)
            ?.copyWith(queryType: QueryType.extended),
      );
    } else {
      setState(() => _allowOnlyExtendedQuery = false);
    }
  }

  Widget _buildDocumentTypeFormField() {
    return BlocBuilder<LabelCubit<DocumentType>, LabelState<DocumentType>>(
      builder: (context, state) {
        return LabelFormField<DocumentType>(
          formBuilderState: widget.formKey.currentState,
          name: DocumentFilterForm.fkDocumentType,
          labelOptions: state.labels,
          textFieldLabel: S.of(context).documentDocumentTypePropertyLabel,
          initialValue: widget.initialFilter.documentType,
          prefixIcon: const Icon(Icons.description_outlined),
        );
      },
    );
  }

  Widget _buildCorrespondentFormField() {
    return BlocBuilder<LabelCubit<Correspondent>, LabelState<Correspondent>>(
      builder: (context, state) {
        return LabelFormField<Correspondent>(
          formBuilderState: widget.formKey.currentState,
          name: DocumentFilterForm.fkCorrespondent,
          labelOptions: state.labels,
          textFieldLabel: S.of(context).documentCorrespondentPropertyLabel,
          initialValue: widget.initialFilter.correspondent,
          prefixIcon: const Icon(Icons.person_outline),
        );
      },
    );
  }

  Widget _buildStoragePathFormField() {
    return BlocBuilder<LabelCubit<StoragePath>, LabelState<StoragePath>>(
      builder: (context, state) {
        return LabelFormField<StoragePath>(
          formBuilderState: widget.formKey.currentState,
          name: DocumentFilterForm.fkStoragePath,
          labelOptions: state.labels,
          textFieldLabel: S.of(context).documentStoragePathPropertyLabel,
          initialValue: widget.initialFilter.storagePath,
          prefixIcon: const Icon(Icons.folder_outlined),
        );
      },
    );
  }

  Widget _buildQueryFormField() {
    return TextQueryFormField(
      name: DocumentFilterForm.fkQuery,
      onlyExtendedQueryAllowed: _allowOnlyExtendedQuery,
      initialValue: widget.initialFilter.query,
    );
  }

  BlocBuilder<LabelCubit<Tag>, LabelState<Tag>> _buildTagsFormField() {
    return BlocBuilder<LabelCubit<Tag>, LabelState<Tag>>(
      builder: (context, state) {
        return TagFormField(
          name: DocumentModel.tagsKey,
          initialValue: widget.initialFilter.tags,
          allowCreation: false,
          selectableOptions: state.labels,
        );
      },
    );
  }
}
