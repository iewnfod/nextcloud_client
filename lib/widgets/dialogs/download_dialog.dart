import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nextcloud_client/download_manager.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';
import 'package:webdav_client/webdav_client.dart';

class DownloadDialog extends StatefulWidget {
  final File file;
  final Client davClient;
  final DownloadManager dm;

  const DownloadDialog({
    super.key,
    required this.file,
    required this.davClient,
    required this.dm,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  String _downloadPath = getDefaultDownloadPath();
  bool _setAsDefault = false;
  bool _isLoading = false;
  String _errorMessage = '';

  void _chooseDirectory() {
    FilePicker.platform.getDirectoryPath(initialDirectory: _downloadPath).then((
      path,
    ) {
      if (path != null) {
        setState(() {
          _downloadPath = path;
        });
        setStringPref("defaultDownloadPath", _downloadPath);
      }
    });
  }

  void _download() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    String savePathBase = '$_downloadPath/${widget.file.name!}';
    int offset = 0;
    String savePath = savePathBase;
    while (fileExists(savePath)) {
      offset += 1;
      savePath = savePathBase.replaceFirstMapped(
        RegExp(r'(\.[^.]*)$'),
        (match) => '($offset)${match.group(1)}',
      );
    }

    final download = DownloadItem(
      davFile: widget.file,
      savePath: savePath,
      onUpdate: widget.dm.updateDownload,
    );
    download.start(widget.davClient);
    widget.dm.addDownload(download);

    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    getBoolPref("setAsDefaultDownloadPath").then((value) {
      setState(() {
        _setAsDefault = value ?? false;
      });

      if (_setAsDefault) {
        getStringPref("defaultDownloadPath").then((path) {
          if (path != null) {
            setState(() {
              _downloadPath = path;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        child: Center(
          child: Card(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height * 0.4,
              constraints: BoxConstraints(minWidth: 400, minHeight: 250),
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: .start,
                    spacing: 10,
                    children: [
                      Column(
                        mainAxisAlignment: .start,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            "Download File",
                            style: TextStyle(fontSize: 18, fontWeight: .bold),
                          ),
                          Text(
                            widget.file.name!,
                            overflow: .ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0),
                        child: Row(
                          spacing: 16,
                          children: [
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                controller: TextEditingController(
                                  text: _downloadPath,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Download Location",
                                ),
                              ),
                            ),
                            SoftButton(
                              onPressed: () {
                                _chooseDirectory();
                              },
                              child: Icon(Icons.folder_open),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _setAsDefault,
                            onChanged: (v) {
                              setState(() {
                                _setAsDefault = v ?? !_setAsDefault;
                              });
                              setBoolPref(
                                "setAsDefaultDownloadPath",
                                _setAsDefault,
                              );
                              if (_setAsDefault) {
                                setStringPref(
                                  "defaultDownloadPath",
                                  _downloadPath,
                                );
                              }
                            },
                          ),
                          Text("Set as default download location"),
                        ],
                      ),
                    ],
                  ),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      overflow: .ellipsis,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.red),
                    ),
                  Row(
                    mainAxisAlignment: .end,
                    spacing: 10,
                    children: [
                      SoftButton(
                        onPressed: () {
                          if (_isLoading) return;
                          Navigator.of(context).pop();
                        },
                        color: Colors.red,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "Cancel",
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      SoftButton(
                        onPressed: () {
                          _download();
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(),
                                )
                              : Text("Start Download"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
