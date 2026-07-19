part of 'profile_screen.dart';

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
    final sharingApi = ref.read(sharingApiProvider);
    final authService = ref.read(authServiceProvider);

    try {
      await notificationService.initialize(requestPermissions: false);
      await notificationService.requestUserPermission();

      final state = await notificationService.getPermissionState();
      if (state == NotificationPermissionState.enabled) {
        final userId = authService.currentUser?.id;
        if (userId != null && userId.trim().isNotEmpty) {
          final token = await notificationService.getFcmToken();
          if (token != null && token.trim().isNotEmpty) {
            await sharingApi.registerPushToken(
              userId: userId,
              token: token,
              platform: notificationService.currentPlatform,
            );
            await ShareHandoffService.instance.syncPushToken(
              token: token,
              platform: notificationService.currentPlatform,
            );
          }
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
        ? AppTheme.neonGreen
        : isUnavailable
        ? AppTheme.surfaceElevatedColor(context)
        : AppTheme.yellow;
    final buttonTextColor = buttonColor.computeLuminance() > 0.5
        ? AppTheme.black
        : AppTheme.white;

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

class _LocationPreferenceCard extends ConsumerStatefulWidget {
  const _LocationPreferenceCard();

  @override
  ConsumerState<_LocationPreferenceCard> createState() =>
      _LocationPreferenceCardState();
}

class _LocationPreferenceCardState
    extends ConsumerState<_LocationPreferenceCard> {
  LocationPermissionState? _permissionState;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPermissionState();
    });
  }

  Future<void> _loadPermissionState() async {
    final state = await LocationService.instance.getPermissionState();
    if (!mounted) return;
    setState(() {
      _permissionState = state;
    });
  }

  Future<void> _enableLocation() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await LocationService.instance.requestPermission();
      final state = await LocationService.instance.getPermissionState();
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

  Future<void> _openLocationSettings() async {
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
    final isEnabled = state == LocationPermissionState.enabled;
    final isServiceDisabled = state == LocationPermissionState.serviceDisabled;
    final buttonColor = isEnabled
        ? AppTheme.neonGreen
        : isServiceDisabled
        ? AppTheme.surfaceElevatedColor(context)
        : AppTheme.yellow;
    final buttonTextColor = buttonColor.computeLuminance() > 0.5
        ? AppTheme.black
        : AppTheme.white;

    return _ProfileActionCard(
      title: 'LOCATION',
      subtitle: isServiceDisabled
          ? 'TURN ON DEVICE LOCATION SERVICES SO REELPIN CAN CENTER THE MAP AROUND YOU.'
          : 'YOU CAN CHANGE THIS PERMISSION IN PHONE SETTINGS.',
      trailing: GestureDetector(
        onTap: isEnabled ? _openLocationSettings : _enableLocation,
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
                  isEnabled ? Icons.location_on : Icons.location_searching,
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
                    : isServiceDisabled
                    ? 'TURN ON'
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

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      decoration: AppTheme.brutalCard(context, color: AppTheme.bg(context)),
      child: Padding(
        padding: EdgeInsets.all(layout.inset(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: layout.gap(6)),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textSec(context),
                      fontSize: layout.font(11),
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: layout.inset(12)),
            trailing,
          ],
        ),
      ),
    );
  }
}
