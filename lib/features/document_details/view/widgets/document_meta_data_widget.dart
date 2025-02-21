import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/connectivity_cubit.dart';
import 'package:paperless_mobile/core/widgets/offline_widget.dart';
import 'package:paperless_mobile/extensions/flutter_extensions.dart';
import 'package:paperless_mobile/features/document_details/cubit/document_details_cubit.dart';
import 'package:paperless_mobile/features/document_details/view/widgets/details_item.dart';
import 'package:paperless_mobile/generated/l10n.dart';
import 'package:paperless_mobile/helpers/format_helpers.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';

class DocumentMetaDataWidget extends StatelessWidget {
  final Future<DocumentMetaData> metaData;
  final DocumentModel document;
  final double itemSpacing;
  const DocumentMetaDataWidget({
    super.key,
    required this.metaData,
    required this.document,
    required this.itemSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        if (!state.isConnected) {
          return const Center(
            child: OfflineWidget(),
          );
        }
        return FutureBuilder<DocumentMetaData>(
          future: metaData,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final meta = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              children: [
                DetailsItem(
                  label: S
                      .of(context)
                      .documentArchiveSerialNumberPropertyLongLabel,
                  content: document.archiveSerialNumber != null
                      ? Text(document.archiveSerialNumber.toString())
                      : TextButton.icon(
                          icon: const Icon(Icons.archive_outlined),
                          label: Text(S
                              .of(context)
                              .documentDetailsPageAssignAsnButtonLabel),
                          onPressed: () => _assignAsn(context),
                        ),
                ).paddedOnly(bottom: itemSpacing),
                DetailsItem.text(DateFormat().format(document.modified),
                        label: S.of(context).documentModifiedPropertyLabel,
                        context: context)
                    .paddedOnly(bottom: itemSpacing),
                DetailsItem.text(DateFormat().format(document.added),
                        label: S.of(context).documentAddedPropertyLabel,
                        context: context)
                    .paddedOnly(bottom: itemSpacing),
                DetailsItem.text(
                  meta.mediaFilename,
                  context: context,
                  label:
                      S.of(context).documentMetaDataMediaFilenamePropertyLabel,
                ).paddedOnly(bottom: itemSpacing),
                DetailsItem.text(
                  meta.originalChecksum,
                  context: context,
                  label: S.of(context).documentMetaDataChecksumLabel,
                ).paddedOnly(bottom: itemSpacing),
                DetailsItem.text(formatBytes(meta.originalSize, 2),
                        label:
                            S.of(context).documentMetaDataOriginalFileSizeLabel,
                        context: context)
                    .paddedOnly(bottom: itemSpacing),
                DetailsItem.text(
                  meta.originalMimeType,
                  label: S.of(context).documentMetaDataOriginalMimeTypeLabel,
                  context: context,
                ).paddedOnly(bottom: itemSpacing),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignAsn(BuildContext context) async {
    try {
      await context.read<DocumentDetailsCubit>().assignAsn(document);
    } on PaperlessServerException catch (error, stackTrace) {
      showErrorMessage(context, error, stackTrace);
    }
  }
}
