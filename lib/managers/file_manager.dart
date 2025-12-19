import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:nextcloud/core.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:webdav_client/webdav_client.dart';

class FileManager {
  List<String> path = [""];
  Map<String, List<File>> trees = {};
  Map<String, Image> thumbnails = {};
  Client davClient;
  NextcloudClient client;
  Function onUpdate;

  Timer? _saveTimer;
  final Duration _saveDelay = const Duration(seconds: 2);

  FileManager({
    required this.client,
    required this.davClient,
    required this.onUpdate,
  });

  void _scheduleSave() {
    if (_saveTimer != null && _saveTimer!.isActive) {
      return;
    }

    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      _performSave();
    });
  }

  Future<List<File>> _fetchFolderTree(String path) async {
    print("Fetching folder tree for path: $path");
    try {
      final data = await davClient.readDir(path);
      if (data.isEmpty) {
        return [];
      } else {
        return data.toList();
      }
    } catch (e) {
      print("Error fetching folder tree: $e");
      return [];
    }
  }

  Future<void> fetchFolderTree(
    String path, {
    bool autoFetchThumbnails = true,
    int depth = 1,
  }) async {
    final tree = await _fetchFolderTree(path);
    tree.sort((a, b) {
      if (a.isDir == true && b.isDir == false) {
        return -1;
      } else if (a.isDir == false && b.isDir == true) {
        return 1;
      } else {
        return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
      }
    });
    trees[path] = tree;
    onUpdate();
    _scheduleSave();
    if (depth > 1) {
      for (final f in tree) {
        if (f.isDir == true) {
          fetchFolderTree(
            f.path!,
            autoFetchThumbnails: autoFetchThumbnails,
            depth: depth - 1,
          );
        }
      }
    }
    if (autoFetchThumbnails) {
      tree.forEach((f) {
        if (f.path != null && f.isDir == false) {
          _fetchThumbnail(f.path!);
        }
      });
    }
  }

  List<File> getFolderTree(
    String path, {
    bool autoFetch = true,
    bool autoFetchThumbnails = true,
  }) {
    if (trees[path] != null) {
      return trees[path]!;
    } else {
      if (autoFetch) {
        fetchFolderTree(path, autoFetchThumbnails: autoFetchThumbnails);
      }
      return [];
    }
  }

  void _fetchThumbnail(String filePath, {int? x = 64, int? y = 64}) {
    if (thumbnails.containsKey(filePath)) {
      return;
    }
    if (filePath.endsWith('.zip') ||
        filePath.endsWith('.tar') ||
        filePath.endsWith('.gz') ||
        filePath.endsWith('.7z') ||
        filePath.endsWith('.rar')) {
      return;
    }
    print("Fetching thumbnail for $filePath");
    client.core.preview
        .getPreview(file: filePath, x: x, y: y)
        .then((res) {
          try {
            if (res.statusCode != 200) {
              print(
                "Failed to fetch thumbnail for $filePath: ${res.statusCode}",
              );
              return;
            } else {
              final img = Image.memory(res.body);
              thumbnails[filePath] = img;
              onUpdate();
            }
          } catch (e) {
            print("Error processing thumbnail for $filePath: $e");
          }
        })
        .catchError((e) {
          print("Error fetching thumbnail for $filePath: $e");
        });
  }

  Image? getThumbnail(String path, {bool autoFetch = true}) {
    if (thumbnails[path] == null && autoFetch) {
      _fetchThumbnail(path);
    }
    return thumbnails[path];
  }

  String path2String(List<String> p) {
    if (p.isEmpty || (p.length == 1 && p[0] == "")) {
      return "/";
    }
    return p.join("/");
  }

  String getPathString() {
    return path2String(path);
  }

  void pushPath(String segment, {bool autoFetch = true}) {
    path.add(segment);
    onUpdate();
    _scheduleSave();
    if (autoFetch) {
      fetchFolderTree(getPathString());
    }
  }

  void popPath({int index = -1, bool autoFetch = true}) {
    if (index == -1) {
      path.removeLast();
    } else {
      if (index > 0 || index < path.length) {
        path = path.sublist(0, index);
      }
    }
    onUpdate();
    _scheduleSave();
    if (autoFetch) {
      fetchFolderTree(getPathString());
    }
  }

  void _performSave() {
    final json = toJson();
    print("Saving FileManager state... ${jsonEncode(json)}");
    setStringPref("fm", jsonEncode(json));
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'trees': trees.map(
        (key, value) =>
            MapEntry(key, value.map((f) => davFile2Json(f)).toList()),
      ),
    };
  }

  FileManager.fromJson(
    Map<String, dynamic> json, {
    required this.client,
    required this.davClient,
    required this.onUpdate,
  }) {
    path = List<String>.from(json['path']);
    trees = (json['trees'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>).map((value) => json2DavFile(value)).toList(),
      ),
    );
  }

  void dispose() {
    _performSave();
  }
}
