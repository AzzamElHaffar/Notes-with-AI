import 'package:flutter/material.dart';

class ShowDeleteNoteDialog extends StatelessWidget {
  final int selectedNoteId;
  final Function(int) onDelete;

  const ShowDeleteNoteDialog({
    super.key,
    required this.selectedNoteId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Note'),
      content: const Text('Are you sure you want to delete this note?'),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Delete'),
          onPressed: () {
            Navigator.of(context).pop();
            if (selectedNoteId != -1) {
              onDelete(selectedNoteId);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No note selected for deletion')),
              );
            }
          },
        ),
      ],
    );
  }
}