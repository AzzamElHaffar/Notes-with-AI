import '../models/prompt.dart';
import '../services/database_service.dart';

class PromptsController {
  final DatabaseService _databaseService = DatabaseService();
  List<Prompt> _prompts = [];
  List<Prompt> _filteredPrompts = [];
  List<Map<String, dynamic>> _folders = [];
  int? _selectedFolderId;

  List<Prompt> get filteredPrompts => _filteredPrompts;
  List<Map<String, dynamic>> get folders => _folders;
  int? get selectedFolderId => _selectedFolderId;

  Future<void> loadFolders() async {
    try {
      final folders = await _databaseService.getPromptFolders();
      _folders = folders;
      // print('Loaded ${folders.length} prompt folders from the database');
    } catch (e) {
      print('Error loading prompt folders: $e');
      rethrow;
    }
  }

  Future<void> loadPrompts() async {
    try {
      final prompts =
          await _databaseService.getPrompts(folderId: _selectedFolderId);
      _prompts = prompts;
      _filteredPrompts = prompts;
      print(
          'Loaded ${prompts.length} prompts from the database for folder: ${_selectedFolderId ?? "All"}');
    } catch (e) {
      print('Error loading prompts: $e');
      rethrow;
    }
  }

  Future<int> addFolder(String folderName) async {
    final folderId = await _databaseService.insertPromptFolder(folderName);
    // print('Added prompt folder: $folderName with id: $folderId');
    await loadFolders();
    _selectedFolderId = folderId;
    return folderId;
  }

  void filterPrompts(String query) {
    _filteredPrompts = _prompts
        .where((prompt) =>
            prompt.title.toLowerCase().contains(query.toLowerCase()) ||
            prompt.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<int> addPrompt(String initialContent) async {
    try {
      final prompt = Prompt(
        content: initialContent,
        timestamp: DateTime.now(),
        folderId: _selectedFolderId,
      );
      final id = await _databaseService.insertPrompt(prompt);
      // print('Added prompt with id: $id');
      await loadPrompts();
      return id;
    } catch (e) {
      print('Error adding prompt: $e');
      rethrow;
    }
  }

  Future<void> updatePrompt(int id, String content) async {
    try {
      final prompt = _prompts.firstWhere((prompt) => prompt.id == id);
      prompt.content = content;
      prompt.timestamp = DateTime.now();
      prompt.updateTitle();
      await _databaseService.updatePrompt(prompt);
      // print(
      //     'Updated prompt with id: $id, content: $content, title: ${prompt.title}');
      await loadPrompts();
    } catch (e) {
      print('Error updating prompt: $e');
      rethrow;
    }
  }

  Future<void> deletePrompt(int id) async {
    try {
      await _databaseService.deletePrompt(id);
      // print('Deleted prompt with id: $id');
      await loadPrompts();
    } catch (e) {
      print('Error deleting prompt: $e');
      rethrow;
    }
  }

  Future<void> deleteFolder(int folderId) async {
    try {
      await _databaseService.deletePromptFolder(folderId);
      // print('Deleted prompt folder with id: $folderId');
      await loadFolders();
      _selectedFolderId = null;
      await loadPrompts();
    } catch (e) {
      print('Error deleting prompt folder: $e');
      rethrow;
    }
  }

  Future<void> renameFolder(int folderId, String newName) async {
    try {
      await _databaseService.updatePromptFolder(folderId, newName);
      await loadFolders();
    } catch (e) {
      print('Error renaming prompt folder: $e');
      rethrow;
    }
  }

  Future<void> renamePrompt(int promptId, String newName) async {
    try {
      await _databaseService.updatePromptName(promptId, newName);
      await loadPrompts();
    } catch (e) {
      print('Error renaming prompt: $e');
      rethrow;
    }
  }

  void setSelectedFolderId(int? folderId) {
    _selectedFolderId = folderId;
  }

  Map<String, List<Prompt>> groupPrompts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    Map<String, List<Prompt>> groupedPrompts = {
      'Today': _filteredPrompts
          .where((prompt) => prompt.timestamp.isAfter(today))
          .toList(),
      'Yesterday': _filteredPrompts
          .where((prompt) =>
              prompt.timestamp.isAfter(yesterday) &&
              prompt.timestamp.isBefore(today))
          .toList(),
      'Last 7 Days': _filteredPrompts
          .where((prompt) =>
              prompt.timestamp.isAfter(lastWeek) &&
              prompt.timestamp.isBefore(yesterday))
          .toList(),
      'This Month': _filteredPrompts
          .where((prompt) =>
              prompt.timestamp.isAfter(thisMonth) &&
              prompt.timestamp.isBefore(lastWeek))
          .toList(),
      'Older Prompts': _filteredPrompts
          .where((prompt) => prompt.timestamp.isBefore(thisMonth))
          .toList(),
    };

    groupedPrompts.forEach((key, prompts) {
      prompts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    return groupedPrompts;
  }

  Future<void> setFavoritePrompt(int favoriteId, int promptId) async {
    await _databaseService.setFavoritePrompt(favoriteId, promptId);
  }

  Future<Prompt?> getFavoritePrompt(int favoriteId) async {
    final promptId = await _databaseService.getFavoritePromptId(favoriteId);
    if (promptId != null) {
      final prompts = await _databaseService.getPrompts();
      return prompts.firstWhere((prompt) => prompt.id == promptId);
    }
    return null;
  }

  Future<String?> getFavoritePromptTitle(int favoriteId) async {
    return await _databaseService.getFavoritePromptTitle(favoriteId);
  }

  Future<bool> isFavoritePrompt(int promptId) async {
    for (int i = 1; i <= 3; i++) {
      final favoritePromptId = await _databaseService.getFavoritePromptId(i);
      if (favoritePromptId == promptId) {
        return true;
      }
    }
    return false;
  }

  Future<void> removeFavoritePrompt(int promptId) async {
    for (int i = 1; i <= 3; i++) {
      final favoritePromptId = await _databaseService.getFavoritePromptId(i);
      if (favoritePromptId == promptId) {
        await _databaseService.setFavoritePrompt(i, null);
        // print('Removed favorite prompt $promptId from favorite slot $i');
        break;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    return await _databaseService.getPromptFolders();
  }

  Future<void> movePromptToFolder(int promptId, int folderId) async {
    await _databaseService.movePromptToFolder(promptId, folderId);
    await loadPrompts();
  }

  Future<String> exportPromptsToJson() async {
    return await _databaseService.exportPromptsToJson();
  }

  Future<void> importPromptsFromJson(String jsonString) async {
    await _databaseService.importPromptsFromJson(jsonString);
    await loadPrompts();
  }
}
