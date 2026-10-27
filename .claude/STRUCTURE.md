# reelpin-app structure

Every tracked file, then every function and class signature with its line
number. Signatures only: open the file at that line for the body. Find a
symbol here before opening whole files.

Generated, never hand-written: `python3 .claude/structure.py > .claude/STRUCTURE.md`.
Python signatures come from `ast` (route decorators shown as `[GET /path]`).
Dart signatures come from a brace-aware regex scan of classes, members,
top-level functions and top-level `final`/`const` values such as providers,
so an unusual declaration can be missed; grep the code when unsure.

## Files

```
.agent/
  skills/
     (22 files, not listed)
.gitattributes
.github/
  workflows/
    build-dev-apk.yml
    validate.yml
.gitignore
.metadata
.vscode/
  settings.json
README.md
analysis_options.yaml
android/
  .gitignore
  app/
    build.gradle.kts
    src/
      debug/
        AndroidManifest.xml
      main/
        AndroidManifest.xml
        kotlin/
          com/
            chetanjain/
              reelpin/
                MainActivity.kt
                ReelShareFileProvider.kt
                ShareEnqueueService.kt
                ShareIntentParser.kt
                ShareReceiverActivity.kt
        res/
          drawable/
             (1 image, font or media files)
            launch_background.xml
          drawable-v21/
            launch_background.xml
          font/
             (2 image, font or media files)
          mipmap-anydpi-v26/
            ic_launcher.xml
          mipmap-hdpi/
             (2 image, font or media files)
          mipmap-mdpi/
             (2 image, font or media files)
          mipmap-xhdpi/
             (2 image, font or media files)
          mipmap-xxhdpi/
             (2 image, font or media files)
          mipmap-xxxhdpi/
             (2 image, font or media files)
          values/
            colors.xml
            styles.xml
          values-v31/
            styles.xml
      profile/
        AndroidManifest.xml
      test/
        kotlin/
          com/
            chetanjain/
              reelpin/
                ShareIntentParserTest.kt
  build.gradle.kts
  gradle/
    wrapper/
      gradle-wrapper.properties
  gradle.properties
  settings.gradle.kts
assets/
  config/
    README.md
  fonts/
     (4 image, font or media files)
  images/
     (11 image, font or media files)
    guide/
       (8 image, font or media files)
docs/
  .nojekyll
  delete-account.html
  index.html
  screenshots/
     (7 image, font or media files)
  superpowers/
    specs/
      2026-09-17-personal-context-engine-design.md
ios/
  .gitignore
  ExportOptions.plist
  Flutter/
    AppFrameworkInfo.plist
    Debug.xcconfig
    Release.xcconfig
    ShareExtension-Debug.xcconfig
    ShareExtension-Profile.xcconfig
    ShareExtension-Release.xcconfig
  Podfile
  Podfile.lock
  Runner/
    AppDelegate.swift
    AppStoreRunner.entitlements
    Assets.xcassets/
      AppIcon.appiconset/
         (15 image, font or media files)
        Contents.json
      LaunchBackground.colorset/
        Contents.json
      LaunchImage.imageset/
         (3 image, font or media files)
        Contents.json
        README.md
    Base.lproj/
      LaunchScreen.storyboard
      Main.storyboard
    Info.plist
    PrivacyInfo.xcprivacy
    Runner-Bridging-Header.h
    Runner.entitlements
    SceneDelegate.swift
  Runner.xcodeproj/
    project.pbxproj
    project.xcworkspace/
      contents.xcworkspacedata
      xcshareddata/
        IDEWorkspaceChecks.plist
        WorkspaceSettings.xcsettings
    xcshareddata/
      xcschemes/
        Runner.xcscheme
  Runner.xcworkspace/
    contents.xcworkspacedata
    xcshareddata/
      IDEWorkspaceChecks.plist
      WorkspaceSettings.xcsettings
  RunnerTests/
    RunnerTests.swift
  Share Extension/
    AppStoreShareExtension.entitlements
    Base.lproj/
      MainInterface.storyboard
    CollectionFolderCell.swift
    Fonts/
       (2 image, font or media files)
    Info.plist
    Share Extension.entitlements
    ShareUrlExtractor.swift
    ShareViewController.swift
lib/
  app_entry.dart
  bootstrap.dart
  components/
    collections/
      add_to_collection_sheet.dart
      collection_folder_tile.dart
      collection_form_sheet.dart
      collection_tile_renderer.dart
      reel_actions_sheet.dart
      selection_tick.dart
      share_collection_sheet.dart
    common/
      app_back_button.dart
      app_bottom_sheet.dart
      app_switch.dart
      confirm_dialog.dart
    reels/
      category_badge.dart
      processing_reel_card.dart
      reel_card.dart
    sharing/
      share_card.dart
  constants/
    app_colors.dart
    app_layout.dart
    app_spacing.dart
    app_theme.dart
    source_platforms.dart
  data_models/
    account/
      library_stats.dart
      user_entitlement.dart
    app_config/
      remote_config.dart
    collections/
      collection_models.dart
    discover/
      discover_response.dart
      search_response.dart
      search_result.dart
    map/
      map_bounds.dart
      map_place_search_response.dart
      map_response.dart
    notifications/
      app_notification.dart
    reels/
      processing_job.dart
      reel.dart
      reel_filters.dart
      reel_page.dart
    sharing/
      pending_share.dart
      share_resolve_response.dart
  env.dart
  http/
    account_http.dart
    api_client.dart
    api_exception.dart
    collections_http.dart
    discover_http.dart
    map_http.dart
    mock_collections_http.dart
    reels_http.dart
    sharing_http.dart
  main.dart
  providers.dart
  reelpin_app.dart
  repositories/
    reel_repository.dart
  router.dart
  screens/
    app_shell/
      app_shell.dart
      authenticated_shell.dart
      partials/
        app_shell_controller.dart
        nav_item.dart
    auth/
      auth_screen.dart
    collections/
      collection_detail_screen.dart
      collections_screen.dart
      partials/
        collection_sticky_note.dart
    discover/
      discover_screen.dart
      partials/
        saved_date_calendar_sheet.dart
        search_result_tile.dart
    feature_announcement/
      feature_announcement_screen.dart
    home/
      home_screen.dart
      partials/
        filter_option.dart
        platform_filter_tile.dart
    how_to/
      how_to_use_screen.dart
      partials/
        how_to_stage.dart
        how_to_step.dart
    map/
      map_screen.dart
      partials/
        map_place_search_sheet.dart
    onboarding/
      onboarding_screen.dart
      partials/
        onboarding_card.dart
        onboarding_step.dart
    paywall/
      paywall_screen.dart
    profile/
      partials/
        location_preference_card.dart
        notification_preference_card.dart
        profile_action_card.dart
        share_picker_preference_card.dart
      profile_screen.dart
    reel_detail/
      reel_detail_loader_screen.dart
      reel_detail_screen.dart
    setup_required/
      setup_required_screen.dart
    splash/
      splash_screen.dart
    update_required/
      update_required_screen.dart
  services/
    analytics/
      analytics_event.dart
      analytics_service.dart
    app_update_service.dart
    auth/
      auth_service.dart
      profile_service.dart
      supabase_client.dart
    cache/
      content_cache.dart
    device_metadata_service.dart
    how_to_guide_service.dart
    location/
      location_service.dart
    notifications/
      notification_service.dart
      notification_tap_handler.dart
    remote_config/
      remote_config_service.dart
    sharing/
      collection_link.dart
      collection_link_cache.dart
      collection_share_message.dart
      linkrunner_service.dart
      pending_deep_link.dart
      push_registration_service.dart
      reel_share_service.dart
      share_flow_analytics_service.dart
      share_handoff_service.dart
      shared_collection_prefetch.dart
  utils/
    app_logger.dart
    app_store_links.dart
    auth_error_message.dart
    category_marker_icon.dart
    error_message.dart
    location_maps_uri.dart
  view_models/
    collections_view_model.dart
    discover_view_model.dart
    entitlements_view_model.dart
    home_view_model.dart
    map_view_model.dart
    processing_jobs_view_model.dart
    reel_detail_view_model.dart
    reel_filters_view_model.dart
    remote_config_view_model.dart
    search_view_model.dart
    session_view_model.dart
    theme_view_model.dart
    user_state_coordinator.dart
linux/
  .gitignore
  CMakeLists.txt
  flutter/
    CMakeLists.txt
    generated_plugin_registrant.cc
    generated_plugin_registrant.h
    generated_plugins.cmake
  runner/
    CMakeLists.txt
    main.cc
    my_application.cc
    my_application.h
macos/
  .gitignore
  Flutter/
    Flutter-Debug.xcconfig
    Flutter-Release.xcconfig
    GeneratedPluginRegistrant.swift
  Podfile
  Runner/
    AppDelegate.swift
    Assets.xcassets/
      AppIcon.appiconset/
         (7 image, font or media files)
        Contents.json
    Base.lproj/
      MainMenu.xib
    Configs/
      AppInfo.xcconfig
      Debug.xcconfig
      Release.xcconfig
      Warnings.xcconfig
    DebugProfile.entitlements
    Info.plist
    MainFlutterWindow.swift
    Release.entitlements
  Runner.xcodeproj/
    project.pbxproj
    project.xcworkspace/
      xcshareddata/
        IDEWorkspaceChecks.plist
    xcshareddata/
      xcschemes/
        Runner.xcscheme
  Runner.xcworkspace/
    contents.xcworkspacedata
    xcshareddata/
      IDEWorkspaceChecks.plist
  RunnerTests/
    RunnerTests.swift
play-assets/
   (2 image, font or media files)
  phone/
    app-store-6.5/
       (11 image, font or media files)
    generate_store_screenshots.py
    play-store/
       (11 image, font or media files)
    source/
       (10 image, font or media files)
  tablet-10inch/
     (5 image, font or media files)
  tablet-7inch/
     (5 image, font or media files)
pubspec.lock
pubspec.yaml
test/
  app_entry_test.dart
  components/
    collections/
      collection_folder_tile_test.dart
    processing_reel_card_test.dart
  constants/
    source_platforms_test.dart
  data_models/
    account/
      user_entitlement_test.dart
    app_config/
      remote_config_test.dart
    collection_models_test.dart
    map/
      map_response_test.dart
    notifications/
      app_notification_test.dart
    reels/
      processing_job_test.dart
      reel_filters_test.dart
      reel_test.dart
    sharing/
      pending_share_test.dart
  env_test.dart
  fixtures/
    api_v2/
      error_idempotency_conflict.json
      error_processing_unavailable.json
      error_unauthorized.json
      error_validation.json
      job_list.json
      library_stats.json
      map_pins.json
      reel_detail.json
      reel_page.json
      search_results.json
      share_resolved.json
      share_token_minted.json
      submission_accepted.json
      submission_in_flight.json
    api_v2.dart
  http/
    api_client_test.dart
    collections_api_client_test.dart
  repositories/
    reel_repository_cache_test.dart
    reel_repository_test.dart
  router_test.dart
  screens/
    app_shell_tab_index_test.dart
    collections/
      collection_detail_tabs_test.dart
      share_collection_sheet_test.dart
    feature_announcement/
      feature_announcement_screen_test.dart
    home/
      home_empty_state_test.dart
      home_filter_sheet_test.dart
      home_paywall_banner_test.dart
    how_to/
      how_to_use_screen_test.dart
    onboarding/
      onboarding_screen_test.dart
    profile/
      profile_screen_test.dart
    reel_detail/
      locked_history_copy_test.dart
      reel_detail_screen_test.dart
      reel_share_card_test.dart
    update_required/
      update_required_screen_test.dart
  services/
    cache/
      content_cache_test.dart
    how_to_guide_service_test.dart
    notifications/
      notification_tap_handler_test.dart
    remote_config/
      remote_config_service_test.dart
    sharing/
      collection_link_cache_test.dart
      collection_link_test.dart
      collection_share_message_test.dart
      linkrunner_service_test.dart
      push_registration_service_test.dart
      share_flow_analytics_service_test.dart
      share_handoff_collections_test.dart
      shared_collection_prefetch_test.dart
  utils/
    auth_error_message_test.dart
    category_marker_icon_test.dart
  view_models/
    collections_view_model_test.dart
    discover_view_model_test.dart
    home_view_model_test.dart
    map_view_model_test.dart
    processing_jobs_view_model_test.dart
    reel_filters_view_model_test.dart
    remote_config_view_model_test.dart
    search_view_model_test.dart
    session_view_model_test.dart
    theme_view_model_test.dart
    user_state_coordinator_test.dart
tool/
  check_architecture.dart
  check_assets.dart
  reelpin.sh
  reelpin_flutter.sh
  verify_project.dart
web/
   (1 image, font or media files)
  icons/
     (4 image, font or media files)
  index.html
  manifest.json
windows/
  .gitignore
  CMakeLists.txt
  flutter/
    CMakeLists.txt
    generated_plugin_registrant.cc
    generated_plugin_registrant.h
    generated_plugins.cmake
  runner/
    CMakeLists.txt
    Runner.rc
    flutter_window.cpp
    flutter_window.h
    main.cpp
    resource.h
    resources/
       (1 image, font or media files)
    runner.exe.manifest
    utils.cpp
    utils.h
    win32_window.cpp
    win32_window.h
```

## Signatures

### lib/app_entry.dart

- L20 `class AppEntry extends ConsumerStatefulWidget`
  - L21 `const AppEntry({super.key})`
  - L24 `ConsumerState<AppEntry> createState()`
- L27 `class _AppEntryState extends ConsumerState<AppEntry> with WidgetsBindingObserver`
  - L38 `void initState()`
  - L65 `void _startContentLoad()`
  - L84 `Future<void> _waitForLocalRemoteConfig( RemoteConfigViewModel remoteConfig, )`
  - L99 `void _startCollectionLaunch()`
  - L112 `void dispose()`
  - L118 `void didChangeAppLifecycleState(AppLifecycleState state)`
  - L125 `Future<void> _loadOnboardingState()`
  - L134 `Future<void> _completeOnboarding()`
  - L148 `Widget build(BuildContext context)`

### lib/bootstrap.dart

- L20 `Future<void> bootstrap()`
- L65 `Future<void> _initializeFirebase()`
- L94 `void _configureImageCache()`

### lib/components/collections/add_to_collection_sheet.dart

- L17 `Future<void> showAddToCollectionSheet( BuildContext context, List<String> reelIds, )`
- L30 `class AddToCollectionSheet extends ConsumerStatefulWidget`
  - L31 `const AddToCollectionSheet({super.key, required this.reelIds})`
  - L36 `ConsumerState<AddToCollectionSheet> createState()`
- L40 `class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet>`
  - L44 `void initState()`
  - L51 `void _toggle(String collectionId)`
  - L62 `void _save()`
  - L89 `Future<void> _createAndAdd()`
  - L96 `Widget build(BuildContext context)`
  - L202 `Widget _buildBody( BuildContext context, bool isLoading, List<CollectionSummary> editable, Map<String, Color> accents, )`
- L270 `class _SaveButton extends StatelessWidget`
  - L271 `const _SaveButton({required this.count, required this.onTap})`
  - L277 `Widget build(BuildContext context)`

### lib/components/collections/collection_folder_tile.dart

- L14 `class CollectionFolderTile extends StatelessWidget`
  - L15 `const CollectionFolderTile({ super.key, required this.collection, required this.accent, required this.onTap, this.compact = false, this.overlay, })`
  - L52 `static Map<String, Color> accentsFor(List<CollectionSummary> collections)`
  - L62 `static int _byCreation(CollectionSummary a, CollectionSummary b)`
  - L75 `Widget build(BuildContext context)`
- L142 `class _FolderShape extends StatelessWidget`
  - L143 `const _FolderShape({ required this.name, required this.accent, required this.note, })`
  - L154 `Widget build(BuildContext context)`
- L209 `class _PinnedNote extends StatelessWidget`
  - L210 `const _PinnedNote({required this.note})`
  - L215 `Widget build(BuildContext context)`
- L299 `class _CountLabel extends StatelessWidget`
  - L300 `const _CountLabel({required this.count})`
  - L305 `Widget build(BuildContext context)`
- L322 `class _SharedBadge extends StatelessWidget`
  - L323 `const _SharedBadge({required this.isOwner})`
  - L328 `Widget build(BuildContext context)`
- L344 `class _NoteClipper extends CustomClipper<Path>`
  - L346 `Path getClip(Size size)`
  - L361 `bool shouldReclip(covariant CustomClipper<Path> oldClipper)`

### lib/components/collections/collection_form_sheet.dart

- L14 `Future<CollectionSummary?> showCollectionFormSheet( BuildContext context, { CollectionSummary? collection, })`
- L26 `class CollectionFormSheet extends ConsumerStatefulWidget`
  - L27 `const CollectionFormSheet({super.key, this.collection})`
  - L33 `ConsumerState<CollectionFormSheet> createState()`
- L37 `class _CollectionFormSheetState extends ConsumerState<CollectionFormSheet>`
  - L43 `bool get _isEditing`
  - L46 `void initState()`
  - L57 `void dispose()`
  - L64 `Widget build(BuildContext context)`
  - L163 `Widget _buildField( BuildContext context, { required TextEditingController controller, required String label, required int maxLength, required int maxLines, bool autofocus = false, })`
  - L230 `Future<void> _save()`

### lib/components/collections/collection_tile_renderer.dart

- L20 `class CollectionTileRenderer`
  - L21 `CollectionTileRenderer._()`
  - L27 `static Future<Uint8List?> renderTile({ required CollectionSummary collection, required Color accent, Brightness brightness = Brightness.light, })`
  - L84 `static Widget _tileFrame({ required CollectionSummary collection, required Color accent, required Brightness brightness, })`
  - L119 `static Future<Map<String, String>> writeTiles({ required String directory, required List<CollectionSummary> collections, })`

### lib/components/collections/reel_actions_sheet.dart

- L10 `enum _ReelAction`
- L14 `Future<void> showReelActionsSheet( BuildContext context, Reel reel, { VoidCallback? onDelete, })`
- L104 `class _ActionButton extends StatelessWidget`
  - L105 `const _ActionButton({ required this.label, required this.color, required this.icon, required this.onTap, })`
  - L118 `Widget build(BuildContext context)`

### lib/components/collections/selection_tick.dart

- L13 `class SelectionTick extends StatelessWidget`
  - L14 `const SelectionTick({super.key})`
  - L17 `Widget build(BuildContext context)`

### lib/components/collections/share_collection_sheet.dart

- L27 `Future<void> showShareCollectionSheet( BuildContext context, String collectionId, )`
- L37 `class ShareCollectionSheet extends ConsumerStatefulWidget`
  - L38 `const ShareCollectionSheet({super.key, required this.collectionId})`
  - L43 `ConsumerState<ShareCollectionSheet> createState()`
- L47 `class _ShareCollectionSheetState extends ConsumerState<ShareCollectionSheet>`
  - L59 `void initState()`
  - L70 `void dispose()`
  - L75 `Future<void> _restoreCachedLink()`
  - L80 `Future<void> _loadMembers()`
  - L87 `CollectionSummary? get _collection`
  - L92 `Future<void> _toggleLink(bool enabled)`
  - L115 `Future<void> _regenerateLink()`
  - L129 `Future<void> _shareLink()`
  - L143 `Future<void> _presentShare( CollectionShareMessage message, { required String? role, })`
  - L177 `Future<Uint8List?> _renderShareCard(String? role)`
  - L213 `Future<Uint8List?> _captureCard(GlobalKey boundaryKey)`
  - L236 `Future<void> _copy(String value, String label)`
  - L247 `Future<void> _openCollaborators(bool isOwner)`
  - L267 `Future<void> _invite(String role)`
  - L291 `Widget build(BuildContext context)`
