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
    chat/
      chat_answer_actions.dart
      chat_answer_card.dart
      chat_answer_text.dart
      chat_attachment_sheet.dart
      chat_chart_block.dart
      chat_composer.dart
      chat_places_block.dart
      chat_question_bubble.dart
      chat_reel_strip.dart
      chat_reel_strip_card.dart
      chat_suggestions_block.dart
      chat_table_block.dart
      chat_thinking_stages.dart
      chat_thread_drawer.dart
    collections/
      add_to_collection_sheet.dart
      collection_folder_tile.dart
      collection_form_sheet.dart
      collection_tile_renderer.dart
      pick_collection_sheet.dart
      reel_actions_sheet.dart
      selection_tick.dart
      share_collection_sheet.dart
      share_to_collection_chat.dart
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
    chat_feature.dart
    source_platforms.dart
  data_models/
    account/
      library_stats.dart
      user_entitlement.dart
    chat/
      answer_block.dart
      answer_text_segment.dart
      chat_attachment.dart
      chat_thread.dart
      collection_chat_page.dart
      collection_chat_thread.dart
      thinking_stage.dart
    collections/
      collection_models.dart
    discover/
      discover_response.dart
      search_response.dart
      search_result.dart
    map/
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
    chat_http.dart
    collection_chat_http.dart
    collections_http.dart
    discover_http.dart
    map_http.dart
    mock_chat_http.dart
    mock_collection_chat_http.dart
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
    chat/
      chat_screen.dart
      partials/
        chat_empty_state.dart
    collections/
      collection_ask_screen.dart
      collection_detail_screen.dart
      collections_screen.dart
      partials/
        collection_chat_panel.dart
        collection_sticky_note.dart
        collection_tab_bar.dart
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
    chat/
      chat_reel_cache.dart
      chat_thread_store.dart
    device_metadata_service.dart
    how_to_guide_service.dart
    location/
      location_service.dart
    notifications/
      notification_service.dart
      notification_tap_handler.dart
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
    answer_text_parser.dart
    app_logger.dart
    app_store_links.dart
    auth_error_message.dart
    category_marker_icon.dart
    error_message.dart
    location_maps_uri.dart
  view_models/
    chat_view_model.dart
    collection_chat_view_model.dart
    collections_view_model.dart
    discover_view_model.dart
    entitlements_view_model.dart
    home_view_model.dart
    map_view_model.dart
    processing_jobs_view_model.dart
    reel_detail_view_model.dart
    reel_filters_view_model.dart
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
    chat/
      answer_blocks_test.dart
      chat_answer_actions_test.dart
      chat_answer_card_test.dart
      chat_answer_text_test.dart
      chat_composer_test.dart
      chat_places_block_test.dart
      chat_reel_strip_card_test.dart
      chat_reel_strip_test.dart
      chat_thinking_stages_test.dart
    collections/
      collection_folder_tile_test.dart
    processing_reel_card_test.dart
  constants/
    source_platforms_test.dart
  data_models/
    account/
      user_entitlement_test.dart
    chat/
      chat_thread_test.dart
      collection_chat_page_test.dart
    collection_models_test.dart
    map/
      map_place_search_response_test.dart
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
    mock_chat_http_test.dart
    mock_collection_chat_http_test.dart
  repositories/
    reel_repository_cache_test.dart
    reel_repository_test.dart
  router_test.dart
  screens/
    app_shell_tab_index_test.dart
    chat/
      chat_screen_test.dart
    chat_attachment_sheet_test.dart
    collections/
      collection_chat_panel_test.dart
      collection_detail_tabs_test.dart
      share_collection_sheet_test.dart
    feature_announcement/
      feature_announcement_screen_test.dart
    home/
      home_empty_state_test.dart
      home_filter_sheet_test.dart
    how_to/
      how_to_use_screen_test.dart
    onboarding/
      onboarding_screen_test.dart
    reel_detail/
      reel_share_card_test.dart
  services/
    cache/
      content_cache_test.dart
    chat/
      chat_reel_cache_test.dart
      chat_thread_store_test.dart
    how_to_guide_service_test.dart
    notifications/
      notification_tap_handler_test.dart
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
    answer_text_parser_test.dart
    auth_error_message_test.dart
    category_marker_icon_test.dart
  view_models/
    chat_view_model_test.dart
    collection_chat_view_model_test.dart
    collections_view_model_test.dart
    discover_view_model_test.dart
    home_view_model_test.dart
    map_view_model_test.dart
    processing_jobs_view_model_test.dart
    reel_filters_view_model_test.dart
    search_view_model_test.dart
    session_view_model_test.dart
    theme_view_model_test.dart
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

- L18 `class AppEntry extends ConsumerStatefulWidget`
  - L19 `const AppEntry({super.key})`
  - L22 `ConsumerState<AppEntry> createState()`
- L25 `class _AppEntryState extends ConsumerState<AppEntry> with WidgetsBindingObserver`
  - L34 `void initState()`
  - L52 `void _startContentLoad()`
  - L70 `void _startCollectionLaunch()`
  - L83 `void dispose()`
  - L89 `void didChangeAppLifecycleState(AppLifecycleState state)`
  - L95 `Future<void> _loadOnboardingState()`
  - L104 `Future<void> _completeOnboarding()`
  - L118 `Widget build(BuildContext context)`

### lib/bootstrap.dart

- L20 `Future<void> bootstrap()`
- L65 `Future<void> _initializeFirebase()`
- L94 `void _configureImageCache()`

### lib/components/chat/chat_answer_actions.dart

- L14 `String answerPlainText(ChatMessage message)`
- L48 `class ChatAnswerActions extends StatelessWidget`
  - L49 `const ChatAnswerActions({ super.key, required this.message, required this.onSaveToCollection, })`
  - L61 `Widget build(BuildContext context)`
  - L109 `Widget _chip( BuildContext context, { required String label, required Color? colour, required VoidCallback? onTap, })`

### lib/components/chat/chat_answer_card.dart

- L22 `class ChatAnswerCard extends StatelessWidget`
  - L23 `const ChatAnswerCard({ super.key, required this.message, required this.onRetry, required this.library, required this.reelCache, required this.onTapReel, required this.onSaveToCollection, this.sharedByName, })`
  - L52 `Widget build(BuildContext context)`
  - L80 `Widget _buildSharedMarker(BuildContext context)`
  - L99 `Widget _buildBlock(BuildContext context, AnswerBlock block)`
  - L141 `Widget _buildFailure(BuildContext context)`

### lib/components/chat/chat_answer_text.dart

- L19 `class ChatAnswerTextView extends StatelessWidget`
  - L20 `const ChatAnswerTextView({super.key, required this.text})`
  - L34 `Widget build(BuildContext context)`
  - L71 `Widget _buildHeading(BuildContext context, String text)`
  - L89 `Widget _buildBulletGroup( BuildContext context, List<String> bullets, Color dotColor, )`
  - L105 `Widget _buildBullet(BuildContext context, String text, Color dotColor)`
  - L134 `Widget _buildParagraph(BuildContext context, String text)`
  - L148 `Widget _richText(BuildContext context, String text, TextStyle baseStyle)`

### lib/components/chat/chat_attachment_sheet.dart

- L14 `Future<ChatAttachment?> showChatAttachmentSheet( BuildContext context, { required List<Reel> library, })`
- L74 `Widget _row( BuildContext context, { required Color colour, required IconData icon, required String label, required VoidCallback? onTap, })`
- L123 `Future<void> _pickImage(BuildContext context, ImageSource source)`
- L148 `Future<void> _pickFile(BuildContext context)`
- L169 `void _showAttachmentError(ScaffoldMessengerState messenger)`
- L184 `Future<void> _pickSave(BuildContext context, List<Reel> library)`
- L216 `Future<void> _pasteLink(BuildContext context)`
- L234 `class _LinkEntrySheet extends StatefulWidget`
  - L235 `const _LinkEntrySheet()`
  - L238 `State<_LinkEntrySheet> createState()`
- L241 `class _LinkEntrySheetState extends State<_LinkEntrySheet>`
  - L245 `void dispose()`
  - L251 `Widget build(BuildContext context)`

### lib/components/chat/chat_chart_block.dart

- L11 `class ChatChartBlockView extends StatelessWidget`
  - L12 `const ChatChartBlockView({super.key, required this.block})`
  - L23 `Widget build(BuildContext context)`

### lib/components/chat/chat_composer.dart

- L8 `class ChatComposer extends StatefulWidget`
  - L9 `const ChatComposer({ super.key, required this.onSend, required this.enabled, this.onAttach, this.initialText = '', this.pending = const [], this.onRemoveAttachment, })`
  - L33 `State<ChatComposer> createState()`
- L36 `class _ChatComposerState extends State<ChatComposer>`
  - L42 `void didUpdateWidget(covariant ChatComposer oldWidget)`
  - L56 `void dispose()`
  - L61 `void _send()`
  - L70 `Widget build(BuildContext context)`
  - L91 `Widget _pendingChips(BuildContext context)`
  - L146 `Widget _inputRow(BuildContext context)`
  - L218 `Widget _button( BuildContext context, { required Color color, required Widget child, required VoidCallback onTap, })`

### lib/components/chat/chat_places_block.dart

- L21 `class ChatPlacesBlockView extends StatelessWidget`
  - L22 `const ChatPlacesBlockView({super.key, required this.places})`
  - L30 `Widget build(BuildContext context)`
- L77 `class _PlaceCard extends StatefulWidget`
  - L78 `const _PlaceCard({required this.place})`
  - L83 `State<_PlaceCard> createState()`
- L86 `class _PlaceCardState extends State<_PlaceCard>`
  - L110 `void initState()`
  - L116 `void didUpdateWidget(covariant _PlaceCard oldWidget)`
  - L124 `Future<void> _loadIcon()`
  - L131 `Widget build(BuildContext context)`
  - L222 `Future<void> _openInMaps(Uri uri)`

### lib/components/chat/chat_question_bubble.dart

- L11 `class ChatQuestionBubble extends StatelessWidget`
  - L12 `const ChatQuestionBubble({super.key, required this.message})`
  - L17 `Widget build(BuildContext context)`

### lib/components/chat/chat_reel_strip.dart

- L22 `class ChatReelStrip extends StatefulWidget`
  - L23 `const ChatReelStrip({ super.key, required this.reelIds, required this.library, required this.onTapReel, required this.reelCache, })`
  - L40 `State<ChatReelStrip> createState()`
- L43 `class _ChatReelStripState extends State<ChatReelStrip>`
  - L59 `void initState()`
  - L65 `void didUpdateWidget(covariant ChatReelStrip oldWidget)`
  - L75 `void _resolveMissing()`
  - L102 `Widget build(BuildContext context)`

### lib/components/chat/chat_reel_strip_card.dart

- L17 `class ChatReelStripCard extends StatelessWidget`
  - L18 `const ChatReelStripCard({super.key, required this.reel, required this.onTap})`
  - L24 `Widget build(BuildContext context)`
  - L64 `Widget _buildThumbnail(BuildContext context, Color catColor)`
  - L119 `Widget _buildPlain(BuildContext context)`
  - L135 `Widget _title( BuildContext context, { required Color color, List<Shadow>? shadows, })`

### lib/components/chat/chat_suggestions_block.dart

- L11 `class ChatSuggestionsBlockView extends StatelessWidget`
  - L12 `const ChatSuggestionsBlockView({super.key, required this.block})`
  - L17 `Widget build(BuildContext context)`
- L43 `class _SuggestionCard extends StatelessWidget`
  - L44 `const _SuggestionCard({required this.item})`
  - L49 `Widget build(BuildContext context)`

### lib/components/chat/chat_table_block.dart

- L9 `class ChatTableBlockView extends StatelessWidget`
  - L10 `const ChatTableBlockView({super.key, required this.block})`
  - L15 `Widget build(BuildContext context)`
  - L46 `Widget _cell( String text, { bool bold = false, bool onYellow = false, Color? color, })`

### lib/components/chat/chat_thinking_stages.dart

- L10 `class ChatThinkingStages extends StatelessWidget`
  - L11 `const ChatThinkingStages({super.key, required this.stages})`
  - L25 `Widget build(BuildContext context)`
  - L53 `Widget _buildRow( BuildContext context, { required String label, required bool isPending, Color? tickColor, bool done = false, })`

