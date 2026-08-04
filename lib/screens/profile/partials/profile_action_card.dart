part of '../profile_screen.dart';

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
      decoration: AppTheme.brutalCard(context, color: AppColors.bg(context)),
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
                      color: AppColors.fg(context),
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: layout.gap(6)),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceMono(
                      color: AppColors.textSec(context),
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
