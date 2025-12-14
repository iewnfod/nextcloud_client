import 'package:flutter/material.dart';
import 'package:nextcloud_client/utils.dart';
import 'package:webdav_client/webdav_client.dart';

class RemoveDownloadDialog extends StatefulWidget {
  final void Function() onRemove;
  final File file;
  final String savePath;

  const RemoveDownloadDialog({
    super.key,
    required this.onRemove,
    required this.file,
    required this.savePath,
  });

  @override
  State<RemoveDownloadDialog> createState() => _RemoveDownloadDialogState();
}

class _RemoveDownloadDialogState extends State<RemoveDownloadDialog> {
  bool _alsoRemoveOnDisk = false;
  bool _rememberOption = false;

  void _remove() {
    if (_rememberOption) {
      setBoolPref("removeOnDisk", _alsoRemoveOnDisk);
      setBoolPref("rememberRemoveOnDisk", _rememberOption);
    } else {
      setBoolPref("removeOnDisk", false);
      setBoolPref("rememberRemoveOnDisk", false);
    }

    if (_alsoRemoveOnDisk) {
      deleteFile(widget.savePath);
    }

    widget.onRemove();
  }

  @override
  void initState() {
    super.initState();
    getBoolPref("removeOnDisk").then((value) {
      if (value != null) {
        setState(() {
          _alsoRemoveOnDisk = value;
        });
      }
    });
    getBoolPref("rememberRemoveOnDisk").then((value) {
      if (value != null) {
        setState(() {
          _rememberOption = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      title: Column(
        crossAxisAlignment: .start,
        children: [
          Text("Remove Download"),
          Text(
            widget.file.name ?? "",
            overflow: .ellipsis,
            maxLines: 1,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
      content: Container(
        constraints: BoxConstraints(minHeight: 150.0),
        height: MediaQuery.of(context).size.height * 0.15,
        child: Column(
          mainAxisAlignment: .start,
          crossAxisAlignment: .start,
          children: [
            Text(
              "Are you sure you want to remove the download?",
              maxLines: 3,
              overflow: .ellipsis,
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Checkbox(
                  value: _alsoRemoveOnDisk,
                  onChanged: (value) {
                    setState(() {
                      _alsoRemoveOnDisk = value ?? !_alsoRemoveOnDisk;
                    });
                  },
                ),
                Text("Also remove the file from disk", overflow: .ellipsis),
              ],
            ),
            if (_alsoRemoveOnDisk)
              Row(
                children: [
                  Checkbox(
                    value: _rememberOption,
                    onChanged: (value) {
                      setState(() {
                        _rememberOption = value ?? !_rememberOption;
                      });
                    },
                  ),
                  Text("Remember this option", overflow: .ellipsis),
                ],
              ),
            SizedBox(height: 16.0),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            _remove();
            Navigator.of(context).pop(true);
          },
          child: Text("Remove"),
        ),
      ],
    );
  }
}