### lib/components/chat/chat_thread_drawer.dart

- L9 `class ChatThreadDrawer extends StatelessWidget`
  - L10 `const ChatThreadDrawer({ super.key, required this.threads, required this.onOpen, required this.onNewChat, this.heading = 'YOUR CHATS', })`
  - L24 `Widget build(BuildContext context)`

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

### lib/components/collections/pick_collection_sheet.dart

- L15 `Future<List<CollectionSummary>?> showPickCollectionSheet( BuildContext context, { String? excludeCollectionId, })`
- L31 `class PickCollectionSheet extends ConsumerStatefulWidget`
  - L32 `const PickCollectionSheet({super.key, this.excludeCollectionId})`
  - L39 `ConsumerState<PickCollectionSheet> createState()`
- L43 `class _PickCollectionSheetState extends ConsumerState<PickCollectionSheet>`
  - L47 `void initState()`
  - L54 `void _toggle(String collectionId)`
  - L60 `void _save(List<CollectionSummary> editable)`
  - L67 `Widget build(BuildContext context)`
  - L145 `Widget _buildBody( BuildContext context, bool isLoading, List<CollectionSummary> editable, Map<String, Color> accents, )`
- L213 `class _SaveButton extends StatelessWidget`
  - L214 `const _SaveButton({required this.count, required this.onTap})`
  - L220 `Widget build(BuildContext context)`

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

### lib/components/collections/share_to_collection_chat.dart

- L15 `Future<void> shareToCollectionChat( BuildContext context, WidgetRef ref, { required List<AnswerBlock> blocks, String? excludeCollectionId, })`

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

### lib/constants/chat_feature.dart

- L6 `const bool chatEnabled = bool.fromEnvironment`

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

### lib/data_models/chat/answer_block.dart

- L4 `sealed class AnswerBlock`
  - L5 `const AnswerBlock()`
  - L7 `Map<String, dynamic> toJson()`
  - L11 `static AnswerBlock? fromJson(Map<String, dynamic> json)`
- L45 `List<String> _stringList(dynamic raw)`
- L50 `List<Map<String, dynamic>> _mapList(dynamic raw)`
- L55 `List<List<String>> _listOfStringLists(dynamic raw)`
- L63 `double _asDouble(dynamic raw, [double fallback = 0])`
- L69 `class TextBlock extends AnswerBlock`
  - L72 `const TextBlock(this.text)`
  - L75 `Map<String, dynamic> toJson()`
- L81 `class ReelRefsBlock extends AnswerBlock`
  - L84 `const ReelRefsBlock(this.reelIds)`
  - L87 `Map<String, dynamic> toJson()`
- L90 `class PlacesBlock extends AnswerBlock`
  - L93 `const PlacesBlock(this.places)`
  - L96 `Map<String, dynamic> toJson()`
- L102 `class TableBlock extends AnswerBlock`
  - L106 `const TableBlock({required this.columns, required this.rows})`
  - L109 `Map<String, dynamic> toJson()`
- L116 `class ChartBlock extends AnswerBlock`
  - L120 `const ChartBlock({required this.title, required this.bars})`
  - L123 `Map<String, dynamic> toJson()`
- L133 `class SuggestionsBlock extends AnswerBlock`
  - L137 `const SuggestionsBlock({required this.title, required this.items})`
  - L140 `Map<String, dynamic> toJson()`
- L147 `class Suggestion`
  - L155 `const Suggestion({ required this.title, required this.kind, required this.why, })`
  - L161 `factory Suggestion.fromJson(Map<String, dynamic> json)`
  - L167 `Map<String, dynamic> toJson()`
- L170 `class AnswerPlace`
  - L180 `const AnswerPlace({ required this.name, required this.latitude, required this.longitude, required this.category, this.reelId, })`
  - L188 `factory AnswerPlace.fromJson(Map<String, dynamic> json)`
  - L196 `Map<String, dynamic> toJson()`
- L205 `class ChartBar`
  - L210 `const ChartBar({ required this.label, required this.value, required this.category, })`
  - L216 `factory ChartBar.fromJson(Map<String, dynamic> json)`
  - L222 `Map<String, dynamic> toJson()`

### lib/data_models/chat/answer_text_segment.dart

- L4 `sealed class AnswerTextSegment`
  - L5 `const AnswerTextSegment()`
- L8 `class AnswerHeading extends AnswerTextSegment`
  - L10 `const AnswerHeading(this.text)`
- L13 `class AnswerBullet extends AnswerTextSegment`
  - L15 `const AnswerBullet(this.text)`
- L18 `class AnswerParagraph extends AnswerTextSegment`
  - L20 `const AnswerParagraph(this.text)`

### lib/data_models/chat/chat_attachment.dart

- L1 `enum AttachmentKind`
- L6 `extension AttachmentKindLabel on AttachmentKind`
  - L7 `String get label`
- L19 `class ChatAttachment`
  - L36 `const ChatAttachment({ required this.kind, required this.displayName, this.localPath, this.url, this.reelId, this.collectionId, })`
  - L45 `factory ChatAttachment.fromJson(Map<String, dynamic> json)`
  - L61 `Map<String, dynamic> toJson()`

### lib/data_models/chat/chat_thread.dart

- L4 `enum MessageRole`
- L6 `enum MessageStatus`
- L8 `class ChatMessage`
  - L29 `const ChatMessage({ required this.id, required this.role, required this.createdAt, this.text = '', this.attachments = const [], this.blocks = const [], this.status = MessageStatus.complete, this.authorName = '', this.isShared = false, })`
  - L41 `ChatMessage copyWith({List<AnswerBlock>? blocks, MessageStatus? status})`
  - L42 `ChatMessage( id: id, role: role, createdAt: createdAt, text: text, attachments: attachments, blocks: blocks ?? this.blocks, status: status ?? this.status, authorName: authorName, isShared: isShared, )`
  - L54 `factory ChatMessage.fromJson(Map<String, dynamic> json)`
  - L75 `Map<String, dynamic> toJson()`
- L86 `class ChatThread`
  - L96 `const ChatThread({ required this.id, required this.title, required this.createdAt, required this.updatedAt, this.messages = const [], })`
  - L104 `ChatThread copyWith({ String? title, List<ChatMessage>? messages, DateTime? updatedAt, })`
  - L116 `factory ChatThread.fromJson(Map<String, dynamic> json)`
  - L128 `Map<String, dynamic> toJson()`
- L140 `List<Map<String, dynamic>> _mapList(dynamic raw)`

### lib/data_models/chat/collection_chat_page.dart

- L8 `class CollectionChatPage`
  - L11 `const CollectionChatPage({this.messages = const []})`
  - L13 `factory CollectionChatPage.fromJson(Map<String, dynamic> json)`

### lib/data_models/chat/collection_chat_thread.dart

- L3 `class CollectionChatThread`
  - L12 `const CollectionChatThread({ required this.id, required this.title, this.questionCount = 0, this.updatedAt, })`
  - L19 `factory CollectionChatThread.fromJson(Map<String, dynamic> json)`
  - L20 `CollectionChatThread( id: json['thread_id']?.toString() ?? 'main', title: json['title']?.toString() ?? '', questionCount: (json['question_count'] as num?)?.toInt() ?? 0, updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''), )`
  - L29 `static List<CollectionChatThread> listFromJson(Object? raw)`
  - L40 `Map<String, dynamic> toJson()`

### lib/data_models/chat/thinking_stage.dart

- L1 `enum ThinkingStageState`
- L5 `class ThinkingStage`
  - L9 `const ThinkingStage({required this.label, required this.state})`
  - L11 `ThinkingStage copyWith({ThinkingStageState? state})`
  - L12 `ThinkingStage(label: label, state: state ?? this.state)`

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

### lib/data_models/map/map_place_search_response.dart

- L3 `class MapPlaceSearchResponse`
  - L4 `const MapPlaceSearchResponse({ required this.query, required this.searchMode, required this.total, required this.results, this.googleStatus = 'ok', })`
  - L21 `bool get isGoogleSearchUnavailable`
  - L23 `factory MapPlaceSearchResponse.fromJson(Map<String, dynamic> json)`
- L41 `class MapPlaceSearchResult`
  - L42 `const MapPlaceSearchResult({ required this.resultType, this.sourceType, this.mapItem, this.googlePlaceId, required this.displayTitle, required this.displayAddress, required this.placeName, this.latitude, this.longitude, this.googleMapsUrl, required this.placeTypes, required this.canPin, })`
  - L70 `bool get isExisting`
  - L71 `bool get isGooglePlace`
  - L73 `factory MapPlaceSearchResult.fromJson(Map<String, dynamic> json)`

### lib/data_models/map/map_response.dart

- L3 `class MapResponse`
  - L4 `const MapResponse({ required this.totalPinnedLocations, required this.visiblePinnedLocations, required this.mapItems, this.selectedCategory, })`
  - L18 `factory MapResponse.fromJson(Map<String, dynamic> json, {String? category})`
- L37 `class MapItem`
  - L38 `const MapItem({ required this.reelId, required this.title, required this.summary, required this.category, required this.subCategory, required this.categoryLabel, required this.locations, required this.markerId, required this.latitude, required this.longitude, required this.locationName, required this.locationDisplayLabel, this.mapItemId, this.sourceType = 'content', this.displayTitle = '', this.shortDetail = '', this.subCategoryLabel = '', this.locationAddress, this.googleMapsUrl, this.googlePlaceId, this.placeTypes = const [], this.canHide = true, this.canRemove = true, })`
  - L88 `bool get isManual`
  - L89 `bool get canOpenDetails`
  - L90 `String get effectiveMapItemId`
  - L91 `String get displayName`
  - L93 `String get displayDetail`
  - L96 `factory MapItem.fromJson(Map<String, dynamic> json)`
  - L147 `Reel toReel()`

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
  - L176 `Map<String, dynamic> toJson()`
  - L211 `static List<Location> _parseLocations(dynamic raw)`
  - L228 `bool get isUnparsed`
  - L230 `static String _normalizedContentType(dynamic raw)`
  - L239 `static String _normalizedParseStatus(dynamic raw)`
  - L244 `static String? _normalizedNullableString(dynamic raw)`
  - L249 `static List<String> _stringList(dynamic raw)`

### lib/data_models/reels/reel_filters.dart

- L15 `class ReelSubcategoryFilter`
  - L20 `const ReelSubcategoryFilter({ required this.name, required this.label, required this.count, })`
  - L26 `factory ReelSubcategoryFilter.fromJson(Map<String, dynamic> json)`
  - L38 `String get displayLabel`
- L41 `class ReelCategoryGroup`
  - L47 `const ReelCategoryGroup({ required this.category, required this.label, required this.count, required this.subcategories, })`
  - L54 `factory ReelCategoryGroup.fromJson(Map<String, dynamic> json)`
  - L82 `String get displayLabel`
  - L84 `ReelSubcategoryFilter? subcategoryNamed(String? name)`
- L96 `class ReelPlatformGroup`
  - L103 `const ReelPlatformGroup({ required this.platform, required this.label, required this.count, required this.topCategory, required this.categories, })`
  - L111 `factory ReelPlatformGroup.fromJson(Map<String, dynamic> json)`
  - L122 `String get displayLabel`
  - L124 `ReelCategoryGroup? categoryNamed(String? category)`
- L133 `class ReelFiltersResponse`
  - L143 `const ReelFiltersResponse({ required this.totalCount, required this.topPlatform, required this.selectedPreviewCount, required this.platforms, required this.categories, })`
  - L151 `factory ReelFiltersResponse.fromJson(Map<String, dynamic> json)`
  - L172 `ReelPlatformGroup? platformNamed(String? platform)`
- L181 `List<ReelCategoryGroup> _parseCategories(Object? raw)`

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
- L50 `class SupabaseConfig`
  - L51 `SupabaseConfig._()`
  - L58 `static Future<void> loadLocalConfig()`
  - L60 `static String get url`
  - L62 `static String get anonKey`
  - L65 `static String get redirectScheme`
  - L69 `static bool get isConfigured`
  - L72 `static String get redirectUrl`
  - L74 `static String _defaultRedirectScheme()`

### lib/http/account_http.dart

