import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/translation/sort_field_localization_mapper.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/documents/view/widgets/search/sort_field_selection_bottom_sheet.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';

class SortDocumentsButton extends StatelessWidget {
  const SortDocumentsButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentsCubit, DocumentsState>(
      builder: (context, state) {
        if (state.filter.sortField == null) {
          return const SizedBox.shrink();
        }
        return TextButton.icon(
          icon: Icon(state.filter.sortOrder == SortOrder.ascending
              ? Icons.arrow_upward
              : Icons.arrow_downward),
          label: Text(translateSortField(context, state.filter.sortField)),
          onPressed: () {
            showModalBottomSheet(
              elevation: 2,
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              builder: (_) => BlocProvider<DocumentsCubit>.value(
                value: context.read<DocumentsCubit>(),
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => LabelCubit<DocumentType>(
                        context.read<LabelRepository<DocumentType>>(),
                      ),
                    ),
                    BlocProvider(
                      create: (context) => LabelCubit<Correspondent>(
                        context.read<LabelRepository<Correspondent>>(),
                      ),
                    ),
                  ],
                  child: SortFieldSelectionBottomSheet(
                    initialSortField: state.filter.sortField,
                    initialSortOrder: state.filter.sortOrder,
                    onSubmit: (field, order) =>
                        context.read<DocumentsCubit>().updateCurrentFilter(
                              (filter) => filter.copyWith(
                                sortField: field,
                                sortOrder: order,
                              ),
                            ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