- L388 `class _InviteButton extends StatelessWidget`
  - L389 `const _InviteButton({ required this.icon, required this.label, required this.hint, required this.color, required this.onTap, })`
  - L404 `Widget build(BuildContext context)`
- L461 `class _SheetRow extends StatelessWidget`
  - L462 `const _SheetRow({ required this.label, required this.hint, required this.trailing, })`
  - L473 `Widget build(BuildContext context)`
- L507 `class _LinkChip extends StatelessWidget`
  - L508 `const _LinkChip({ required this.url, this.onCopy, this.onShare, this.onRegenerate, })`
  - L521 `Widget build(BuildContext context)`
- L563 `class _ChipAction extends StatelessWidget`
  - L564 `const _ChipAction({ required this.icon, required this.tooltip, required this.onTap, })`
  - L575 `Widget build(BuildContext context)`
- L592 `class _CollaboratorsRow extends StatelessWidget`
  - L593 `const _CollaboratorsRow({required this.count, required this.onTap})`
  - L599 `Widget build(BuildContext context)`
- L644 `class _CollaboratorsSheet extends StatefulWidget`
  - L645 `const _CollaboratorsSheet({ required this.scrollController, required this.members, required this.canManage, required this.onRemove, })`
  - L658 `State<_CollaboratorsSheet> createState()`
- L661 `class _CollaboratorsSheetState extends State<_CollaboratorsSheet>`
  - L665 `Future<void> _remove(CollectionMember member)`
  - L678 `Widget build(BuildContext context)`
- L705 `class _MemberRow extends StatelessWidget`
  - L706 `const _MemberRow({ required this.member, required this.canManage, required this.onRemove, this.isRemoving = false, })`
  - L719 `Widget build(BuildContext context)`

### lib/components/common/app_back_button.dart

- L17 `class AppBackButton extends StatelessWidget`
  - L18 `const AppBackButton({super.key, this.onTap})`
  - L24 `Widget build(BuildContext context)`

### lib/components/common/app_bottom_sheet.dart

- L16 `class AppBottomSheet extends StatelessWidget`
  - L17 `const AppBottomSheet({ super.key, required this.title, required this.child, this.subtitle, this.trailing, this.maxHeightFactor = 0.72, this.fillHeight = false, })`
  - L44 `Widget build(BuildContext context)`
- L117 `Future<T?> showAppBottomSheet<T>({ required BuildContext context, required WidgetBuilder builder, })`
- L134 `Future<T?> showExpandableAppBottomSheet<T>({ required BuildContext context, required Widget Function(ScrollController controller) builder, double initialSize = 0.55, double minSize = 0.3, double maxSize = 0.94, })`

### lib/components/common/app_switch.dart

- L10 `class AppSwitch extends StatelessWidget`
  - L11 `const AppSwitch({super.key, required this.value, required this.onChanged})`
  - L23 `Widget build(BuildContext context)`

### lib/components/common/confirm_dialog.dart

- L15 `Future<bool?> showConfirmDialog( BuildContext context, { required String title, required String message, String confirmLabel = 'DELETE', String cancelLabel = 'CANCEL', bool isDestructive = true, })`

### lib/components/reels/category_badge.dart

- L8 `class CategoryBadge extends StatelessWidget`
  - L16 `const CategoryBadge({ super.key, required this.category, this.isSelected = false, this.onTap, this.small = false, this.customHeight = 40, this.customFontSize = 12, })`
  - L27 `Widget build(BuildContext context)`
  - L86 `Color _contrastText(Color bg)`

### lib/components/reels/processing_reel_card.dart

- L17 `class ProcessingReelCard extends StatefulWidget`
  - L18 `const ProcessingReelCard({ super.key, required this.job, this.isSettling = false, })`
  - L31 `State<ProcessingReelCard> createState()`
- L34 `class _ProcessingReelCardState extends State<ProcessingReelCard> with TickerProviderStateMixin`
  - L51 `void initState()`
  - L66 `void didUpdateWidget(covariant ProcessingReelCard oldWidget)`
  - L78 `double get _targetLevel`
  - L86 `void dispose()`
  - L93 `Widget build(BuildContext context)`
  - L155 `Widget _buildLabel(BuildContext context, AppLayout layout)`
- L194 `class _WaterPainter extends CustomPainter`
  - L195 `const _WaterPainter({ required this.level, required this.phase, required this.color, })`
  - L206 `void paint(Canvas canvas, Size size)`
  - L230 `bool shouldRepaint(covariant _WaterPainter old)`

### lib/components/reels/reel_card.dart

- L15 `class ReelCard extends StatefulWidget`
  - L28 `const ReelCard({ super.key, required this.reel, required this.onTap, this.onDelete, this.onLongPress, this.selected, })`
  - L38 `State<ReelCard> createState()`
- L41 `class _ReelCardState extends State<ReelCard> with SingleTickerProviderStateMixin`
  - L48 `void initState()`
  - L61 `void dispose()`
  - L67 `Widget build(BuildContext context)`
  - L147 `Widget _buildThumbnailCard(BuildContext context, Reel reel, Color catColor)`
  - L229 `Widget _buildTextCard(BuildContext context, Reel reel, Color catColor)`
  - L293 `Widget _buildBottomInfoRow( BuildContext context, Reel reel, { required Color textColor, required Color secondaryColor, required Color borderColor, List<Shadow>? shadows, })`
  - L333 `Widget _buildUnparsedBadge(BuildContext context)`
  - L358 `Widget? _sourcePlatformBadge(BuildContext context, Reel reel)`
  - L378 `String _untitledLabel(Reel reel)`
  - L380 `String _savedItemLabel(Reel reel)`
  - L389 `String _tikTokUrl(Reel reel)`
  - L400 `Widget _buildCategoryTag(BuildContext context, String label, Color catColor)`
  - L446 `void _showDeleteSheet(BuildContext context)`
  - L525 `Future<void> _confirmDelete(BuildContext context)`
- L547 `class _ReelThumbnail extends StatelessWidget`
  - L548 `const _ReelThumbnail({required this.url, required this.fallbackColor})`
  - L559 `Widget build(BuildContext context)`
- L587 `class _UnselectedTick extends StatelessWidget`
  - L588 `const _UnselectedTick()`
  - L591 `Widget build(BuildContext context)`

### lib/components/sharing/share_card.dart

- L9 `class ReelShareCard extends StatelessWidget`
  - L12 `const ReelShareCard({super.key, required this.reel})`
  - L15 `Widget build(BuildContext context)`
  - L184 `static String _typeLabel(Reel reel)`
  - L212 `static String _shareSummary(String value)`
- L231 `class CollectionShareCard extends StatelessWidget`
  - L232 `const CollectionShareCard({ super.key, required this.name, required this.note, required this.itemCount, required this.role, this.ownerName, this.memberCount = 0, })`
  - L257 `Widget build(BuildContext context)`
- L444 `class _CollectionStats extends StatelessWidget`
  - L445 `const _CollectionStats({required this.itemCount, required this.memberCount})`
  - L451 `Widget build(BuildContext context)`
- L478 `class _StatBlock extends StatelessWidget`
  - L479 `const _StatBlock({required this.value, required this.label})`
  - L485 `Widget build(BuildContext context)`
- L521 `class _ShareBadge extends StatelessWidget`
  - L526 `const _ShareBadge({ required this.label, required this.color, required this.textColor, })`
  - L533 `Widget build(BuildContext context)`
- L555 `class _ShareHeader extends StatelessWidget`
  - L559 `const _ShareHeader({required this.kicker, required this.badge})`
  - L562 `Widget build(BuildContext context)`
- L620 `class _PinnedNote extends StatelessWidget`
  - L628 `const _PinnedNote({ required this.child, required this.color, required this.pinAlignment, required this.angle, required this.childPadding, this.height, })`
  - L638 `Widget build(BuildContext context)`
- L687 `class _ShareSummaryNote extends StatelessWidget`
  - L691 `const _ShareSummaryNote({required this.summary, required this.maxLines})`
  - L694 `Widget build(BuildContext context)`
- L726 `class _NoteTitle extends StatelessWidget`
  - L731 `const _NoteTitle({ required this.label, required this.color, this.fontSize = 12, })`
  - L738 `Widget build(BuildContext context)`
- L757 `class _ShareActionNote extends StatelessWidget`
  - L761 `const _ShareActionNote({required this.actions, this.isPrimary = false})`
  - L764 `Widget build(BuildContext context)`
- L777 `class _ShareMiniNote extends StatelessWidget`
  - L786 `const _ShareMiniNote({ required this.label, required this.items, required this.color, required this.textColor, required this.angle, required this.height, required this.fontSize, })`
  - L797 `Widget build(BuildContext context)`
  - L896 `double _heightForItems(int itemCount)`
- L905 `class _ShareFooter extends StatelessWidget`
  - L907 `Widget build(BuildContext context)`
- L946 `class _ShareStickyNoteClipper extends CustomClipper<Path>`
  - L948 `Path getClip(Size size)`
  - L963 `bool shouldReclip(covariant CustomClipper<Path> oldClipper)`

### lib/constants/app_colors.dart

- L5 `class AppColors`
  - L6 `AppColors._()`
  - L60 `static Color bg(BuildContext context)`
  - L66 `static Color fg(BuildContext context)`
  - L70 `static Color textSec(BuildContext context)`
  - L76 `static Color surfaceElevatedColor(BuildContext context)`
  - L96 `static Color getCategoryColor(String category)`
  - L102 `static int _stablePaletteIndex(String value)`

### lib/constants/app_layout.dart

- L6 `class AppLayout`
  - L7 `AppLayout._(this.size, this.padding)`
  - L12 `static AppLayout of(BuildContext context)`
  - L17 `double get width`
  - L18 `double get height`
  - L19 `double get shortestSide`
  - L21 `bool get isCompactWidth`
  - L22 `bool get isCompactHeight`
  - L23 `bool get isCompact`
  - L24 `bool get isTablet`
  - L26 `double scale( double value, { double minFactor = 0.82, double maxFactor = 1.18, bool useHeight = false, })`
  - L37 `double inset(double value)`
  - L39 `double gap(double value)`
  - L42 `double font( double value, { double minFactor = 0.88, double maxFactor = 1.14, })`
  - L48 `EdgeInsets pagePadding({ double horizontal = AppSpacing.xl, double top = AppSpacing.xl, double bottom = AppSpacing.xxl, })`
  - L61 `int gridColumns({ int compact = 2, int regular = 2, int wide = 3, int tablet = 4, })`
  - L72 `double gridAspect({ double compact = 0.76, double regular = 0.80, double wide = 0.88, double tablet = 0.94, })`
  - L83 `double clampWidth( double fraction, { required double min, required double max, })`

### lib/constants/app_spacing.dart

- L3 `class AppSpacing`
  - L4 `AppSpacing._()`
- L16 `class AppInsets`
  - L17 `AppInsets._()`

### lib/constants/app_theme.dart

- L6 `class AppTheme`
  - L7 `AppTheme._()`
  - L16 `static List<BoxShadow> brutalShadow(BuildContext context)`
  - L25 `static List<BoxShadow> brutalShadowSmall(BuildContext context)`
  - L53 `static BoxDecoration brutalBox( BuildContext context, { Color? color, double borderRadius = 0, bool shadow = true, double borderW = borderWidth, })`
  - L69 `static BoxDecoration brutalCard( BuildContext context, { Color? color, double borderRadius = 0, })`
  - L83 `static BoxDecoration glassDecoration( BuildContext context, { double opacity = 0.7, double borderRadius = 0, })`
  - L91 `static BoxDecoration cardDecoration( BuildContext context, { double borderRadius = 0, })`
  - L102 `static ThemeData get brutalTheme`
  - L103 `static ThemeData get darkTheme`
  - L105 `static ThemeData _buildTheme({required bool isDark})`

### lib/constants/source_platforms.dart

- L7 `class SourcePlatform`
  - L8 `const SourcePlatform._({ required this.id, required this.name, required this.assetPath, required this.savedItemNoun, required this.openSourceNoun, })`
  - L34 `String get label`
  - L103 `String itemNoun({String? contentType, String? sourceUrl})`
  - L129 `static SourcePlatform? fromTikTokUrl(String? value)`
  - L147 `static SourcePlatform? byId(String? id)`

### lib/data_models/account/library_stats.dart

- L1 `class LibraryStats`
  - L2 `const LibraryStats({ required this.totalReels, required this.totalPinnedLocations, required this.totalTags, required this.totalCategories, required this.totalSubcategories, })`
  - L17 `Map<String, dynamic> toJson()`
  - L25 `factory LibraryStats.fromJson(Map<String, dynamic> json)`

### lib/data_models/account/user_entitlement.dart

- L1 `enum SearchMode`
  - L5 `static SearchMode fromValue(String? value)`
- L16 `class EntitlementLimits`
  - L17 `const EntitlementLimits({ this.savedReels, this.pinnedLocations, this.searchesPerMonth, this.processingJobsPerHour, })`
  - L29 `factory EntitlementLimits.fromJson(Map<String, dynamic> json)`
- L41 `class EntitlementUsage`
  - L42 `const EntitlementUsage({ this.savedReels = 0, this.pinnedLocations = 0, this.tags = 0, this.categories = 0, this.subcategories = 0, })`
  - L56 `factory EntitlementUsage.fromJson(Map<String, dynamic> json)`
- L67 `class UserEntitlement`
  - L68 `const UserEntitlement({ required this.userId, required this.plan, required this.subscriptionStatus, required this.isPremium, required this.restricted, this.billingInterval, this.errorMessage, })`
  - L88 `factory UserEntitlement.fromJson( Map<String, dynamic> json, { required String userId, })`
  - L103 `bool get isPro`
  - L104 `bool get isFree`
- L107 `class PlanCard`
  - L108 `const PlanCard({ required this.plan, required this.name, required this.price, required this.features, required this.limits, this.billingInterval, this.ctaLabel, })`
  - L126 `factory PlanCard.fromJson(Map<String, dynamic> json)`
- L142 `class EntitlementsResponse`
  - L143 `const EntitlementsResponse({ required this.currentEntitlement, required this.usage, required this.limits, required this.features, required this.pricing, required this.planCards, required this.paywallMessages, })`
  - L164 `factory EntitlementsResponse.fromJson(Map<String, dynamic> json)`
  - L190 `String contentAccessSignature()`
  - L210 `String? messageFor(String entryPoint)`
- L216 `Map<String, dynamic> _map(Object? value)`

### lib/data_models/app_config/remote_config.dart

- L6 `class RemoteConfig`
  - L7 `const RemoteConfig({ this.updateRequired = const UpdateRequirement(), this.featureAnnouncement = const FeatureAnnouncement(), this.paywallVisible = false, })`
  - L17 `factory RemoteConfig.fromJson(Map<String, dynamic> json)`
- L30 `class UpdateRequirement`
  - L31 `const UpdateRequirement({ this.enabled = false, this.minBuildIos, this.minBuildAndroid, this.hard = false, this.title = '', this.body = '', this.storeUrlIos = '', this.storeUrlAndroid = '', })`
  - L51 `factory UpdateRequirement.fromJson(Map<String, dynamic> json)`
  - L67 `bool appliesTo(TargetPlatform platform, int build)`
  - L77 `String storeUrlFor(TargetPlatform platform)`
- L82 `class FeatureAnnouncement`
  - L83 `const FeatureAnnouncement({ this.enabled = false, this.id = '', this.title = '', this.body = '', this.showOnce = false, })`
  - L97 `factory FeatureAnnouncement.fromJson(Map<String, dynamic> json)`
  - L109 `bool get isShowable`
- L112 `Map<String, dynamic> _objectOf(Object? value)`
- L116 `String _stringOf(Object? value)`
- L118 `int? _intOf(Object? value)`

### lib/data_models/collections/collection_models.dart

- L3 `class CollectionSummary`
  - L4 `const CollectionSummary({ required this.id, required this.name, this.webUrl = '', this.description = '', this.coverReelId, this.visibility = 'private', this.role = 'owner', this.itemCount = 0, this.memberCount = 0, this.createdAt, this.updatedAt, })`
  - L30 `bool get hasLink`
  - L31 `bool get canEdit`
  - L32 `bool get isOwner`
  - L34 `factory CollectionSummary.fromJson(Map<String, dynamic> json)`
  - L51 `Map<String, dynamic> toJson()`
  - L65 `CollectionSummary copyWith({ String? name, String? description, String? coverReelId, String? visibility, String? role, int? itemCount, int? memberCount, })`
- L90 `class CollectionPagination`
  - L91 `const CollectionPagination({this.nextCursor, this.limit = 25})`
  - L96 `bool get hasMore`
  - L99 `Map<String, dynamic> toJson()`
  - L105 `factory CollectionPagination.fromJson(Map<String, dynamic> json)`
- L113 `class CollectionDetail`
  - L114 `const CollectionDetail({ required this.collection, required this.reels, required this.pagination, this.canEdit = false, })`
  - L131 `Map<String, dynamic> toJson()`
  - L138 `factory CollectionDetail.fromJson(Map<String, dynamic> json)`
  - L158 `CollectionDetail append(CollectionDetail next)`
  - L167 `CollectionDetail copyWith({ CollectionSummary? collection, List<Reel>? reels, CollectionPagination? pagination, })`
  - L180 `static Reel _reelFromItem(Map<String, dynamic> json)`
  - L205 `static Map<String, dynamic> _itemFromReel(Reel reel)`
- L217 `class CollectionMember`
  - L218 `const CollectionMember({ required this.userId, required this.role, this.createdAt, })`
  - L230 `String get label`
  - L235 `factory CollectionMember.fromJson(Map<String, dynamic> json)`
- L244 `class CollectionMembers`
  - L245 `const CollectionMembers({required this.ownerId, this.members = const []})`
  - L250 `factory CollectionMembers.fromJson(Map<String, dynamic> json)`
- L267 `class CollectionLink`
  - L268 `const CollectionLink({required this.url, required this.token})`
  - L273 `factory CollectionLink.fromJson(Map<String, dynamic> json)`
- L281 `class CollectionInvite`
  - L282 `const CollectionInvite({ required this.url, required this.token, required this.role, this.expiresAt, })`
  - L294 `factory CollectionInvite.fromJson(Map<String, dynamic> json)`

### lib/data_models/discover/discover_response.dart

- L3 `class DiscoverResponse`
  - L4 `const DiscoverResponse({ required this.recentSaves, required this.recentSavesCount, required this.savedDates, required this.reelsForSelectedDate, required this.categoryGrid, required this.quickSearchPrompts, required this.pagination, this.selectedDate, })`
  - L24 `factory DiscoverResponse.fromJson(Map<String, dynamic> json)`
  - L51 `static List<Reel> _reels(dynamic raw)`
- L58 `class SavedDateOption`
  - L59 `const SavedDateOption({required this.value, required this.label})`
- L65 `class DiscoverCategory`
  - L66 `const DiscoverCategory({ required this.category, required this.label, required this.count, })`
  - L76 `factory DiscoverCategory.fromJson(Map<String, dynamic> json)`
- L86 `class DiscoverPagination`
  - L87 `const DiscoverPagination({this.nextCursor, this.limit = 0})`
  - L92 `bool get hasMore`
  - L94 `factory DiscoverPagination.fromJson(Map<String, dynamic> json)`

### lib/data_models/discover/search_response.dart

