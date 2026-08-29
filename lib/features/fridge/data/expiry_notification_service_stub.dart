enum ExpiryNotificationPermission { unsupported, prompt, denied, granted }

class ExpiryNotificationService {
  const ExpiryNotificationService();

  bool get isSupported => false;

  Future<ExpiryNotificationPermission> currentPermission() async {
    return ExpiryNotificationPermission.unsupported;
  }

  Future<ExpiryNotificationPermission> requestPermission() async {
    return ExpiryNotificationPermission.unsupported;
  }

  void show({
    required String title,
    required String body,
    required String tag,
  }) {}
}
