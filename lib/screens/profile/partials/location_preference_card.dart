part of '../profile_screen.dart';

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
        ? AppColors.neonGreen
        : isServiceDisabled
        ? AppColors.surfaceElevatedColor(context)
        : AppColors.yellow;
    final buttonTextColor = buttonColor.computeLuminance() > 0.5
        ? AppColors.black
        : AppColors.white;

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