- L4 `class SearchResponse`
  - L5 `const SearchResponse({ required this.query, required this.results, required this.total, required this.searchMode, })`
  - L17 `factory SearchResponse.fromJson(Map<String, dynamic> json)`

### lib/data_models/discover/search_result.dart

- L3 `class SearchResult`
  - L9 `const SearchResult({ required this.reel, required this.relevanceScore, this.relevancePercent = '', this.displayScoreLabel = '', })`
  - L16 `factory SearchResult.fromJson(Map<String, dynamic> json)`

### lib/data_models/map/map_bounds.dart

- L3 `class MapBounds`
  - L4 `const MapBounds({ required this.south, required this.west, required this.north, required this.east, })`
  - L20 `bool get hasArea`
  - L22 `Map<String, String> toQueryParameters()`
  - L30 `bool operator ==(Object other)`
  - L38 `int get hashCode`

### lib/data_models/map/map_place_search_response.dart

- L3 `class MapPlaceSearchResponse`
  - L4 `const MapPlaceSearchResponse({ required this.query, required this.searchMode, required this.total, required this.results, })`
  - L16 `factory MapPlaceSearchResponse.fromJson(Map<String, dynamic> json)`
- L33 `class MapPlaceSearchResult`
  - L34 `const MapPlaceSearchResult({ required this.resultType, this.sourceType, this.mapItem, this.googlePlaceId, required this.displayTitle, required this.displayAddress, required this.placeName, this.latitude, this.longitude, this.googleMapsUrl, required this.placeTypes, required this.canPin, })`
  - L62 `bool get isExisting`
  - L63 `bool get isGooglePlace`
  - L65 `factory MapPlaceSearchResult.fromJson(Map<String, dynamic> json)`

### lib/data_models/map/map_response.dart

- L3 `class MapResponse`
  - L4 `const MapResponse({required this.mapItems, this.truncated = false})`
  - L15 `factory MapResponse.fromJson(Map<String, dynamic> json)`
- L27 `class MapItem`
  - L28 `const MapItem({ required this.reelId, required this.title, required this.summary, required this.category, required this.subCategory, required this.categoryLabel, required this.locations, required this.markerId, required this.latitude, required this.longitude, required this.locationName, required this.locationDisplayLabel, this.mapItemId, this.sourceType = 'content', this.displayTitle = '', this.shortDetail = '', this.subCategoryLabel = '', this.locationAddress, this.googleMapsUrl, this.googlePlaceId, this.placeTypes = const [], this.canHide = true, this.canRemove = true, })`
  - L78 `bool get isManual`
  - L79 `bool get canOpenDetails`
  - L80 `String get effectiveMapItemId`
  - L81 `String get displayName`
  - L83 `String get displayDetail`
  - L86 `factory MapItem.fromJson(Map<String, dynamic> json)`
  - L144 `Reel toReel()`

### lib/data_models/notifications/app_notification.dart

- L5 `enum AppNotificationTarget`
- L16 `enum AppNotificationOpenSource`
- L23 `class AppNotification`
  - L24 `const AppNotification({ required this.title, required this.body, required this.target, required this.isMalformed, required this.data, this.notificationId, this.reelId, this.jobId, this.announcementId, this.campaignId, this.collectionId, })`
  - L50 `bool get isReelReady`
  - L52 `factory AppNotification.fromRemoteMessage(RemoteMessage message)`
  - L60 `factory AppNotification.fromData({ required Map<String, dynamic> data, String? title, String? body, })`
  - L154 `String toLocalPayload()`
  - L158 `static AppNotification fromLocalPayload(String? payload)`
  - L181 `static String? _nonEmpty(String? value)`
- L187 `class OpenedAppNotification`
  - L188 `const OpenedAppNotification({ required this.notification, required this.source, })`

### lib/data_models/reels/processing_job.dart

- L3 `class ProcessingJob`
  - L40 `const ProcessingJob({ required this.id, required this.status, this.normalizedUrl, this.sourcePlatform, this.sourceContentType, this.sourceContentId, this.currentStep, this.progressPercent, this.failureCode, this.errorMessage, required this.terminal, this.retryScheduled = false, this.statusLabel, this.statusMessage, this.stage, this.estimatedSecondsRemaining, this.summary, this.nextRetryAt, this.createdAt, this.recommendedPollAfterSeconds, this.retryable = false, this.resultReelId, this.collectionIds = const [], this.reel, this.alreadySaved = false, })`
  - L68 `factory ProcessingJob.fromJson(Map<String, dynamic> json)`
  - L128 `bool get isCompleted`
  - L129 `bool get isTerminalFailure`
  - L130 `bool get isRetryScheduled`
  - L132 `static int? _parseInt(dynamic value)`
  - L137 `static String? _normalizedNullableString(dynamic value)`

### lib/data_models/reels/reel.dart

- L3 `class Location`
  - L11 `const Location({ required this.name, this.address, this.latitude, this.longitude, this.displayLabel, this.googleMapsUrl, })`
  - L20 `factory Location.fromJson(Map<String, dynamic> json)`
  - L49 `Map<String, dynamic> toJson()`
- L59 `class Reel`
  - L93 `const Reel({ required this.id, required this.userId, required this.url, required this.title, required this.summary, required this.caption, required this.transcript, required this.category, required this.subCategory, required this.keyFacts, required this.locations, required this.peopleMentioned, required this.actionableItems, this.webUrl = '', this.sourceUrl = '', this.originalUrl = '', this.normalizedUrl = '', this.thumbnailUrl = '', this.categoryLabel = '', this.subCategoryLabel = '', this.contentType = 'post', this.parseStatus = 'parsed', this.sourcePlatform, this.sourceContentType, this.mappableLocations = const [], this.createdAt, this.displayDate = '', this.relativeDate = '', this.savedDateKey = '', this.hasMapLocations = false, this.primaryLocationLabel = '', this.mapLocationCount = 0, })`
  - L128 `factory Reel.fromJson(Map<String, dynamic> json)`
  - L178 `Map<String, dynamic> toJson()`
  - L218 `Reel withDisplayFieldsFrom(Reel listed)`
  - L264 `static List<Location> _parseLocations(dynamic raw)`
  - L281 `bool get isUnparsed`
  - L283 `static String _normalizedContentType(dynamic raw)`
  - L292 `static String _normalizedParseStatus(dynamic raw)`
  - L297 `static String? _normalizedNullableString(dynamic raw)`
  - L302 `static List<String> _stringList(dynamic raw)`

### lib/data_models/reels/reel_filters.dart

- L15 `class ReelSubcategoryFilter`
  - L20 `const ReelSubcategoryFilter({ required this.name, required this.label, required this.count, })`
  - L26 `factory ReelSubcategoryFilter.fromJson(Map<String, dynamic> json)`
  - L39 `String get displayLabel`
- L42 `class ReelCategoryGroup`
  - L48 `const ReelCategoryGroup({ required this.category, required this.label, required this.count, required this.subcategories, })`
  - L55 `factory ReelCategoryGroup.fromJson(Map<String, dynamic> json)`
  - L83 `String get displayLabel`
  - L85 `ReelSubcategoryFilter? subcategoryNamed(String? name)`
- L97 `class ReelPlatformGroup`
  - L104 `const ReelPlatformGroup({ required this.platform, required this.label, required this.count, required this.topCategory, required this.categories, })`
  - L112 `factory ReelPlatformGroup.fromJson(Map<String, dynamic> json)`
  - L123 `String get displayLabel`
  - L125 `ReelCategoryGroup? categoryNamed(String? category)`
- L134 `class ReelFiltersResponse`
  - L144 `const ReelFiltersResponse({ required this.totalCount, required this.topPlatform, required this.selectedPreviewCount, required this.platforms, required this.categories, })`
  - L152 `factory ReelFiltersResponse.fromJson(Map<String, dynamic> json)`
  - L173 `ReelPlatformGroup? platformNamed(String? platform)`
- L182 `List<ReelCategoryGroup> _parseCategories(Object? raw)`

### lib/data_models/reels/reel_page.dart

- L3 `class ReelPage`
  - L4 `const ReelPage({required this.reels, required this.limit, this.nextCursor})`
  - L10 `bool get hasMore`
  - L12 `factory ReelPage.fromJson(Map<String, dynamic> json)`

### lib/data_models/sharing/pending_share.dart

- L1 `class PendingShare`
  - L2 `const PendingShare({ required this.rawPayloadText, this.collectionIds = const [], })`
  - L10 `static PendingShare? fromNative(Object? value)`

### lib/data_models/sharing/share_resolve_response.dart

- L1 `class ShareResolveResponse`
  - L2 `const ShareResolveResponse({ required this.supported, this.url, this.sourcePlatform, this.sourceContentType, })`
  - L14 `factory ShareResolveResponse.fromJson(Map<String, dynamic> json)`

### lib/env.dart

- L3 `class ApiConfig`
  - L4 `ApiConfig._()`
  - L14 `static String get baseUrl`
- L30 `class LinkrunnerConfig`
  - L31 `LinkrunnerConfig._()`
  - L39 `static String get token`
  - L42 `static String? get secretKey`
  - L45 `static String? get keyId`
  - L47 `static bool get isConfigured`
- L53 `class RemoteConfigEndpoint`
  - L54 `RemoteConfigEndpoint._()`
  - L58 `static String get url`
  - L60 `static bool get isConfigured`
- L63 `class SupabaseConfig`
  - L64 `SupabaseConfig._()`
  - L71 `static Future<void> loadLocalConfig()`
  - L73 `static String get url`
  - L75 `static String get anonKey`
  - L78 `static String get redirectScheme`
  - L82 `static bool get isConfigured`
  - L85 `static String get redirectUrl`
  - L87 `static String _defaultRedirectScheme()`

### lib/http/account_http.dart

- L4 `abstract interface class AccountHttp`
  - L5 `Future<EntitlementsResponse> getAccountEntitlements({required String userId})`
  - L7 `Future<LibraryStats> getLibraryStats()`
  - L9 `Future<void> deleteAccount()`

### lib/http/api_client.dart

- L35 `class ApiClient implements ReelsHttp, DiscoverHttp, MapHttp, CollectionsHttp, AccountHttp, SharingHttp`
  - L56 `ApiClient({ http.Client? client, ContentCache? cache, String? baseUrl, String? Function()? accessTokenProvider, Future<void> Function()? sessionRefresher, })`
  - L71 `Future<Reel> processReel( String url, { String userId = 'default-user', void Function(ProcessingJob job)? onJobUpdate, })`
  - L85 `Future<ProcessingJob> enqueueReelProcessing( String url, { String userId = 'default-user', List<String> collectionIds = const [], })`
  - L93 `Future<ProcessingJob> _submitReel( String url, { List<String> collectionIds = const [], })`
  - L143 `Future<List<ProcessingJob>> listProcessingJobs({ bool activeOnly = true, int limit = 20, })`
  - L177 `Future<ProcessingJob> _getProcessingJob(String jobId)`
  - L197 `Future<Reel> _waitForProcessingJob( String jobId, { ProcessingJob? initialJob, void Function(ProcessingJob job)? onJobUpdate, })`
  - L245 `Future<Reel?> _completedJobResult(ProcessingJob job)`
  - L260 `void _throwIfTerminalFailure(ProcessingJob job)`
  - L270 `Duration _jobPollingDelay(int attempt, ProcessingJob job)`
  - L300 `String _jobFailureMessage(ProcessingJob job)`
  - L342 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L402 `Future<List<Reel>> getReels({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, int limit = 50, })`
  - L424 `Future<Reel> getReel(String reelId)`
  - L445 `Future<void> deleteReel(String reelId)`
  - L465 `Future<List<CollectionSummary>> getCollections()`
  - L487 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L520 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L548 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L577 `Future<void> deleteCollection(String collectionId)`
  - L595 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L619 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L640 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L661 `Future<void> disableCollectionLink(String collectionId)`
  - L679 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L700 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L724 `Future<void> leaveCollection(String collectionId)`
  - L742 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L767 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L786 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`
  - L818 `CollectionSummary _collectionFromMutation(http.Response res)`
  - L828 `Future<ReelFiltersResponse> getReelFilters({ String? userId, String? platform, String? category, String? subcategory, })`
  - L881 `Future<SearchResponse> searchReels( String query, { String userId = 'default-user', String? category, String? subcategory, int limit = 5, http.Client? client, })`
  - L944 `Future<EntitlementsResponse> getAccountEntitlements({ required String userId, })`
  - L982 `Future<MapResponse> getMapData({ required MapBounds bounds, String? category, })`
  - L1026 `Future<MapResponse> getNearbyPins({ required double latitude, required double longitude, int limit = 5, })`
  - L1059 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L1096 `Future<MapItem> pinMapPlace( String googlePlaceId, { String? sessionToken, })`
  - L1127 `Future<void> removeMapItem(String mapItemId)`
  - L1146 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = 25, })`
  - L1190 `Future<LibraryStats> getLibraryStats()`
  - L1211 `Future<void> deleteAccount()`
  - L1228 `Future<ShareResolveResponse> resolveSharePayload({ required String rawPayloadText, })`
  - L1257 `Future<void> registerPushToken({ required String userId, required String token, required String platform, required String appVersion, required String appBuild, required String timezone, required String locale, })`
  - L1285 `Future<void> unregisterPushToken({required String token})`
  - L1305 `Future<void> recordNotificationOpened({ required String notificationId, })`
  - L1329 `Future<String> mintShareToken()`
  - L1349 `Future<void> revokeShareToken()`
  - L1365 `Future<http.Response> _sendRequest( Future<http.Response> Function(String baseUrl) request, )`
  - L1404 `Uri _apiUri( String baseUrl, String path, { Map<String, String>? queryParameters, })`
  - L1423 `Future<http.Response> _sendRequestWithClient( http.Client client, Future<http.Response> Function(String baseUrl, http.Client client) request, )`
  - L1430 `String _networkErrorMessage(Object? error)`
  - L1434 `void _logNetworkError(String baseUrl, Object error)`
  - L1440 `Map<String, String> _headers({bool json = false})`
  - L1449 `static bool _isBlank(String? value)`
  - L1451 `static String _pageLimit(int limit)`
  - L1455 `static String _newIdempotencyKey()`
  - L1467 `static String? _currentAccessToken()`
  - L1475 `void _requireRequestAccount(String? sentToken)`
  - L1486 `static String? _tokenSubject(String? token)`
  - L1504 `Future<bool> _renewSession()`
  - L1516 `static Future<void> _refreshCurrentSession()`
  - L1523 `ApiException _exceptionFromResponse( http.Response res, { required String fallbackMessage, })`

### lib/http/api_exception.dart

- L1 `class ApiException implements Exception`
  - L2 `const ApiException( this.message, this.statusCode, { this.errorCode, this.requestId, this.details = const {}, this.retryable = false, })`
  - L18 `bool get isUpgradeRequired`
  - L22 `bool get isMonthlyReelLimitReached`
  - L24 `bool get isHistoryUpgradeRequired`
  - L27 `String toString()`

### lib/http/collections_http.dart

- L3 `abstract interface class CollectionsHttp`
  - L4 `Future<List<CollectionSummary>> getCollections()`
  - L6 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L12 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L18 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L25 `Future<void> deleteCollection(String collectionId)`
  - L27 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L32 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L37 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L39 `Future<void> disableCollectionLink(String collectionId)`
  - L41 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L43 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L48 `Future<void> leaveCollection(String collectionId)`
  - L50 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L55 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L57 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`

### lib/http/discover_http.dart

- L5 `abstract interface class DiscoverHttp`
  - L6 `Future<SearchResponse> searchReels( String query, { String userId = 'default-user', String? category, String? subcategory, int limit = 5, http.Client? client, })`
  - L15 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = 25, })`

### lib/http/map_http.dart

- L5 `abstract interface class MapHttp`
  - L6 `Future<MapResponse> getMapData({required MapBounds bounds, String? category})`
  - L8 `Future<MapResponse> getNearbyPins({ required double latitude, required double longitude, int limit = 5, })`
  - L14 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L21 `Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken})`
  - L23 `Future<void> removeMapItem(String mapItemId)`

### lib/http/mock_collections_http.dart

