import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud_client/managers/download_manager.dart';
import 'package:nextcloud_client/managers/file_manager.dart';
import 'package:nextcloud_client/managers/upload_manager.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:nextcloud_client/widgets/dialogs/delete_dialog.dart';
import 'package:nextcloud_client/widgets/dialogs/download_dialog.dart';
import 'package:nextcloud_client/widgets/dialogs/new_folder_dialog.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';
import 'package:webdav_client/webdav_client.dart';

class AllFilesTab extends StatefulWidget {
  final NextcloudClient client;
  final Client davClient;
  final DownloadManager dm;
  final UploadManager um;
  final FileManager fm;

  const AllFilesTab({
    super.key,
    required this.client,
    required this.davClient,
    required this.dm,
    required this.um,
    required this.fm,
  });

  @override
  State<AllFilesTab> createState() => _AllFilesTabState();
}

class _AllFilesTabState extends State<AllFilesTab> {
  void _downloadFile(File f) {
    print("Downloading file: ${f.name!}");
    showDialog(
      context: context,
      builder: (context) {
        return DownloadDialog(
          file: f,
          davClient: widget.davClient,
          dm: widget.dm,
        );
      },
    );
  }

  void _newFolder() {
    print("Creating new folder");
    showDialog(
      context: context,
      builder: (context) {
        return NewFolderDialog(
          onCreate: (n) {
            widget.davClient
                .mkdir(widget.fm.path2String([...widget.fm.path, n]))
                .then((_) {
                  widget.fm.fetchFolderTree(widget.fm.getPathString());
                })
                .catchError((e) {
                  print("Error creating folder: $e");
                });
          },
        );
      },
    );
  }

  void _delete(File f) {
    print("Deleting file/folder: ${f.name!}");
    showDialog(
      context: context,
      builder: (context) {
        return DeleteDialog(
          onRemove: () {
            widget.davClient
                .removeAll(f.path!)
                .then((_) {
                  widget.fm.fetchFolderTree(widget.fm.getPathString());
                })
                .catchError((e) {
                  print("Error deleting file/folder: $e");
                });
          },
          file: f,
        );
      },
    );
  }

  void _upload() {
    FilePicker.platform.pickFiles(allowMultiple: true).then((f) {
      f?.files.forEach((file) {
        if (file.path != null) {
          if (!fileExists(file.path!)) {
            return;
          }
          if (isFolder(file.path!)) {
            return;
          }
          final item = UploadItem(
            localPath: file.path!,
            remotePath: widget.fm.path2String([...widget.fm.path, file.name]),
            onUpdate: widget.um.updateUpload,
          );
          widget.um.addUpload(item);
          item.start(widget.davClient);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    widget.fm.fetchFolderTree(widget.fm.getPathString(), depth: 2);
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
          spacing: 10,
          children: [
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Row(
                  spacing: 5,
                  children: widget.fm.path.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    return SoftButton(
                      onPressed: () {
                        widget.fm.popPath(index: index + 1);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(.circular(8.0)),
                        ),
                        minimumSize: Size(0, 40),
                      ),
                      child: Text(p.isEmpty ? "/" : p),
                    );
                  }).toList(),
                ),
                Row(
                  spacing: 8.0,
                  children: [
                    SoftButton(
                      onPressed: () {
                        _newFolder();
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(.circular(8.0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 5),
                          Transform.translate(
                            offset: Offset(0, -2),
                            child: Text("New Folder"),
                          ),
                        ],
                      ),
                    ),
                    SoftButton(
                      onPressed: () {
                        _upload();
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(.circular(8.0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.upload),
                          SizedBox(width: 5),
                          Transform.translate(
                            offset: Offset(0, -2),
                            child: Text("Upload"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  SoftButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: .circular(8.0),
                          topRight: .circular(8.0),
                        ),
                      ),
                    ),
                    color: Colors.grey.withAlpha(5),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: .spaceBetween,
                        spacing: 16.0,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(width: 30, height: 20),
                                SizedBox(width: 10),
                                Transform.translate(
                                  offset: Offset(0, -1),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.5,
                                    ),
                                    child: Text("Name"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text("Size"),
                          SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.withAlpha(100)),
                  Expanded(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: .vertical,
                        primary: true,
                        child: Column(
                          children:
                              widget.fm
                                  .getFolderTree(
                                    widget.fm.getPathString(),
                                    autoFetch: false,
                                    autoFetchThumbnails: false,
                                  )
                                  .isEmpty
                              ? [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.7,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ]
                              : widget.fm.getFolderTree(widget.fm.getPathString()).map((
                                  v,
                                ) {
                                  return Column(
                                    children: [
                                      SoftButton(
                                        onPressed: () {
                                          if (v.name != null) {
                                            if (v.isDir == true) {
                                              widget.fm.pushPath(v.name!);
                                            } else {
                                              _downloadFile(v);
                                            }
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.zero,
                                          ),
                                        ),
                                        color: Colors.grey.withAlpha(5),
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Row(
                                            mainAxisAlignment: .spaceBetween,
                                            spacing: 16.0,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 30,
                                                      height: 30,
                                                      child: v.isDir == true
                                                          ? Icon(
                                                              Icons.folder,
                                                              size: 24,
                                                            )
                                                          : (widget
                                                                .fm
                                                                .thumbnails
                                                                .containsKey(
                                                                  v.path!,
                                                                ))
                                                          ? Container(
                                                              clipBehavior:
                                                                  .hardEdge,
                                                              decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius.all(
                                                                      .circular(
                                                                        4.0,
                                                                      ),
                                                                    ),
                                                              ),
                                                              child: widget.fm
                                                                  .getThumbnail(
                                                                    v.path!,
                                                                  ),
                                                            )
                                                          : Icon(
                                                              Icons
                                                                  .insert_drive_file,
                                                              size: 24,
                                                            ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Transform.translate(
                                                      offset: Offset(0, -1),
                                                      child: ConstrainedBox(
                                                        constraints:
                                                            BoxConstraints(
                                                              maxWidth:
                                                                  MediaQuery.of(
                                                                    context,
                                                                  ).size.width *
                                                                  0.5,
                                                            ),
                                                        child: Text(
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          v.name ?? "Unknown",
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                v.isDir == true
                                                    ? "-"
                                                    : calcSize(v.size ?? 0),
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: IconButton(
                                                  onPressed: () {
                                                    _delete(v);
                                                  },
                                                  icon: Icon(Icons.delete),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        height: 1,
                                        color: Colors.grey.withAlpha(100),
                                      ),
                                    ],
                                  );
                                }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
