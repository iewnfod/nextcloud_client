import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:synchronized/synchronized.dart';
import 'package:webdav_client/webdav_client.dart';

class DownloadManager {
  final Map<String, DownloadItem> _downloads = {};
  final Lock _lock = Lock();

  Timer? _debounceTimer;
  Timer? _saveTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 100);
  final Duration _saveDelay = const Duration(seconds: 2);
  final Set<String> _pendingUpdates = HashSet();
  final List<DownloadItem> _batchUpdates = [];

  final void Function(List<DownloadItem>) onBatchUpdate;

  DownloadManager({required this.onBatchUpdate});

  Future<void> addDownload(DownloadItem item) async {
    await _lock.synchronized(() {
      _downloads[item.id] = item;
    });
    immediateUpdate(item: item);
  }

  Future<void> updateDownload(
    DownloadItem item, {
    bool? isProgressUpdate = false,
  }) async {
    if (isProgressUpdate == true) {
      await _lock.synchronized(() {
        _downloads[item.id] = item;
      });
      _scheduleUpdate(item.id);
    } else {
      await _lock.synchronized(() {
        _downloads[item.id] = item;
      });
      immediateUpdate(item: item);
    }
  }

  Future<void> removeDownload(String id) async {
    await _lock.synchronized(() {
      _downloads.remove(id);
    });
    immediateUpdate();
  }

  Future<List<DownloadItem>> getAllDownloads() async {
    return await _lock.synchronized(() => _downloads.values.toList());
  }

  Future<DownloadItem?> getDownload(String id) async {
    return await _lock.synchronized(() => _downloads[id]);
  }

  void _scheduleUpdate(String downloadId) {
    _pendingUpdates.add(downloadId);

    if (_debounceTimer != null && _debounceTimer!.isActive) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _performBatchUpdate();
    });
  }

  void _scheduleSave() {
    if (_saveTimer != null && _saveTimer!.isActive) {
      return;
    }

    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      _performSave();
    });
  }

  Future<void> _performSave() async {
    final json = await toJson();
    print("Saving DownloadManager state...");
    setStringPref("dm", jsonEncode(json));
  }

  Future<void> _performBatchUpdate() async {
    await _lock.synchronized(() {
      _batchUpdates.clear();
      for (var id in _pendingUpdates) {
        final item = _downloads[id];
        if (item != null) {
          _batchUpdates.add(item);
        }
      }
      _pendingUpdates.clear();
    });

    if (_batchUpdates.isNotEmpty) {
      onBatchUpdate(List.from(_batchUpdates));
    }

    _scheduleSave();
  }

  Future<void> immediateUpdate({DownloadItem? item}) async {
    if (item != null) {
      await _lock.synchronized(() {
        _downloads[item.id] = item;
      });
    }
    _debounceTimer?.cancel();
    onBatchUpdate([if (item != null) item]);
    _scheduleSave();
  }

  void dispose() {
    _performSave();
    _debounceTimer?.cancel();
  }

  Future<int> countWithStatus(DownloadStatus status) async {
    int count = 0;
    await _lock.synchronized(() {
      _downloads.forEach((key, item) {
        if (item.status == status) {
          count++;
        }
      });
    });
    return count;
  }

  Future<int> count() async {
    return await _lock.synchronized(() => _downloads.length);
  }

  Future<Map<String, dynamic>> toJson() async {
    Map<String, dynamic> json = {};
    await _lock.synchronized(() {
      json['downloads'] = _downloads.values
          .map((download) => download.toJson())
          .toList();
    });
    return json;
  }

  DownloadManager.fromJson(
    Map<String, dynamic> json, {
    required this.onBatchUpdate,
  }) {
    if (json['downloads'] != null && json['downloads'] is List) {
      for (var itemJson in json['downloads']) {
        final item = DownloadItem.fromJson(
          itemJson as Map<String, dynamic>,
          onUpdate: updateDownload,
        );
        _downloads[item.id] = item;
      }
    }
  }
}

enum DownloadStatus { pending, inProgress, completed, failed, paused }

class DownloadItem {
  final String id;