- L12 `const bool useMockCollections = `
- L19 `class MockCollectionsHttp implements CollectionsHttp`
  - L20 `MockCollectionsHttp()`
  - L39 `void _seed()`
  - L97 `void _add(CollectionSummary collection, List<Reel> reels)`
  - L103 `List<Reel> _makeReels( String prefix, int count, String category, String platform, )`
  - L124 `Reel _makeReel({ required String id, required String title, required String category, required String platform, required int daysAgo, })`
  - L169 `Future<List<CollectionSummary>> getCollections()`
  - L175 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L186 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`
  - L210 `CollectionDetail _detail( CollectionSummary collection, { required int limit, String? cursor, bool? canEdit, })`
  - L232 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L244 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L276 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L291 `Future<void> deleteCollection(String collectionId)`
  - L301 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L329 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L340 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L350 `Future<void> disableCollectionLink(String collectionId)`
  - L358 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L376 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L389 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L404 `Future<void> leaveCollection(String collectionId)`
  - L417 `Future<void> _wait()`
  - L419 `CollectionSummary _require(String id)`
  - L427 `CollectionSummary _requireEditable(String id)`
  - L438 `CollectionSummary _requireOwner(String id)`

### lib/http/reels_http.dart

- L6 `abstract interface class ReelsHttp`
  - L7 `Future<Reel> processReel( String url, { String userId = 'default-user', void Function(ProcessingJob job)? onJobUpdate, })`
  - L15 `Future<ProcessingJob> enqueueReelProcessing( String url, { String userId = 'default-user', List<String> collectionIds = const [], })`
  - L23 `Future<List<ProcessingJob>> listProcessingJobs({ bool activeOnly = true, int limit = 20, })`
  - L28 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L38 `Future<List<Reel>> getReels({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, int limit = 50, })`
  - L47 `Future<Reel> getReel(String reelId)`
  - L49 `Future<void> deleteReel(String reelId)`
  - L54 `Future<ReelFiltersResponse> getReelFilters({ String? userId, String? platform, String? category, String? subcategory, })`

### lib/http/sharing_http.dart

- L3 `abstract interface class SharingHttp`
  - L4 `Future<ShareResolveResponse> resolveSharePayload({ required String rawPayloadText, })`
  - L8 `Future<void> registerPushToken({ required String userId, required String token, required String platform, required String appVersion, required String appBuild, required String timezone, required String locale, })`
  - L18 `Future<void> unregisterPushToken({required String token})`
  - L20 `Future<void> recordNotificationOpened({required String notificationId})`
  - L22 `Future<String> mintShareToken()`
  - L24 `Future<void> revokeShareToken()`

### lib/main.dart

- L3 `Future<void> main()`

### lib/providers.dart

- L33 `final themeViewModelProvider = ChangeNotifierProvider<ThemeViewModel>`
- L37 `final remoteConfigViewModelProvider = `
- L44 `final profileServiceProvider = Provider<ProfileService>`
- L48 `final authServiceProvider = Provider<AuthService>`
- L52 `final sessionViewModelProvider = ChangeNotifierProvider<SessionViewModel>`
- L64 `final notificationServiceProvider = Provider<NotificationService>`
- L68 `final shareFlowAnalyticsServiceProvider = Provider<ShareFlowAnalyticsService>`
- L74 `final apiClientProvider = Provider<ApiClient>`
- L78 `final reelsHttpProvider = Provider<ReelsHttp>`
- L82 `final mapHttpProvider = Provider<MapHttp>`
- L86 `final collectionsHttpProvider = Provider<CollectionsHttp>`
- L93 `final collectionsViewModelProvider = `
- L101 `final accountHttpProvider = Provider<AccountHttp>`
- L105 `final sharingHttpProvider = Provider<SharingHttp>`
- L109 `final pushRegistrationServiceProvider = Provider<PushRegistrationService>`
- L118 `final reelRepositoryProvider = ChangeNotifierProvider<ReelRepository>`
- L125 `final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>`
- L136 `final mapViewModelProvider = ChangeNotifierProvider<MapViewModel>`
- L140 `final reelFiltersViewModelProvider = `
- L145 `final discoverViewModelProvider = ChangeNotifierProvider<DiscoverViewModel>`
- L151 `final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>`
- L155 `final entitlementsViewModelProvider = `
- L169 `final processingJobsViewModelProvider = `
- L196 `final appShellControllerProvider = StateProvider<AppShellController?>`
- L200 `final userStateCoordinatorProvider = Provider<UserStateCoordinator>`

### lib/reelpin_app.dart

- L8 `class ReelPinApp extends ConsumerWidget`
  - L9 `const ReelPinApp({super.key, required this.isSupabaseConfigured})`
  - L14 `Widget build(BuildContext context, WidgetRef ref)`

### lib/repositories/reel_repository.dart

- L22 `class SearchCancelledException implements Exception`
  - L23 `const SearchCancelledException()`
- L26 `class ReelRepository extends ChangeNotifier`
  - L46 `ReelRepository( this._apiService, this._authService, { ContentCache? contentCache, })`
  - L52 `String get _currentUserId`
  - L60 `List<Reel> get cachedReels`
  - L61 `String? get cacheUserId`
  - L62 `bool get hasMoreReels`
  - L63 `bool get hasHydratedCache`
  - L64 `SearchMode? get lastSearchMode`
  - L65 `int get lastSearchTotal`
  - L70 `Future<void> hydrateCache()`
  - L87 `Future<void> _hydrateCache()`
  - L125 `Future<void> loadInitialReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L151 `Future<void> _loadInitialReels({ required bool forceRefresh, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L175 `Future<void> loadMoreReels({ String? platform, String? category, String? subcategory, String? savedDate, })`
  - L202 `Future<void> _loadMoreReelsInternal({ String? platform, String? category, String? subcategory, String? savedDate, })`
  - L226 `Future<void> _fetchAndStorePage({ required bool reset, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L254 `Future<List<Reel>> getReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L271 `Future<ReelPage> getReelsPage({ String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = _pageSize, })`
  - L290 `Future<Reel> getReel(String reelId, {bool forceRefresh = false})`
  - L295 `Future<Reel> processReel( String url, { void Function(ProcessingJob job)? onJobUpdate, })`
  - L309 `Future<ProcessingJob> enqueueReelProcessing( String url, { List<String> collectionIds = const [], })`
  - L326 `void insertReel(Reel reel)`
  - L335 `Future<List<ProcessingJob>> listProcessingJobs({int limit = 20})`
  - L339 `Future<ReelFiltersResponse> getFilters({ String? platform, String? category, String? subcategory, })`
  - L352 `Future<MapResponse> getMapData({ required MapBounds bounds, String? category, })`
  - L359 `Future<MapResponse> getNearbyPins({ required double latitude, required double longitude, int limit = 5, })`
  - L371 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, })`
  - L383 `Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken})`
  - L387 `Future<void> removeMapItem(String mapItemId)`
  - L391 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = _pageSize, })`
  - L403 `Future<LibraryStats> getLibraryStats()`
  - L407 `Future<void> deleteReel(String reelId)`
  - L413 `Future<SearchResponse> search( String query, { String? category, String? subcategory, })`
  - L455 `void clearCache()`
  - L471 `Future<void> clearUserCache()`
  - L478 `bool _hasFilters( String? platform, String? category, String? subcategory, String? savedDate, )`
  - L491 `void cancelActiveSearch()`
  - L497 `bool _isActiveSearchClient(http.Client client)`
  - L501 `void dispose()`

### lib/router.dart

- L22 `Route<void> reelDetailRoute(Reel reel)`
- L27 `Route<void> reelDetailSlideRoute(Reel reel)`
- L43 `Route<void> reelDetailLoaderRoute(String reelId)`
- L49 `Route<void> featureAnnouncementRoute({ required String title, required String body, })`
- L60 `Route<void> updateRequiredRoute(UpdateRequirement requirement)`
- L67 `Route<void> howToUseRoute({bool isFirstRun = false})`
- L74 `Route<void> profileRoute()`
- L81 `Route<void> collectionDetailRoute(String collectionId, {bool animate = true})`
- L98 `Route<void> sharedCollectionRoute( String token, { bool animate = true, String? url, })`
- L116 `Route<void> paywallRoute({ PaywallEntryPoint entryPoint = PaywallEntryPoint.account, })`
- L124 `Future<void> openPaywall( BuildContext context, { PaywallEntryPoint entryPoint = PaywallEntryPoint.account, })`

### lib/screens/app_shell/app_shell.dart

- L41 `const _navIconSize = 27.0`
- L43 `class AppShell extends ConsumerStatefulWidget`
  - L44 `const AppShell({super.key, this.controller})`
  - L49 `ConsumerState<AppShell> createState()`
- L52 `class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver`
  - L85 `void initState()`
  - L111 `Future<void> _initCollectionDeepLinks()`
  - L140 `Future<void> _handleDeferredLink()`
  - L145 `Future<void> _handleIncomingUri(Uri uri)`
  - L158 `void _routeCollectionUri(Uri uri)`
  - L171 `Future<void> _openLaunchLink(CollectionLink link)`
  - L185 `void _routeCollectionLink(CollectionLink link, {bool animate = true})`
  - L201 `Future<void> _openSharedCollection( String token, { bool animate = true, String? url, })`
  - L213 `Future<void> _acceptCollectionInvite( String token, { bool animate = true, })`
  - L240 `void _initSharingIntent()`
  - L264 `void _processSharedData(List<SharedMediaFile> files)`
  - L272 `Future<void> _handleSharedPayload( String payload, { bool showConfirmation = true, List<String> collectionIds = const [], })`
  - L319 `Future<void> _enqueueSharedReel( String url, { required bool showConfirmation, List<String> collectionIds = const [], })`
  - L447 `void _showSaveFailure(ScaffoldMessengerState messenger, Object error)`
  - L472 `void dispose()`
  - L482 `void didChangeAppLifecycleState(AppLifecycleState state)`
  - L512 `Future<void> _drainPendingNativeShares()`
  - L545 `Future<void> _runFirstRunFlow()`
  - L550 `Future<void> _maybeShowHowToGuide()`
  - L578 `Future<bool> _accountHasSaves()`
  - L584 `Future<void> _maybePromptInitialPermissions()`
  - L602 `Future<bool> _enableReelPinPermissions()`
  - L638 `Future<void> _syncPushTokenRegistrationIfPossible()`
  - L652 `void _openSearchFromHome()`
  - L660 `Future<void> _scrollHomeToTop()`
  - L669 `void _showHomeAtTop()`
  - L678 `void _selectControlledTab(int index)`
  - L686 `bool _isHomeScrolledDown()`
  - L691 `Future<void> _refreshSavedContent()`
  - L703 `void _selectTab(int index)`
  - L719 `void _refreshSelectedContent(int index)`
  - L731 `Widget build(BuildContext context)`
  - L779 `Widget _buildNavBar()`
  - L827 `Widget _buildNavItem(int index, _NavItem item)`

### lib/screens/app_shell/authenticated_shell.dart

- L20 `class AuthenticatedShell extends ConsumerStatefulWidget`
  - L21 `const AuthenticatedShell({super.key})`
  - L24 `ConsumerState<AuthenticatedShell> createState()`
- L27 `class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell>`
  - L55 `void initState()`
  - L99 `Widget build(BuildContext context)`
  - L103 `Future<void> _initializeBackgroundMessaging()`
  - L137 `Future<void> _syncPushTokenRegistration({ String? candidateToken, int retryAttempt = 1, })`
  - L190 `void _schedulePushTokenRegistrationRetry({int attempt = 1})`
  - L201 `Future<void> _refreshSavedReels()`
  - L209 `void _queueNotificationOpen(OpenedAppNotification opened)`
  - L216 `Future<void> _handleNotificationOpen(OpenedAppNotification opened)`
  - L269 `void _showRemotePrompts()`
  - L279 `Future<void> _presentRemotePrompts()`
  - L301 `void _openShellTab(VoidCallback selectTab)`
  - L306 `Future<void> _recordNotificationOpen(String notificationId)`
  - L314 `void _clearUserScopedState()`
  - L325 `void dispose()`

### lib/screens/app_shell/partials/app_shell_controller.dart

- L5 `class AppTabLayout`
  - L6 `const AppTabLayout()`
- L14 `class AppShellController`
  - L19 `void showHome()`
  - L23 `void showMap()`
  - L27 `void showSaved()`
  - L31 `void showDiscover()`
  - L35 `void _select(int index)`
  - L45 `void attachForTest(ValueChanged<int> callback)`
  - L47 `void _attach(ValueChanged<int> callback)`
  - L56 `void _detach()`

### lib/screens/app_shell/partials/nav_item.dart

- L6 `class _NavItem`
  - L11 `const _NavItem({this.icon, this.assetPath, required this.label})`

### lib/screens/auth/auth_screen.dart

- L12 `class AuthScreen extends ConsumerStatefulWidget`
  - L13 `const AuthScreen({super.key})`
  - L16 `ConsumerState<AuthScreen> createState()`
- L19 `class _AuthScreenState extends ConsumerState<AuthScreen>`
  - L31 `void dispose()`
  - L39 `void _setMode(bool signUp)`
  - L49 `Future<void> _submit(SessionViewModel sessionVm)`
  - L75 `Widget build(BuildContext context)`
  - L416 `bool get _showsAppleSignIn`
  - L422 `Widget _modeButton( BuildContext context, { required String label, required bool active, required VoidCallback onTap, })`
  - L450 `Widget _providerButton( BuildContext context, { required String label, required Widget icon, required bool isBusy, required VoidCallback onTap, Color color = AppColors.white, Color textColor = AppColors.black, Color borderColor = AppColors.black, Color arrowColor = AppColors.black, })`
  - L506 `Widget _messageBanner( BuildContext context, { required String text, required Color color, required Color textColor, })`
  - L531 `Widget _inputField( BuildContext context, { required TextEditingController controller, required String label, required String hint, required String? Function(String?) validator, bool obscureText = false, TextInputType? keyboardType, Widget? suffixIcon, })`

### lib/screens/collections/collection_detail_screen.dart

- L30 `class CollectionDetailScreen extends ConsumerStatefulWidget`
  - L31 `const CollectionDetailScreen({ super.key, required this.collectionId, this.sharedToken, this.sharedUrl, this.initialName, })`
  - L50 `bool get isShared`
  - L53 `ConsumerState<CollectionDetailScreen> createState()`
- L57 `class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen>`
  - L68 `void initState()`
  - L103 `Future<void> _loadOwnLink()`
  - L110 `String? get _collectionShareUrl`
  - L119 `Future<void> _loadShared()`
  - L147 `Future<void> _refresh()`
  - L156 `Future<void> _edit(CollectionSummary collection)`
  - L160 `Future<void> _confirmDelete(CollectionSummary collection)`
  - L178 `Future<void> _confirmLeave(CollectionSummary collection)`
  - L193 `Future<void> _confirmRemoveReel(Reel reel)`
  - L211 `Future<void> _runGuarded( Future<void> Function() action, { required String fallback, bool popOnSuccess = false, })`
  - L231 `Widget build(BuildContext context)`
  - L344 `Widget _buildHeader( BuildContext context, CollectionsViewModel vm, CollectionSummary? collection, { required bool canEdit, })`
  - L424 `List<Widget> _buildContent( BuildContext context, { required bool ownsReels, required CollectionDetail? detail, required bool isLoading, required String? error, required bool canEdit, })`
  - L500 `Widget _buildReelGrid( BuildContext context, List<Reel> reels, { required bool canEdit, required bool ownsReels, required List<ProcessingJob> processingJobs, })`
  - L584 `Widget _buildPaginationState(BuildContext context, CollectionDetail detail)`
  - L608 `Widget _buildLoading(BuildContext context)`
- L623 `class _HeaderAction extends StatelessWidget`
  - L624 `const _HeaderAction({ required this.icon, required this.onTap, this.color, this.iconColor, })`
  - L637 `Widget build(BuildContext context)`
- L656 `class _SharedBanner extends StatelessWidget`
  - L657 `const _SharedBanner()`
  - L660 `Widget build(BuildContext context)`
- L690 `class _MessageCard extends StatelessWidget`
  - L691 `const _MessageCard({ required this.title, required this.body, this.icon, this.onRetry, })`
  - L704 `Widget build(BuildContext context)`

### lib/screens/collections/collections_screen.dart

- L19 `class CollectionsScreen extends ConsumerStatefulWidget`
  - L20 `const CollectionsScreen({super.key})`
  - L23 `ConsumerState<CollectionsScreen> createState()`
- L26 `class _CollectionsScreenState extends ConsumerState<CollectionsScreen>`
  - L28 `void initState()`
  - L42 `double _navBarClearance(BuildContext context)`
  - L46 `Future<void> _createCollection()`
  - L56 `Future<void> _refresh()`
  - L63 `Widget build(BuildContext context)`
  - L100 `Widget _buildHeader(BuildContext context, CollectionsViewModel vm)`
  - L160 `List<Widget> _buildBody(BuildContext context, CollectionsViewModel vm)`
  - L197 `Widget _buildGrid(BuildContext context, List<CollectionSummary> collections)`
- L245 `class _LoadingState extends StatelessWidget`
  - L247 `Widget build(BuildContext context)`
- L265 `class _MessageAction`
  - L266 `const _MessageAction({required this.label, required this.onTap})`
- L272 `class _MessageCard extends StatelessWidget`
  - L273 `const _MessageCard({ required this.title, required this.body, this.hugeIcon, this.onRetry, this.action, })`
  - L290 `Widget build(BuildContext context)`

### lib/screens/collections/partials/collection_sticky_note.dart

- L7 `const double _pinAngle = -0.28`
- L9 `class _CollectionStickyNote extends StatelessWidget`
  - L10 `const _CollectionStickyNote({ required this.note, required this.canEdit, this.onEdit, })`
  - L23 `Widget build(BuildContext context)`
- L196 `class _StickyNoteClipper extends CustomClipper<Path>`
  - L198 `Path getClip(Size size)`
  - L213 `bool shouldReclip(covariant CustomClipper<Path> oldClipper)`

### lib/screens/discover/discover_screen.dart

- L24 `class DiscoverScreen extends ConsumerStatefulWidget`
  - L25 `const DiscoverScreen({super.key, this.focusRequestId = 0})`
  - L30 `ConsumerState<DiscoverScreen> createState()`
- L33 `class _DiscoverScreenState extends ConsumerState<DiscoverScreen>`
  - L43 `void initState()`
  - L56 `void dispose()`
  - L65 `void didUpdateWidget(covariant DiscoverScreen oldWidget)`
  - L70 `void _handleControllerTextChanged()`
  - L79 `void _scheduleFocusIfRequested()`
  - L91 `Widget build(BuildContext context)`
  - L259 `void _handleSearchChanged(SearchViewModel vm, String query)`
  - L274 `void _doSearch(SearchViewModel vm, String query)`
  - L285 `Widget? _buildSearchFieldAction(BuildContext context, SearchViewModel vm)`
  - L316 `void _clearSearch(SearchViewModel vm, {bool keepFocus = false})`
  - L337 `void _clearDateFilter()`
  - L341 `Future<void> _openCategory(DiscoverCategory category)`
  - L355 `Future<void> _pickSavedDate(BuildContext context)`
  - L392 `Widget _buildNoResults(BuildContext context, String query)`
  - L446 `Widget _buildMinimumQueryState(BuildContext context, String query)`
  - L501 `Widget _buildDiscoverContent( BuildContext context, DiscoverViewModel discoverVm, )`
  - L664 `Widget _buildDiscoverError( BuildContext context, DiscoverViewModel discoverVm, )`
  - L705 `Widget _buildCategoryReelsContent( BuildContext context, DiscoverViewModel discoverVm, )`
  - L806 `Widget _buildCategoryReelsError( BuildContext context, DiscoverViewModel discoverVm, )`
  - L846 `Widget _buildCategoryReelsEmpty(BuildContext context, String categoryLabel)`
  - L871 `Widget _buildCategoryReelGrid(BuildContext context, List<Reel> reels)`
  - L916 `Widget _buildDateEmptyState(BuildContext context, String selectedDateLabel)`
  - L959 `Widget _buildQuickSearches(BuildContext context, List<String> prompts)`
  - L998 `Widget _buildRecentSaves(BuildContext context, List<Reel> reels)`
  - L1101 `Widget _buildCategoryGrid( BuildContext context, List<DiscoverCategory> categories, )`
  - L1194 `Widget _buildSearchingState(BuildContext context)`
  - L1233 `Widget _buildResults(BuildContext context, SearchViewModel vm)`
  - L1295 `Widget _buildError(BuildContext context, SearchViewModel vm)`

### lib/screens/discover/partials/saved_date_calendar_sheet.dart

- L3 `class _SavedDateCalendarSheet extends StatefulWidget`
  - L4 `const _SavedDateCalendarSheet({ required this.savedDates, required this.selectedSavedDate, })`
  - L13 `State<_SavedDateCalendarSheet> createState()`
- L17 `class _SavedDateCalendarSheetState extends State<_SavedDateCalendarSheet>`
  - L22 `void initState()`
  - L41 `Widget build(BuildContext context)`
  - L177 `Widget _monthButton( BuildContext context, { required IconData icon, required VoidCallback onTap, })`
  - L194 `Widget _buildDayCell( BuildContext context, { required DateTime? day, required DateTime? selectedDay, })`
  - L264 `List<DateTime?> _visibleDays()`
  - L287 `void _showPreviousMonth()`
  - L293 `void _showNextMonth()`
  - L299 `String _monthLabel(DateTime date)`
  - L317 `static DateTime? _parseSavedDate(String? value)`
  - L325 `static DateTime _dayKey(DateTime date)`
- L330 `class _WeekdayLabel extends StatelessWidget`
  - L331 `const _WeekdayLabel({required this.label})`
  - L336 `Widget build(BuildContext context)`

### lib/screens/discover/partials/search_result_tile.dart

- L10 `class SearchResultTile extends StatelessWidget`
  - L13 `const SearchResultTile({super.key, required this.result})`
  - L16 `Widget build(BuildContext context)`
  - L99 `Color _contrastText(Color bg)`

### lib/screens/feature_announcement/feature_announcement_screen.dart

- L8 `class FeatureAnnouncementScreen extends StatelessWidget`
  - L9 `const FeatureAnnouncementScreen({ super.key, required this.title, required this.body, })`
  - L19 `Widget build(BuildContext context)`

### lib/screens/home/home_screen.dart

- L28 `class HomeScreen extends ConsumerStatefulWidget`
  - L29 `const HomeScreen({super.key, this.onSearchTap, this.scrollController})`
  - L35 `ConsumerState<HomeScreen> createState()`
- L38 `class _HomeScreenState extends ConsumerState<HomeScreen>`
  - L46 `bool get _isSelecting`
  - L48 `void _startSelection(String reelId)`
  - L52 `void _toggleSelection(String reelId)`
  - L60 `void _endSelection()`
  - L64 `Future<void> _addSelectionToCollection(HomeViewModel vm)`
  - L71 `Future<void> _deleteSelection(HomeViewModel vm)`
  - L89 `void initState()`
  - L109 `bool _isEmptyStateVisible(HomeViewModel vm, {required bool hasProcessing})`
  - L121 `Widget build(BuildContext context)`
  - L324 `Widget _buildPaginationState(BuildContext context, HomeViewModel vm)`
  - L388 `Widget _buildSearchButton(BuildContext context)`
  - L405 `Widget _buildFilterButton( BuildContext context, HomeViewModel vm, ReelFiltersViewModel filtersVm, )`
  - L444 `bool _showFreeHistoryBanner(UserEntitlement? entitlements)`
  - L448 `Widget _buildFreePlanBanner( BuildContext context, EntitlementsResponse entitlements, )`
  - L515 `Widget _buildReelGrid( BuildContext context, HomeViewModel vm, List<ProcessingJob> processingJobs, )`
  - L596 `Widget _buildShimmerGrid(BuildContext context)`
  - L643 `Widget _buildEmptyState(BuildContext context)`
  - L696 `Widget _buildEmptyFlow(BuildContext context)`
  - L741 `Widget _emptyFlowTile( BuildContext context, { required IconData icon, required String title, required String caption, required Color color, required Color iconColor, Color? textColor, })`
  - L795 `Widget _flowArrow(BuildContext context)`
  - L812 `Widget _buildGuideButton(BuildContext context)`
  - L882 `Widget _buildFirstSaveHint(BuildContext context)`
  - L931 `String _supportedPlatformSentence()`
  - L939 `Widget _platformIconBadge(BuildContext context, SourcePlatform platform)`
  - L960 `Widget _buildErrorState(BuildContext context, HomeViewModel vm)`
  - L1044 `void _showFilterSheet( BuildContext context, HomeViewModel vm, ReelFiltersViewModel filtersVm, )`
  - L1445 `String _activeFilterLabel({ required ReelFiltersViewModel filtersVm, required String? platform, required String? category, required String? subcategory, })`
  - L1461 `String _filterHint({ required String? platform, required String? category, required bool hasSubcategories, })`
  - L1477 `Widget _buildFilterSheetStatus( BuildContext context, { required String label, })`
  - L1510 `Widget _buildFilterSheetError( BuildContext context, ReelFiltersViewModel filtersVm, )`
  - L1566 `Widget _buildFilterSheetEmpty(BuildContext context)`
  - L1582 `Widget _buildCompactFilterSummary( BuildContext context, { required String activeFilterLabel, required int previewCount, required int totalCount, required Color currentAccentColor, required ReelPlatformGroup? topPlatform, })`
  - L1621 `Widget _buildFilterInfoCard( BuildContext context, { required String label, required String title, required String subtitle, required Color accentColor, })`
  - L1687 `Widget _buildFilterDropdownField( BuildContext context, { required String label, required String hint, required String? value, required bool enabled, required Color accentColor, required List<_FilterOption> items, required ValueChanged<String?> onChanged, })`
  - L1802 `Widget _buildCountBadge( BuildContext context, int count, { required Color backgroundColor, })`
- L1833 `class _SelectionBar extends StatelessWidget`
  - L1834 `const _SelectionBar({ required this.count, required this.onCancel, required this.onAdd, required this.onDelete, })`
  - L1847 `Widget build(BuildContext context)`
- L1911 `class _SelectionAction extends StatelessWidget`
  - L1912 `const _SelectionAction({ required this.icon, required this.color, required this.iconColor, required this.onTap, this.label, })`
  - L1930 `Widget build(BuildContext context)`

### lib/screens/home/partials/filter_option.dart

- L6 `class _FilterOption`
  - L12 `const _FilterOption({ required this.value, required this.label, required this.count, required this.accentColor, })`

### lib/screens/home/partials/platform_filter_tile.dart

- L9 `class _PlatformFilterTile extends StatelessWidget`
  - L10 `const _PlatformFilterTile({ required this.platformId, required this.label, required this.count, required this.isSelected, required this.onTap, })`
  - L25 `Widget build(BuildContext context)`
- L103 `class _PlatformArtwork extends StatelessWidget`
  - L104 `const _PlatformArtwork({required this.platformId, required this.size})`
  - L110 `Widget build(BuildContext context)`
- L134 `Color _platformAccentColor(String? platformId)`

### lib/screens/how_to/how_to_use_screen.dart

- L29 `class HowToUseScreen extends StatefulWidget`
  - L30 `const HowToUseScreen({super.key, this.isFirstRun = false})`
  - L37 `State<HowToUseScreen> createState()`
- L40 `class _HowToUseScreenState extends State<HowToUseScreen>`
  - L164 `void didChangeDependencies()`
  - L192 `bool get _isLastStep`
  - L195 `void initState()`
  - L207 `void dispose()`
  - L214 `void _advance()`
  - L227 `void _goBack()`
  - L236 `void _registerMiss()`
  - L244 `Widget build(BuildContext context)`
  - L278 `Widget _buildContent( BuildContext context, AppLayout layout, _HowToStep step, { required double viewportHeight, })`
  - L361 `Widget _buildHeader(BuildContext context, _HowToStep step)`
  - L433 `Widget _buildProgress(BuildContext context, _HowToStep step)`
  - L456 `Widget _buildHint(BuildContext context, _HowToStep step)`

### lib/screens/how_to/partials/how_to_stage.dart

- L6 `const howToHotspotKey = ValueKey`
- L17 `class _HowToStage extends StatefulWidget`
  - L18 `const _HowToStage({ super.key, required this.step, required this.onHotspotTap, required this.onMissedTap, required this.isLastStep, })`
  - L32 `State<_HowToStage> createState()`
- L35 `class _HowToStageState extends State<_HowToStage> with SingleTickerProviderStateMixin`
  - L46 `void initState()`
  - L55 `void dispose()`
  - L61 `Widget build(BuildContext context)`
  - L174 `Widget _buildMissingAsset(BuildContext context)`
- L207 `class _HotspotPulsePainter extends CustomPainter`
  - L208 `const _HotspotPulsePainter({ required this.progress, required this.markWidth, required this.markHeight, required this.corner, required this.maxScale, })`
  - L223 `void paint(Canvas canvas, Size size)`
  - L250 `bool shouldRepaint(_HotspotPulsePainter oldDelegate)`

### lib/screens/how_to/partials/how_to_step.dart

- L9 `class _HowToStep`
  - L10 `const _HowToStep({ required this.assetPath, required this.label, required this.title, required this.body, required this.accent, required this.hotspotX, required this.hotspotY, required this.hotspotWidth, required this.hotspotHeight, required this.aspectRatio, this.hotspotCorner = _kCircleCorner, })`
- L47 `const double _kCircleCorner = 0.5`
- L50 `const double _kGuideAspectRatio = 784 / 1600`

### lib/screens/map/map_screen.dart

- L27 `class MapScreen extends ConsumerStatefulWidget`
  - L28 `const MapScreen({super.key})`
  - L31 `ConsumerState<MapScreen> createState()`
- L34 `class _MapScreenState extends ConsumerState<MapScreen>`
  - L72 `void initState()`
  - L84 `void didChangeDependencies()`
  - L96 `Future<void> _initUserLocation()`
  - L118 `void _centerMapOnUserCountry()`
  - L135 `Future<void> _recenterToUserLocation()`
  - L164 `Future<void> _reportViewport()`
  - L182 `Future<void> _refreshMapPins()`
  - L186 `Future<void> _openPlaceSearchSheet()`
  - L206 `void _focusMapItem(MapItem item)`
  - L215 `void _handleMapViewModelChanged()`
  - L219 `void _scheduleVisibleMarkerSync()`
  - L230 `Future<void> _syncVisibleMarkers(MapViewModel mapVm)`
  - L278 `Future<BitmapDescriptor> _createCustomPin(String category)`
  - L281 `void _fitMarkers(Set<Marker> markers)`
  - L285 `void _fitPositions(List<LatLng> positions)`
  - L312 `Widget build(BuildContext context)`
  - L663 `Widget _mapNotice(String message)`
  - L686 `Widget _mapButton({required IconData icon, required VoidCallback onTap})`
  - L703 `Set<Marker> _buildMarkers(MapViewModel vm)`
  - L726 `Widget _buildPinSheet(BuildContext context, MapItem item)`
  - L966 `Future<void> _confirmRemoveMapItem(BuildContext context, MapItem item)`
  - L998 `void dispose()`

### lib/screens/map/partials/map_place_search_sheet.dart

- L3 `class _MapPlaceSearchSheet extends ConsumerStatefulWidget`
  - L4 `const _MapPlaceSearchSheet({ required this.onMapItemSelected, required this.onMapItemPinned, })`
  - L13 `ConsumerState<_MapPlaceSearchSheet> createState()`
- L17 `class _MapPlaceSearchSheetState extends ConsumerState<_MapPlaceSearchSheet>`
  - L30 `void initState()`
  - L41 `void dispose()`
  - L49 `void _handleTextChanged()`
  - L64 `void _runSearch({bool force = false})`
  - L77 `Future<void> _handleResultTap( MapPlaceSearchResult result, String resultKey, )`
  - L135 `Widget build(BuildContext context)`
  - L231 `Widget _buildSearchField(BuildContext context, MapViewModel vm)`
  - L271 `Widget? _buildSearchFieldAction(BuildContext context, MapViewModel vm)`
  - L305 `Widget _buildResults(BuildContext context, MapViewModel vm, String query)`
  - L389 `List<MapPlaceSearchResult> _savedResults(List<MapPlaceSearchResult> results)`
  - L395 `String _placeResultKey(MapPlaceSearchResult result, int index)`
- L405 `enum _PlaceSearchTab`
- L407 `class _PlaceSearchTabs extends StatelessWidget`
  - L408 `const _PlaceSearchTabs({ required this.selectedTab, required this.allCount, required this.savedCount, required this.onChanged, })`
  - L421 `Widget build(BuildContext context)`
- L455 `class _PlaceSearchTabButton extends StatelessWidget`
  - L456 `const _PlaceSearchTabButton({ required this.label, required this.count, required this.isSelected, required this.onTap, })`
  - L469 `Widget build(BuildContext context)`
- L519 `class _PlaceSearchMessage extends StatelessWidget`
  - L520 `const _PlaceSearchMessage({ required this.icon, required this.title, required this.accentColor, this.body, this.isLoading = false, })`
  - L535 `Widget build(BuildContext context)`
- L601 `class _PlaceSearchSummary extends StatelessWidget`
  - L602 `const _PlaceSearchSummary({ required this.count, required this.query, required this.tab, })`
  - L613 `Widget build(BuildContext context)`
- L652 `class _MapPlaceResultTile extends StatelessWidget`
  - L653 `const _MapPlaceResultTile({ required this.result, required this.isSaving, required this.onTap, })`
  - L664 `Widget build(BuildContext context)`
  - L781 `String _firstNonEmpty(List<String?> values)`

### lib/screens/onboarding/onboarding_screen.dart

- L15 `class OnboardingScreen extends StatefulWidget`
  - L16 `const OnboardingScreen({super.key, required this.onContinue})`
  - L21 `State<OnboardingScreen> createState()`
- L24 `class _OnboardingScreenState extends State<OnboardingScreen>`
  - L64 `void initState()`
  - L70 `void dispose()`
  - L75 `void _next()`
  - L88 `Widget build(BuildContext context)`

### lib/screens/onboarding/partials/onboarding_card.dart

- L3 `class _OnboardingCard extends StatelessWidget`
  - L4 `const _OnboardingCard({required this.step, required this.isActive})`
  - L10 `Widget build(BuildContext context)`

### lib/screens/onboarding/partials/onboarding_step.dart

- L3 `class _OnboardingStep`
  - L4 `const _OnboardingStep({ required this.label, required this.title, required this.body, required this.accent, required this.icon, required this.bullet, required this.highlights, this.platforms = const [], })`

### lib/screens/paywall/paywall_screen.dart

- L11 `enum PaywallEntryPoint`
  - L16 `const PaywallEntryPoint(this.messageKey)`
- L22 `class PaywallScreen extends ConsumerWidget`
  - L23 `const PaywallScreen({super.key, required this.entryPoint})`
  - L28 `Widget build(BuildContext context, WidgetRef ref)`
  - L171 `Widget _sectionTitle(BuildContext context, String text)`
  - L184 `Widget _statusCard(BuildContext context, EntitlementsResponse? response)`
  - L262 `List<Widget> _buildBackendPlanCards( BuildContext context, List<PlanCard> planCards, )`
  - L296 `Widget _planCard( BuildContext context, { required PlanCard card, required Color accent, })`

### lib/screens/profile/partials/location_preference_card.dart

- L3 `class _LocationPreferenceCard extends ConsumerStatefulWidget`
  - L4 `const _LocationPreferenceCard()`
  - L7 `ConsumerState<_LocationPreferenceCard> createState()`
- L11 `class _LocationPreferenceCardState extends ConsumerState<_LocationPreferenceCard>`
  - L17 `void initState()`
  - L24 `Future<void> _loadPermissionState()`
  - L32 `Future<void> _enableLocation()`
  - L55 `Future<void> _openLocationSettings()`
  - L75 `Widget build(BuildContext context)`

### lib/screens/profile/partials/notification_preference_card.dart

- L3 `class _NotificationPreferenceCard extends ConsumerStatefulWidget`
  - L4 `const _NotificationPreferenceCard()`
  - L7 `ConsumerState<_NotificationPreferenceCard> createState()`
- L11 `class _NotificationPreferenceCardState extends ConsumerState<_NotificationPreferenceCard>`
  - L17 `void initState()`
  - L24 `Future<void> _loadPermissionState()`
  - L40 `Future<void> _enableNotifications()`
  - L77 `Future<void> _openNotificationSettings()`
  - L97 `Widget build(BuildContext context)`

### lib/screens/profile/partials/profile_action_card.dart

- L3 `class _ProfileActionCard extends StatelessWidget`
  - L4 `const _ProfileActionCard({ required this.title, required this.subtitle, required this.trailing, })`
  - L15 `Widget build(BuildContext context)`

### lib/screens/profile/partials/share_picker_preference_card.dart

- L8 `class _SharePickerPreferenceCard extends ConsumerStatefulWidget`
  - L9 `const _SharePickerPreferenceCard()`
  - L12 `ConsumerState<_SharePickerPreferenceCard> createState()`
- L16 `class _SharePickerPreferenceCardState extends ConsumerState<_SharePickerPreferenceCard>`
  - L22 `void initState()`
  - L27 `Future<void> _load()`
  - L33 `Future<void> _set(bool enabled)`
  - L51 `Widget build(BuildContext context)`

### lib/screens/profile/profile_screen.dart

- L27 `class ProfileScreen extends ConsumerStatefulWidget`
  - L28 `const ProfileScreen({super.key})`
  - L31 `ConsumerState<ProfileScreen> createState()`
- L34 `class _ProfileScreenState extends ConsumerState<ProfileScreen>`
  - L39 `String? get _currentUserId`
  - L43 `void initState()`
  - L53 `Future<void> _restoreStats()`
  - L61 `Future<void> _hydrateStats()`
  - L76 `Future<void> _loadStats()`
  - L116 `Widget build(BuildContext context)`
  - L430 `Future<void> _confirmDeleteAccount()`
  - L456 `Future<bool?> _showDeleteAccountDialog({ required String title, required String message, required String actionLabel, })`
  - L469 `Widget _sectionTitle(BuildContext context, String text)`
  - L482 `Widget _divider(BuildContext context)`
  - L491 `Widget _statTile( BuildContext context, { required String value, required String label, required Color color, })`
  - L528 `Widget _buildStatsCard(BuildContext context, LibraryStats? stats)`
  - L576 `Widget _actionCard( BuildContext context, { required Color color, required String title, required String subtitle, required Widget trailing, })`

### lib/screens/reel_detail/reel_detail_loader_screen.dart

- L11 `class ReelDetailLoaderScreen extends ConsumerStatefulWidget`
  - L12 `const ReelDetailLoaderScreen({ super.key, required this.reelId, this.collectionUrl, })`
  - L25 `ConsumerState<ReelDetailLoaderScreen> createState()`
- L29 `class _ReelDetailLoaderScreenState extends ConsumerState<ReelDetailLoaderScreen>`
  - L34 `void initState()`
  - L39 `void _load()`
  - L45 `void _retry()`
  - L50 `Widget build(BuildContext context)`

### lib/screens/reel_detail/reel_detail_screen.dart

- L30 `class _ShareLocationLink`
  - L34 `const _ShareLocationLink(this.label, this.url)`
- L37 `const String _appStoreUrl = appStoreUrl`
- L38 `const String _playStoreUrl = playStoreUrl`
- L42 `final RegExp _pinterestHostRegex = RegExp`
- L46 `Uri? locationMapsUri(Location loc)`
- L57 `String? _firstNonEmpty(List<String?> values)`
- L67 `class ReelDetailScreen extends ConsumerStatefulWidget`
  - L87 `const ReelDetailScreen({ super.key, required this.reel, this.readOnly = false, this.collectionUrl, this.refreshOnOpen = true, })`
  - L96 `ConsumerState<ReelDetailScreen> createState()`
- L99 `class _ReelDetailScreenState extends ConsumerState<ReelDetailScreen>`
  - L107 `Reel get reel`
  - L108 `String get _savedItemNoun`
  - L121 `String get _untitledLabel`
  - L122 `String get _openSourceLabel`
  - L123 `String get _openSourceErrorLabel`
  - L124 `String get _openSourceNoun`
  - L139 `String? get _sourcePlatform`
  - L156 `bool get _isShortsSource`
  - L162 `bool get _isInstagramPostSource`
  - L178 `Iterable<Uri> get _sourceUris sync*`
  - L192 `bool _hasSourceUri(bool Function(Uri uri) test)`
  - L194 `bool _isYoutubeUri(Uri uri)`
  - L202 `bool _isTikTokUri(Uri uri)`
  - L205 `bool _isYoutubeShortsUri(Uri uri)`
  - L211 `bool _isInstagramUri(Uri uri)`
  - L216 `bool _isXUri(Uri uri)`
  - L227 `bool _isPinterestUri(Uri uri)`
  - L232 `bool _isRedditUri(Uri uri)`
  - L237 `bool _isLinkedInUri(Uri uri)`
  - L240 `bool _isHostOrSubdomainOf(String host, String domain)`
  - L243 `bool _isInstagramPostUri(Uri uri)`
  - L249 `bool _isInstagramReelUri(Uri uri)`
  - L255 `Color get _detailTextColor`
  - L260 `void initState()`
  - L272 `Widget build(BuildContext context)`
  - L846 `Color _contrastText(Color bg)`
  - L850 `Widget _sectionTitle(String title)`
  - L873 `Widget _section(String title, String body)`
  - L892 `Widget _buildLockedHistoryState(BuildContext context)`
  - L957 `Future<void> _shareReel()`
  - L1017 `String get _shareTitle`
  - L1024 `String _shareText(String? reelUrl)`
  - L1064 `List<_ShareLocationLink> _shareLocationLinks()`
  - L1080 `String _shareLocationLabel(Location location)`
  - L1089 `String? get _shareReelUrl`
  - L1104 `Widget _shareButton(AppLayout layout, {required EdgeInsetsGeometry margin})`
  - L1148 `Future<void> _confirmDelete(BuildContext context)`
  - L1193 `T? _maybeRead<T>(ProviderListenable<T> provider)`
  - L1201 `Uri? _locationMapsUri(Location loc)`
  - L1205 `Future<void> _openLocation(Uri uri)`
  - L1211 `Future<void> _openReel()`
  - L1225 `Uri? get _openReelUrl`
  - L1240 `Uri? _externalUri(String rawUrl)`
  - L1253 `void _showOpenReelError()`
  - L1268 `Future<void> _refreshReel()`

### lib/screens/setup_required/setup_required_screen.dart

- L8 `class SetupRequiredScreen extends StatelessWidget`
  - L9 `const SetupRequiredScreen({super.key})`
  - L12 `Widget build(BuildContext context)`

### lib/screens/splash/splash_screen.dart

- L7 `class SplashScreen extends StatelessWidget`
  - L8 `const SplashScreen({super.key})`
  - L11 `Widget build(BuildContext context)`

### lib/screens/update_required/update_required_screen.dart

- L16 `class UpdateRequiredScreen extends StatelessWidget`
  - L17 `const UpdateRequiredScreen({super.key, required this.requirement})`
  - L21 `bool get _isHard`
  - L23 `Future<void> _openStore()`
  - L39 `Widget build(BuildContext context)`

### lib/services/analytics/analytics_event.dart

- L12 `enum AnalyticsEvent`
  - L41 `const AnalyticsEvent(this.wireName)`

### lib/services/analytics/analytics_service.dart

- L13 `class AnalyticsService`
  - L14 `AnalyticsService._()`
  - L28 `static void installErrorHandlers()`
  - L48 `static void markReady()`
  - L50 `static Future<void> log( AnalyticsEvent event, { Map<String, Object>? parameters, })`
  - L66 `static Future<void> recordError(Object error, StackTrace? stack)`

### lib/services/app_update_service.dart

- L5 `class AppUpdateService`
  - L6 `AppUpdateService._()`
  - L8 `static Future<void> checkForImmediateUpdate()`

### lib/services/auth/auth_service.dart

- L13 `class AuthService`
  - L14 `AuthService(this._profileService)`
  - L18 `Session? get currentSession`
  - L19 `User? get currentUser`
  - L24 `Stream<AuthState> get authStateChanges`
  - L32 `static void handleAuthStreamError(Object error, StackTrace stack)`
  - L37 `Future<AuthResponse> signInWithEmail({ required String email, required String password, })`
  - L47 `Future<AuthResponse> signUpWithEmail({ required String email, required String password, String? fullName, })`
  - L63 `Future<void> signInWithGoogle()`
  - L71 `Future<AuthResponse> signInWithApple()`
  - L113 `Future<void> signOut()`
  - L117 `Future<void> ensureProfile()`
  - L136 `String? _readString(Map<String, dynamic>? source, List<String> keys)`
  - L149 `String? _appleFullName(AuthorizationCredentialAppleID credential)`
  - L159 `String _sha256(String input)`

### lib/services/auth/profile_service.dart

- L3 `class ProfileService`
  - L4 `Future<void> upsertProfile({ required String id, String? email, String? fullName, String? avatarUrl, })`

### lib/services/auth/supabase_client.dart

- L3 `SupabaseClient get supabase`

### lib/services/cache/content_cache.dart

- L12 `class ContentCacheKeys`
  - L13 `const ContentCacheKeys._()`
  - L24 `static String collectionDetail(String id)`
- L50 `class ContentCache`
  - L51 `ContentCache._({ String? Function()? userIdProvider, Future<Directory> Function()? directoryLoader, })`
  - L61 `factory ContentCache.forTesting({ required Directory directory, required String? Function() userIdProvider, })`
  - L93 `bool get _isSupported`
  - L95 `String? get _currentUserId`
  - L97 `static String? _signedInUserId()`
  - L107 `Duration _maxAgeFor(String key)`
  - L112 `Future<Map<String, dynamic>?> read(String key)`
  - L152 `Future<void> write( String key, Map<String, dynamic> payload, { String? expectedUserId, })`
  - L179 `Future<void> _write( String key, { required String userId, required Map<String, dynamic> payload, })`
  - L202 `Future<void> invalidate(String key)`
  - L220 `Future<void> invalidateContent()`
  - L225 `Future<void> clear()`
  - L240 `Future<File?> _fileFor(String key)`
  - L256 `Future<Directory> _directory()`
  - L270 `static Future<Directory> _createDirectory()`

### lib/services/device_metadata_service.dart

- L6 `class DeviceMetadata`
  - L7 `const DeviceMetadata({ required this.appVersion, required this.appBuild, required this.timezone, required this.locale, })`
- L20 `class DeviceMetadataService`
  - L21 `const DeviceMetadataService()`
  - L27 `Future<DeviceMetadata> load()`
  - L54 `String _value(dynamic value)`

### lib/services/how_to_guide_service.dart

- L12 `class HowToGuideService`
  - L13 `HowToGuideService._()`
  - L19 `Future<void> markGuidePending()`
  - L38 `Future<bool> takePendingGuide({ required Future<bool> Function() hasExistingSaves, })`

### lib/services/location/location_service.dart

- L3 `enum LocationPermissionState`
- L5 `class LocationService`
  - L6 `LocationService._()`
  - L10 `Future<bool> requestPermission()`
  - L23 `Future<LocationPermissionState> getPermissionState()`
  - L38 `Future<Position?> getCurrentOrLastKnownLocation({ bool requestPermissionIfNeeded = true, })`
  - L59 `Future<void> warmUpLocation()`
  - L63 `Future<bool> openAppSettings()`
  - L67 `Future<bool> _hasLocationPermission()`

### lib/services/notifications/notification_service.dart

- L14 `Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message)`
- L23 `bool get _supportsNativeFirebaseMessaging`
- L28 `bool get _usesSystemForegroundPresentation`
- L31 `enum NotificationPermissionState`
- L33 `class NotificationService`
  - L34 `NotificationService._()`
  - L56 `bool get isFirebaseConfigured`
  - L57 `Stream<AppNotification> get onReelReady`
  - L58 `Stream<OpenedAppNotification> get onNotificationOpened`
  - L61 `Future<void> initialize({bool requestPermissions = true})`
  - L80 `Future<void> _initializeOnce()`
  - L149 `void _handleForegroundMessage(RemoteMessage message)`
  - L166 `void _handleLocalNotificationResponse(NotificationResponse response)`
  - L175 `void _dispatchNotificationOpen(OpenedAppNotification opened)`
  - L183 `List<OpenedAppNotification> consumePendingNotificationOpens()`
  - L189 `Future<NotificationSettings?> requestUserPermission()`
  - L214 `Future<NotificationPermissionState?> getLastKnownPermissionState()`
  - L230 `Future<NotificationPermissionState> getPermissionState()`
  - L265 `Future<String?> getFcmToken({ Duration apnsTimeout = const Duration(seconds: 5), })`
  - L293 `Future<String?> getCurrentFcmToken()`
  - L297 `void rememberFcmToken(String token)`
  - L301 `Stream<String> get onTokenRefresh`
  - L308 `Future<void> showMessageNotification(AppNotification notification)`
  - L327 `String get currentPlatform`
  - L335 `bool _shouldPresentForegroundNotification(AppNotification notification)`
  - L354 `bool _shouldShowLocalForegroundNotification(RemoteMessage message)`
  - L358 `NotificationPermissionState _mapAuthorizationStatus( AuthorizationStatus status, )`
  - L368 `Future<void> _persistPermissionState( NotificationPermissionState state, )`
  - L380 `Future<String?> _waitForApnsToken({required Duration timeout})`
  - L397 `int _notificationIdFor(AppNotification notification)`
  - L410 `String? _nonEmpty(String? value)`

### lib/services/notifications/notification_tap_handler.dart

- L7 `typedef NotificationAction = Future<void> Function()`
- L8 `typedef ReelNotificationAction = Future<void> Function(String reelId)`
- L9 `typedef CollectionNotificationAction = Future<void> Function(String collectionId)`
- L11 `typedef AnnouncementNotificationAction = Future<void> Function(AppNotification notification)`
- L13 `typedef NotificationOpenTracker = Future<void> Function(String notificationId)`
- L15 `class NotificationTapHandler`
  - L18 `Future<bool> handle( OpenedAppNotification opened, { required NotificationOpenTracker trackOpen, required ReelNotificationAction openReel, required AnnouncementNotificationAction openAnnouncement, required NotificationAction openHome, required NotificationAction openMap, required NotificationAction openDiscover, required NotificationAction openProfile, required NotificationAction openAppUpdate, required CollectionNotificationAction openCollection, })`
  - L89 `void clear()`

### lib/services/remote_config/remote_config_service.dart

- L15 `class RemoteConfigService`
  - L16 `RemoteConfigService({ required String url, http.Client? client, this.timeout = const Duration(seconds: 5), this.refreshInterval = const Duration(hours: 1), DateTime Function()? clock, })`
  - L36 `bool get isEnabled`
  - L38 `Future<RemoteConfig?> readCached()`
  - L55 `Future<RemoteConfig?> fetchIfDue()`
  - L88 `Future<bool> wasAnnouncementShown(String id)`
  - L101 `Future<void> markAnnouncementShown(String id)`
  - L112 `RemoteConfig _decode(String raw)`

### lib/services/sharing/collection_link.dart

- L8 `class CollectionLink`
  - L9 `const CollectionLink._(this.token, {required this.isInvite, this.url})`
  - L20 `static CollectionLink? parse(Uri uri)`
  - L38 `static List<String> _segments(Uri uri)`
  - L47 `static CollectionLink? _of( String token, { required bool isInvite, String? url, })`

### lib/services/sharing/collection_link_cache.dart

- L16 `class CollectionLinkCache`
  - L17 `CollectionLinkCache._()`
  - L23 `String _keyFor(String collectionId)`
  - L25 `Future<String?> read(String collectionId)`
  - L37 `Future<void> write(String collectionId, String url)`
  - L49 `Future<void> clear(String collectionId)`

### lib/services/sharing/collection_share_message.dart

- L6 `class CollectionShareMessage`
  - L7 `const CollectionShareMessage({required this.subject, required this.body})`
  - L20 `factory CollectionShareMessage.forLink({ required String collectionName, required String url, int itemCount = 0, })`
  - L40 `factory CollectionShareMessage.forInvite({ required String collectionName, required String url, required String role, })`
  - L59 `static String _cleanName(String value)`

### lib/services/sharing/linkrunner_service.dart

- L21 `class LinkrunnerService`
  - L22 `LinkrunnerService._()`
  - L29 `bool get isInitialised`
  - L31 `Future<void> init()`
  - L52 `Future<Uri> resolve(Uri incoming)`
  - L70 `Future<Uri?> deferredLink()`

### lib/services/sharing/pending_deep_link.dart

- L16 `class PendingDeepLink`
  - L17 `PendingDeepLink._()`
  - L22 `static Future<void> capture()`
  - L32 `static Uri? get pendingUri`
  - L39 `static CollectionLink? get pendingCollectionLink`
  - L48 `static CollectionLink? takeCollectionLink()`
  - L56 `static Uri? take()`

### lib/services/sharing/push_registration_service.dart

- L6 `class PushRegistrationService`
  - L7 `PushRegistrationService({ required NotificationService notificationService, required SharingHttp sharingHttp, DeviceMetadataService deviceMetadataService = const DeviceMetadataService(), })`
  - L19 `Future<String?> register({ required String userId, String? candidateToken, Duration apnsTimeout = const Duration(seconds: 5), })`
  - L50 `Future<void> unregisterCurrentDevice()`
  - L57 `Future<void> recordNotificationOpened(String notificationId)`

### lib/services/sharing/reel_share_service.dart

- L3 `class ReelShareService`
  - L4 `ReelShareService._()`
  - L10 `static Future<void> shareReelCard({ required Uint8List pngBytes, required String text, required String subject, })`
  - L24 `static Future<void> shareText({ required String text, required String subject, })`

### lib/services/sharing/share_flow_analytics_service.dart

- L5 `class ShareFlowAnalyticsSnapshot`
  - L6 `const ShareFlowAnalyticsSnapshot({ required this.detectedCount, required this.duplicateCount, required this.startedCount, required this.succeededCount, required this.failedCount, this.lastSharedUrl, this.lastFailure, this.lastEventAt, })`
  - L26 `Map<String, dynamic> toJson()`
  - L38 `factory ShareFlowAnalyticsSnapshot.fromJson(Map<String, dynamic> json)`
  - L54 `ShareFlowAnalyticsSnapshot copyWith({ int? detectedCount, int? duplicateCount, int? startedCount, int? succeededCount, int? failedCount, String? lastSharedUrl, String? lastFailure, DateTime? lastEventAt, })`
- L77 `class ShareFlowAnalyticsService`
  - L80 `Future<ShareFlowAnalyticsSnapshot> loadSnapshot()`
  - L108 `Future<void> clear()`
  - L113 `Future<void> recordShareDetected(String url)`
  - L123 `Future<void> recordDuplicateShareSkipped(String url)`
  - L133 `Future<void> recordEnqueueStarted(String url)`
  - L143 `Future<void> recordEnqueueSucceeded(String url)`
  - L154 `Future<void> recordEnqueueFailed(String url, Object error)`
  - L165 `Future<void> _update( ShareFlowAnalyticsSnapshot Function(ShareFlowAnalyticsSnapshot current) transform, )`

### lib/services/sharing/share_handoff_service.dart

- L11 `class ShareHandoffService`
  - L12 `ShareHandoffService._()`
  - L35 `bool get _supportsNativeHandoff`
  - L40 `Future<String?> getShareToken()`
  - L46 `Future<void> setShareToken(String? token)`
  - L59 `Future<void> syncAuthenticatedUser(String userId, String? accessToken)`
  - L103 `Future<bool> isCollectionPickerEnabled()`
  - L117 `Future<void> setCollectionPickerEnabled( bool enabled, List<CollectionSummary> collections, { Future<Map<String, String>> Function({ required String directory, required List<CollectionSummary> collections, })? renderTiles, })`
  - L147 `Future<void> syncCollections( List<CollectionSummary> collections, { Future<Map<String, String>> Function({ required String directory, required List<CollectionSummary> collections, })? renderTiles, })`
  - L230 `Future<void> syncPushToken({ required String token, required String platform, })`
  - L247 `Future<void> clearPushToken()`
  - L254 `Future<void> clear()`
  - L281 `Future<String?> drainPendingShares()`
  - L294 `Future<String?> _shareAssetsDirectory()`
  - L306 `Future<void> _syncNative()`

### lib/services/sharing/shared_collection_prefetch.dart

- L14 `class SharedCollectionPrefetch`
  - L15 `SharedCollectionPrefetch._()`
  - L21 `static void start(String token, Future<CollectionDetail> Function() load)`
  - L32 `static Future<CollectionDetail>? take(String token)`

### lib/utils/app_logger.dart

- L3 `class AppLogger`
  - L4 `AppLogger._()`
  - L6 `static void debug(Object? message)`
  - L10 `static void info(Object? message)`
  - L14 `static void error(Object? message)`

### lib/utils/app_store_links.dart

- L4 `const String appStoreUrl = 'https://apps.apple.com/us/app/reelpin/id6777110022'`
- L5 `const String playStoreUrl = `
- L8 `String get storeListingUrl`
- L11 `Future<bool> launchStoreListing()`

### lib/utils/auth_error_message.dart

- L7 `enum AuthOperation`
- L9 `String authErrorMessage(Object error, {required AuthOperation operation})`
- L85 `bool _isConnectionError(Object error)`

### lib/utils/category_marker_icon.dart

- L10 `Future<BitmapDescriptor> createCategoryMarkerIcon(String category)`
- L20 `Future<Uint8List> createCategoryMarkerPng(String category)`

### lib/utils/error_message.dart

- L7 `String userFacingErrorMessage( Object error, { String fallbackMessage = 'Something went wrong. Please try again.', })`
- L30 `bool _looksTechnicalError(String message)`
- L45 `String _technicalErrorFallback(ApiException error, String fallbackMessage)`

### lib/utils/location_maps_uri.dart

- L3 `Uri? locationMapsSearchUri({ String? name, String? displayLabel, String? address, String? backendUrl, double? latitude, double? longitude, })`
- L31 `Uri? _externalLocationUri(String? rawUrl)`
- L44 `String? _firstNonEmpty(List<String?> values)`

### lib/view_models/collections_view_model.dart

- L14 `class CollectionsViewModel extends ChangeNotifier`
  - L15 `CollectionsViewModel(this._api, {ContentCache? cache, this.renderShareTiles})`
  - L57 `List<CollectionSummary> get collections`
  - L58 `bool get isLoadingCollections`
  - L59 `String? get collectionsError`
  - L60 `bool isLoadingDetailFor(String id)`
  - L61 `String? detailErrorFor(String id)`
  - L62 `bool get isMutating`
  - L64 `void reset()`
  - L84 `Future<void> get detailWarmUp`
  - L86 `CollectionDetail? detailFor(String id)`
  - L90 `bool isDetailPlaceholder(String id)`
  - L99 `void seedDetailFromSummary(String id)`
  - L116 `Future<void> hydrateFromCache()`
  - L143 `Future<void> loadCollections({bool forceRefresh = false})`
  - L154 `Future<void> _loadCollections()`
  - L192 `Future<void> hydrateDetailFromCache(String id)`
  - L211 `bool _hasRealDetail(String id)`
  - L221 `Future<void> _warmDetails(List<CollectionSummary> summaries)`
  - L233 `Future<void> _warmDetail(CollectionSummary summary, int generation)`
  - L246 `Future<void> loadCollectionDetail(String id, {bool forceRefresh = false})`
  - L258 `Future<void> _loadCollectionDetail(String id)`
  - L289 `Future<void> loadMore(String id)`
  - L311 `Future<CollectionSummary?> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L335 `Future<void> updateCollection({ required String collectionId, String? name, String? description, })`
  - L355 `Future<void> deleteCollection(String id)`
  - L372 `Future<void> addReelsToCollections({ required List<String> collectionIds, required List<String> reelIds, })`
  - L399 `Future<void> removeReel({ required String collectionId, required String reelId, })`
  - L424 `Future<CollectionLink?> enableLink(String id)`
  - L436 `Future<void> disableLink(String id)`
  - L444 `Future<CollectionMembers?> loadMembers(String id)`
  - L454 `Future<void> removeMember({ required String collectionId, required String memberUserId, })`
  - L466 `Future<CollectionInvite?> createInvite({ required String collectionId, required String role, })`
  - L483 `Future<void> leave(String id)`
  - L493 `Future<CollectionSummary?> acceptInvite(String token)`
  - L505 `Future<void> _mutate(Future<void> Function(int generation) action)`
  - L523 `Future<void> _syncShareTargets()`
  - L530 `void _upsert(CollectionSummary collection)`
  - L539 `void _setVisibility(String id, String visibility)`

