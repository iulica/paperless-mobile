import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:paperless_api/paperless_api.dart';
import 'package:paperless_mobile/core/bloc/connectivity_cubit.dart';
import 'package:paperless_mobile/core/bloc/paperless_server_information_cubit.dart';
import 'package:paperless_mobile/core/global/constants.dart';
import 'package:paperless_mobile/core/repository/label_repository.dart';
import 'package:paperless_mobile/core/repository/saved_view_repository.dart';
import 'package:paperless_mobile/core/translation/error_code_localization_mapper.dart';
import 'package:paperless_mobile/features/document_scan/cubit/document_scanner_cubit.dart';
import 'package:paperless_mobile/features/document_scan/view/scanner_page.dart';
import 'package:paperless_mobile/features/document_upload/cubit/document_upload_cubit.dart';
import 'package:paperless_mobile/features/document_upload/view/document_upload_preparation_page.dart';
import 'package:paperless_mobile/features/documents/cubit/documents_cubit.dart';
import 'package:paperless_mobile/features/documents/view/pages/documents_page.dart';
import 'package:paperless_mobile/features/home/view/route_description.dart';
import 'package:paperless_mobile/features/inbox/cubit/inbox_cubit.dart';
import 'package:paperless_mobile/features/inbox/view/pages/inbox_page.dart';
import 'package:paperless_mobile/features/labels/cubit/label_cubit.dart';
import 'package:paperless_mobile/features/labels/view/pages/labels_page.dart';
import 'package:paperless_mobile/features/notifications/services/local_notification_service.dart';
import 'package:paperless_mobile/features/paged_document_view/cubit/document_paging_bloc_mixin.dart';
import 'package:paperless_mobile/features/saved_view/cubit/saved_view_cubit.dart';
import 'package:paperless_mobile/features/sharing/share_intent_queue.dart';
import 'package:paperless_mobile/features/tasks/cubit/task_status_cubit.dart';
import 'package:paperless_mobile/generated/l10n.dart';
import 'package:paperless_mobile/helpers/file_helpers.dart';
import 'package:paperless_mobile/helpers/message_helpers.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:responsive_builder/responsive_builder.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final DocumentScannerCubit _scannerCubit = DocumentScannerCubit();
  late final InboxCubit _inboxCubit;
  late Timer _inboxTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData(context);
    _inboxCubit = InboxCubit(
      context.read(),
      context.read(),
      context.read(),
      context.read(),
      context.read(),
      context.read(),
    );
    _listenToInboxChanges();
    context.read<ConnectivityCubit>().reload();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _listenForReceivedFiles();
    });
  }

  void _listenToInboxChanges() {
    _inboxCubit.refreshItemsInInboxCount();
    _inboxTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
      } else {
        _inboxCubit.refreshItemsInInboxCount();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_inboxTimer.isActive) {
      log('App is now in foreground, start polling for statistics.');
      _listenToInboxChanges();
    } else if (state != AppLifecycleState.resumed) {
      log('App is now in background, stop polling for statistics.');
      _inboxTimer.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxTimer.cancel();
    _inboxCubit.close();
    super.dispose();
  }

  void _listenForReceivedFiles() async {
    if (ShareIntentQueue.instance.hasUnhandledFiles) {
      await _handleReceivedFile(ShareIntentQueue.instance.pop()!);
    }
    ShareIntentQueue.instance.addListener(() async {
      final queue = ShareIntentQueue.instance;
      while (queue.hasUnhandledFiles) {
        final file = queue.pop()!;
        await _handleReceivedFile(file);
      }
    });
  }

  bool _isFileTypeSupported(SharedMediaFile file) {
    return supportedFileExtensions.contains(
      file.path.split('.').last.toLowerCase(),
    );
  }

  Future<void> _handleReceivedFile(SharedMediaFile file) async {
    SharedMediaFile mediaFile;
    if (Platform.isIOS) {
      // Workaround for file not found on iOS: https://stackoverflow.com/a/72813212
      mediaFile = SharedMediaFile(
        file.path.replaceAll('file://', ''),
        file.thumbnail,
        file.duration,
        file.type,
      );
    } else {
      mediaFile = file;
    }

    if (!_isFileTypeSupported(mediaFile)) {
      Fluttertoast.showToast(
        msg: translateError(context, ErrorCode.unsupportedFileFormat),
      );
      if (Platform.isAndroid) {
        // As stated in the docs, SystemNavigator.pop() is ignored on IOS to comply with HCI guidelines.
        await SystemNavigator.pop();
      }
      return;
    }
    final filename = extractFilenameFromPath(mediaFile.path);
    final extension = p.extension(mediaFile.path);
    try {
      if (await File(mediaFile.path).exists()) {
        final bytes = File(mediaFile.path).readAsBytesSync();
        final success = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => BlocProvider.value(
                  value: DocumentUploadCubit(
                    documentApi: context.read(),
                    tagRepository: context.read(),
                    correspondentRepository: context.read(),
                    documentTypeRepository: context.read(),
                  ),
                  child: DocumentUploadPreparationPage(
                    fileBytes: bytes,
                    filename: filename,
                    title: filename,
                    fileExtension: extension,
                  ),
                ),
              ),
            ) ??
            false;
        if (success) {
          await Fluttertoast.showToast(
            msg: S.of(context).documentUploadSuccessText,
          );
          SystemNavigator.pop();
        }
      } else {
        Fluttertoast.showToast(
          msg: S.of(context).receiveSharedFilePermissionDeniedMessage,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: S.of(context).receiveSharedFilePermissionDeniedMessage,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      RouteDescription(
        icon: const Icon(Icons.description_outlined),
        selectedIcon: Icon(
          Icons.description,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: S.of(context).bottomNavDocumentsPageLabel,
      ),
      RouteDescription(
        icon: const Icon(Icons.document_scanner_outlined),
        selectedIcon: Icon(
          Icons.document_scanner,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: S.of(context).bottomNavScannerPageLabel,
      ),
      RouteDescription(
        icon: const Icon(Icons.sell_outlined),
        selectedIcon: Icon(
          Icons.sell,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: S.of(context).bottomNavLabelsPageLabel,
      ),
      RouteDescription(
          icon: const Icon(Icons.inbox_outlined),
          selectedIcon: Icon(
            Icons.inbox,
            color: Theme.of(context).colorScheme.primary,
          ),
          label: S.of(context).bottomNavInboxPageLabel,
          badgeBuilder: (icon) => BlocBuilder<InboxCubit, InboxState>(
                bloc: _inboxCubit,
                builder: (context, state) {
                  if (state.itemsInInboxCount > 0) {
                    return Badge.count(
                      count: state.itemsInInboxCount,
                      child: icon,
                    );
                  }
                  return icon;
                },
              )),
    ];
    final routes = <Widget>[
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => DocumentsCubit(
              context.read(),
              context.read(),
            ),
          ),
          BlocProvider(
            create: (context) => SavedViewCubit(
              context.read(),
            ),
          ),
        ],
        child: const DocumentsPage(),
      ),
      BlocProvider.value(
        value: _scannerCubit,
        child: const ScannerPage(),
      ),
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => LabelCubit<Correspondent>(context.read()),
          ),
          BlocProvider(
            create: (context) => LabelCubit<DocumentType>(context.read()),
          ),
          BlocProvider(
            create: (context) => LabelCubit<Tag>(context.read()),
          ),
          BlocProvider(
            create: (context) => LabelCubit<StoragePath>(context.read()),
          ),
        ],
        child: const LabelsPage(),
      ),
      MultiBlocProvider(
        providers: [
          // We need to manually downcast the inboxcubit to the
          // mixed-in DocumentPagingBlocMixin to use the
          // DocumentPagingViewMixin in the inbox.
          BlocProvider<DocumentPagingBlocMixin>.value(
            value: _inboxCubit,
          ),
          BlocProvider<InboxCubit>.value(
            value: _inboxCubit,
          ),
        ],
        child: const InboxPage(),
      ),
      // const SettingsPage(),
    ];
    return MultiBlocListener(
      listeners: [
        BlocListener<ConnectivityCubit, ConnectivityState>(
          //Only re-initialize data if the connectivity changed from not connected to connected
          listenWhen: (previous, current) =>
              current == ConnectivityState.connected,
          listener: (context, state) {
            _initializeData(context);
          },
        ),
        BlocListener<TaskStatusCubit, TaskStatusState>(
          listener: (context, state) {
            if (state.task != null) {
              // Handle local notifications on task change (only when app is running for now).
              context
                  .read<LocalNotificationService>()
                  .notifyTaskChanged(state.task!);
            }
          },
        ),
      ],
      child: ResponsiveBuilder(
        builder: (context, sizingInformation) {
          if (!sizingInformation.isMobile) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations
                        .map((e) => e.toNavigationRailDestination())
                        .toList(),
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onNavigationChanged,
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: routes[_currentIndex],
                  ),
                ],
              ),
            );
          }
          return Scaffold(
            bottomNavigationBar: NavigationBar(
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 4.0,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavigationChanged,
              destinations:
                  destinations.map((e) => e.toNavigationDestination()).toList(),
            ),
            body: routes[_currentIndex],
          );
        },
      ),
    );
  }

  void _onNavigationChanged(index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _initializeData(BuildContext context) {
    try {
      context.read<LabelRepository<Tag>>().findAll();
      context.read<LabelRepository<Correspondent>>().findAll();
      context.read<LabelRepository<DocumentType>>().findAll();
      context.read<LabelRepository<StoragePath>>().findAll();
      context.read<SavedViewRepository>().findAll();
      context.read<PaperlessServerInformationCubit>().updateInformtion();
    } on PaperlessServerException catch (error, stackTrace) {
      showErrorMessage(context, error, stackTrace);
    }
  }
}
