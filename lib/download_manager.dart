import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:synchronized/synchronized.dart';
import 'package:webdav_client/webdav_client.dart';

class DownloadManager {
  final Map<String, DownloadItem> _downloads = {};
  final Lock _lock = Lock();

  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 100);
  final Set<String> _pendingUpdates = HashSet();
  final List<DownloadItem> _batchUpdates = [];

  final void Function(List<DownloadItem>) onBatchUpdate;

  DownloadManager({required this.onBatchUpdate});

  Future<void> addDownload(DownloadItem item) async {
    await _lock.synchronized(() {
      _downloads[item.id] = item;
    });
    immediateUpdate(item);
  }

  Future<void> updateDownload(
    DownloadItem item, {
    bool? isProgressUpdate = false,
  }) async {
    if (isProgressUpdate == true) {
      await _lock.synchronized(() {
        _downloads[item.id] = item;
        _scheduleUpdate(item.id);
      });
    } else {
      await _lock.synchronized(() {
        _downloads[item.id] = item;
      });
      immediateUpdate(item);
    }
  }

  Future<void> removeDownload(String id) async {
    DownloadItem? item;
    await _lock.synchronized(() {
      item = _downloads[id];
      _downloads.remove(id);
    });
    immediateUpdate(item!);
  }

  Future<List<DownloadItem>> getAllDownloads() async {
    return await _lock.synchronized(() => _downloads.values.toList());
  }

  Future<DownloadItem?> getDownload(String id) async {
    return await _lock.synchronized(() => _downloads[id]);
  }

  void _scheduleUpdate(String downloadId) {
    _pendingUpdates.add(downloadId);

    _debounceTimer?.cancel();

    _debounceTimer = Timer(_debounceDelay, () {
      _performBatchUpdate();
    });
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
  }

  Future<void> immediateUpdate(DownloadItem item) async {
    await _lock.synchronized(() {
      _downloads[item.id] = item;
    });
    _debounceTimer?.cancel();
    onBatchUpdate([item]);
  }

  void dispose() {
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
}

enum DownloadStatus { pending, inProgress, completed, failed, paused }

class DownloadItem {
  final String id = UniqueKey().toString();

  final File davFile;
  final String savePath;
  final void Function(DownloadItem) onUpdate;

  DownloadStatus status = DownloadStatus.pending;
  double progress = 0;

  CancelToken? _cancelToken;
  int _receivedBytes = 0;

  DownloadItem({
    required this.davFile,
    required this.savePath,
    required this.onUpdate,
  });

  void setStatus(DownloadStatus newStatus) {
    status = newStatus;
    onUpdate(this);
  }

  void setProgress(double newProgress) {
    progress = newProgress;
    onUpdate(this);
  }

  void pause() {
    if (_cancelToken != null && status == .inProgress) {
      _cancelToken!.cancel("Download paused by user");
      setStatus(DownloadStatus.paused);
      onUpdate(this);
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
          onProgress: (count, total) {
            setProgress((count + _receivedBytes) / (total + _receivedBytes));
          },
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
    setStatus(.inProgress);
  }
}
