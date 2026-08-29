// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

enum ExpiryNotificationPermission { unsupported, prompt, denied, granted }

class ExpiryNotificationService {
  const ExpiryNotificationService();

  bool get isSupported => html.Notification.supported;

  Future<ExpiryNotificationPermission> currentPermission() async {
    if (!isSupported) return ExpiryNotificationPermission.unsupported;
    return _permissionFromValue(html.Notification.permission);
  }

  Future<ExpiryNotificationPermission> requestPermission() async {
    if (!isSupported) return ExpiryNotificationPermission.unsupported;
    final permission = await html.Notification.requestPermission();
    return _permissionFromValue(permission);
  }

  void show({
    required String title,
    required String body,
    required String tag,
  }) {
    if (!isSupported || html.Notification.permission != 'granted') return;
    html.Notification(title, body: body, tag: tag);
  }

  static ExpiryNotificationPermission _permissionFromValue(String? value) {
    switch (value) {
      case 'granted':
        return ExpiryNotificationPermission.granted;
      case 'denied':
        return ExpiryNotificationPermission.denied;
      default:
        return ExpiryNotificationPermission.prompt;
    }
  }
}