- L4 `abstract interface class AccountHttp`
  - L5 `Future<EntitlementsResponse> getAccountEntitlements({required String userId})`
  - L7 `Future<LibraryStats> getLibraryStats()`
  - L9 `Future<void> deleteAccount()`

### lib/http/api_client.dart

- L34 `class ApiClient implements ReelsHttp, DiscoverHttp, MapHttp, CollectionsHttp, AccountHttp, SharingHttp`
  - L54 `ApiClient({ http.Client? client, String? baseUrl, String? Function()? accessTokenProvider, Future<void> Function()? sessionRefresher, })`
  - L67 `Future<Reel> processReel( String url, { String userId = 'default-user', void Function(ProcessingJob job)? onJobUpdate, })`
  - L81 `Future<ProcessingJob> enqueueReelProcessing( String url, { String userId = 'default-user', List<String> collectionIds = const [], })`
  - L89 `Future<ProcessingJob> _submitReel( String url, { List<String> collectionIds = const [], })`
  - L139 `Future<List<ProcessingJob>> listProcessingJobs({ bool activeOnly = true, int limit = 20, })`
  - L173 `Future<ProcessingJob> _getProcessingJob(String jobId)`
  - L193 `Future<Reel> _waitForProcessingJob( String jobId, { ProcessingJob? initialJob, void Function(ProcessingJob job)? onJobUpdate, })`
  - L241 `Future<Reel?> _completedJobResult(ProcessingJob job)`
  - L256 `void _throwIfTerminalFailure(ProcessingJob job)`
  - L266 `Duration _jobPollingDelay(int attempt, ProcessingJob job)`
  - L296 `String _jobFailureMessage(ProcessingJob job)`
  - L338 `Future<ReelPage> getReelsPage({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = 50, })`
  - L391 `Future<List<Reel>> getReels({ String? userId, String? platform, String? category, String? subcategory, String? savedDate, int limit = 50, })`
  - L413 `Future<Reel> getReel(String reelId)`
  - L434 `Future<void> deleteReel(String reelId)`
  - L454 `Future<List<CollectionSummary>> getCollections()`
  - L476 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L509 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L537 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L566 `Future<void> deleteCollection(String collectionId)`
  - L584 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L608 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L629 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L650 `Future<void> disableCollectionLink(String collectionId)`
  - L668 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L689 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L713 `Future<void> leaveCollection(String collectionId)`
  - L731 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L756 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L775 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`
  - L807 `CollectionSummary _collectionFromMutation(http.Response res)`
  - L817 `Future<ReelFiltersResponse> getReelFilters({ String? userId, String? platform, String? category, String? subcategory, })`
  - L860 `Future<SearchResponse> searchReels( String query, { String userId = 'default-user', String? category, String? subcategory, int limit = 5, http.Client? client, })`
  - L923 `Future<EntitlementsResponse> getAccountEntitlements({ required String userId, })`
  - L952 `Future<MapResponse> getMapData({String? category})`
  - L988 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L1025 `Future<MapItem> pinMapPlace( String googlePlaceId, { String? sessionToken, })`
  - L1056 `Future<void> removeMapItem(String mapItemId)`
  - L1075 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = 25, })`
  - L1112 `Future<LibraryStats> getLibraryStats()`
  - L1133 `Future<void> deleteAccount()`
  - L1150 `Future<ShareResolveResponse> resolveSharePayload({ required String rawPayloadText, })`
  - L1179 `Future<void> registerPushToken({ required String userId, required String token, required String platform, required String appVersion, required String appBuild, required String timezone, required String locale, })`
  - L1207 `Future<void> unregisterPushToken({required String token})`
  - L1227 `Future<void> recordNotificationOpened({ required String notificationId, })`
  - L1251 `Future<String> mintShareToken()`
  - L1271 `Future<void> revokeShareToken()`
  - L1287 `Future<http.Response> _sendRequest( Future<http.Response> Function(String baseUrl) request, )`
  - L1315 `Uri _apiUri( String baseUrl, String path, { Map<String, String>? queryParameters, })`
  - L1334 `Future<http.Response> _sendRequestWithClient( http.Client client, Future<http.Response> Function(String baseUrl, http.Client client) request, )`
  - L1341 `String _networkErrorMessage(Object? error)`
  - L1345 `void _logNetworkError(String baseUrl, Object error)`
  - L1351 `Map<String, String> _headers({bool json = false})`
  - L1360 `static bool _isBlank(String? value)`
  - L1362 `static String _pageLimit(int limit)`
  - L1366 `static String _newIdempotencyKey()`
  - L1378 `static String? _currentAccessToken()`
  - L1388 `Future<bool> _renewSession()`
  - L1400 `static Future<void> _refreshCurrentSession()`
  - L1407 `ApiException _exceptionFromResponse( http.Response res, { required String fallbackMessage, })`

### lib/http/api_exception.dart

- L1 `class ApiException implements Exception`
  - L2 `const ApiException( this.message, this.statusCode, { this.errorCode, this.requestId, this.details = const {}, this.retryable = false, })`
  - L18 `bool get isUpgradeRequired`
  - L19 `bool get isMonthlyReelLimitReached`
  - L21 `bool get isHistoryUpgradeRequired`
  - L24 `String toString()`

### lib/http/chat_http.dart

- L7 `sealed class ChatEvent`
  - L8 `const ChatEvent()`
- L11 `class StageEvent extends ChatEvent`
  - L14 `const StageEvent(this.stage)`
- L17 `class AnswerEvent extends ChatEvent`
  - L20 `const AnswerEvent(this.blocks)`
- L31 `class ChatHistoryEntry`
  - L37 `const ChatHistoryEntry({required this.role, required this.text})`
  - L39 `Map<String, dynamic> toJson()`
- L48 `abstract interface class ChatHttp`
  - L49 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments, List<ChatHistoryEntry> history, })`
  - L60 `Future<List<String>> fetchSuggestions()`

### lib/http/collection_chat_http.dart

- L14 `abstract interface class CollectionChatHttp`
  - L16 `Future<List<CollectionChatThread>> fetchThreads(String collectionId)`
  - L20 `Future<CollectionChatPage> fetchMessages( String collectionId, { required String threadId, String? after, })`
  - L26 `Stream<ChatEvent> ask({ required String collectionId, required String threadId, required String text, List<ChatAttachment> attachments, })`
  - L35 `Future<void> shareAnswer({ required String collectionId, required String threadId, required String questionText, required List<AnswerBlock> blocks, })`
  - L42 `Future<void> deleteMessage({ required String collectionId, required String messageId, })`

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

- L4 `abstract interface class MapHttp`
  - L5 `Future<MapResponse> getMapData({String? category})`
  - L7 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L14 `Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken})`
  - L16 `Future<void> removeMapItem(String mapItemId)`

### lib/http/mock_chat_http.dart

- L14 `class MockChatHttp implements ChatHttp`
  - L15 `MockChatHttp({ required List<Reel> Function() reelsSource, Duration stageDelay = const Duration(milliseconds: 650), })`
  - L56 `Future<List<String>> fetchSuggestions()`
  - L70 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments = const [], List<ChatHistoryEntry> history = const [], })`
  - L96 `Stream<ChatEvent> _stage(String label)`
  - L106 `List<Reel> _match(String query, List<Reel> library)`
  - L121 `Set<String> _terms(String query)`
  - L129 `List<AnswerBlock> _answer( String query, List<Reel> reels, { required bool usingFallback, })`
  - L182 `List<AnswerPlace> _places(List<Reel> reels)`
  - L204 `List<ChartBar> _bars(List<Reel> reels)`
  - L225 `List<Reel> _seedReels(String query)`

### lib/http/mock_collection_chat_http.dart

- L17 `class MockCollectionChatHttp implements CollectionChatHttp`
  - L18 `MockCollectionChatHttp({ Duration stageDelay = const Duration(milliseconds: 650), String authorName = 'You', })`
  - L30 `List<ChatMessage> _thread(String collectionId, String threadId)`
  - L34 `Future<List<CollectionChatThread>> fetchThreads(String collectionId)`
  - L53 `static String _titleOf(List<ChatMessage> thread)`
  - L69 `Future<CollectionChatPage> fetchMessages( String collectionId, { required String threadId, String? after, })`
  - L85 `Stream<ChatEvent> ask({ required String collectionId, required String threadId, required String text, List<ChatAttachment> attachments = const [], })`
  - L116 `Future<void> shareAnswer({ required String collectionId, required String threadId, required String questionText, required List<AnswerBlock> blocks, })`
  - L132 `Future<void> deleteMessage({ required String collectionId, required String messageId, })`
  - L141 `void _append( String collectionId, String threadId, { required String question, required List<AnswerBlock> blocks, required bool isShared, List<ChatAttachment> attachments = const [], })`

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

- L37 `final themeViewModelProvider = ChangeNotifierProvider<ThemeViewModel>`
- L41 `final profileServiceProvider = Provider<ProfileService>`
- L45 `final authServiceProvider = Provider<AuthService>`
- L49 `final sessionViewModelProvider = ChangeNotifierProvider<SessionViewModel>`
- L61 `final notificationServiceProvider = Provider<NotificationService>`
- L65 `final shareFlowAnalyticsServiceProvider = Provider<ShareFlowAnalyticsService>`
- L71 `final apiClientProvider = Provider<ApiClient>`
- L75 `final reelsHttpProvider = Provider<ReelsHttp>`
- L79 `final mapHttpProvider = Provider<MapHttp>`
- L83 `final collectionsHttpProvider = Provider<CollectionsHttp>`
- L90 `final collectionsViewModelProvider = `
- L98 `final accountHttpProvider = Provider<AccountHttp>`
- L102 `final sharingHttpProvider = Provider<SharingHttp>`
- L106 `final pushRegistrationServiceProvider = Provider<PushRegistrationService>`
- L115 `final reelRepositoryProvider = ChangeNotifierProvider<ReelRepository>`
- L122 `final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>`
- L133 `final mapViewModelProvider = ChangeNotifierProvider<MapViewModel>`
- L137 `final reelFiltersViewModelProvider = `
- L142 `final discoverViewModelProvider = ChangeNotifierProvider<DiscoverViewModel>`
- L148 `final searchViewModelProvider = ChangeNotifierProvider<SearchViewModel>`
- L152 `final entitlementsViewModelProvider = `
- L166 `final processingJobsViewModelProvider = `
- L191 `final chatThreadStoreProvider = Provider<ChatThreadStore>`
- L197 `final chatHttpProvider = Provider<ChatHttp>`
- L203 `final collectionChatHttpProvider = Provider<CollectionChatHttp>`
- L207 `final chatViewModelProvider = ChangeNotifierProvider<ChatViewModel>`
- L217 `final collectionChatViewModelProvider = ChangeNotifierProvider.autoDispose`
- L227 `final appShellControllerProvider = StateProvider<AppShellController?>`
- L231 `final userStateCoordinatorProvider = Provider<UserStateCoordinator>`

### lib/reelpin_app.dart

- L8 `class ReelPinApp extends ConsumerWidget`
  - L9 `const ReelPinApp({super.key, required this.isSupabaseConfigured})`
  - L14 `Widget build(BuildContext context, WidgetRef ref)`

### lib/repositories/reel_repository.dart

- L21 `class SearchCancelledException implements Exception`
  - L22 `const SearchCancelledException()`
