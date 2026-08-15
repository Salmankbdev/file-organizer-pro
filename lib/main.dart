import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(settings: SettingsService());
  await controller.init();
  // Optional: auto-scan the default folder when the app starts.
  final defaultFolder = controller.settings.defaultFolder;
  if (controller.settings.autoScanOnStart &&
      defaultFolder != null &&
      defaultFolder.isNotEmpty) {
    controller.scanFolder(defaultFolder);
  }
  runApp(FileOrganizerApp(controller: controller));
}
