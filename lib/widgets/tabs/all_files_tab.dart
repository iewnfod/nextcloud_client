import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud/core.dart';
import 'package:nextcloud/nextcloud.dart';
import 'package:nextcloud_client/download_manager.dart';
import 'package:nextcloud_client/upload_manager.dart';
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
  final List<String> path;
  final void Function(List<String>) updatePath;

  const AllFilesTab({
    super.key,
    required this.client,
    required this.davClient,
    required this.dm,
    required this.um,
    required this.path,
    required this.updatePath,
  });

  @override
  State<AllFilesTab> createState() => _AllFilesTabState();
}

class _AllFilesTabState extends State<AllFilesTab> {
  List<File> tree = [];
  Map<String, Image> _thumbnails = {};

  Future<List<File>> _fetchFolderTree(String path) async {
    print("Fetching folder tree for path: $path");
    try {
      final data = await widget.davClient.readDir(path);
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

  void _thumbnail(String filePath, {int? x = 64, int? y = 64}) {
    print("Fetching thumbnail for $filePath");
    widget.client.core.preview
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
              setState(() {
                _thumbnails[filePath] = img;
              });
            }
          } catch (e) {
            print("Error processing thumbnail for $filePath: $e");
          }
        })
        .catchError((e) {
          print("Error fetching thumbnail for $filePath: $e");
        });
  }

  String _path2String(List<String> path) {
    if (path.isEmpty || (path.length == 1 && path[0] == "")) {
      return "/";
    }
    return path.join("/");
  }

  void _pushPath(String segment) {
    final newPath = [...widget.path, segment];
    _updateFolderTree(newPath).then((status) {
      if (status) {
        widget.updatePath(newPath);
      }
    });
  }

  Future<bool> _updateFolderTree(
    List<String> newPath, {
    bool? sort = true,
  }) async {
    try {
      final v = await _fetchFolderTree(_path2String(newPath));
      if (sort == true) {
        v.sort((f1, f2) {
          if (f1.isDir == f2.isDir) {
            return f1.name!.compareTo(f2.name!);
          } else if (f1.isDir == true) {
            return -1;
          } else {
            return 1;
          }
        });
      }
      setState(() {
        tree = v;
      });
      for (var f in v) {
        if (f.isDir != true) {
          _thumbnail(f.path!);
        }
      }
      return true;
    } catch (e) {
      print("Error updating folder tree: $e");
      return false;
    }
  }

  void _popPath(int index) {
    final newPath = widget.path.sublist(0, index + 1);
    _updateFolderTree(newPath).then((status) {
      if (status) {
        widget.updatePath(newPath);
      }
    });
  }

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
                .mkdir(_path2String([...widget.path, n]))
                .then((_) {
                  _updateFolderTree(widget.path);
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
                  _updateFolderTree(widget.path);
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
            remotePath: _path2String([...widget.path, file.name]),
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
    _updateFolderTree(widget.path);
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
                  children: widget.path.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    return SoftButton(
                      onPressed: () {
                        _popPath(index);
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
                          children: tree.map((v) {
                            return Column(
                              children: [
                                SoftButton(
                                  onPressed: () {
                                    if (v.name != null) {
                                      if (v.isDir == true) {
                                        _pushPath(v.name!);
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
                                                    : (_thumbnails.containsKey(
                                                        v.path!,
                                                      ))
                                                    ? Container(
                                                        clipBehavior: .hardEdge,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                .circular(4.0),
                                                              ),
                                                        ),
                                                        child:
                                                            _thumbnails[v
                                                                .path!],
                                                      )
                                                    : Icon(
                                                        Icons.insert_drive_file,
                                                        size: 24,
                                                      ),
                                              ),
                                              SizedBox(width: 10),
                                              Transform.translate(
                                                offset: Offset(0, -1),
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth:
                                                        MediaQuery.of(
                                                          context,
                                                        ).size.width *
                                                        0.5,
                                                  ),
                                                  child: Text(
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    v.name ?? "Unknown",
                                                    style: const TextStyle(
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