- L25 `class ReelRepository extends ChangeNotifier`
  - L44 `ReelRepository( this._apiService, this._authService, { ContentCache? contentCache, })`
  - L50 `String get _currentUserId`
  - L58 `List<Reel> get cachedReels`
  - L59 `String? get cacheUserId`
  - L60 `bool get hasMoreReels`
  - L61 `bool get hasHydratedCache`
  - L62 `SearchMode? get lastSearchMode`
  - L63 `int get lastSearchTotal`
  - L68 `Future<void> hydrateCache()`
  - L85 `Future<void> _hydrateCache()`
  - L121 `Future<void> loadInitialReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L147 `Future<void> _loadInitialReels({ required bool forceRefresh, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L169 `Future<void> loadMoreReels({ String? platform, String? category, String? subcategory, String? savedDate, })`
  - L196 `Future<void> _loadMoreReelsInternal({ String? platform, String? category, String? subcategory, String? savedDate, })`
  - L218 `Future<void> _fetchAndStorePage({ required bool reset, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L245 `Future<List<Reel>> getReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L262 `Future<ReelPage> getReelsPage({ String? platform, String? category, String? subcategory, String? savedDate, String? cursor, int limit = _pageSize, })`
  - L281 `Future<Reel> getReel(String reelId, {bool forceRefresh = false})`
  - L286 `Future<Reel> processReel( String url, { void Function(ProcessingJob job)? onJobUpdate, })`
  - L300 `Future<ProcessingJob> enqueueReelProcessing( String url, { List<String> collectionIds = const [], })`
  - L317 `void insertReel(Reel reel)`
  - L326 `Future<List<ProcessingJob>> listProcessingJobs({int limit = 20})`
  - L330 `Future<ReelFiltersResponse> getFilters({ String? platform, String? category, String? subcategory, })`
  - L343 `Future<MapResponse> getMapData({String? category})`
  - L347 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, })`
  - L359 `Future<MapItem> pinMapPlace(String googlePlaceId, {String? sessionToken})`
  - L363 `Future<void> removeMapItem(String mapItemId)`
  - L367 `Future<DiscoverResponse> getDiscover({ String? savedDate, String? cursor, int limit = _pageSize, })`
  - L379 `Future<LibraryStats> getLibraryStats()`
  - L383 `Future<void> deleteReel(String reelId)`
  - L389 `Future<SearchResponse> search( String query, { String? category, String? subcategory, })`
  - L431 `void clearCache()`
  - L443 `Future<void> clearUserCache()`
  - L450 `bool _hasFilters( String? platform, String? category, String? subcategory, String? savedDate, )`
  - L463 `void cancelActiveSearch()`
  - L469 `bool _isActiveSearchClient(http.Client client)`
  - L473 `void dispose()`

### lib/router.dart

- L23 `Route<void> reelDetailRoute(Reel reel)`
- L28 `Route<void> reelDetailSlideRoute(Reel reel)`
- L44 `Route<void> reelDetailLoaderRoute(String reelId)`
- L50 `Route<void> featureAnnouncementRoute({ required String title, required String body, })`
- L59 `Route<void> howToUseRoute({bool isFirstRun = false})`
- L66 `Route<void> profileRoute()`
- L73 `Route<void> collectionDetailRoute(String collectionId, {bool animate = true})`
- L90 `Route<void> sharedCollectionRoute( String token, { bool animate = true, String? url, })`
- L108 `Route<void> paywallRoute({ PaywallEntryPoint entryPoint = PaywallEntryPoint.account, })`
- L116 `Future<void> openPaywall( BuildContext context, { PaywallEntryPoint entryPoint = PaywallEntryPoint.account, })`
- L132 `Future<void> openChat( BuildContext context, WidgetRef ref, { String seedText = '', List<ChatAttachment> seedAttachments = const [], required VoidCallback showAskTab, })`

### lib/screens/app_shell/app_shell.dart

- L43 `const _navIconSize = 27.0`
- L45 `class AppShell extends ConsumerStatefulWidget`
  - L46 `const AppShell({super.key, this.controller})`
  - L51 `ConsumerState<AppShell> createState()`
- L54 `class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver`
  - L92 `void initState()`
  - L118 `Future<void> _initCollectionDeepLinks()`
  - L147 `Future<void> _handleDeferredLink()`
  - L152 `Future<void> _handleIncomingUri(Uri uri)`
  - L165 `void _routeCollectionUri(Uri uri)`
  - L178 `Future<void> _openLaunchLink(CollectionLink link)`
  - L192 `void _routeCollectionLink(CollectionLink link, {bool animate = true})`
  - L208 `Future<void> _openSharedCollection( String token, { bool animate = true, String? url, })`
  - L220 `Future<void> _acceptCollectionInvite( String token, { bool animate = true, })`
  - L247 `void _initSharingIntent()`
  - L271 `void _processSharedData(List<SharedMediaFile> files)`
  - L279 `Future<void> _handleSharedPayload( String payload, { bool showConfirmation = true, List<String> collectionIds = const [], })`
  - L326 `Future<void> _enqueueSharedReel( String url, { required bool showConfirmation, List<String> collectionIds = const [], })`
  - L470 `void dispose()`
  - L480 `void didChangeAppLifecycleState(AppLifecycleState state)`
  - L510 `Future<void> _drainPendingNativeShares()`
  - L543 `Future<void> _runFirstRunFlow()`
  - L548 `Future<void> _maybeShowHowToGuide()`
  - L576 `Future<bool> _accountHasSaves()`
  - L582 `Future<void> _maybePromptInitialPermissions()`
  - L600 `Future<bool> _enableReelPinPermissions()`
  - L636 `Future<void> _syncPushTokenRegistrationIfPossible()`
  - L650 `void _openSearchFromHome()`
  - L658 `Future<void> _scrollHomeToTop()`
  - L667 `void _showHomeAtTop()`
  - L676 `void _selectControlledTab(int index)`
  - L684 `bool _isHomeScrolledDown()`
  - L689 `Future<void> _refreshSavedContent()`
  - L701 `void _selectTab(int index)`
  - L717 `void _refreshSelectedContent(int index)`
  - L731 `Widget build(BuildContext context)`
  - L780 `Widget _buildNavBar()`
  - L828 `Widget _buildNavItem(int index, _NavItem item)`

### lib/screens/app_shell/authenticated_shell.dart

- L19 `class AuthenticatedShell extends ConsumerStatefulWidget`
  - L20 `const AuthenticatedShell({super.key})`
  - L23 `ConsumerState<AuthenticatedShell> createState()`
- L26 `class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell>`
  - L52 `void initState()`
  - L93 `Widget build(BuildContext context)`
  - L97 `Future<void> _initializeBackgroundMessaging()`
  - L131 `Future<void> _syncPushTokenRegistration({ String? candidateToken, int retryAttempt = 1, })`
  - L184 `void _schedulePushTokenRegistrationRetry({int attempt = 1})`
  - L195 `Future<void> _refreshSavedReels()`
  - L203 `void _queueNotificationOpen(OpenedAppNotification opened)`
  - L210 `Future<void> _handleNotificationOpen(OpenedAppNotification opened)`
  - L259 `void _openShellTab(VoidCallback selectTab)`
  - L264 `Future<void> _recordNotificationOpen(String notificationId)`
  - L272 `void _clearUserScopedState()`
  - L283 `void dispose()`

### lib/screens/app_shell/partials/app_shell_controller.dart

- L8 `class AppTabLayout`
  - L9 `const AppTabLayout._({ required this.home, required this.map, required this.ask, required this.saved, required this.discover, })`
  - L17 `factory AppTabLayout.forChatEnabled(bool chatEnabled)`
- L36 `class AppShellController`
  - L37 `AppShellController()`
  - L40 `AppShellController.forTest({required bool chatEnabled})`
  - L47 `void showHome()`
  - L51 `void showMap()`
  - L55 `void showSaved()`
  - L59 `void showDiscover()`
  - L63 `void showAsk()`
  - L72 `void _select(int index)`
  - L82 `void attachForTest(ValueChanged<int> callback)`
  - L84 `void _attach(ValueChanged<int> callback)`
  - L93 `void _detach()`

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

### lib/screens/chat/chat_screen.dart

- L24 `class ChatScreen extends ConsumerStatefulWidget`
  - L25 `const ChatScreen({super.key})`
  - L28 `ConsumerState<ChatScreen> createState()`
- L31 `class _ChatScreenState extends ConsumerState<ChatScreen>`
  - L45 `void initState()`
  - L62 `void dispose()`
  - L67 `void _scrollToBottom()`
  - L82 `double _composerBottomClearance(BuildContext context)`
  - L90 `Widget build(BuildContext context)`
  - L193 `Widget _buildHeader(BuildContext context)`
  - L228 `Widget _headerButton( BuildContext context, IconData icon, VoidCallback onTap, )`
  - L249 `Widget _buildThread(ChatThread thread, ChatViewModel viewModel)`
  - L296 `List<String> _suggestions()`

### lib/screens/chat/partials/chat_empty_state.dart

- L7 `class ChatEmptyState extends StatelessWidget`
  - L8 `const ChatEmptyState({ super.key, required this.suggestions, required this.onSuggestionTap, required this.savedCount, })`
  - L26 `Widget build(BuildContext context)`

### lib/screens/collections/collection_ask_screen.dart

- L18 `class CollectionAskScreen extends ConsumerStatefulWidget`
  - L19 `const CollectionAskScreen({ super.key, required this.collectionId, required this.collectionName, required this.canEdit, })`
  - L33 `ConsumerState<CollectionAskScreen> createState()`
- L37 `class _CollectionAskScreenState extends ConsumerState<CollectionAskScreen>`
  - L43 `Widget build(BuildContext context)`
  - L90 `Widget _buildHeader(BuildContext context, CollectionChatViewModel viewModel)`
  - L154 `Widget _headerButton( BuildContext context, IconData icon, VoidCallback onTap, )`

### lib/screens/collections/collection_detail_screen.dart

- L33 `class CollectionDetailScreen extends ConsumerStatefulWidget`
  - L34 `const CollectionDetailScreen({ super.key, required this.collectionId, this.sharedToken, this.sharedUrl, this.initialName, this.offerChat = chatEnabled, })`
  - L60 `bool get isShared`
  - L63 `ConsumerState<CollectionDetailScreen> createState()`
- L67 `class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen>`
  - L78 `void initState()`
  - L113 `Future<void> _loadOwnLink()`
  - L120 `String? get _collectionShareUrl`
  - L129 `Future<void> _loadShared()`
  - L157 `Future<void> _refresh()`
  - L166 `Future<void> _edit(CollectionSummary collection)`
  - L170 `Future<void> _confirmDelete(CollectionSummary collection)`
  - L188 `Future<void> _confirmLeave(CollectionSummary collection)`
  - L203 `Future<void> _confirmRemoveReel(Reel reel)`
  - L221 `Future<void> _runGuarded( Future<void> Function() action, { required String fallback, bool popOnSuccess = false, })`
  - L241 `Widget build(BuildContext context)`
  - L377 `void _openAsk(CollectionSummary collection, {required bool canEdit})`
  - L389 `Widget _buildHeader( BuildContext context, CollectionsViewModel vm, CollectionSummary? collection, { required bool canEdit, })`
  - L469 `List<Widget> _buildContent( BuildContext context, { required bool ownsReels, required CollectionDetail? detail, required bool isLoading, required String? error, required bool canEdit, })`
  - L545 `Widget _buildReelGrid( BuildContext context, List<Reel> reels, { required bool canEdit, required bool ownsReels, required List<ProcessingJob> processingJobs, })`
  - L629 `Widget _buildPaginationState(BuildContext context, CollectionDetail detail)`
  - L653 `Widget _buildLoading(BuildContext context)`
- L668 `class _HeaderAction extends StatelessWidget`
  - L669 `const _HeaderAction({ required this.icon, required this.onTap, this.color, this.iconColor, })`
  - L682 `Widget build(BuildContext context)`
- L701 `class _SharedBanner extends StatelessWidget`
  - L702 `const _SharedBanner()`
  - L705 `Widget build(BuildContext context)`
- L735 `class _MessageCard extends StatelessWidget`
  - L736 `const _MessageCard({ required this.title, required this.body, this.icon, this.onRetry, })`
  - L749 `Widget build(BuildContext context)`

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

### lib/screens/collections/partials/collection_chat_panel.dart

- L27 `class CollectionChatPanel extends ConsumerStatefulWidget`
  - L28 `const CollectionChatPanel({ super.key, required this.collectionId, required this.canEdit, })`
  - L41 `ConsumerState<CollectionChatPanel> createState()`
- L45 `class _CollectionChatPanelState extends ConsumerState<CollectionChatPanel>`
  - L52 `void initState()`
  - L70 `Widget build(BuildContext context)`
  - L125 `Widget _thread( CollectionChatViewModel viewModel, List<ChatMessage> rawMessages, )`
  - L189 `Widget _empty(BuildContext context)`
  - L211 `Widget _failed(BuildContext context, CollectionChatViewModel viewModel)`

### lib/screens/collections/partials/collection_sticky_note.dart

- L7 `const double _pinAngle = -0.28`
- L9 `class _CollectionStickyNote extends StatelessWidget`
  - L10 `const _CollectionStickyNote({ required this.note, required this.canEdit, this.onEdit, })`
  - L23 `Widget build(BuildContext context)`
- L196 `class _StickyNoteClipper extends CustomClipper<Path>`
  - L198 `Path getClip(Size size)`
  - L213 `bool shouldReclip(covariant CustomClipper<Path> oldClipper)`

### lib/screens/collections/partials/collection_tab_bar.dart

- L9 `class _CollectionTabBar extends StatelessWidget`
  - L10 `const _CollectionTabBar({required this.onAsk})`
  - L15 `Widget build(BuildContext context)`
  - L38 `Widget _tab( BuildContext context, { required String label, required bool selected, required VoidCallback? onTap, })`

### lib/screens/discover/discover_screen.dart

- L25 `class DiscoverScreen extends ConsumerStatefulWidget`
  - L26 `const DiscoverScreen({super.key, this.focusRequestId = 0})`
  - L31 `ConsumerState<DiscoverScreen> createState()`
- L34 `class _DiscoverScreenState extends ConsumerState<DiscoverScreen>`
  - L44 `void initState()`
  - L57 `void dispose()`
  - L66 `void didUpdateWidget(covariant DiscoverScreen oldWidget)`
  - L71 `void _handleControllerTextChanged()`
  - L80 `void _scheduleFocusIfRequested()`
  - L92 `Widget build(BuildContext context)`
  - L291 `void _handleSearchChanged(SearchViewModel vm, String query)`
  - L306 `void _doSearch(SearchViewModel vm, String query)`
  - L317 `Widget? _buildSearchFieldAction(BuildContext context, SearchViewModel vm)`
  - L348 `void _clearSearch(SearchViewModel vm, {bool keepFocus = false})`
  - L369 `void _clearDateFilter()`
  - L373 `Future<void> _openCategory(DiscoverCategory category)`
  - L387 `Future<void> _pickSavedDate(BuildContext context)`
  - L424 `Widget _buildNoResults(BuildContext context, String query)`
  - L478 `Widget _buildMinimumQueryState(BuildContext context, String query)`
  - L533 `Widget _buildDiscoverContent( BuildContext context, DiscoverViewModel discoverVm, )`
  - L696 `Widget _buildDiscoverError( BuildContext context, DiscoverViewModel discoverVm, )`
  - L737 `Widget _buildCategoryReelsContent( BuildContext context, DiscoverViewModel discoverVm, )`
  - L838 `Widget _buildCategoryReelsError( BuildContext context, DiscoverViewModel discoverVm, )`
  - L878 `Widget _buildCategoryReelsEmpty(BuildContext context, String categoryLabel)`
  - L903 `Widget _buildCategoryReelGrid(BuildContext context, List<Reel> reels)`
  - L948 `Widget _buildDateEmptyState(BuildContext context, String selectedDateLabel)`
  - L991 `Widget _buildQuickSearches(BuildContext context, List<String> prompts)`
  - L1030 `Widget _buildRecentSaves(BuildContext context, List<Reel> reels)`
  - L1133 `Widget _buildCategoryGrid( BuildContext context, List<DiscoverCategory> categories, )`
  - L1226 `Widget _buildSearchingState(BuildContext context)`
  - L1265 `Widget _buildResults(BuildContext context, SearchViewModel vm)`
  - L1327 `Widget _buildError(BuildContext context, SearchViewModel vm)`

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
  - L321 `Widget _buildPaginationState(BuildContext context, HomeViewModel vm)`
  - L385 `Widget _buildSearchButton(BuildContext context)`
  - L402 `Widget _buildFilterButton( BuildContext context, HomeViewModel vm, ReelFiltersViewModel filtersVm, )`
  - L441 `bool _showFreeHistoryBanner(UserEntitlement? entitlements)`
  - L445 `Widget _buildFreePlanBanner( BuildContext context, EntitlementsResponse entitlements, )`
  - L512 `Widget _buildReelGrid( BuildContext context, HomeViewModel vm, List<ProcessingJob> processingJobs, )`
  - L593 `Widget _buildShimmerGrid(BuildContext context)`
  - L640 `Widget _buildEmptyState(BuildContext context)`
  - L693 `Widget _buildEmptyFlow(BuildContext context)`
  - L738 `Widget _emptyFlowTile( BuildContext context, { required IconData icon, required String title, required String caption, required Color color, required Color iconColor, Color? textColor, })`
  - L792 `Widget _flowArrow(BuildContext context)`
  - L809 `Widget _buildGuideButton(BuildContext context)`
  - L879 `Widget _buildFirstSaveHint(BuildContext context)`
  - L928 `String _supportedPlatformSentence()`
  - L936 `Widget _platformIconBadge(BuildContext context, SourcePlatform platform)`
  - L957 `Widget _buildErrorState(BuildContext context, HomeViewModel vm)`
  - L1041 `void _showFilterSheet( BuildContext context, HomeViewModel vm, ReelFiltersViewModel filtersVm, )`
  - L1442 `String _activeFilterLabel({ required ReelFiltersViewModel filtersVm, required String? platform, required String? category, required String? subcategory, })`
  - L1458 `String _filterHint({ required String? platform, required String? category, required bool hasSubcategories, })`
  - L1474 `Widget _buildFilterSheetStatus( BuildContext context, { required String label, })`
  - L1507 `Widget _buildFilterSheetError( BuildContext context, ReelFiltersViewModel filtersVm, )`
  - L1563 `Widget _buildFilterSheetEmpty(BuildContext context)`
  - L1579 `Widget _buildCompactFilterSummary( BuildContext context, { required String activeFilterLabel, required int previewCount, required int totalCount, required Color currentAccentColor, required ReelPlatformGroup? topPlatform, })`
  - L1618 `Widget _buildFilterInfoCard( BuildContext context, { required String label, required String title, required String subtitle, required Color accentColor, })`
  - L1684 `Widget _buildFilterDropdownField( BuildContext context, { required String label, required String hint, required String? value, required bool enabled, required Color accentColor, required List<_FilterOption> items, required ValueChanged<String?> onChanged, })`
  - L1799 `Widget _buildCountBadge( BuildContext context, int count, { required Color backgroundColor, })`
- L1830 `class _SelectionBar extends StatelessWidget`
  - L1831 `const _SelectionBar({ required this.count, required this.onCancel, required this.onAdd, required this.onDelete, })`
  - L1844 `Widget build(BuildContext context)`
- L1908 `class _SelectionAction extends StatelessWidget`
  - L1909 `const _SelectionAction({ required this.icon, required this.color, required this.iconColor, required this.onTap, this.label, })`
  - L1927 `Widget build(BuildContext context)`

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

- L26 `class MapScreen extends ConsumerStatefulWidget`
  - L27 `const MapScreen({super.key})`
  - L30 `ConsumerState<MapScreen> createState()`
- L33 `class _MapScreenState extends ConsumerState<MapScreen>`
  - L70 `void initState()`
  - L82 `void didChangeDependencies()`
  - L94 `Future<void> _initUserLocation()`
  - L116 `void _centerMapOnUserCountry()`
  - L131 `void _recenterToUserLocation()`
  - L141 `Future<void> _refreshMapPins()`
  - L145 `Future<void> _openPlaceSearchSheet()`
  - L165 `void _focusMapItem(MapItem item)`
  - L174 `void _handleMapViewModelChanged()`
  - L178 `void _scheduleVisibleMarkerSync()`
  - L189 `Future<void> _syncVisibleMarkers(MapViewModel mapVm)`
  - L239 `Future<BitmapDescriptor> _createCustomPin(String category)`
  - L242 `void _fitMarkers(Set<Marker> markers)`
  - L269 `Widget build(BuildContext context)`
  - L605 `Widget _mapButton({required IconData icon, required VoidCallback onTap})`
  - L622 `Set<Marker> _buildMarkers(MapViewModel vm)`
  - L645 `Widget _buildPinSheet(BuildContext context, MapItem item)`
  - L885 `Future<void> _confirmRemoveMapItem(BuildContext context, MapItem item)`
  - L915 `void dispose()`

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
  - L416 `List<MapPlaceSearchResult> _savedResults(List<MapPlaceSearchResult> results)`
  - L422 `String _placeResultKey(MapPlaceSearchResult result, int index)`
- L432 `enum _PlaceSearchTab`
- L434 `class _PlaceSearchTabs extends StatelessWidget`
  - L435 `const _PlaceSearchTabs({ required this.selectedTab, required this.allCount, required this.savedCount, required this.onChanged, })`
  - L448 `Widget build(BuildContext context)`
- L482 `class _PlaceSearchTabButton extends StatelessWidget`
  - L483 `const _PlaceSearchTabButton({ required this.label, required this.count, required this.isSelected, required this.onTap, })`
  - L496 `Widget build(BuildContext context)`
- L546 `class _PlaceSearchNotice extends StatelessWidget`
  - L547 `const _PlaceSearchNotice()`
  - L550 `Widget build(BuildContext context)`
- L582 `class _PlaceSearchMessage extends StatelessWidget`
  - L583 `const _PlaceSearchMessage({ required this.icon, required this.title, required this.accentColor, this.body, this.isLoading = false, })`
  - L598 `Widget build(BuildContext context)`
- L664 `class _PlaceSearchSummary extends StatelessWidget`
  - L665 `const _PlaceSearchSummary({ required this.count, required this.query, required this.tab, })`
  - L676 `Widget build(BuildContext context)`
- L715 `class _MapPlaceResultTile extends StatelessWidget`
  - L716 `const _MapPlaceResultTile({ required this.result, required this.isSaving, required this.onTap, })`
  - L727 `Widget build(BuildContext context)`
  - L844 `String _firstNonEmpty(List<String?> values)`

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
  - L40 `void initState()`
  - L50 `Future<void> _hydrateStats()`
  - L58 `Future<void> _loadStats()`
  - L95 `Widget build(BuildContext context)`
  - L398 `Future<void> _confirmDeleteAccount()`
  - L424 `Future<bool?> _showDeleteAccountDialog({ required String title, required String message, required String actionLabel, })`
  - L437 `Widget _sectionTitle(BuildContext context, String text)`
  - L450 `Widget _divider(BuildContext context)`
  - L459 `Widget _statTile( BuildContext context, { required String value, required String label, required Color color, })`
  - L496 `Widget _buildStatsCard(BuildContext context, LibraryStats? stats)`
  - L544 `Widget _actionCard( BuildContext context, { required Color color, required String title, required String subtitle, required Widget trailing, })`

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

- L32 `class _ShareLocationLink`
  - L36 `const _ShareLocationLink(this.label, this.url)`
- L39 `const String _appStoreUrl = appStoreUrl`
- L40 `const String _playStoreUrl = playStoreUrl`
- L44 `final RegExp _pinterestHostRegex = RegExp`
- L48 `Uri? locationMapsUri(Location loc)`
- L59 `String? _firstNonEmpty(List<String?> values)`
- L69 `class ReelDetailScreen extends ConsumerStatefulWidget`
  - L89 `const ReelDetailScreen({ super.key, required this.reel, this.readOnly = false, this.collectionUrl, this.refreshOnOpen = true, })`
  - L98 `ConsumerState<ReelDetailScreen> createState()`
- L101 `class _ReelDetailScreenState extends ConsumerState<ReelDetailScreen>`
  - L109 `Reel get reel`
  - L110 `String get _savedItemNoun`
  - L123 `String get _untitledLabel`
  - L124 `String get _openSourceLabel`
  - L125 `String get _openSourceErrorLabel`
  - L126 `String get _openSourceNoun`
  - L141 `String? get _sourcePlatform`
  - L158 `bool get _isShortsSource`
  - L164 `bool get _isInstagramPostSource`
  - L180 `Iterable<Uri> get _sourceUris sync*`
  - L194 `bool _hasSourceUri(bool Function(Uri uri) test)`
  - L196 `bool _isYoutubeUri(Uri uri)`
  - L204 `bool _isTikTokUri(Uri uri)`
  - L207 `bool _isYoutubeShortsUri(Uri uri)`
  - L213 `bool _isInstagramUri(Uri uri)`
  - L218 `bool _isXUri(Uri uri)`
  - L229 `bool _isPinterestUri(Uri uri)`
  - L234 `bool _isRedditUri(Uri uri)`
  - L239 `bool _isLinkedInUri(Uri uri)`
  - L242 `bool _isHostOrSubdomainOf(String host, String domain)`
  - L245 `bool _isInstagramPostUri(Uri uri)`
  - L251 `bool _isInstagramReelUri(Uri uri)`
  - L257 `Color get _detailTextColor`
  - L262 `void initState()`
  - L274 `Widget build(BuildContext context)`
  - L856 `Color _contrastText(Color bg)`
  - L860 `Widget _sectionTitle(String title)`
  - L883 `Widget _section(String title, String body)`
  - L902 `Widget _buildLockedHistoryState(BuildContext context)`
  - L960 `Future<void> _shareReel()`
  - L1020 `String get _shareTitle`
  - L1027 `String _shareText(String? reelUrl)`
  - L1067 `List<_ShareLocationLink> _shareLocationLinks()`
  - L1083 `String _shareLocationLabel(Location location)`
  - L1092 `String? get _shareReelUrl`
  - L1107 `Widget _shareButton(AppLayout layout, {required EdgeInsetsGeometry margin})`
  - L1153 `Widget _askAboutButton(AppLayout layout)`
  - L1181 `Future<void> _confirmDelete(BuildContext context)`
  - L1226 `T? _maybeRead<T>(ProviderListenable<T> provider)`
  - L1234 `Uri? _locationMapsUri(Location loc)`
  - L1238 `Future<void> _openLocation(Uri uri)`
  - L1244 `Future<void> _openReel()`
  - L1258 `Uri? get _openReelUrl`
  - L1273 `Uri? _externalUri(String rawUrl)`
  - L1286 `void _showOpenReelError()`
  - L1301 `Future<void> _refreshReel()`

### lib/screens/setup_required/setup_required_screen.dart

- L8 `class SetupRequiredScreen extends StatelessWidget`
  - L9 `const SetupRequiredScreen({super.key})`
  - L12 `Widget build(BuildContext context)`

### lib/screens/splash/splash_screen.dart

- L7 `class SplashScreen extends StatelessWidget`
  - L8 `const SplashScreen({super.key})`
  - L11 `Widget build(BuildContext context)`

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
  - L152 `Future<void> write(String key, Map<String, dynamic> payload)`
  - L172 `Future<void> _write( String key, { required String userId, required Map<String, dynamic> payload, })`
  - L195 `Future<void> invalidate(String key)`
  - L213 `Future<void> invalidateContent()`
  - L218 `Future<void> clear()`
  - L233 `Future<File?> _fileFor(String key)`
  - L249 `Future<Directory> _directory()`
  - L263 `static Future<Directory> _createDirectory()`

### lib/services/chat/chat_reel_cache.dart

- L14 `class ChatReelCache`
  - L15 `ChatReelCache(this._fetchReel)`
  - L34 `Reel? cached(String reelId)`
  - L41 `Future<Reel?> resolve(String reelId)`
  - L48 `Future<Reel?> _fetchAndCache(String reelId)`

### lib/services/chat/chat_thread_store.dart

- L18 `class ChatThreadStore`
  - L19 `ChatThreadStore({SharedPreferences? preferences})`
  - L26 `Future<SharedPreferences> get _prefs async`
  - L29 `Future<List<ChatThread>> load(String userId)`
  - L54 `Future<void> save(String userId, List<ChatThread> threads)`
  - L65 `Future<void> clear()`

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
  - L32 `bool get _supportsNativeHandoff`
  - L37 `Future<String?> getShareToken()`
  - L43 `Future<void> setShareToken(String? token)`
  - L54 `Future<void> syncAuthenticatedUser(String userId, String? accessToken)`
  - L82 `Future<bool> isCollectionPickerEnabled()`
  - L96 `Future<void> setCollectionPickerEnabled( bool enabled, List<CollectionSummary> collections, { Future<Map<String, String>> Function({ required String directory, required List<CollectionSummary> collections, })? renderTiles, })`
  - L124 `Future<void> syncCollections( List<CollectionSummary> collections, { Future<Map<String, String>> Function({ required String directory, required List<CollectionSummary> collections, })? renderTiles, })`
  - L180 `Future<void> syncPushToken({ required String token, required String platform, })`
  - L197 `Future<void> clearPushToken()`
  - L204 `Future<void> clear()`
  - L222 `Future<String?> drainPendingShares()`
  - L235 `Future<String?> _shareAssetsDirectory()`
  - L247 `Future<void> _syncNative()`

### lib/services/sharing/shared_collection_prefetch.dart

- L14 `class SharedCollectionPrefetch`
  - L15 `SharedCollectionPrefetch._()`
  - L21 `static void start(String token, Future<CollectionDetail> Function() load)`
  - L32 `static Future<CollectionDetail>? take(String token)`

### lib/utils/answer_text_parser.dart

- L17 `List<AnswerTextSegment> parseAnswerText(String text)`
- L55 `final _headingCharset = RegExp`
- L56 `final _hasLetter = RegExp`
- L57 `const _bulletPrefixes = ['- ', '• ', '* ']`
- L59 `bool _isHeading(String trimmed)`
- L67 `String? _bulletText(String trimmed)`
- L77 `class BoldRun`
  - L81 `const BoldRun(this.text, this.bold)`
  - L84 `bool operator ==(Object other)`
  - L88 `int get hashCode`
- L91 `final _boldMarker = RegExp`
- L95 `List<BoldRun> parseBoldRuns(String text)`

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

- L14 `Future<BitmapDescriptor> createCategoryMarkerIcon(String category)`
- L24 `Future<Uint8List> createCategoryMarkerPng(String category)`

### lib/utils/error_message.dart

- L7 `String userFacingErrorMessage( Object error, { String fallbackMessage = 'Something went wrong. Please try again.', })`
- L30 `bool _looksTechnicalError(String message)`
- L45 `String _technicalErrorFallback(ApiException error, String fallbackMessage)`

### lib/utils/location_maps_uri.dart

- L3 `Uri? locationMapsSearchUri({ String? name, String? displayLabel, String? address, String? backendUrl, double? latitude, double? longitude, })`
- L31 `Uri? _externalLocationUri(String? rawUrl)`
- L44 `String? _firstNonEmpty(List<String?> values)`

### lib/view_models/chat_view_model.dart

- L11 `class ChatViewModel extends ChangeNotifier`
  - L12 `ChatViewModel( this._http, this._store, { required String Function() currentUserId, })`
  - L42 `List<ChatThread> get threads`
  - L43 `List<ThinkingStage> get stages`
  - L44 `List<String> get suggestions`
  - L48 `bool get isAnswering`
  - L50 `String get seedText`
  - L51 `List<ChatAttachment> get seedAttachments`
  - L54 `ChatThread? get activeThread`
  - L61 `Future<void> hydrate()`
  - L69 `Future<void> loadSuggestions()`
  - L83 `ChatThread _downgradeStaleSending(ChatThread thread)`
  - L99 `void startNewThread({ String? seedText, List<ChatAttachment> seedAttachments = const [], })`
  - L110 `void openThread(String threadId)`
  - L118 `void consumeSeed()`
  - L134 `List<ChatHistoryEntry> _historyFrom(List<ChatMessage> messages)`
  - L160 `Future<void> send( String text, { List<ChatAttachment> attachments = const [], })`
  - L206 `Future<void> retryLast()`
  - L250 `Future<void> _consume( String threadId, String pendingId, String question, List<ChatAttachment> attachments, List<ChatHistoryEntry> history, )`
  - L289 `void _applyStage(String threadId, ThinkingStage stage)`
  - L301 `void _completeAnswer( String threadId, String pendingId, List<AnswerBlock> blocks, )`
  - L314 `void _failAnswer(String threadId, String pendingId)`
  - L324 `void _updateMessage( String threadId, String messageId, ChatMessage Function(ChatMessage) transform, )`
  - L340 `ChatThread _createThread(String question, DateTime now)`
  - L352 `void _replaceThread(ChatThread thread)`
  - L361 `Future<void> _persist()`
  - L369 `void reset()`

### lib/view_models/collection_chat_view_model.dart

- L25 `class CollectionChatViewModel extends ChangeNotifier`
  - L26 `CollectionChatViewModel( this._http, this.collectionId, { Duration pollInterval = const Duration(seconds: 8), ContentCache? cache, })`
  - L51 `List<CollectionChatThread> get threads`
  - L55 `String? get activeThreadId`
  - L56 `List<ChatMessage> get messages`
  - L57 `List<ThinkingStage> get stages`
  - L58 `bool get isAsking`
  - L59 `bool get isLoading`
  - L60 `String? get error`
  - L66 `bool get hasLoaded`
  - L68 `String get _threadsKey`
  - L69 `String _messagesKey(String threadId)`
  - L79 `Future<void> load()`
  - L106 `void openThread(String threadId)`
  - L119 `void startNewThread()`
  - L137 `Future<void> pollOnce()`
  - L163 `void startPolling()`
  - L168 `void stopPolling()`
  - L173 `Future<void> ask( String text, { List<ChatAttachment> attachments = const [], })`
  - L250 `Future<void> _loadActiveThread()`
  - L276 `Future<void> _hydrateFromCache(bool Function() fetched)`
  - L289 `Future<void> _hydrateMessages( String threadId, bool Function() fetched, )`
  - L304 `Future<void> _reloadQuietly(String threadId)`
  - L316 `void _setThreads(List<CollectionChatThread> threads)`
  - L327 `void _setMessages(String threadId, List<ChatMessage> messages)`
  - L341 `static Map<String, dynamic> _messageJson(ChatMessage message)`
  - L347 `void _applyStage(ThinkingStage stage)`
  - L358 `void _completePending(String pendingId, List<AnswerBlock> blocks)`
  - L363 `void _failPending(String pendingId)`
  - L366 `void _replace(String id, ChatMessage Function(ChatMessage) transform)`
  - L374 `void _notify()`
  - L380 `void dispose()`

### lib/view_models/collections_view_model.dart

- L14 `class CollectionsViewModel extends ChangeNotifier`
  - L15 `CollectionsViewModel(this._api, {ContentCache? cache, this.renderShareTiles})`
  - L56 `List<CollectionSummary> get collections`
  - L57 `bool get isLoadingCollections`
  - L58 `String? get collectionsError`
  - L59 `bool isLoadingDetailFor(String id)`
  - L60 `String? detailErrorFor(String id)`
  - L61 `bool get isMutating`
  - L65 `Future<void> get detailWarmUp`
  - L67 `CollectionDetail? detailFor(String id)`
  - L71 `bool isDetailPlaceholder(String id)`
  - L79 `void bumpToFront(String collectionId)`
  - L93 `void seedDetailFromSummary(String id)`
  - L110 `Future<void> hydrateFromCache()`
  - L132 `Future<void> loadCollections({bool forceRefresh = false})`
  - L142 `Future<void> _loadCollections()`
  - L175 `Future<void> hydrateDetailFromCache(String id)`
  - L189 `bool _hasRealDetail(String id)`
  - L199 `Future<void> _warmDetails(List<CollectionSummary> summaries)`
  - L210 `Future<void> _warmDetail(CollectionSummary summary)`
  - L222 `Future<void> loadCollectionDetail(String id, {bool forceRefresh = false})`
  - L233 `Future<void> _loadCollectionDetail(String id)`
  - L259 `Future<void> loadMore(String id)`
  - L278 `Future<CollectionSummary?> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L298 `Future<void> updateCollection({ required String collectionId, String? name, String? description, })`
  - L317 `Future<void> deleteCollection(String id)`
  - L333 `Future<void> addReelsToCollections({ required List<String> collectionIds, required List<String> reelIds, })`
  - L357 `Future<void> removeReel({ required String collectionId, required String reelId, })`
  - L381 `Future<CollectionLink?> enableLink(String id)`
  - L390 `Future<void> disableLink(String id)`
  - L397 `Future<CollectionMembers?> loadMembers(String id)`
  - L405 `Future<void> removeMember({ required String collectionId, required String memberUserId, })`
  - L417 `Future<CollectionInvite?> createInvite({ required String collectionId, required String role, })`
  - L431 `Future<void> leave(String id)`
  - L440 `Future<CollectionSummary?> acceptInvite(String token)`
  - L449 `Future<void> _mutate(Future<void> Function() action)`
  - L464 `Future<void> _syncShareTargets()`
  - L471 `void _upsert(CollectionSummary collection)`
  - L480 `void _setVisibility(String id, String visibility)`

