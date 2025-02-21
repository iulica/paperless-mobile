import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/notifier/document_changed_notifier.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/paged_documents_state.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';

part 'inbox_cubit.g.dart';
part 'inbox_state.dart';

class InboxCubit extends HydratedCubit<InboxState>
    with DocumentPagingBlocMixin {
  final LabelRepository<Tag> _tagsRepository;
  final LabelRepository<Correspondent> _correspondentRepository;
  final LabelRepository<DocumentType> _documentTypeRepository;

  final PaperlessDocumentsApi _documentsApi;

  @override
  final DocumentChangedNotifier notifier;

  final PaperlessServerStatsApi _statsApi;

  final List<StreamSubscription> _subscriptions = [];

  @override
  PaperlessDocumentsApi get api => _documentsApi;

  InboxCubit(
    this._tagsRepository,
    this._documentsApi,
    this._correspondentRepository,
    this._documentTypeRepository,
    this._statsApi,
    this.notifier,
  ) : super(
          InboxState(
            availableCorrespondents:
                _correspondentRepository.current?.values ?? {},
            availableDocumentTypes:
                _documentTypeRepository.current?.values ?? {},
            availableTags: _tagsRepository.current?.values ?? {},
          ),
        ) {
    notifier.subscribe(
      this,
      onDeleted: remove,
      onUpdated: (document) {
        if (document.tags
            .toSet()
            .intersection(state.inboxTags.toSet())
            .isEmpty) {
          remove(document);
          emit(state.copyWith(itemsInInboxCount: state.itemsInInboxCount - 1));
        } else {
          replace(document);
        }
      },
    );
    _subscriptions.add(
      _tagsRepository.values.listen((event) {
        if (event?.hasLoaded ?? false) {
          emit(state.copyWith(availableTags: event!.values));
        }
      }),
    );
    _subscriptions.add(
      _correspondentRepository.values.listen((event) {
        if (event?.hasLoaded ?? false) {
          emit(state.copyWith(
            availableCorrespondents: event!.values,
          ));
        }
      }),
    );
    _subscriptions.add(
      _documentTypeRepository.values.listen((event) {
        if (event?.hasLoaded ?? false) {
          emit(state.copyWith(availableDocumentTypes: event!.values));
        }
      }),
    );

    refreshItemsInInboxCount(false);
    loadInbox();
  }

  void refreshItemsInInboxCount([bool shouldLoadInbox = true]) async {
    final stats = await _statsApi.getServerStatistics();

    if (stats.documentsInInbox != state.itemsInInboxCount && shouldLoadInbox) {
      loadInbox();
    }
    emit(
      state.copyWith(
        itemsInInboxCount: stats.documentsInInbox,
      ),
    );
  }

  ///
  /// Fetches inbox tag ids and loads the inbox items (documents).
  ///
  Future<void> loadInbox() async {
    final inboxTags = await _tagsRepository.findAll().then(
          (tags) => tags.where((t) => t.isInboxTag ?? false).map((t) => t.id!),
        );

    if (inboxTags.isEmpty) {
      // no inbox tags = no inbox items.
      return emit(
        state.copyWith(
          hasLoaded: true,
          value: [],
          inboxTags: [],
        ),
      );
    }
    emit(state.copyWith(inboxTags: inboxTags));
    updateFilter(
      filter: DocumentFilter(
        sortField: SortField.added,
        tags: IdsTagsQuery.fromIds(inboxTags),
      ),
    );
  }

  ///
  /// Updates the document with all inbox tags removed and removes the document
  /// from the inbox.
  ///
  Future<Iterable<int>> removeFromInbox(DocumentModel document) async {
    final tagsToRemove =
        document.tags.toSet().intersection(state.inboxTags.toSet());

    final updatedTags = {...document.tags}..removeAll(tagsToRemove);
    final updatedDocument = await api.update(
      document.copyWith(tags: updatedTags),
    );
    // Remove first so document is not replaced first.
    remove(document);
    notifier.notifyUpdated(updatedDocument);
    return tagsToRemove;
  }

  ///
  /// Adds the previously removed tags to the document and performs an update.
  ///
  Future<void> undoRemoveFromInbox(
    DocumentModel document,
    Iterable<int> removedTags,
  ) async {
    final updatedDocument = await _documentsApi.update(
      document.copyWith(
        tags: {...document.tags, ...removedTags},
      ),
    );
    notifier.notifyUpdated(updatedDocument);
    emit(state.copyWith(itemsInInboxCount: state.itemsInInboxCount + 1));
    return reload();
  }

  ///
  /// Removes inbox tags from all documents in the inbox.
  ///
  Future<void> clearInbox() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _documentsApi.bulkAction(
        BulkModifyTagsAction.removeTags(
          state.documents.map((e) => e.id),
          state.inboxTags,
        ),
      );
      emit(state.copyWith(
        hasLoaded: true,
        value: [],
        itemsInInboxCount: 0,
      ));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> assignAsn(DocumentModel document) async {
    if (document.archiveSerialNumber == null) {
      final int asn = await _documentsApi.findNextAsn();
      final updatedDocument = await _documentsApi
          .update(document.copyWith(archiveSerialNumber: asn));

      replace(updatedDocument);
    }
  }

  void acknowledgeHint() {
    emit(state.copyWith(isHintAcknowledged: true));
  }

  @override
  InboxState fromJson(Map<String, dynamic> json) {
    return InboxState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(InboxState state) {
    return state.toJson();
  }

  @override
  Future<void> close() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    return super.close();
  }
}