  final File davFile;
  final String savePath;
  final void Function(DownloadItem, {bool? isProgressUpdate}) onUpdate;
  DateTime createdAt;
  DateTime updatedAt;

  DownloadStatus status = DownloadStatus.pending;
  double progress = 0;
  double speed = 0;
  DateTime? startedAt;

  CancelToken? _cancelToken;
  int _receivedBytes = 0;

  DownloadItem({
    required this.davFile,
    required this.savePath,
    required this.onUpdate,
  }) : id = UniqueKey().toString(),
       createdAt = DateTime.now(),
       updatedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'davFile': {
        'cTime': davFile.cTime?.toIso8601String(),
        'eTag': davFile.eTag,
        'name': davFile.name,
        'path': davFile.path,
        'size': davFile.size,
        'isDir': davFile.isDir,
        'mTime': davFile.mTime?.toIso8601String(),
        'mimeType': davFile.mimeType,
      },
      'savePath': savePath,
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DownloadItem.fromJson(Map<String, dynamic> json, {required this.onUpdate})
    : davFile = File(
        cTime: json['davFile']['cTime'] != null
            ? DateTime.parse(json['davFile']['cTime'] as String)
            : null,
        eTag: json['davFile']['eTag'] as String?,
        name: json['davFile']['name'] as String?,
        path: json['davFile']['path'] as String?,
        size: json['davFile']['size'] as int?,
        isDir: json['davFile']['isDir'] as bool?,
        mTime: json['davFile']['mTime'] != null
            ? DateTime.parse(json['davFile']['mTime'] as String)
            : null,
        mimeType: json['davFile']['mimeType'] as String?,
      ),
      id = json['id'] as String,
      savePath = json['savePath'] as String,
      status = getDownloadStatusFromString(json['status'] as String),
      progress = (json['progress'] as num).toDouble(),
      createdAt = DateTime.parse(json['createdAt'] as String),
      updatedAt = DateTime.parse(json['updatedAt'] as String);

  void _update({bool isProgressUpdate = false}) {
    updatedAt = DateTime.now();
    onUpdate(this, isProgressUpdate: isProgressUpdate);
  }

  void setStatus(DownloadStatus newStatus) {
    status = newStatus;
    _update();
  }

  void setProgress(int count, int total) {
    double newProgress = total > 0 ? count / total : 0;
    progress = newProgress;
    if (startedAt != null) {
      final passedTime = DateTime.now().difference(startedAt!).inMilliseconds;
      if (count > 0 && passedTime > 0) {
        speed = count / (passedTime / 1000);
      }
    }
    _update(isProgressUpdate: true);
  }

  void pause() {
    if (_cancelToken != null && status == .inProgress) {
      _cancelToken!.cancel("Download paused by user");
      setStatus(DownloadStatus.paused);
      _update();
    }
  }

  void start(Client davClient) {
    if (status != DownloadStatus.pending) {
      print("Download already started");
    }
    if (davFile.path == null) {
      print("Invalid DAV file path");
    }

    _cancelToken = CancelToken();

    if (fileExists(savePath)) {
      _receivedBytes = getFileSize(savePath);
    }

    davClient
        .read2File(
          davFile.path!,
          savePath,
          onProgress: setProgress,
          cancelToken: _cancelToken,
          options: Options(
            headers: {
              if (_receivedBytes > 0) "Range": "bytes=$_receivedBytes-",
            },
          ),
        )
        .then((_) {
          setStatus(.completed);
        })
        .catchError((e) {
          if (CancelToken.isCancel(e)) {
            print("Download cancelled: $e");
            return;
          }
          setStatus(.failed);
          print("Download error: $e");
        });

    startedAt = DateTime.now();
    setStatus(.inProgress);
  }
}

DownloadStatus getDownloadStatusFromString(String status) {
  status = status.trim().toLowerCase();
  switch (status) {
    case 'pending':
      return DownloadStatus.pending;
    case 'inProgress':
      return DownloadStatus.inProgress;
    case 'completed':
      return DownloadStatus.completed;
    case 'failed':
      return DownloadStatus.failed;
    case 'paused':
      return DownloadStatus.paused;
    default:
      return DownloadStatus.pending;
  }
}
