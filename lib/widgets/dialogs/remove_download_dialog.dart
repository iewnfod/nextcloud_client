import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';

class RemoveDownloadDialog extends StatelessWidget {
  final void Function() onRemove;
  final File file;

  const RemoveDownloadDialog({
    super.key,
    required this.onRemove,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Remove Download"),
      content: Text(
        "Are you sure you want to remove the download for ${file.name}?",
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
            onRemove();
            Navigator.of(context).pop(true);
          },
          child: Text("Remove"),
        ),
      ],
    );
  }
}