### lib/view_models/discover_view_model.dart

- L13 `class DiscoverViewModel extends ChangeNotifier`
  - L14 `DiscoverViewModel(this._repository)`
  - L32 `DiscoverResponse? get discover`
  - L33 `ReelPage? get categoryReelsPage`
  - L34 `bool get isLoadingDiscover`
  - L35 `bool get isLoadingCategoryReels`
  - L36 `String? get discoverError`
  - L37 `String? get categoryReelsError`
  - L38 `String? get selectedSavedDate`
  - L39 `String? get selectedSavedDateLabel`
  - L40 `String? get selectedCategory`
  - L41 `String? get selectedCategoryLabel`
  - L42 `int? get selectedCategoryExpectedCount`
  - L46 `Future<void> hydrateFromCache()`
  - L72 `Future<void> loadDiscover({bool forceRefresh = false})`
  - L105 `Future<void> selectSavedDate(SavedDateOption option)`
  - L113 `Future<void> clearDateFilter()`
  - L121 `Future<void> openCategory(DiscoverCategory category)`
  - L163 `void clearCategorySelection()`
  - L175 `void clearTransientSelection()`
  - L197 `void removeReel(String reelId)`
  - L266 `void reset()`
  - L283 `void _clearCategorySelectionInState()`
  - L292 `String? _labelForSavedDate(DiscoverResponse response, String? savedDate)`
  - L304 `List<Reel> _withoutReel(List<Reel> reels, String reelId)`

