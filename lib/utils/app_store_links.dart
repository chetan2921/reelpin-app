import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const String appStoreUrl = 'https://apps.apple.com/us/app/reelpin/id6777110022';
const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.chetanjain.reelpin';

String get storeListingUrl =>
    defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;

Future<bool> launchStoreListing() {
  return launchUrl(
    Uri.parse(storeListingUrl),
    mode: LaunchMode.externalApplication,
  );
}
