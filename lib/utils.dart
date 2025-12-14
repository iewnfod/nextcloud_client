import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

String calcSize(int size) {
  if (size < 1024) {
    return "$size B";
  } else if (size < 1024 * 1024) {
    return "${(size / 1024).toStringAsFixed(2)} KB";
  } else if (size < 1024 * 1024 * 1024) {
    return "${(size / (1024 * 1024)).toStringAsFixed(2)} MB";
  } else {
    return "${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }
}

String getDefaultDownloadPath() {
  if (Platform.isAndroid) {
    return "/storage/emulated/0/Download";
  } else if (Platform.isIOS) {
    return "/var/mobile/Containers/Data/Application/Documents";
  } else if (Platform.isWindows) {
    return "${Platform.environment['USERPROFILE']}\\Downloads";
  } else if (Platform.isLinux) {
    return "${Platform.environment['HOME']}/Downloads";
  } else if (Platform.isMacOS) {
    return "/Users/${Platform.environment['USER']}/Downloads";
  } else {
    return ".";
  }
}

Future<bool?> getBoolPref(String key) async {
  try {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(key);
  } catch (e) {
    print("Error getting bool pref $key: $e");
    return null;
  }
}

Future<String?> getStringPref(String key) async {
  try {
    final pref = await SharedPreferences.getInstance();
    return pref.getString(key);
  } catch (e) {
    print("Error getting string pref $key: $e");
    return null;
  }
}

Future<void> setBoolPref(String key, bool value) async {
  try {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(key, value);
  } catch (e) {
    print("Error setting bool pref $key: $e");
  }
}

Future<void> setStringPref(String key, String value) async {
  try {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(key, value);
  } catch (e) {
    print("Error setting string pref $key: $e");
  }
}

bool fileExists(String path) {
  final file = File(path);
  return file.existsSync();
}

String capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

int getFileSize(String path) {
  final file = File(path);
  return file.lengthSync();
}

Future<void> deleteFile(String path) async {
  print("Deleting file at $path");
  final file = File(path);
  if (file.existsSync()) {
    await file.delete();
  }
}

String formatSpeed(double speed) {
  if (speed < 1024) {
    return "${speed.toStringAsFixed(2)} B/s";
  } else if (speed < 1024 * 1024) {
    return "${(speed / 1024).toStringAsFixed(2)} KB/s";
  } else if (speed < 1024 * 1024 * 1024) {
    return "${(speed / (1024 * 1024)).toStringAsFixed(2)} MB/s";
  } else {
    return "${(speed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s";
  }
}

String getFileName(String path) {
  return File(path).uri.pathSegments.last;
}

void openFolderAndHighlight(String path) {
  if (Platform.isWindows) {
    Process.run('explorer.exe', ['/select,', path]);
  } else if (Platform.isMacOS) {
    Process.run('open', ['-R', path]);
  } else {
    OpenFile.open(Directory(path).parent.path);
  }
}