### lib/view_models/entitlements_view_model.dart

- L18 `class EntitlementsViewModel extends ChangeNotifier`
  - L19 `EntitlementsViewModel( this._accountHttp, this._authService, this._repository, this._homeViewModel, this._mapViewModel, this._reelFiltersViewModel, this._discoverViewModel, this._searchViewModel, )`
  - L45 `EntitlementsResponse? get response`
  - L46 `UserEntitlement? get entitlement`
  - L47 `bool get isLoading`
  - L48 `String? get error`
  - L49 `bool get hasEntitlement`
  - L54 `Future<void> hydrateFromCache()`
  - L74 `Future<void> refresh({bool reloadContent = false})`
  - L96 `Future<void> _refresh({required bool reloadContent})`
  - L164 `void reset()`

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

- L13 `class MapViewModel extends ChangeNotifier`
  - L16 `MapViewModel(this._mapHttp)`
  - L37 `List<MapItem> get mapItems`
  - L38 `bool get isLoading`
  - L39 `bool get isLoadingMore`
  - L40 `bool get hasMoreReels`
  - L41 `String? get error`
  - L42 `String? get selectedCategory`
  - L43 `MapItem? get selectedMapItem`
  - L44 `int get totalPinnedLocations`
  - L45 `int get visiblePinnedLocations`
  - L46 `List<MapPlaceSearchResult> get placeSearchResults`
  - L48 `bool get isSearchingPlaces`
  - L49 `bool get isPlaceSuggestionUnavailable`
  - L50 `bool get isSavingMapPin`
  - L51 `bool get isRemovingMapPin`
  - L52 `String? get placeSearchError`
  - L53 `String? get mapPinActionError`
  - L54 `String get lastPlaceQuery`
  - L57 `List<Reel> get reelsWithLocations`
  - L61 `Reel? get selectedReel`
  - L64 `Location? get selectedLocation`
  - L68 `Future<void> hydrateFromCache()`
  - L91 `Future<void> loadMapReels({bool forceRefresh = false})`
  - L121 `Future<void> loadMoreReels()`
  - L123 `void filterByCategory(String? category)`
  - L131 `void selectMapItem(MapItem? item)`
  - L136 `void selectReel(Reel? reel, {Location? location})`
  - L142 `void reset()`
  - L164 `Future<void> searchMapPlaces(String query)`
  - L215 `Future<MapItem?> pinPlace(MapPlaceSearchResult result)`
  - L248 `Future<bool> removeMapItem(MapItem item)`
  - L288 `void clearPlaceSearch()`
  - L300 `void _upsertMapItem(MapItem item)`
  - L313 `void upsertProcessedReel(Reel reel)`
  - L317 `void removeReel(String reelId)`

