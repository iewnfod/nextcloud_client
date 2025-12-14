import 'package:flutter/material.dart';
import 'package:nextcloud_client/download_manager.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:nextcloud_client/widgets/dialogs/remove_download_dialog.dart';
import 'package:open_file/open_file.dart';
import 'package:webdav_client/webdav_client.dart';

class DownloadsTab extends StatefulWidget {
  final Client davClient;
  final DownloadManager dm;

  const DownloadsTab({super.key, required this.davClient, required this.dm});

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab> {
  void _cancel(DownloadItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return RemoveDownloadDialog(
          onRemove: () {
            _cancelAction(item);
          },
          file: item.davFile,
          savePath: item.savePath,
        );
      },
    );
  }

  void _cancelAction(DownloadItem item) {
    if (item.status == .inProgress) {
      item.pause();
    }
    widget.dm.removeDownload(item.id);
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
                    "Downloads",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  FutureBuilder(
                    future: widget.dm.countWithStatus(.inProgress),
                    builder: (context, inProgressSnapshot) {
                      return FutureBuilder(
                        future: widget.dm.count(),
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
                future: widget.dm.getAllDownloads(),
                builder: (context, snapshot) {
                  return Scrollbar(
                    child: ListView(
                      primary: true,
                      children: [
                        for (var download in (snapshot.data ?? []).reversed)
                          DownloadTab(
                            download: download,
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

class DownloadTab extends StatelessWidget {
  final DownloadItem download;
  final void Function(DownloadItem) start;
  final void Function(DownloadItem) cancel;

  const DownloadTab({
    super.key,
    required this.download,
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
                widthFactor: download.progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topRight: .circular(8.0),
                      bottomRight: .circular(8.0),
                    ),
                    color: Theme.of(context).colorScheme.primary.withAlpha(
                      download.status == .inProgress ||
                              download.status == .paused
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
                            getFileName(download.savePath),
                            overflow: .ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: .bold),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          capitalize(download.status.name),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (download.status == .inProgress &&
                            download.progress > 0)
                          Text(
                            " - Progress: ${(download.progress * 100).toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (download.status == .inProgress)
                          Text(
                            " - Speed: ${formatSpeed(download.speed)}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    download.status == .pending ||
                            download.status == .paused ||
                            download.status == .failed
                        ? IconButton(
                            onPressed: () {
                              start(download);
                            },
                            icon: Icon(
                              download.status == .failed
                                  ? Icons.refresh
                                  : Icons.play_arrow,
                            ),
                          )
                        : download.status == DownloadStatus.inProgress
                        ? IconButton(
                            onPressed: () {
                              download.pause();
                            },
                            icon: Icon(Icons.pause),
                          )
                        : download.status == .completed
                        ? Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  OpenFile.open(download.savePath);
                                },
                                icon: Icon(Icons.file_open_outlined),
                              ),
                              IconButton(
                                onPressed: () {
                                  openFolderAndHighlight(download.savePath);
                                },
                                icon: Icon(Icons.folder_open),
                              ),
                            ],
                          )
                        : SizedBox.shrink(),
                    IconButton(
                      onPressed: () {
                        cancel(download);
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
