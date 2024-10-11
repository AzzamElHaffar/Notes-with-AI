 class Prompt {
  final int? id;
  String content;
  DateTime timestamp;
  String title;
  int? folderId;

  Prompt({
    this.id,
    required this.content,
    required this.timestamp,
    String? title,
    this.folderId,
  }) : title = title ?? _generateTitle(content);

  static String _generateTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    return firstLine.isEmpty
        ? 'Untitled'
        : (firstLine.length > 25
            ? '${firstLine.substring(0, 25)}...'
            : firstLine);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'title': title,
      'folder_id': folderId,
    };
  }

  factory Prompt.fromMap(Map<String, dynamic> map) {
    return Prompt(
      id: map['id'] as int?,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      title:
          map['title'] as String? ?? _generateTitle(map['content'] as String),
      folderId: map['folder_id'] as int?,
    );
  }

  void updateTitle() {
    title = _generateTitle(content);
  }
}
