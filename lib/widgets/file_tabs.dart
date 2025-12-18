import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud_client/download_manager.dart';
import 'package:nextcloud_client/upload_manager.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';
import 'package:nextcloud_client/widgets/tabs/all_files_tab.dart';
import 'package:nextcloud_client/widgets/tabs/downloads_tab.dart';
import 'package:nextcloud_client/widgets/tabs/uploads_tab.dart';
import 'package:webdav_client/webdav_client.dart';

class FileTabs extends StatefulWidget {
  final NextcloudClient client;
  final Client davClient;
  final List<String> path;
  final void Function(List<String>) updatePath;
  final DownloadManager dm;
  final UploadManager um;

  const FileTabs({
    super.key,
    required this.client,
    required this.davClient,
    required this.path,
    required this.updatePath,
    required this.dm,
    required this.um,
  });

  @override
  State<FileTabs> createState() => _FileTabsState();
}

class _FileTabsState extends State<FileTabs> {
  static const items = [
    {"icon": Icons.folder_copy_outlined, "label": "Files", "tab": "files"},
    {"icon": Icons.download, "label": "Downloads", "tab": "downloads"},
    {"icon": Icons.upload, "label": "Uploads", "tab": "uploads"},
    {"icon": Icons.sync, "label": "Sync", "tab": "sync"},
  ];

  String _currentTab = "files";

  void _switchTab(String tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Padding(
          padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.only(
                      topLeft: .circular(8.0),
                      bottomLeft: .circular(8.0),
                    ),
                  ),
                  constraints: BoxConstraints(maxWidth: 400, minWidth: 200),
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: Flex(
                    direction: .vertical,
                    spacing: 10,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 8.0, right: 8.0),
                        child: SizedBox(
                          height: 45,
                          child: Transform.translate(
                            offset: Offset(0, -5),
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Transform.translate(
                                    offset: Offset(0, 3),
                                    child: Icon(Icons.search, size: 20),
                                  ),
                                ),
                                prefixIconConstraints: BoxConstraints(
                                  maxWidth: 40,
                                  maxHeight: 30,
                                ),
                                hintText: "Search files...",
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Flex(
                          direction: .vertical,
                          spacing: 5,
                          children: items.map((item) {
                            return SoftButton(
                              selected: _currentTab == item["tab"],
                              onPressed: () {
                                _switchTab(item["tab"] as String);
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8.0),
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(item["icon"] as IconData, size: 22),
                                    SizedBox(width: 10),
                                    Transform.translate(
                                      offset: Offset(0, -1),
                                      child: item["label"] == "Downloads"
                                          ? FutureBuilder(
                                              future: widget.dm.countWithStatus(
                                                .inProgress,
                                              ),
                                              builder: (context, snapshot) {
                                                final count =
                                                    snapshot.data ?? 0;
                                                if (count == 0) {
                                                  return Text(
                                                    item["label"] as String,
                                                  );
                                                } else {
                                                  return Text(
                                                    "${item["label"]} ($count)",
                                                  );
                                                }
                                              },
                                            )
                                          : item["label"] == "Uploads"
                                          ? FutureBuilder(
                                              future: widget.um.countWithStatus(
                                                .inProgress,
                                              ),
                                              builder: (context, snapshot) {
                                                final count =
                                                    snapshot.data ?? 0;
                                                if (count == 0) {
                                                  return Text(
                                                    item["label"] as String,
                                                  );
                                                } else {
                                                  return Text(
                                                    "${item["label"]} ($count)",
                                                  );
                                                }
                                              },
                                            )
                                          : Text(item["label"] as String),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                _currentTab == "files"
                    ? AllFilesTab(
                        client: widget.client,
                        davClient: widget.davClient,
                        dm: widget.dm,
                        um: widget.um,
                        path: widget.path,
                        updatePath: widget.updatePath,
                      )
                    : _currentTab == "downloads"
                    ? DownloadsTab(davClient: widget.davClient, dm: widget.dm)
                    : _currentTab == "uploads"
                    ? UploadsTab(davClient: widget.davClient, um: widget.um)
                    : Expanded(
                        child: Center(child: Text("Tab not implemented yet.")),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
