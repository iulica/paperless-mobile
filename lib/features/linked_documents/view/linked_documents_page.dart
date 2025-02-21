import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paperless_mobile/core/bloc/connectivity_cubit.dart';
import 'package:paperless_mobile/features/documents/view/widgets/adaptive_documents_view.dart';
import 'package:paperless_mobile/features/documents/view/widgets/selection/view_type_selection_widget.dart';
import 'package:paperless_mobile/features/linked_documents/cubit/linked_documents_cubit.dart';
import 'package:paperless_mobile/features/paged_document_view/view/document_paging_view_mixin.dart';
import 'package:paperless_mobile/generated/l10n.dart';
import 'package:paperless_mobile/routes/document_details_route.dart';

class LinkedDocumentsPage extends StatefulWidget {
  const LinkedDocumentsPage({super.key});

  @override
  State<LinkedDocumentsPage> createState() => _LinkedDocumentsPageState();
}

class _LinkedDocumentsPageState extends State<LinkedDocumentsPage>
    with DocumentPagingViewMixin {
  @override
  final pagingScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).linkedDocumentsPageTitle),
        actions: [
          BlocBuilder<LinkedDocumentsCubit, LinkedDocumentsState>(
            builder: (context, state) {
              return ViewTypeSelectionWidget(
                viewType: state.viewType,
                onChanged: context.read<LinkedDocumentsCubit>().setViewType,
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LinkedDocumentsCubit, LinkedDocumentsState>(
        builder: (context, state) {
          return BlocBuilder<ConnectivityCubit, ConnectivityState>(
            builder: (context, connectivity) {
              return CustomScrollView(
                controller: pagingScrollController,
                slivers: [
                  SliverAdaptiveDocumentsView(
                    viewType: state.viewType,
                    documents: state.documents,
                    hasInternetConnection: connectivity.isConnected,
                    isLabelClickable: false,
                    isLoading: state.isLoading,
                    hasLoaded: state.hasLoaded,
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
      ),
    );
  }
}
