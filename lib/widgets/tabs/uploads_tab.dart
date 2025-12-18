import 'package:flutter/material.dart';
import 'package:nextcloud_client/managers/upload_manager.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:webdav_client/webdav_client.dart';

class UploadsTab extends StatefulWidget {
  final Client davClient;
  final UploadManager um;

  const UploadsTab({super.key, required this.davClient, required this.um});
  @override
  State<UploadsTab> createState() => _UploadsTabState();
}

class _UploadsTabState extends State<UploadsTab> {
  void _cancel(UploadItem item) {
    if (item.status == .inProgress) {
      item.pause();
    }
    widget.um.removeUpload(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: .circular(8.0),
            bottomRight: .circular(8.0),
          ),
        ),
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 8.0,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10.0),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    "Uploads",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  FutureBuilder(
                    future: widget.um.countWithStatus(.inProgress),
                    builder: (context, inProgressSnapshot) {
                      return FutureBuilder(
                        future: widget.um.count(),
                        builder: (context, totalSnapShot) {
                          return Text(
                            "${inProgressSnapshot.data ?? 0}/${totalSnapShot.data ?? 0} in progress",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: widget.um.getAllUploads(),
                builder: (context, snapshot) {
                  return Scrollbar(
                    child: ListView(
                      primary: true,
                      children: [
                        for (var upload in (snapshot.data ?? []).reversed)
                          UploadTab(
                            upload: upload,
                            start: (item) {
                              item.start(widget.davClient);
                            },
                            cancel: (item) {
                              _cancel(item);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadTab extends StatelessWidget {
  final UploadItem upload;
  final void Function(UploadItem) start;
  final void Function(UploadItem) cancel;

  const UploadTab({
    super.key,
    required this.upload,
    required this.start,
    required this.cancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: .antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: .centerLeft,
              child: FractionallySizedBox(
                widthFactor: upload.progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: .circular(8.0),
                      bottomRight: .circular(8.0),
                    ),
                    color: Theme.of(context).colorScheme.primary.withAlpha(
                      upload.status == .inProgress || upload.status == .paused
                          ? 31
                          : 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .center,
              children: [
                Column(
                  crossAxisAlignment: .start,
                  spacing: 5.0,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            getFileName(upload.localPath),
                            overflow: .ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: .bold),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          capitalize(upload.status.name),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (upload.status == .inProgress && upload.progress > 0)
                          Text(
                            " - Progress: ${(upload.progress * 100).toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (upload.status == .inProgress)
                          Text(
                            " - Speed: ${formatSpeed(upload.speed)}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (upload.status == .failed &&
                            upload.errorMessage != null)
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Text(
                              " - Error: ${upload.errorMessage!.replaceAll("\n", "\t")}",
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    upload.status == .pending ||
                            upload.status == .paused ||
                            upload.status == .failed
                        ? IconButton(
                            onPressed: () {
                              if (upload.status == .failed) {
                                upload.resetUploadSlice();
                              }
                              start(upload);
                            },
                            icon: Icon(
                              upload.status == .failed
                                  ? Icons.refresh
                                  : Icons.play_arrow,
                            ),
                          )
                        : upload.status == .inProgress
                        ? IconButton(
                            onPressed: () {
                              upload.pause();
                            },
                            icon: Icon(Icons.pause),
                          )
                        : SizedBox.shrink(),
                    IconButton(
                      onPressed: () {
                        cancel(upload);
                      },
                      icon: Icon(Icons.cancel_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