### lib/view_models/processing_jobs_view_model.dart

- L16 `class ProcessingJobsViewModel extends ChangeNotifier`
  - L17 `ProcessingJobsViewModel(this._repository, {this.onJobsFinished})`
  - L59 `List<ProcessingJob> get jobs`
  - L60 `bool get hasJobs`
  - L64 `bool isSettling(String jobId)`
  - L69 `List<ProcessingJob> jobsForCollection(String collectionId)`
  - L82 `void trackEnqueued( ProcessingJob job, { List<String> collectionIds = const [], })`
  - L105 `Future<void> refresh()`
  - L120 `Future<void> _applyServerJobs(List<ProcessingJob> latest)`
  - L187 `bool _isStillShown(String jobId, Set<String> activeIds)`
  - L200 `bool _isAbandoned(ProcessingJob job)`
  - L208 `void _syncTimer()`
  - L228 `Duration _pollInterval()`
  - L240 `void setForeground(bool isForeground)`
  - L246 `void reset()`
  - L257 `void dispose()`

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
  - L16 `ReelFiltersViewModel(this._repository)`
  - L24 `ReelFiltersResponse? get response`
  - L26 `List<ReelPlatformGroup> get platforms`
  - L31 `List<ReelCategoryGroup> get categoryGroups`
  - L34 `List<String> get categories`
  - L37 `int get totalCount`
  - L38 `int get selectedPreviewCount`
  - L39 `String? get topPlatform`
  - L40 `bool get isLoading`
  - L41 `String? get error`
  - L42 `bool get hasPlatforms`
  - L43 `bool get hasGroups`
  - L45 `ReelPlatformGroup? platformNamed(String? platform)`
  - L50 `List<ReelCategoryGroup> categoriesFor(String? platform)`
  - L57 `int previewCountFor({ String? platform, String? category, String? subcategory, })`
  - L86 `void reset()`
  - L95 `Future<void> hydrateFromCache()`
  - L116 `Future<void> loadFilters({ bool forceRefresh = false, String? platform, String? category, String? subcategory, })`

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
  - L52 `Session? get session`
  - L53 `User? get currentUser`
  - L55 `bool get isAuthenticated`
  - L56 `bool get isSigningIn`
  - L57 `bool get isSigningOut`
  - L58 `bool get isDeletingAccount`
  - L59 `bool get isBusy`
  - L60 `String? get error`
  - L61 `String? get statusMessage`
  - L63 `String get email`
  - L65 `String get displayName`
  - L85 `String? get avatarUrl`
  - L88 `String get initials`
  - L104 `Future<void> signInWithGoogle()`
  - L129 `Future<void> signInWithApple()`
  - L155 `Future<void> signOut()`
  - L188 `Future<bool> deleteAccount()`
  - L221 `Future<bool> signInWithEmail({ required String email, required String password, })`
  - L252 `Future<bool> signUpWithEmail({ required String email, required String password, String? fullName, })`
  - L295 `void clearError()`
  - L301 `void clearStatusMessage()`
  - L314 `Future<void> _bootstrap()`
  - L319 `Future<void> _syncProfileSilently()`
  - L329 `Future<void> _syncShareHandoffState()`
  - L345 `Future<void> _ensureShareToken()`
  - L358 `String? _readString(Map<String, dynamic>? source, List<String> keys)`
  - L371 `String _normalizeError(Object error)`
  - L382 `bool _looksTechnicalError(String message)`
  - L395 `void dispose()`

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
  - L17 `UserStateCoordinator({ required SearchViewModel searchViewModel, required ReelFiltersViewModel reelFiltersViewModel, required MapViewModel mapViewModel, required HomeViewModel homeViewModel, required DiscoverViewModel discoverViewModel, required ReelRepository reelRepository, required EntitlementsViewModel entitlementsViewModel, required ProcessingJobsViewModel processingJobsViewModel, required ChatViewModel chatViewModel, })`
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

- L24 `void main()`
- L197 `Future<void> _pumpPageTransition(WidgetTester tester)`
- L202 `void _sizeView(WidgetTester tester)`
- L211 `Future<void> _capturePendingLink(WidgetTester tester, String url)`
- L227 `Widget _appEntry({MockCollectionsHttp? collectionsHttp})`
- L240 `Future<void> _pumpAppEntry(WidgetTester tester)`
- L256 `class _FakeSessionViewModel extends SessionViewModel`
  - L257 `_FakeSessionViewModel(AuthService authService)`
- L265 `class _FakeAuthService extends AuthService`
  - L266 `_FakeAuthService()`
  - L269 `Session? get currentSession`
  - L272 `User? get currentUser`
  - L275 `Stream<AuthState> get authStateChanges`
  - L278 `Future<void> ensureProfile()`
