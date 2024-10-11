import '../models/note.dart';
import '../models/pages.dart';
import '../services/database_service.dart';

class NotesController {
  final DatabaseService _databaseService = DatabaseService();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  List<Map<String, dynamic>> _folders = [];
  List<Pages> _pages = [];
  int? _selectedFolderId;

  List<Note> get filteredNotes => _filteredNotes;
  List<Map<String, dynamic>> get folders => _folders;
  List<Pages> get pages => _pages;
  int? get selectedFolderId => _selectedFolderId;

  void filterNotes(String query) {
    _filteredNotes = _notes
        .where((note) =>
            note.title.toLowerCase().contains(query.toLowerCase()) ||
            note.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> loadNotes() async {
    try {
      final notes =
          await _databaseService.getNotes(folderId: _selectedFolderId);
      _notes = notes;
      _filteredNotes = notes;
      // print(
      //     'Loaded ${notes.length} notes from the database for folder: ${_selectedFolderId ?? "All"}');
    } catch (e) {
      print('Error loading notes: $e');
      rethrow;
    }
  }

  Future<void> loadPages(int noteId) async {
    try {
      final pages = await _databaseService.getPages(noteId: noteId);
      _pages = pages;
      // print('Loaded ${folders.length} folders from the database');
    } catch (e) {
      print('Error loading folders: $e');
      rethrow;
    }
  }

  Future<int> addNote(String initialContent) async {
    try {
      final note = Note(
        content: initialContent,
        timestamp: DateTime.now(),
        folderId: _selectedFolderId,
      );
      final id = await _databaseService.insertNote(note);
      // print('Added note with id: $id');
      await loadNotes();
      return id;
    } catch (e) {
      print('Error adding note: $e');
      rethrow;
    }
  }

  Future<int> addPage(int noteId, String content, {int? pageIndex}) async {
    try {
      final page = Pages(
        content: content,
        timestamp: DateTime.now(),
        pageindex: pageIndex ?? _pages.length + 1,
        noteId: noteId,
      );
      final id = await _databaseService.insertPage(page);
      // print('Added page with id: $id for note: $noteId');
      await loadPages(noteId);
      return id;
    } catch (e) {
      print('Error adding page: $e');
      rethrow;
    }
  }

  Future<void> updateNote(int id, String content) async {
    try {
      final note = _notes.firstWhere((note) => note.id == id);
      note.content = content;
      note.timestamp = DateTime.now();
      note.updateTitle();
      await _databaseService.updateNote(note);
      // print(
      //     'Updated note with id: $id, content: $content, title: ${note.title}');
      await loadNotes();
    } catch (e) {
      print('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> updatePage(Pages page) async {
    try {
      page.timestamp = DateTime.now();
      await _databaseService.updatePage(page);
      // print('Updated page with id: ${page.id}');
      await loadPages(page.noteId!);
    } catch (e) {
      print('Error updating page: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(int id) async {
    try {
      await _databaseService.deletePagesByNoteId(id);
      await _databaseService.deleteNote(id);
      // print('Deleted note with id: $id');
      await loadNotes();
    } catch (e) {
      print('Error deleting note: $e');
      rethrow;
    }
  }

  Future<void> deletePage(int noteId, int pageIndex) async {
    try {
      if (pageIndex >= 0 && pageIndex < _pages.length) {
        final pageToDelete = _pages[pageIndex];
        await _databaseService.deletePage(pageToDelete.id!);
        // print('Deleted page with index: $pageIndex for note: $noteId');
        await loadPages(noteId);
      } else {
        print('Invalid page index: $pageIndex');
      }
    } catch (e) {
      print('Error deleting page: $e');
      rethrow;
    }
  }

  Future<void> loadFolders() async {
    try {
      final folders = await _databaseService.getFolders();
      _folders = folders;
      // print('Loaded ${folders.length} folders from the database');
    } catch (e) {
      print('Error loading folders: $e');
      rethrow;
    }
  }

  Future<int> addFolder(String folderName) async {
    final folderId = await _databaseService.insertFolder(folderName);
    // print('Added folder: $folderName with id: $folderId');
    await loadFolders();
    _selectedFolderId = folderId;
    return folderId;
  }

  Future<void> deleteFolder(int folderId) async {
    try {
      await _databaseService.deleteFolder(folderId);
      // print('Deleted folder with id: $folderId');
      await loadFolders();
      _selectedFolderId = null;
      await loadNotes();
    } catch (e) {
      print('Error deleting folder: $e');
      rethrow;
    }
  }

  Future<void> renameFolder(int folderId, String newName) async {
    try {
      await _databaseService.updateFolder(folderId, newName);
      await loadFolders();
    } catch (e) {
      print('Error renaming folder: $e');
      rethrow;
    }
  }

  void setSelectedFolderId(int? folderId) {
    _selectedFolderId = folderId;
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    return await _databaseService.getFolders();
  }

  Map<String, List<Note>> groupNotes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    Map<String, List<Note>> groupedNotes = {
      'Today': _filteredNotes
          .where((note) => note.timestamp.isAfter(today))
          .toList(),
      'Yesterday': _filteredNotes
          .where((note) =>
              note.timestamp.isAfter(yesterday) &&
              note.timestamp.isBefore(today))
          .toList(),
      'Last 7 Days': _filteredNotes
          .where((note) =>
              note.timestamp.isAfter(lastWeek) &&
              note.timestamp.isBefore(yesterday))
          .toList(),
      'This Month': _filteredNotes
          .where((note) =>
              note.timestamp.isAfter(thisMonth) &&
              note.timestamp.isBefore(lastWeek))
          .toList(),
      'Older Notes': _filteredNotes
          .where((note) => note.timestamp.isBefore(thisMonth))
          .toList(),
    };

    groupedNotes.forEach((key, notes) {
      notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    return groupedNotes;
  }

  Future<String?> getFirstPageContent(int noteId) async {
    try {
      await loadPages(noteId);
      if (_pages.isNotEmpty) {
        return _pages.first.content;
      }
      return null;
    } catch (e) {
      print('Error getting first page content: $e');
      return null;
    }
  }

  // Add this method to the NotesController class
  Future<void> moveNoteToFolder(int noteId, int folderId) async {
    await _databaseService.moveNoteToFolder(noteId, folderId);
    await loadNotes();
  }
}
