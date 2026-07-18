import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> isLocationGranted() async {
    final status = await Permission.location.status;
    return status.isGranted || status.isLimited;
  }

  Future<bool> isNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> areAllPermissionsGranted() async {
    final loc = await isLocationGranted();
    final notif = await isNotificationGranted();
    return loc && notif;
  }

  Future<bool> requestLocation() async {
    final status = await Permission.location.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> requestAllPermissions() async {
    await [
      Permission.location,
      Permission.notification,
    ].request();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
