import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/connectivity_cubit.dart';
import 'package:paperless_mobile/features/documents/view/widgets/adaptive_documents_view.dart';
import 'package:paperless_mobile/features/documents/view/widgets/documents_empty_state.dart';
import 'package:paperless_mobile/features/paged_document_view/view/document_paging_view_mixin.dart';
import 'package:paperless_mobile/features/similar_documents/cubit/similar_documents_cubit.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:paperless_mobile/routes/document_details_route.dart';

class SimilarDocumentsView extends StatefulWidget {
  const SimilarDocumentsView({super.key});

  @override
  State<SimilarDocumentsView> createState() => _SimilarDocumentsViewState();
}

class _SimilarDocumentsViewState extends State<SimilarDocumentsView>
    with DocumentPagingViewMixin {
  @override
  final pagingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    try {
      context.read<SimilarDocumentsCubit>().initialize();
    } on PaperlessServerException catch (error, stackTrace) {
      showErrorMessage(context, error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SimilarDocumentsCubit, SimilarDocumentsState>(
      builder: (context, state) {
        if (state.hasLoaded && !state.isLoading && state.documents.isEmpty) {
          return DocumentsEmptyState(
            state: state,
            onReset: () => context.read<SimilarDocumentsCubit>().updateFilter(
                  filter: DocumentFilter.initial.copyWith(
                    moreLike: () =>
                        context.read<SimilarDocumentsCubit>().documentId,
                  ),
                ),
          );
        }

        return BlocBuilder<ConnectivityCubit, ConnectivityState>(
          builder: (context, connectivity) {
            return CustomScrollView(
              controller: pagingScrollController,
              slivers: [
                SliverAdaptiveDocumentsView(
                  documents: state.documents,
                  hasInternetConnection: connectivity.isConnected,
                  isLabelClickable: false,
                  isLoading: state.isLoading,
                  hasLoaded: state.hasLoaded,
                  enableHeroAnimation: false,
                  onTap: (document) {
                    Navigator.pushNamed(
                      context,
                      DocumentDetailsRoute.routeName,
                      arguments: DocumentDetailsRouteArguments(
                        document: document,
                        isLabelClickable: false,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
