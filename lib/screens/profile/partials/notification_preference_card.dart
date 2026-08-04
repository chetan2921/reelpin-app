part of '../profile_screen.dart';

class _NotificationPreferenceCard extends ConsumerStatefulWidget {
  const _NotificationPreferenceCard();

  @override
  ConsumerState<_NotificationPreferenceCard> createState() =>
      _NotificationPreferenceCardState();
}

class _NotificationPreferenceCardState
    extends ConsumerState<_NotificationPreferenceCard> {
  NotificationPermissionState? _permissionState;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPermissionState();
    });
  }

  Future<void> _loadPermissionState() async {
    final notificationService = ref.read(notificationServiceProvider);
    final cachedState = await notificationService.getLastKnownPermissionState();
    if (mounted && cachedState != null) {
      setState(() {
        _permissionState = cachedState;
      });
    }
    await notificationService.initialize(requestPermissions: false);
    final state = await notificationService.getPermissionState();
    if (!mounted) return;
    setState(() {
      _permissionState = state;
    });
  }

  Future<void> _enableNotifications() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    final notificationService = ref.read(notificationServiceProvider);
    final authService = ref.read(authServiceProvider);

    try {
      await notificationService.initialize(requestPermissions: false);
      await notificationService.requestUserPermission();

      final state = await notificationService.getPermissionState();
      if (state == NotificationPermissionState.enabled) {
        final userId = authService.currentUser?.id;
        if (userId != null && userId.trim().isNotEmpty) {
          await ref
              .read(pushRegistrationServiceProvider)
              .register(userId: userId);
        }
      }

      if (!mounted) return;
      setState(() {
        _permissionState = state;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await LocationService.instance.openAppSettings();
      await _loadPermissionState();
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final state = _permissionState;
    final isEnabled = state == NotificationPermissionState.enabled;
    final isUnavailable = state == NotificationPermissionState.unavailable;
    final buttonColor = isEnabled
        ? AppColors.neonGreen
        : isUnavailable
        ? AppColors.surfaceElevatedColor(context)
        : AppColors.yellow;
    final buttonTextColor = buttonColor.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;

    return _ProfileActionCard(
      title: 'NOTIFICATIONS',
      subtitle: isUnavailable
          ? 'NOTIFICATION SERVICES ARE NOT AVAILABLE IN THIS BUILD.'
          : 'YOU CAN CHANGE THIS PERMISSION IN PHONE SETTINGS.',
      trailing: GestureDetector(
        onTap: isUnavailable
            ? null
            : isEnabled
            ? _openNotificationSettings
            : _enableNotifications,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: layout.inset(10),
            vertical: layout.gap(8),
          ),
          decoration: AppTheme.brutalBox(
            context,
            color: buttonColor,
            shadow: false,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isUpdating) ...[
                SizedBox(
                  width: layout.inset(14),
                  height: layout.inset(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: buttonTextColor,
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(
                  isEnabled ? Icons.notifications_active : Icons.notifications,
                  size: 15,
                  color: buttonTextColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _isUpdating
                    ? 'CHECKING'
                    : isEnabled
                    ? 'ENABLED'
                    : isUnavailable
                    ? 'UNAVAILABLE'
                    : 'DISABLED',
                style: GoogleFonts.spaceMono(
                  color: buttonTextColor,
                  fontSize: layout.font(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
