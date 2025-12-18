import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud_client/constants.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:synchronized/synchronized.dart';
import 'package:webdav_client/webdav_client.dart';

class UploadManager {
  final Map<String, UploadItem> _uploads = {};
  final Lock _lock = Lock();

  Timer? _debounceTimer;
  Timer? _saveTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 100);
  final Duration _saveDelay = const Duration(seconds: 2);
  final Set<String> _pendingUpdates = HashSet();
  final List<UploadItem> _batchUpdates = [];

  final void Function(List<UploadItem>) onBatchUpdate;

  UploadManager({required this.onBatchUpdate});

  Future<void> addUpload(UploadItem item) async {
    await _lock.synchronized(() {
      _uploads[item.id] = item;
    });
    immediateUpdate(item: item);
  }

  Future<void> updateUpload(
    UploadItem item, {
    bool? isProgressUpdate = false,
  }) async {
    if (isProgressUpdate == true) {
      await _lock.synchronized(() {
        _uploads[item.id] = item;
      });
      _scheduleUpdate(item.id);
    } else {
      await _lock.synchronized(() {
        _uploads[item.id] = item;
      });
      immediateUpdate(item: item);
    }
  }

  Future<void> removeUpload(String id) async {
    await _lock.synchronized(() {
      _uploads.remove(id);
    });
    immediateUpdate();
  }

  Future<List<UploadItem>> getAllUploads() async {
    return await _lock.synchronized(() => _uploads.values.toList());
  }

  Future<UploadItem?> getUpload(String id) async {
    return await _lock.synchronized(() => _uploads[id]);
  }

  void _scheduleUpdate(String uploadId) {
    _pendingUpdates.add(uploadId);
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
    print("Saving UploadManager state...");
    setStringPref("um", jsonEncode(json));
  }

  Future<void> _performBatchUpdate() async {
    await _lock.synchronized(() {
      _batchUpdates.clear();
      for (var id in _pendingUpdates) {
        final item = _uploads[id];
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

  Future<void> immediateUpdate({UploadItem? item}) async {
    if (item != null) {
      await _lock.synchronized(() {
        _uploads[item.id] = item;
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

  Future<int> countWithStatus(UploadStatus status) async {
    int count = 0;
    await _lock.synchronized(() {
      _uploads.forEach((key, item) {
        if (item.status == status) {
          count++;
        }
      });
    });
    return count;
  }

  Future<int> count() async {
    return await _lock.synchronized(() => _uploads.length);
  }

  Future<Map<String, dynamic>> toJson() async {
    Map<String, dynamic> json = {};
    await _lock.synchronized(() {
      json['uploads'] = _uploads.values
          .map((upload) => upload.toJson())
          .toList();
    });
    return json;
  }

  UploadManager.fromJson(
    Map<String, dynamic> json, {
    required this.onBatchUpdate,
  }) {
    if (json['uploads'] != null && json['uploads'] is List) {
      for (var itemJson in json['uploads']) {
        final item = UploadItem.fromJson(
          itemJson as Map<String, dynamic>,
          onUpdate: updateUpload,
        );
        _uploads[item.id] = item;
      }
    }
  }
}

enum UploadStatus { pending, inProgress, completed, failed, paused }

class UploadItem {
  final String id;

  final String localPath;
  final String remotePath;
  final void Function(UploadItem, {bool? isProgressUpdate}) onUpdate;
  DateTime createdAt;
  DateTime updatedAt;
  String? errorMessage;

  UploadStatus status = UploadStatus.pending;
  double progress = 0;
  double speed = 0;
  DateTime? startedAt;
  int? _uploadedSlice;

  CancelToken? _cancelToken;

  UploadItem({
    required this.localPath,
    required this.remotePath,
    required this.onUpdate,
  }) : id = UniqueKey().toString(),
       createdAt = DateTime.now(),
       updatedAt = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'localPath': localPath,
      'remotePath': remotePath,
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'errorMessage': errorMessage,
      '_uploadedSlice': _uploadedSlice,
    };
  }

  UploadItem.fromJson(Map<String, dynamic> json, {required this.onUpdate})
    : id = json['id'] as String,
      localPath = json['localPath'] as String,
      remotePath = json['remotePath'] as String,
      status = getUploadStatusFromString(json['status'] as String),
      progress = (json['progress'] as num).toDouble(),
      createdAt = DateTime.parse(json['createdAt'] as String),
      updatedAt = DateTime.parse(json['updatedAt'] as String),
      errorMessage = json['errorMessage'] as String?,
      _uploadedSlice = json['_uploadedSlice'] as int?;

  void _update({bool isProgressUpdate = false}) {
    updatedAt = DateTime.now();
    onUpdate(this, isProgressUpdate: isProgressUpdate);
  }

  void resetUploadSlice() {
    _uploadedSlice = null;
  }

  void setStatus(UploadStatus newStatus) {
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
      _cancelToken!.cancel("Upload $id paused by user");
      setStatus(UploadStatus.paused);
      _update();
    }
  }

  Future<void> _directUpload(Client davClient) async {
    await davClient.writeFromFile(
      localPath,
      remotePath,
      onProgress: (count, total) {
        setProgress(count, total);
      },
      cancelToken: _cancelToken,
    );
    setStatus(.completed);
  }

  Future<void> _uploadByChunk(Client davClient) async {
    final fileSize = getFileSize(localPath);
    final sliceCount = (fileSize / UPLOAD_SLICE_SIZE).ceil();

    if (sliceCount <= 1) {
      await _directUpload(davClient);
      return;
    }

    final chunkKey = await davClient.createUploadChunk();
    print("Upload chunk key: $chunkKey");

    final f = io.File(localPath);

    setStatus(.inProgress);

    for (int i = _uploadedSlice ?? 0; i < sliceCount; i++) {
      if (_cancelToken?.isCancelled == true) {
        print("Upload $id cancelled, stopping chunked upload");
        return;
      }
      final offset = i * UPLOAD_SLICE_SIZE;
      final currentChunkSize = (i == sliceCount - 1)
          ? fileSize - offset
          : UPLOAD_SLICE_SIZE;
      final sliceStream = await f
          .openRead(offset, offset + currentChunkSize)
          .toList();
      final sliceData = sliceStream.expand((x) => x).toList();

      print("Uploading chunk ${i + 1}/$sliceCount for upload $id");
      await davClient.write(
        "$chunkKey/${i + 1}",
        Uint8List.fromList(sliceData),
        onProgress: (count, total) {
          final overallProgress = ((i * UPLOAD_SLICE_SIZE) + count) / fileSize;
          setProgress((overallProgress * fileSize).toInt(), fileSize);
        },
        cancelToken: _cancelToken,
      );

      _uploadedSlice = i + 1;
    }

    print("Combining upload chunks for upload $id");
    await davClient.combineUploadChunk(chunkKey, remotePath, false);

    setStatus(.completed);
  }

  void start(Client davClient) {
    if (status != .pending) {
      print("Upload $id already started");
    }

    if (!fileExists(localPath)) {
      print("Local file does not exist: $localPath");
      setStatus(UploadStatus.failed);
      return;
    }

    _cancelToken = CancelToken();

    startedAt = DateTime.now();
    _uploadByChunk(davClient)
        .then((_) {
          setStatus(UploadStatus.completed);
        })
        .catchError((e) {
          if (CancelToken.isCancel(e)) {
            print("Upload cancelled: $e");
            return;
          }
          setStatus(UploadStatus.failed);
          errorMessage = e.toString();
          _update();
        });
  }
}

UploadStatus getUploadStatusFromString(String status) {
  status = status.trim().toLowerCase();
  switch (status) {
    case 'pending':
      return UploadStatus.pending;
    case 'inprogress':
      return UploadStatus.inProgress;
    case 'completed':
      return UploadStatus.completed;
    case 'failed':
      return UploadStatus.failed;
    case 'paused':
      return UploadStatus.paused;
    default:
      return UploadStatus.pending;
  }
}
