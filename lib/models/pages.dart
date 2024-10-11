class Pages {
  final int? id;
  String content;
  DateTime timestamp;
  int? pageindex;
  int? noteId;

  Pages({
    this.id,
    required this.content,
    required this.timestamp,
    this.pageindex,
    this.noteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'pageindex': pageindex,
      'note_id': noteId,
    };
  }

  factory Pages.fromMap(Map<String, dynamic> map) {
    return Pages(
      id: map['id'] as int?,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      pageindex: map['pageindex'] as int?,
      noteId: map['note_id'] as int?,
    );
  }

}