### lib/view_models/discover_view_model.dart

- L13 `class DiscoverViewModel extends ChangeNotifier`
  - L14 `DiscoverViewModel(this._repository, {ContentCache? cache})`
  - L35 `DiscoverResponse? get discover`
  - L36 `ReelPage? get categoryReelsPage`
  - L37 `bool get isLoadingDiscover`
  - L38 `bool get isLoadingCategoryReels`
  - L39 `String? get discoverError`
  - L40 `String? get categoryReelsError`
  - L41 `String? get selectedSavedDate`
  - L42 `String? get selectedSavedDateLabel`
  - L43 `String? get selectedCategory`
  - L44 `String? get selectedCategoryLabel`
  - L45 `int? get selectedCategoryExpectedCount`
  - L49 `Future<void> hydrateFromCache()`
  - L72 `Future<void> loadDiscover({bool forceRefresh = false})`
  - L105 `Future<void> selectSavedDate(SavedDateOption option)`
  - L113 `Future<void> clearDateFilter()`
  - L121 `Future<void> openCategory(DiscoverCategory category)`
  - L163 `void clearCategorySelection()`
  - L175 `void clearTransientSelection()`
  - L197 `void removeReel(String reelId)`
  - L266 `void reset()`
  - L284 `void _clearCategorySelectionInState()`
  - L293 `String? _labelForSavedDate(DiscoverResponse response, String? savedDate)`
  - L305 `List<Reel> _withoutReel(List<Reel> reels, String reelId)`