- L281 `class _RecordingCollectionsHttp extends MockCollectionsHttp`
  - L282 `_RecordingCollectionsHttp(this.onFetch)`
  - L287 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`

### test/components/chat/answer_blocks_test.dart

- L11 `Widget _host(Widget child)`
- L17 `ChatReelCache _failingCache()`
- L20 `Reel _reel(String id, String title)`
- L36 `void main()`

### test/components/chat/chat_answer_actions_test.dart

- L7 `ChatMessage _answer(List<AnswerBlock> blocks)`
- L14 `void main()`

### test/components/chat/chat_answer_card_test.dart

- L8 `ChatReelCache _reelCache()`
- L11 `Widget _host(Widget child)`
- L15 `ChatMessage _answer({ List<AnswerBlock> blocks = const [], MessageStatus status = MessageStatus.complete, })`
- L26 `void main()`

### test/components/chat/chat_answer_text_test.dart

- L6 `Widget _host(String text)`
- L10 `Color _dotColor(WidgetTester tester, String bulletText)`
- L20 `void main()`

### test/components/chat/chat_composer_test.dart

- L6 `Widget _host({ required String initialText, List<ChatAttachment> pending = const [], })`
- L21 `void main()`

### test/components/chat/chat_places_block_test.dart

- L6 `Widget _host(Widget child)`
- L10 `void main()`

### test/components/chat/chat_reel_strip_card_test.dart

- L6 `Widget _host(Widget child)`
- L10 `const _reel = Reel`
- L28 `void main()`

### test/components/chat/chat_reel_strip_test.dart

- L9 `Widget _host(Widget child)`
- L13 `Reel _reel(String id, String title)`
- L29 `void main()`

### test/components/chat/chat_thinking_stages_test.dart

- L6 `Widget _host(Widget child)`
- L10 `void main()`

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

### test/data_models/chat/chat_thread_test.dart

- L8 `void main()`

### test/data_models/chat/collection_chat_page_test.dart

- L7 `void main()`

### test/data_models/collection_models_test.dart

- L5 `void main()`
- L191 `const _itemJson = {`

### test/data_models/map/map_place_search_response_test.dart

- L4 `void main()`

### test/data_models/notifications/app_notification_test.dart

- L6 `void main()`

### test/data_models/reels/processing_job_test.dart

- L5 `void main()`

### test/data_models/reels/reel_filters_test.dart

- L4 `Map<String, dynamic> _response()`
- L72 `void main()`

### test/data_models/reels/reel_test.dart

- L6 `void main()`
- L162 `Map<String, Object?> _reelJson(Map<String, Object?> overrides)`

### test/data_models/sharing/pending_share_test.dart

- L4 `void main()`

### test/env_test.dart

- L6 `void main()`

### test/fixtures/api_v2.dart

- L9 `class ApiV2Fixture`
  - L10 `ApiV2Fixture(String name)`
  - L17 `int get status`
  - L19 `Map<String, dynamic> get body`
  - L21 `http.Response toResponse()`

### test/http/api_client_test.dart

- L16 `final _uuidV4 = RegExp`
- L20 `void main()`

### test/http/collections_api_client_test.dart

- L12 `void main()`
- L534 `Map<String, Object?> _error(String code, String message)`
- L543 `const _summaryJson = {`
- L557 `const _itemJson = {`
- L570 `const _detailJson = {`

### test/http/mock_chat_http_test.dart

- L7 `Reel _reel(String id, String title, String category, String subCategory)`
- L25 `void main()`

### test/http/mock_collection_chat_http_test.dart

- L9 `void main()`

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

### test/screens/chat/chat_screen_test.dart

- L20 `class _AlwaysFailsChatHttp implements ChatHttp`
  - L22 `Future<List<String>> fetchSuggestions()`
  - L25 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments = const [], List<ChatHistoryEntry> history = const [], })`
- L37 `class _FirstCallFailsChatHttp implements ChatHttp`
  - L41 `Future<List<String>> fetchSuggestions()`
  - L44 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments = const [], List<ChatHistoryEntry> history = const [], })`
- L56 `class _FakeApiClient extends ApiClient`
  - L57 `_FakeApiClient()`
- L60 `class _FakeAuthService extends AuthService`
  - L61 `_FakeAuthService()`
  - L64 `Session? get currentSession`
  - L67 `User? get currentUser`
  - L76 `Stream<AuthState> get authStateChanges`
- L79 `Future<void> _pumpChatScreen( WidgetTester tester, ChatViewModel viewModel, )`
- L96 `void main()`

### test/screens/chat_attachment_sheet_test.dart

- L6 `void main()`

### test/screens/collections/collection_chat_panel_test.dart

- L21 `class _FakeApiClient extends ApiClient`
  - L22 `_FakeApiClient()`
- L25 `class _FakeAuthService extends AuthService`
  - L26 `_FakeAuthService()`
  - L29 `Session? get currentSession`
  - L32 `User? get currentUser`
  - L41 `Stream<AuthState> get authStateChanges`
- L45 `class _UnreachableCollectionChatHttp implements CollectionChatHttp`
  - L49 `Future<List<CollectionChatThread>> fetchThreads(String collectionId)`
  - L55 `Future<CollectionChatPage> fetchMessages( String collectionId, { required String threadId, String? after, })`
  - L62 `Stream<ChatEvent> ask({ required String collectionId, required String threadId, required String text, List<ChatAttachment> attachments = const [], })`
  - L72 `Future<void> shareAnswer({ required String collectionId, required String threadId, required String questionText, required List<AnswerBlock> blocks, })`
  - L80 `Future<void> deleteMessage({ required String collectionId, required String messageId, })`
- L86 `Future<void> _pumpPanel( WidgetTester tester, CollectionChatHttp http, { required bool canEdit, })`
- L108 `void main()`

### test/screens/collections/collection_detail_tabs_test.dart

- L22 `class _FakeApiClient extends ApiClient`
  - L23 `_FakeApiClient()`
- L26 `class _FakeAuthService extends AuthService`
  - L27 `_FakeAuthService()`
  - L30 `Session? get currentSession`
  - L33 `User? get currentUser`
  - L42 `Stream<AuthState> get authStateChanges`
- L45 `void main()`

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

### test/screens/reel_detail/reel_share_card_test.dart

- L7 `void main()`
- L270 `Reel _shareReel({ String contentType = 'reel', String? sourcePlatform, String title = 'A saved reel worth remembering', String summary = 'This reel has a clear summary that should be readable on the share card.', List<String> keyFacts = const [ 'The reel highlights three spots that can be visited in one afternoon.', 'The creator recommends starting early to avoid crowds.', ], List<String> actionableItems = const [ 'Book the first stop before noon.', 'Walk between each stop instead of driving.', ], })`

### test/services/cache/content_cache_test.dart

- L7 `void main()`

### test/services/chat/chat_reel_cache_test.dart

- L6 `Reel _reel(String id)`
- L22 `void main()`

### test/services/chat/chat_thread_store_test.dart

- L7 `ChatThread _thread(String id)`
- L22 `void main()`

### test/services/how_to_guide_service_test.dart

- L6 `void main()`

### test/services/notifications/notification_tap_handler_test.dart

- L6 `void main()`
- L287 `final _collectionNotification = AppNotification.fromData`
- L299 `AppNotification _featureTargetNotification(String target)`
- L313 `final _reelNotification = AppNotification.fromData`
- L326 `final _featureNotification = AppNotification.fromData`

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

- L12 `void main()`

### test/services/sharing/shared_collection_prefetch_test.dart

- L8 `void main()`
- L69 `CollectionDetail _detail(String name)`

### test/utils/answer_text_parser_test.dart

- L5 `void main()`

### test/utils/auth_error_message_test.dart

- L8 `void main()`

### test/utils/category_marker_icon_test.dart

- L5 `void main()`

### test/view_models/chat_view_model_test.dart

- L15 `class _ControllableChatHttp implements ChatHttp`
  - L19 `int get calls`
  - L22 `Future<List<String>> fetchSuggestions()`
  - L25 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments = const [], List<ChatHistoryEntry> history = const [], })`
  - L37 `void succeed(int callIndex, List<AnswerBlock> blocks)`
  - L42 `void fail(int callIndex, Object error)`
- L48 `class _FakeChatHttp implements ChatHttp`
  - L49 `_FakeChatHttp({this.shouldFail = false})`
  - L56 `Future<List<String>> fetchSuggestions()`
  - L59 `Stream<ChatEvent> sendMessage({ required String threadId, required String text, List<ChatAttachment> attachments = const [], List<ChatHistoryEntry> history = const [], })`
- L75 `void main()`

### test/view_models/collection_chat_view_model_test.dart

- L19 `class _FailingCollectionChatHttp implements CollectionChatHttp`
  - L21 `Future<List<CollectionChatThread>> fetchThreads(String collectionId)`
  - L25 `Future<CollectionChatPage> fetchMessages( String collectionId, { required String threadId, String? after, })`
  - L32 `Stream<ChatEvent> ask({ required String collectionId, required String threadId, required String text, List<ChatAttachment> attachments = const [], })`
  - L42 `Future<void> shareAnswer({ required String collectionId, required String threadId, required String questionText, required List<AnswerBlock> blocks, })`
  - L50 `Future<void> deleteMessage({ required String collectionId, required String messageId, })`
- L58 `class _SlowThreadsHttp implements CollectionChatHttp`
  - L59 `_SlowThreadsHttp(this._inner)`
  - L64 `void release()`
  - L67 `Future<List<CollectionChatThread>> fetchThreads(String collectionId)`
  - L73 `Future<CollectionChatPage> fetchMessages( String collectionId, { required String threadId, String? after, })`
  - L80 `Stream<ChatEvent> ask({ required String collectionId, required String threadId, required String text, List<ChatAttachment> attachments = const [], })`
  - L93 `Future<void> shareAnswer({ required String collectionId, required String threadId, required String questionText, required List<AnswerBlock> blocks, })`
  - L106 `Future<void> deleteMessage({ required String collectionId, required String messageId, })`
- L112 `void main()`

### test/view_models/collections_view_model_test.dart

- L13 `void main()`
- L544 `ContentCache _testCache()`
- L556 `class _TrackedContentCache implements ContentCache`
  - L557 `_TrackedContentCache(this._delegate)`
  - L562 `Future<void> _track(Future<void> operation)`
  - L567 `Future<void> drain()`
  - L574 `Future<Map<String, dynamic>?> read(String key)`
  - L577 `Future<void> write(String key, Map<String, dynamic> payload)`
  - L581 `Future<void> invalidate(String key)`
  - L584 `Future<void> invalidateContent()`
  - L587 `Future<void> clear()`
- L590 `CollectionSummary _summary( String id, { String visibility = 'private', int itemCount = 0, String? name, String? updatedAt, })`
- L606 `Reel _reel(String id)`
- L623 `CollectionDetail _detail( String id, { List<String> reelIds = const [], String? nextCursor, int itemCount = 0, String visibility = 'private', String? updatedAt, })`
- L644 `class _FakeCollectionsHttp implements CollectionsHttp`
  - L645 `_FakeCollectionsHttp({this.collections = const [], this.error})`
  - L671 `Future<List<CollectionSummary>> getCollections()`
  - L678 `Future<CollectionDetail> getCollectionDetail( String collectionId, { int limit = 25, String? cursor, })`
  - L704 `Future<CollectionSummary> createCollection({ required String name, String description = '', List<String> reelIds = const [], })`
  - L714 `Future<CollectionSummary> updateCollection({ required String collectionId, String? name, String? description, String? coverReelId, })`
  - L725 `Future<void> deleteCollection(String collectionId)`
  - L730 `Future<int> addReelsToCollection({ required String collectionId, required List<String> reelIds, })`
  - L746 `Future<void> removeReelFromCollection({ required String collectionId, required String reelId, })`
  - L754 `Future<CollectionLink> enableCollectionLink(String collectionId)`
  - L763 `Future<void> disableCollectionLink(String collectionId)`
  - L768 `Future<CollectionMembers> getCollectionMembers(String collectionId)`
  - L774 `Future<void> removeCollectionMember({ required String collectionId, required String memberUserId, })`
  - L782 `Future<void> leaveCollection(String collectionId)`
  - L787 `Future<CollectionInvite> createCollectionInvite({ required String collectionId, required String role, })`
  - L800 `Future<CollectionSummary> acceptCollectionInvite(String token)`
  - L810 `Future<CollectionDetail> getSharedCollection( String token, { int limit = 25, String? cursor, })`

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

- L18 `void main()`
- L211 `class _FakeReelRepository extends ReelRepository implements MapHttp`
  - L212 `_FakeReelRepository({required this.onSearch})`
  - L219 `_FakeReelRepository.empty({ this.cachedReels = const [], this.mapResponse, this.onMapSearch, this.pinnedMapItem, })`
  - L253 `static Future<SearchResponse> _emptySearch({ required String query, String? category, String? subcategory, })`
  - L265 `Future<void> loadInitialReels({ bool forceRefresh = false, String? platform, String? category, String? subcategory, String? savedDate, })`
  - L278 `Future<MapResponse> getMapData({String? category})`
  - L288 `Future<MapPlaceSearchResponse> searchMapPlaces( String query, { String? category, String? sessionToken, int limit = 8, })`
  - L316 `Future<MapItem> pinMapPlace( String googlePlaceId, { String? sessionToken, })`
  - L324 `Future<void> removeMapItem(String mapItemId)`
  - L329 `Future<SearchResponse> search( String query, { String? category, String? subcategory, })`
- L338 `class _FakeAuthService extends AuthService`
  - L339 `_FakeAuthService()`
  - L342 `Session? get currentSession`
  - L345 `User? get currentUser`
  - L348 `Stream<AuthState> get authStateChanges`
  - L351 `Future<void> ensureProfile()`
- L354 `const _travelReel = Reel`
- L371 `const _travelMapItem = MapItem`
- L388 `const _manualMapItem = MapItem`
- L410 `const _foodReel = Reel`

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

- L14 `void main()`
- L137 `const _signedInUser = User`
- L145 `class _FakeAuthService extends AuthService`
  - L146 `_FakeAuthService(this.events, {this.user, this.stream})`
  - L154 `Session? get currentSession`
  - L157 `User? get currentUser`
  - L160 `Stream<AuthState> get authStateChanges`
  - L164 `Future<void> ensureProfile()`
  - L169 `Future<void> signOut()`
- L174 `class _FakeSharingHttp implements SharingHttp`
  - L175 `_FakeSharingHttp(this.events)`
  - L180 `Future<void> revokeShareToken()`
  - L185 `dynamic noSuchMethod(Invocation invocation)`
- L188 `class _FakeAccountHttp implements AccountHttp`
  - L189 `_FakeAccountHttp(this.events, {this.shouldFail = false})`
  - L195 `Future<void> deleteAccount()`
  - L201 `dynamic noSuchMethod(Invocation invocation)`

### test/view_models/theme_view_model_test.dart

- L7 `void main()`

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

<!-- mapped: reelpin-app@aa18522 | paths: .agent/, .github/, .vscode/, README.md, analysis_options.yaml, android/, assets/, docs/, ios/, lib/, linux/, macos/, play-assets/, pubspec.lock, pubspec.yaml, test/, tool/, web/, windows/ -->
