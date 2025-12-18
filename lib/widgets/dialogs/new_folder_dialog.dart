import 'package:flutter/material.dart';
import 'package:nextcloud_client/widgets/soft_button.dart';

class NewFolderDialog extends StatefulWidget {
  final void Function(String) onCreate;

  const NewFolderDialog({super.key, required this.onCreate});

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  final TextEditingController _controller = TextEditingController();
  String _errorMessage = "";

  void _create() {
    setState(() {
      _errorMessage = "";
    });
    final n = _controller.text.trim();
    if (n.isEmpty) {
      setState(() {
        _errorMessage = "Folder name cannot be empty.";
      });
      return;
    }
    if (n.contains('/')) {
      setState(() {
        _errorMessage = "Folder name cannot contain '/' character.";
      });
      return;
    }
    widget.onCreate(n);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Create New Folder"),
      content: Container(
        constraints: BoxConstraints(
          minHeight: _errorMessage.isNotEmpty ? 90.0 : 50.0,
        ),
        height: MediaQuery.of(context).size.height * 0.1,
        child: Column(
          spacing: 5.0,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Folder Name"),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Cancel"),
        ),
        SoftButton(
          onPressed: () {
            _create();
          },
          child: Text("Create"),
        ),
      ],
    );
  }
}