### lib/view_models/entitlements_view_model.dart

- L18 `class EntitlementsViewModel extends ChangeNotifier`
  - L19 `EntitlementsViewModel( this._accountHttp, this._authService, this._repository, this._homeViewModel, this._mapViewModel, this._reelFiltersViewModel, this._discoverViewModel, this._searchViewModel, { ContentCache? cache, })`
  - L48 `EntitlementsResponse? get response`
  - L49 `UserEntitlement? get entitlement`
  - L50 `bool get isLoading`
  - L51 `String? get error`
  - L52 `bool get hasEntitlement`
  - L57 `Future<void> hydrateFromCache()`
  - L74 `Future<void> refresh({bool reloadContent = false})`
  - L96 `Future<void> _refresh({required bool reloadContent})`
  - L171 `void reset()`

### lib/view_models/home_view_model.dart

- L12 `class HomeViewModel extends ChangeNotifier`
  - L16 `HomeViewModel(this._repository, {void Function(String reelId)? onReelDeleted})`
  - L36 `List<Reel> get reels`
  - L37 `bool get isLoading`
  - L38 `bool get isLoadingMore`
  - L39 `bool get hasMoreReels`
  - L40 `String? get error`
  - L41 `String? get selectedPlatform`
  - L42 `String? get selectedCategory`
  - L43 `String? get selectedSubcategory`
  - L44 `bool get hasActiveFilters`
  - L48 `List<Reel> get allReels`
  - L55 `bool get hasSettledFirstLoad`
  - L57 `bool get isEmpty`
  - L59 `void _syncFromRepository()`
  - L64 `Future<void> loadReels({bool forceRefresh = false})`
  - L106 `Future<void> loadMoreReels()`
  - L135 `void filterByCategory(String? category)`
  - L140 `void applyFilters({String? platform, String? category, String? subcategory})`
  - L148 `void clearFilters()`
  - L156 `void reset()`
  - L170 `Future<Reel> processReel( String url, { void Function(ProcessingJob job)? onJobUpdate, })`
  - L194 `Future<ProcessingJob> enqueueReelProcessing( String url, { List<String> collectionIds = const [], })`
  - L216 `Future<void> deleteReel(String reelId)`
  - L228 `void removeReel(String reelId)`
  - L232 `void _removeReelLocally(String reelId)`
  - L237 `void upsertProcessedReel(Reel reel)`
  - L242 `void dispose()`

