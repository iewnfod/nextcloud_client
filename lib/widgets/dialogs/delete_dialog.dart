import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';

class DeleteDialog extends StatefulWidget {
  final void Function() onRemove;
  final File file;

  const DeleteDialog({super.key, required this.onRemove, required this.file});

  @override
  State<DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<DeleteDialog> {
  void _remove() {
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.5,
      ),
      title: Column(
        crossAxisAlignment: .start,
        children: [
          Text("Delete ${widget.file.isDir == true ? 'Folder' : 'File'}"),
          Text(
            widget.file.name ?? "",
            overflow: .ellipsis,
            maxLines: 1,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
      content: Container(
        constraints: BoxConstraints(minHeight: 50.0),
        height: MediaQuery.of(context).size.height * 0.1,
        child: Column(
          mainAxisAlignment: .start,
          crossAxisAlignment: .start,
          children: [
            Text(
              "Are you sure you want to delete this item? There is no way to recover it after deletion.",
              maxLines: 3,
              overflow: .ellipsis,
            ),
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
          child: Text("Delete"),
        ),
      ],
    );
  }
}