### lib/view_models/map_view_model.dart

- L15 `class MapViewModel extends ChangeNotifier`
  - L20 `MapViewModel(this._mapHttp, this._accountHttp, {ContentCache? cache})`
  - L63 `List<MapItem> get mapItems`
  - L64 `bool get isLoading`
  - L65 `bool get isLoadingMore`
  - L66 `bool get hasMoreReels`
  - L67 `String? get error`
  - L68 `String? get selectedCategory`
  - L69 `MapItem? get selectedMapItem`
  - L74 `int? get totalPinnedLocations`
  - L78 `int? get headerPinCount`
  - L82 `bool get isTruncated`
  - L86 `bool get showsEmptyLibrary`
  - L94 `bool get showsEmptyViewportHint`
  - L100 `String get emptyViewportHint`
  - L106 `List<MapPlaceSearchResult> get placeSearchResults`
  - L108 `bool get isSearchingPlaces`
  - L109 `bool get isSavingMapPin`
  - L110 `bool get isRemovingMapPin`
  - L111 `String? get placeSearchError`
  - L112 `String? get mapPinActionError`
  - L113 `String get lastPlaceQuery`
  - L116 `List<Reel> get reelsWithLocations`
  - L120 `Reel? get selectedReel`
  - L123 `Location? get selectedLocation`
  - L127 `Future<void> hydrateFromCache()`
  - L155 `Future<void> loadMapReels({bool forceRefresh = false})`
  - L201 `void updateViewport(MapBounds bounds)`
  - L212 `Future<void> _loadViewportPins()`
  - L225 `Future<void> refreshOnOpen()`
  - L231 `Future<void> loadLibraryStats()`
  - L250 `Future<List<MapItem>> nearbyMapItems( double latitude, double longitude, )`
  - L268 `Future<void> recenterOnUser({ required double latitude, required double longitude, required void Function() moveToUser, required void Function(List<MapItem> nearby) fitNearby, })`
  - L284 `void userMovedCamera()`
  - L288 `Future<void> loadMoreReels()`
  - L290 `void filterByCategory(String? category)`
  - L298 `void selectMapItem(MapItem? item)`
  - L303 `void selectReel(Reel? reel, {Location? location})`
  - L311 `void reset()`
  - L339 `Future<void> searchMapPlaces(String query)`
  - L387 `Future<MapItem?> pinPlace(MapPlaceSearchResult result)`
  - L426 `Future<bool> removeMapItem(MapItem item)`
  - L467 `void clearPlaceSearch()`
  - L478 `void _upsertMapItem(MapItem item)`
  - L491 `void upsertProcessedReel(Reel reel)`
  - L495 `void removeReel(String reelId)`
  - L507 `void dispose()`

### lib/view_models/processing_jobs_view_model.dart

- L16 `class ProcessingJobsViewModel extends ChangeNotifier`
  - L17 `ProcessingJobsViewModel(this._repository, {this.onJobsFinished})`
  - L60 `List<ProcessingJob> get jobs`
  - L61 `bool get hasJobs`
  - L65 `bool isSettling(String jobId)`
  - L70 `List<ProcessingJob> jobsForCollection(String collectionId)`
  - L83 `void trackEnqueued( ProcessingJob job, { List<String> collectionIds = const [], })`
  - L106 `Future<void> refresh()`
  - L123 `Future<void> _applyServerJobs( List<ProcessingJob> latest, int generation, )`
  - L195 `bool _isStillShown(String jobId, Set<String> activeIds)`
  - L208 `bool _isAbandoned(ProcessingJob job)`
  - L216 `void _syncTimer()`
  - L236 `Duration _pollInterval()`
  - L248 `void setForeground(bool isForeground)`
  - L254 `void reset()`
  - L267 `void dispose()`

### lib/view_models/reel_detail_view_model.dart

- L12 `class ReelDetailViewModel extends ChangeNotifier`
  - L15 `ReelDetailViewModel(this._repository)`
  - L22 `Reel? get reel`
  - L23 `bool get isLoading`
  - L24 `String? get error`
  - L25 `bool get isTranscriptExpanded`
  - L28 `Future<void> loadReel(String reelId)`
  - L47 `void setReel(Reel reel)`
  - L53 `void toggleTranscript()`
  - L59 `Future<bool> deleteReel()`

### lib/view_models/reel_filters_view_model.dart

- L15 `class ReelFiltersViewModel extends ChangeNotifier`
  - L16 `ReelFiltersViewModel(this._repository, {ContentCache? cache})`
  - L27 `ReelFiltersResponse? get response`
  - L29 `List<ReelPlatformGroup> get platforms`
  - L34 `List<ReelCategoryGroup> get categoryGroups`
  - L37 `List<String> get categories`
  - L40 `int get totalCount`
  - L41 `int get selectedPreviewCount`
  - L42 `String? get topPlatform`
  - L43 `bool get isLoading`
  - L44 `String? get error`
  - L45 `bool get hasPlatforms`
  - L46 `bool get hasGroups`
  - L48 `ReelPlatformGroup? platformNamed(String? platform)`
  - L53 `List<ReelCategoryGroup> categoriesFor(String? platform)`
  - L60 `int previewCountFor({ String? platform, String? category, String? subcategory, })`
  - L89 `void reset()`
  - L99 `Future<void> hydrateFromCache()`
  - L119 `Future<void> loadFilters({ bool forceRefresh = false, String? platform, String? category, String? subcategory, })`

### lib/view_models/remote_config_view_model.dart

- L17 `class RemoteConfigViewModel extends ChangeNotifier`
  - L18 `RemoteConfigViewModel( this._service, { Future<int?> Function()? loadBuildNumber, })`
  - L34 `bool get hasLoadedLocalCopy`
  - L38 `Future<void> get localCopyLoaded`
  - L40 `bool get paywallVisible`
  - L44 `UpdateRequirement? get requiredUpdate`
  - L53 `UpdateRequirement? get blockingUpdate`
  - L58 `Future<void> start()`
  - L78 `Future<void> refresh()`
  - L85 `Future<void> _refresh()`
  - L93 `UpdateRequirement? takeUpdateNudge()`
  - L106 `Future<FeatureAnnouncement?> takeAnnouncement()`
  - L124 `Future<void> markAnnouncementShown(FeatureAnnouncement announcement)`
  - L129 `static Future<int?> _nativeBuildNumber()`

### lib/view_models/search_view_model.dart

- L13 `class SearchViewModel extends ChangeNotifier`
  - L18 `SearchViewModel(this._repository)`
  - L30 `List<SearchResult> get results`
  - L31 `int get total`
  - L32 `bool get isSearching`
  - L33 `String? get error`
  - L34 `String? get selectedCategory`
  - L35 `String? get selectedSubcategory`
  - L36 `String get lastQuery`
  - L37 `bool get hasResults`
  - L38 `SearchMode? get backendSearchMode`
  - L39 `bool get isQueryTooShort`
  - L43 `Future<void> search(String query)`
  - L102 `void updateFilters({String? category, String? subcategory})`
  - L112 `void clearFilters()`
  - L123 `void clear()`
  - L135 `void removeReel(String reelId)`

### lib/view_models/session_view_model.dart

- L17 `class SessionViewModel extends ChangeNotifier`
  - L18 `SessionViewModel( this._authService, this._accountHttpFactory, this._sharingHttpFactory, { Future<void> Function()? unregisterPushToken, })`
  - L53 `Session? get session`
  - L54 `User? get currentUser`
  - L56 `bool get isAuthenticated`
  - L57 `bool get isSigningIn`
  - L58 `bool get isSigningOut`
  - L59 `bool get isDeletingAccount`
  - L60 `bool get isBusy`
  - L61 `String? get error`
  - L62 `String? get statusMessage`
  - L64 `String get email`
  - L66 `String get displayName`
  - L86 `String? get avatarUrl`
  - L89 `String get initials`
  - L105 `Future<void> signInWithGoogle()`
  - L130 `Future<void> signInWithApple()`
  - L156 `Future<void> signOut()`
  - L189 `Future<bool> deleteAccount()`
  - L222 `Future<bool> signInWithEmail({ required String email, required String password, })`
  - L253 `Future<bool> signUpWithEmail({ required String email, required String password, String? fullName, })`
  - L296 `void clearError()`
  - L302 `void clearStatusMessage()`
  - L315 `Future<void> _bootstrap()`
  - L320 `Future<void> _syncProfileSilently()`
  - L330 `Future<void> _syncShareHandoffState()`
  - L350 `Future<void> _ensureShareToken(String userId, int generation)`
  - L368 `String? _readString(Map<String, dynamic>? source, List<String> keys)`
  - L381 `String _normalizeError(Object error)`
  - L392 `bool _looksTechnicalError(String message)`
  - L405 `void dispose()`

### lib/view_models/theme_view_model.dart

- L10 `class ThemeViewModel extends ChangeNotifier`
  - L11 `ThemeViewModel({bool isDarkMode = false})`
  - L20 `static Future<ThemeViewModel> restored()`
  - L29 `bool get isDarkMode`
  - L31 `ThemeMode get themeMode`
  - L33 `IconData get themeIcon`
  - L35 `String get themeLabel`
  - L37 `String get nextThemeLabel`
  - L42 `Future<void> loadPreference()`
  - L48 `Future<void> toggleTheme()`
  - L52 `Future<void> setDarkMode(bool value)`

### lib/view_models/user_state_coordinator.dart

- L16 `class UserStateCoordinator`
  - L17 `UserStateCoordinator({ required CollectionsViewModel collectionsViewModel, required SearchViewModel searchViewModel, required ReelFiltersViewModel reelFiltersViewModel, required MapViewModel mapViewModel, required HomeViewModel homeViewModel, required DiscoverViewModel discoverViewModel, required ReelRepository reelRepository, required EntitlementsViewModel entitlementsViewModel, required ProcessingJobsViewModel processingJobsViewModel, })`
  - L54 `Future<void> hydrate()`
  - L63 `Future<void> _hydrate()`
  - L81 `void reset()`

### play-assets/phone/generate_store_screenshots.py

- L107 `def hex_to_rgb(value)`
- L112 `def fill_background(image, bg_hex)`
- L116 `def tracking_text_width(draw, text, font, tracking)`
- L126 `def draw_tracking_text(draw, position, text, font, fill, tracking)`
- L137 `def draw_brutal_box(base, box, fill, border_width, shadow_offset, outline=(0, 0, 0, 255), shadow_fill=(0, 0, 0, 255))`
- L153 `def add_background_shapes(base, panel_hex, accent_hex)`
- L157 `def load_font(path, size)`
- L161 `def wrap_text(draw, text, font, max_width)`
- L176 `def fit_text(draw, text, font_path, max_size, min_size, max_width, max_lines, spacing_ratio)`
- L191 `def add_brand_header(base, accent_hex, label_text)`
- L249 `def add_copy(base, headline, body, accent_hex)`
- L319 `def add_screenshot(base, screenshot_path, accent_hex, min_top)`
- L358 `def render_screen(spec, output_dir, canvas_size)`
- L375 `def render_contact_sheet(output_dir)`
- L407 `def main()`

### test/app_entry_test.dart

- L30 `void main()`
- L326 `RemoteConfigViewModel _remoteConfig(http.Client client)`
- L336 `Future<void> _pumpPageTransition(WidgetTester tester)`
- L341 `void _sizeView(WidgetTester tester)`
- L350 `Future<void> _capturePendingLink(WidgetTester tester, String url)`
- L366 `Widget _appEntry({ MockCollectionsHttp? collectionsHttp, RemoteConfigViewModel? remoteConfig, User? user, })`
- L388 `Future<void> _pumpAppEntry(WidgetTester tester)`
- L404 `class _FakeSessionViewModel extends SessionViewModel`
  - L405 `_FakeSessionViewModel(AuthService authService)`
- L413 `const _signedInUser = User`
- L421 `class _FakeAuthService extends AuthService`
  - L422 `_FakeAuthService({this.user})`
  - L427 `Session? get currentSession`
  - L430 `User? get currentUser`
  - L433 `Stream<AuthState> get authStateChanges`
  - L436 `Future<void> ensureProfile()`
- L439 `class _RecordingCollectionsHttp extends MockCollectionsHttp`
  - L440 `_RecordingCollectionsHttp(this.onFetch)`
  - L445 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`

### test/components/collections/collection_folder_tile_test.dart

- L6 `CollectionSummary _c(String id, String createdAt)`
- L9 `void main()`

### test/components/processing_reel_card_test.dart

- L7 `ProcessingJob _job({int? progress, String? platform})`
- L17 `Future<void> _pumpCard(WidgetTester tester, ProcessingJob job)`
- L38 `void main()`

### test/constants/source_platforms_test.dart

- L4 `void main()`

### test/data_models/account/user_entitlement_test.dart

- L6 `EntitlementsResponse _response({ int savedReels = 3, int? savedReelsLimit = 25, String plan = 'free', bool isPremium = false, bool restricted = false, })`
- L66 `void main()`

### test/data_models/app_config/remote_config_test.dart

- L6 `void main()`

### test/data_models/collection_models_test.dart

- L5 `void main()`
- L191 `const _itemJson = {`

### test/data_models/map/map_response_test.dart

- L6 `Map<String, dynamic> _pin(Map<String, dynamic> extra)`
- L16 `void main()`

### test/data_models/notifications/app_notification_test.dart

- L6 `void main()`

### test/data_models/reels/processing_job_test.dart

- L5 `void main()`

### test/data_models/reels/reel_filters_test.dart

- L4 `Map<String, dynamic> _response()`
- L72 `void main()`

### test/data_models/reels/reel_test.dart

- L6 `void main()`
- L210 `Map<String, Object?> _reelJson(Map<String, Object?> overrides)`

### test/data_models/sharing/pending_share_test.dart

- L4 `void main()`

### test/env_test.dart

- L6 `void main()`

### test/fixtures/api_v2.dart

- L10 `class ApiV2Fixture`
  - L11 `ApiV2Fixture(String name)`
  - L18 `int get status`
  - L20 `Map<String, dynamic> get body`
  - L22 `http.Response toResponse()`

### test/http/api_client_test.dart

- L18 `final _uuidV4 = RegExp`
- L22 `void main()`
- L1534 `String _tokenFor(String subject, String version)`

### test/http/collections_api_client_test.dart

- L12 `void main()`
- L534 `Map<String, Object?> _error(String code, String message)`
- L543 `const _summaryJson = {`
- L557 `const _itemJson = {`
- L570 `const _detailJson = {`

### test/repositories/reel_repository_cache_test.dart

- L14 `void main()`
- L172 `const _cachedReelJson = <String, dynamic>{`
- L180 `class _PendingApiService extends ApiClient`
  - L181 `_PendingApiService()`
  - L186 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L199 `Future<void> deleteReel(String reelId)`
  - L201 `void complete()`
- L207 `const _liveReel = Reel`
- L224 `class _FakeAuthService extends AuthService`
  - L225 `_FakeAuthService()`
  - L228 `Session? get currentSession`
  - L231 `User? get currentUser`
  - L240 `Stream<AuthState> get authStateChanges`
  - L243 `Future<void> ensureProfile()`

### test/repositories/reel_repository_test.dart

- L16 `void main()`
- L85 `class _FakeApiService extends ApiClient`
  - L86 `_FakeApiService({this.searchResponse})`
  - L95 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L109 `Future<void> deleteReel(String reelId)`
  - L115 `Future<SearchResponse> searchReels( String query, { String userId = 'default-user', String? category, String? subcategory, int limit = 5, http.Client? client, })`
- L133 `class _FakeAuthService extends AuthService`
  - L134 `_FakeAuthService()`
  - L137 `Session? get currentSession`
  - L140 `User? get currentUser`
  - L149 `Stream<AuthState> get authStateChanges`
  - L152 `Future<void> ensureProfile()`
- L155 `class _MutableAuthService extends AuthService`
  - L156 `_MutableAuthService(this.userId)`
  - L161 `Session? get currentSession`
  - L164 `User? get currentUser`
  - L173 `Stream<AuthState> get authStateChanges`
  - L176 `Future<void> ensureProfile()`
- L179 `class _DelayedApiService extends ApiClient`
  - L180 `_DelayedApiService()`
  - L189 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L201 `void complete()`
- L206 `const _reelC = Reel`
- L222 `const _reelA = Reel`
- L239 `const _reelB = Reel`
- L256 `const _emptySearchResponse = SearchResponse`

### test/router_test.dart

- L6 `void main()`

### test/screens/app_shell_tab_index_test.dart

- L4 `void main()`

### test/screens/collections/collection_detail_tabs_test.dart

- L18 `class _FakeApiClient extends ApiClient`
  - L19 `_FakeApiClient()`
- L22 `class _FakeAuthService extends AuthService`
  - L23 `_FakeAuthService()`
  - L26 `Session? get currentSession`
  - L29 `User? get currentUser`
  - L38 `Stream<AuthState> get authStateChanges`
- L41 `void main()`

### test/screens/collections/share_collection_sheet_test.dart

- L15 `void main()`
- L163 `class _FakeCollectionsHttp implements CollectionsHttp`
  - L165 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L185 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L190 `dynamic noSuchMethod(Invocation invocation)`

### test/screens/feature_announcement/feature_announcement_screen_test.dart

- L6 `void main()`

### test/screens/home/home_empty_state_test.dart

- L17 `const _sizes = <String, Size>{`
- L23 `Future<void> _pumpEmptyHome(WidgetTester tester, Size size)`
- L42 `void main()`
- L85 `class _EmptyApiClient extends ApiClient`
  - L86 `_EmptyApiClient()`
  - L89 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
- L102 `class _FakeAuthService extends AuthService`
  - L103 `_FakeAuthService()`
  - L106 `Session? get currentSession`
  - L109 `User? get currentUser`
  - L118 `Stream<AuthState> get authStateChanges`
  - L121 `Future<void> ensureProfile()`

### test/screens/home/home_filter_sheet_test.dart

- L17 `Future<void> _pumpHome(WidgetTester tester)`
- L35 `Future<void> _openSheet(WidgetTester tester)`
- L40 `void main()`
- L198 `class _FakeApiClient extends ApiClient`
  - L199 `_FakeApiClient()`
  - L207 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L235 `Future<ReelFiltersResponse> getReelFilters({ String? userId, String? platform, String? category, String? subcategory, })`
- L245 `const _treeJson = <String, dynamic>{`
- L327 `class _FakeAuthService extends AuthService`
  - L328 `_FakeAuthService()`
  - L331 `Session? get currentSession`
  - L334 `User? get currentUser`
  - L343 `Stream<AuthState> get authStateChanges`
  - L346 `Future<void> ensureProfile()`

### test/screens/home/home_paywall_banner_test.dart

- L21 `const _bannerText = 'FREE ACCOUNT ACCESS'`
- L23 `Future<void> _pumpFreeHome( WidgetTester tester, { required Map<String, dynamic> remoteDocument, })`
- L64 `void main()`
- L80 `class _FreePlanApiClient extends ApiClient`
  - L81 `_FreePlanApiClient()`
  - L84 `Future<EntitlementsResponse> getAccountEntitlements({ required String userId, })`
  - L102 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, int? offset, String? cursor, int limit = 50, String? sort, })`
- L117 `class _FakeAuthService extends AuthService`
  - L118 `_FakeAuthService()`
  - L121 `Session? get currentSession`
  - L124 `User? get currentUser`
  - L133 `Stream<AuthState> get authStateChanges`
  - L136 `Future<void> ensureProfile()`

### test/screens/how_to/how_to_use_screen_test.dart

- L9 `const _sizes = <String, Size>{`
- L17 `Future<void> _pumpGuide( WidgetTester tester, { required Size size, double textScale = 1, TargetPlatform platform = TargetPlatform.android, })`
- L47 `Future<void> _settleTransition(WidgetTester tester)`
- L52 `void main()`

### test/screens/onboarding/onboarding_screen_test.dart

- L10 `const _sizes = <String, Size>{`
- L16 `Future<void> _pumpOnboarding( WidgetTester tester, { required Size size, double textScale = 1, })`
- L47 `void _expectStripFits(WidgetTester tester, Size size)`
- L67 `void main()`

### test/screens/profile/profile_screen_test.dart

- L16 `void main()`
- L63 `const _stats = LibraryStats`
- L71 `class _AccountApi extends ApiClient`
  - L77 `Future<LibraryStats> getLibraryStats()`
- L83 `class _Session extends ChangeNotifier implements SessionViewModel`
  - L86 `void switchUser()`
  - L92 `User? get currentUser`
  - L101 `String get displayName`
  - L103 `String get email`
  - L105 `String get initials`
  - L107 `String? get error`
  - L109 `bool get isBusy`
  - L111 `bool get isSigningOut`
  - L113 `bool get isDeletingAccount`
  - L115 `dynamic noSuchMethod(Invocation invocation)`

### test/screens/reel_detail/locked_history_copy_test.dart

- L21 `const _upgradeLine = 'Upgrade to Pro to open older saves again.'`
- L23 `Future<void> _pumpLockedReel( WidgetTester tester, { required Map<String, dynamic> remoteDocument, })`
- L58 `void main()`
- L79 `const _reel = Reel`
- L96 `class _HistoryLockedApiClient extends ApiClient`
  - L97 `_HistoryLockedApiClient()`
  - L100 `Future<Reel> getReel(String reelId)`
- L109 `class _FakeAuthService extends AuthService`
  - L110 `_FakeAuthService()`
  - L113 `Session? get currentSession`
  - L116 `User? get currentUser`
  - L119 `Stream<AuthState> get authStateChanges`
  - L122 `Future<void> ensureProfile()`

### test/screens/reel_detail/reel_detail_screen_test.dart

- L8 `void main()`

### test/screens/reel_detail/reel_share_card_test.dart

- L7 `void main()`
- L270 `Reel _shareReel({ String contentType = 'reel', String? sourcePlatform, String title = 'A saved reel worth remembering', String summary = 'This reel has a clear summary that should be readable on the share card.', List<String> keyFacts = const [ 'The reel highlights three spots that can be visited in one afternoon.', 'The creator recommends starting early to avoid crowds.', ], List<String> actionableItems = const [ 'Book the first stop before noon.', 'Walk between each stop instead of driving.', ], })`

### test/screens/update_required/update_required_screen_test.dart

- L8 `const _hard = UpdateRequirement`
- L16 `const _soft = UpdateRequirement`
- L18 `void main()`

### test/services/cache/content_cache_test.dart

- L7 `void main()`

### test/services/how_to_guide_service_test.dart

- L6 `void main()`

### test/services/notifications/notification_tap_handler_test.dart

- L6 `void main()`
- L287 `final _collectionNotification = AppNotification.fromData`
- L299 `AppNotification _featureTargetNotification(String target)`
- L313 `final _reelNotification = AppNotification.fromData`
- L326 `final _featureNotification = AppNotification.fromData`

### test/services/remote_config/remote_config_service_test.dart

- L11 `const _url = 'https://config.example.com/reelpin.json'`
- L13 `final _document = jsonEncode`
- L22 `void main()`

### test/services/sharing/collection_link_cache_test.dart

- L6 `void main()`

### test/services/sharing/collection_link_test.dart

- L5 `void main()`

### test/services/sharing/collection_share_message_test.dart

- L5 `void main()`

### test/services/sharing/linkrunner_service_test.dart

- L10 `void main()`

### test/services/sharing/push_registration_service_test.dart

- L13 `void main()`
- L71 `class _FakeDeviceMetadataService extends DeviceMetadataService`
  - L72 `const _FakeDeviceMetadataService()`
  - L75 `Future<DeviceMetadata> load()`

### test/services/sharing/share_flow_analytics_service_test.dart

- L5 `void main()`

### test/services/sharing/share_handoff_collections_test.dart

- L13 `void main()`

### test/services/sharing/shared_collection_prefetch_test.dart

- L8 `void main()`
- L69 `CollectionDetail _detail(String name)`

### test/utils/auth_error_message_test.dart

- L8 `void main()`

### test/utils/category_marker_icon_test.dart

- L5 `void main()`

### test/view_models/collections_view_model_test.dart

- L18 `void main()`
- L656 `UserStateCoordinator _coordinatorFor(CollectionsViewModel vm)`
- L664 `class _DeferredContentCache implements ContentCache`
  - L669 `Future<Map<String, dynamic>?> read(String key)`
  - L673 `Future<void> write( String key, Map<String, dynamic> payload, { String? expectedUserId, })`
  - L682 `dynamic noSuchMethod(Invocation invocation)`
- L687 `ContentCache _testCache()`
- L699 `class _TrackedContentCache implements ContentCache`
  - L700 `_TrackedContentCache(this._delegate)`
  - L705 `Future<void> _track(Future<void> operation)`
  - L710 `Future<void> drain()`
  - L717 `Future<Map<String, dynamic>?> read(String key)`
  - L720 `Future<void> write( String key, Map<String, dynamic> payload, { String? expectedUserId, })`
  - L727 `Future<void> invalidate(String key)`
  - L730 `Future<void> invalidateContent()`
  - L733 `Future<void> clear()`
- L736 `CollectionSummary _summary( String id, { String visibility = 'private', int itemCount = 0, String? name, String? updatedAt, })`
- L752 `Reel _reel(String id)`
- L769 `CollectionDetail _detail( String id, { List<String> reelIds = const [], String? nextCursor, int itemCount = 0, String visibility = 'private', String? updatedAt, })`
- L790 `class _FakeCollectionsHttp implements CollectionsHttp`
  - L791 `_FakeCollectionsHttp({this.collections = const [], this.error})`
  - L820 `Future<List<CollectionSummary>> getCollections()`
  - L829 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L855 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L866 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L877 `Future<void> deleteCollection(String collectionId)`
  - L882 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L898 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L906 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L915 `Future<void> disableCollectionLink(String collectionId)`
  - L920 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L926 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L934 `Future<void> leaveCollection(String collectionId)`
  - L939 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L952 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L962 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`

### test/view_models/discover_view_model_test.dart

- L14 `void main()`
- L113 `class _FakeReelRepository extends ReelRepository`
  - L114 `_FakeReelRepository({this.onDiscover, this.onReelsPage})`
  - L130 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = 25, })`
  - L145 `Future<ReelPage> getReelsPage({ String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 25, })`
- L163 `class _FakeAuthService extends AuthService`
  - L164 `_FakeAuthService()`
  - L167 `Session? get currentSession`
  - L170 `User? get currentUser`
  - L173 `Stream<AuthState> get authStateChanges`
  - L176 `Future<void> ensureProfile()`
- L179 `DiscoverResponse _discoverResponse({ required List<Reel> recentSaves, String? selectedDate, })`
- L198 `const _reelA = Reel`
- L215 `const _reelB = Reel`

### test/view_models/home_view_model_test.dart

- L11 `void main()`
- L118 `class _FakeRepository extends ReelRepository`
  - L119 `_FakeRepository()`
  - L128 `bool get hasMoreReels`
  - L131 `Future<void> loadInitialReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L144 `Future<void> loadMoreReels({ String? platform, String? category, String? subcategory, String? savedDate, })`
  - L155 `List<Reel> get cachedReels`
- L158 `class _FakeApiService extends ApiClient`
  - L159 `_FakeApiService()`
  - L162 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
- L175 `class _FakeAuthService extends AuthService`
  - L176 `_FakeAuthService()`
  - L179 `Session? get currentSession`
  - L182 `User? get currentUser`
  - L185 `Stream<AuthState> get authStateChanges`
  - L188 `Future<void> ensureProfile()`

### test/view_models/map_view_model_test.dart

- L25 `void main()`
- L653 `class _FakeAccountHttp implements AccountHttp`
  - L654 `_FakeAccountHttp({this.totalPinnedLocations = 0, this.statsFails = false})`
  - L661 `Future<LibraryStats> getLibraryStats()`
  - L674 `Future<EntitlementsResponse> getAccountEntitlements({ required String userId, })`
  - L679 `Future<void> deleteAccount()`
- L682 `class _FakeReelRepository extends ReelRepository implements MapHttp`
  - L683 `_FakeReelRepository({required this.onSearch})`
  - L694 `_FakeReelRepository.empty({ this.cachedReels = const [], this.mapResponse, this.onGetMapData, this.onGetNearbyPins, this.nearbyResponse, this.nearbyFails = false, this.onMapSearch, this.pinnedMapItem, })`
  - L739 `static Future<SearchResponse> _emptySearch({ required String query, String? category, String? subcategory, })`
  - L751 `Future<void> loadInitialReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L764 `Future<MapResponse> getMapData({ required MapBounds bounds, String? category, })`
  - L775 `Future<MapResponse> getNearbyPins({ required double latitude, required double longitude, int limit = 5, })`
  - L788 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L816 `Future<MapItem> pinMapPlace( String googlePlaceId, { String? sessionToken, })`
  - L824 `Future<void> removeMapItem(String mapItemId)`
  - L829 `Future<SearchResponse> search( String query, { String? category, String? subcategory, })`
- L838 `class _FakeAuthService extends AuthService`
  - L839 `_FakeAuthService()`
  - L842 `Session? get currentSession`
  - L845 `User? get currentUser`
  - L848 `Stream<AuthState> get authStateChanges`
  - L851 `Future<void> ensureProfile()`
- L854 `const _travelReel = Reel`
- L871 `const _travelMapItem = MapItem`
- L889 `const _manualMapItem = MapItem`
- L912 `const _lockedMapItem = MapItem`
- L929 `const _locationId = '66666666-6666-4666-8666-666666666666'`
- L931 `const _goa = MapBounds`
- L933 `const _mumbai = MapBounds`
- L935 `const _foodReel = Reel`

### test/view_models/processing_jobs_view_model_test.dart

- L13 `ProcessingJob _job( String id, { String status = 'processing', bool terminal = false, int? progress, Reel? reel, List<String> collectionIds = const [], DateTime? createdAt, })`
- L33 `Reel _reel(String id)`
- L49 `void main()`
- L335 `class _FakeRepository extends ReelRepository`
  - L336 `_FakeRepository()`
  - L343 `Future<List<ProcessingJob>> listProcessingJobs({int limit = 20})`
- L350 `class _FakeApiService extends ApiClient`
  - L351 `_FakeApiService()`
- L354 `class _FakeAuthService extends AuthService`
  - L355 `_FakeAuthService()`
  - L358 `Session? get currentSession`
  - L361 `User? get currentUser`
  - L364 `Stream<AuthState> get authStateChanges`
  - L367 `Future<void> ensureProfile()`

### test/view_models/reel_filters_view_model_test.dart

- L10 `void main()`
- L124 `class _FakeRepository extends ReelRepository`
  - L125 `_FakeRepository()`
  - L130 `Future<ReelFiltersResponse> getFilters({ String? platform, String? category, String? subcategory, })`
- L140 `const _treeJson = <String, dynamic>{`
- L208 `class _FakeApiService extends ApiClient`
  - L209 `_FakeApiService()`
- L212 `class _FakeAuthService extends AuthService`
  - L213 `_FakeAuthService()`
  - L216 `Session? get currentSession`
  - L219 `User? get currentUser`
  - L222 `Stream<AuthState> get authStateChanges`
  - L225 `Future<void> ensureProfile()`

### test/view_models/remote_config_view_model_test.dart

- L12 `const _url = 'https://config.example.com/reelpin.json'`
- L14 `Map<String, dynamic> _update({required bool hard, int android = 24})`
- L20 `const _announcement = {`
- L28 `RemoteConfigViewModel _viewModel( http.Client client, { int? build = 20, String url = _url, DateTime? now, })`
- L45 `http.Client _serving(Map<String, dynamic> document)`
- L49 `void main()`

### test/view_models/search_view_model_test.dart

- L15 `void main()`
- L86 `class _FakeReelRepository extends ReelRepository`
  - L87 `_FakeReelRepository({required this.onSearch})`
  - L101 `Future<SearchResponse> search( String query, { String? category, String? subcategory, })`
  - L111 `void cancelActiveSearch()`
- L116 `class _FakeAuthService extends AuthService`
  - L117 `_FakeAuthService()`
  - L120 `Session? get currentSession`
  - L123 `User? get currentUser`
  - L126 `Stream<AuthState> get authStateChanges`
  - L129 `Future<void> ensureProfile()`
- L132 `SearchResult _resultFor(String title)`
- L154 `SearchResponse _searchResponse(String query, List<SearchResult> results)`

### test/view_models/session_view_model_test.dart

- L16 `void main()`
- L165 `const _signedInUser = User`
- L173 `class _FakeAuthService extends AuthService`
  - L174 `_FakeAuthService(this.events, {this.user, this.stream})`
  - L182 `Session? get currentSession`
  - L185 `User? get currentUser`
  - L188 `Stream<AuthState> get authStateChanges`
  - L192 `Future<void> ensureProfile()`
  - L197 `Future<void> signOut()`
- L202 `class _FakeSharingHttp implements SharingHttp`
  - L203 `_FakeSharingHttp(this.events, {this.mintGate})`
  - L211 `Future<String> mintShareToken()`
  - L218 `Future<void> revokeShareToken()`
  - L223 `dynamic noSuchMethod(Invocation invocation)`
- L226 `class _FakeAccountHttp implements AccountHttp`
  - L227 `_FakeAccountHttp(this.events, {this.shouldFail = false})`
  - L233 `Future<void> deleteAccount()`
  - L239 `dynamic noSuchMethod(Invocation invocation)`

### test/view_models/theme_view_model_test.dart

- L7 `void main()`

### test/view_models/user_state_coordinator_test.dart

- L33 `void main()`
- L214 `const _filters = <String, dynamic>{`
- L221 `Map<String, dynamic> _payload(String slot)`
- L239 `EntitlementsResponse _entitlements(String userId, {bool restricted = false})`
- L245 `MapItem get _pin`
- L248 `const _place = MapPlaceSearchResult`
- L258 `ProcessingJob _job(String id)`
- L261 `class _State`
  - L296 `void switchUser()`
  - L301 `Future<void> hydrate(String slot)`
  - L316 `bool hasPayload(String slot)`
  - L331 `void dispose()`
- L344 `class _Cache implements ContentCache`
  - L350 `Future<Map<String, dynamic>?> read(String key)`
  - L353 `Future<void> write( String key, Map<String, dynamic> payload, { String? expectedUserId, })`
  - L360 `Future<void> invalidate(String key)`
  - L363 `Future<void> invalidateContent()`
  - L369 `dynamic noSuchMethod(Invocation invocation)`
- L372 `class _Auth extends AuthService`
  - L373 `_Auth()`
  - L377 `User? get currentUser`
- L386 `class _Api extends ApiClient`
  - L399 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L413 `Future<ReelFiltersResponse> getReelFilters({ String? userId, String? platform, String? category, String? subcategory, })`
  - L421 `Future<EntitlementsResponse> getAccountEntitlements({ required String userId, })`
  - L429 `Future<MapResponse> getMapData({ required MapBounds bounds, String? category, })`
  - L438 `Future<LibraryStats> getLibraryStats()`
  - L447 `Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken})`
  - L451 `Future<void> removeMapItem(String mapItemId)`
  - L454 `Future<List<ProcessingJob>> listProcessingJobs({ bool activeOnly = true, int limit = 20, })`

### tool/check_architecture.dart

- L16 `void main()`
- L70 `const _retiredDirectories = ['app', 'core', 'features']`
- L74 `const _allowedImports = <String, Set<String>>{`
- L112 `String _layerOf(String relativePath)`
- L117 `Iterable<String> _importPaths(File file)`
- L126 `Iterable<String> _partialsViolations( String path, String relative, String importPath, )`
- L140 `Iterable<String> _namingViolations(String relative)`
- L190 `const _viewModelExceptions = ['user_state_coordinator.dart']`
- L191 `const _httpExceptions = ['api_client.dart', 'api_exception.dart']`
- L192 `const _vagueNames = [`

### tool/check_assets.dart

- L3 `void main()`

### tool/verify_project.dart

- L3 `void main()`

<!-- mapped: reelpin-app@6ad7c49 plus uncommitted changes | paths: .agent/, .github/, .vscode/, README.md, analysis_options.yaml, android/, assets/, docs/, ios/, lib/, linux/, macos/, play-assets/, pubspec.lock, pubspec.yaml, test/, tool/, web/, windows/ -->
