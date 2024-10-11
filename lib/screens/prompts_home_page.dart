import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/prompts_controller.dart';
import '../controllers/notes_controller.dart';
import '../prompts_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class PromptsHomePage extends StatefulWidget {
  final int selectedNoteId;
  const PromptsHomePage({super.key, required this.selectedNoteId});

  @override
  _PromptsHomePageState createState() => _PromptsHomePageState();
}

class _PromptsHomePageState extends State<PromptsHomePage> {
  final PromptsController _promptsController = PromptsController();
  final NotesController _notesController = NotesController();
  int _selectedPromptId = -1;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _newPromptId;
  final TextEditingController _promptFolderController = TextEditingController();
  final TextEditingController _promptNameController = TextEditingController();
  double _promptFolderListWidth = 200;
  double _promptsListWidth = 320;
  bool _isPromptFolderListVisible = true;
  static const double _minPromptFolderListWidth = 160.0;
  static const double _maxPromptFolderListWidth = 500.0;
  static const double _minPromptsListWidth = 300.0;
  static const double _maxPromptsListWidth = 600.0;
  late int _selectedNoteId;

  @override
  void initState() {
    super.initState();
    _selectedNoteId = widget.selectedNoteId;
    print(_selectedNoteId);
    _loadData();
    _searchController.addListener(_filterPrompts);
    _promptController.addListener(_handlePromptInput);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPrompts);
    _promptController.removeListener(_handlePromptInput);
    _searchController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _promptsController.loadFolders();
    await _promptsController.loadPrompts();
    setState(() {});
  }

  void _updatePromptFolderListWidth(double delta) {
    setState(() {
      _promptFolderListWidth += delta;
      if (_promptFolderListWidth < _minPromptFolderListWidth) {
        _isPromptFolderListVisible = false;
        _promptFolderListWidth = 0;
      } else {
        _isPromptFolderListVisible = true;
        _promptFolderListWidth = _promptFolderListWidth.clamp(
            _minPromptFolderListWidth, _maxPromptFolderListWidth);
      }
    });
  }

  void _showFolderContextMenu(
      BuildContext context, int folderId, String folderName, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Rename'),
          ),
          onTap: () => _renameFolder(folderId, folderName),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
          ),
          onTap: () => _showDeleteFolderDialog(),
        ),
      ],
    );
  }

  void _showPromptContextMenu(
      BuildContext context, int promptId, String promptTitle, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: ListTile(
            leading:
                Image.asset('lib/icons/delete_icon.png', width: 17, height: 17),
            title: const Text('Delete'),
          ),
          onTap: () => _showDeletePromptDialog(),
        ),
        PopupMenuItem(
          child: ListTile(
            leading:
                Image.asset('lib/icons/create_icon.png', width: 17, height: 17),
            title: const Text('Rename'),
          ),
          onTap: () => _renamePrompt(promptId, promptTitle),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Image.asset('lib/icons/favorite_icon.png',
                width: 17, height: 17),
            title: const Text('Set as Favorite'),
          ),
          onTap: () => _showFavoritePromptDialog(promptId),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Image.asset('lib/icons/unfavorite_icon.png',
                width: 17, height: 17),
            title: const Text('Remove Favorite'),
          ),
          onTap: () async {
            await _promptsController.removeFavoritePrompt(promptId);
            setState(() {});
          },
        ),
        PopupMenuItem(
          child: ListTile(
            leading:
                Image.asset('lib/icons/move_icon.png', width: 17, height: 17),
            title: const Text('Move'),
          ),
          onTap: () => _showMoveFolderDialog(promptId),
        ),
      ],
    );
  }

  void _showFavoritePromptDialog(int promptId) async {
    final favoriteTitles = await Future.wait([
      _promptsController.getFavoritePromptTitle(1),
      _promptsController.getFavoritePromptTitle(2),
      _promptsController.getFavoritePromptTitle(3),
    ]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Favorite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Image.asset('lib/icons/favorite_icon.png',
                  width: 17, height: 17),
              title: Text(favoriteTitles[0] ?? 'Available'),
              onTap: () {
                _setFavoritePrompt(1, promptId);
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Image.asset('lib/icons/favorite_icon.png',
                  width: 17, height: 17),
              title: Text(favoriteTitles[1] ?? 'Available'),
              onTap: () {
                _setFavoritePrompt(2, promptId);
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Image.asset('lib/icons/favorite_icon.png',
                  width: 17, height: 17),
              title: Text(favoriteTitles[2] ?? 'Available'),
              onTap: () {
                _setFavoritePrompt(3, promptId);
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setFavoritePrompt(int favoriteId, int promptId) async {
    await _promptsController.setFavoritePrompt(favoriteId, promptId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Set as Favorite $favoriteId')),
    );
  }

  void _renameFolder(int folderId, String currentName) {
    _promptFolderController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          autofocus: true,
          controller: _promptFolderController,
          decoration: const InputDecoration(hintText: 'Enter new folder name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Rename'),
            onPressed: () async {
              final newName = _promptFolderController.text;
              if (newName.isNotEmpty) {
                await _promptsController.renameFolder(folderId, newName);
                Navigator.of(context).pop();
                await _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  void _renamePrompt(int promptId, String currentName) {
    _promptNameController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Prompt'),
        content: TextField(
          autofocus: true,
          controller: _promptNameController,
          decoration: const InputDecoration(hintText: 'Enter new prompt name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Rename'),
            onPressed: () async {
              final newName = _promptNameController.text;
              if (newName.isNotEmpty) {
                await _promptsController.renamePrompt(promptId, newName);
                Navigator.of(context).pop();
                await _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  void _updatePromptsListWidth(double delta) {
    setState(() {
      _promptsListWidth += delta;
      _promptsListWidth =
          _promptsListWidth.clamp(_minPromptsListWidth, _maxPromptsListWidth);
    });
  }

  Future<void> _addFolder() async {
    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Prompt Folder'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
          controller: _promptFolderController,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Create'),
            onPressed: () async {
              final textField = _promptFolderController.text;
              if (textField.isNotEmpty) {
                await _promptsController.addFolder(textField);
                Navigator.of(context).pop(textField);
                await _loadData();
                setState(() {
                  _selectedPromptId = -1;
                  _promptFolderController.clear();
                  _promptController.clear();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder name cannot be empty')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _filterPrompts() {
    _promptsController.filterPrompts(_searchController.text);
    setState(() {});
  }

  void _handlePromptInput() {
    if (_promptController.text.isNotEmpty && _selectedPromptId == -1) {
      print('Handle Prompt Input');
      _addPrompt(_promptController.text);
    }
  }

  Future<void> _addPrompt([String initialContent = '']) async {
    try {
      final id = await _promptsController.addPrompt(initialContent);
      setState(() {
        _selectedPromptId = id;
        _newPromptId = id;
        _promptController.text = initialContent;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPrompt(id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add prompt: $e')),
      );
    }
  }

  void _handlePromptSelection(int promptId) {
    if (_newPromptId != null &&
        _newPromptId != promptId &&
        _promptController.text.isEmpty) {
      _deletePrompt(_newPromptId!);
      _newPromptId = null;
    }
    setState(() {
      _selectedPromptId = promptId;
      _promptController.text = _promptsController.filteredPrompts
          .firstWhere((prompt) => prompt.id == promptId)
          .content;
    });
  }

  void _scrollToPrompt(int id) {
    final index = _promptsController.filteredPrompts
        .indexWhere((prompt) => prompt.id == id);
    if (index != -1) {
      _scrollController.animateTo(
        index * 56.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _updatePrompt(int id, String content) async {
    try {
      await _promptsController.updatePrompt(id, content);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update prompt: $e')),
      );
    }
  }

  Future<void> _deletePrompt(int id) async {
    try {
      await _promptsController.deletePrompt(id);
      await _loadData();
      if (_selectedPromptId == id) {
        setState(() {
          _selectedPromptId = -1;
          _promptController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete prompt: $e')),
      );
    }
  }

  void _deleteSelectedItem() {
    if (_selectedPromptId != -1) {
      _showDeletePromptDialog();
    } else if (_promptsController.selectedFolderId != null) {
      _showDeleteFolderDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prompt or folder selected')),
      );
    }
  }

  void _showDeletePromptDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Prompt'),
          content: const Text('Are you sure you want to delete this prompt?'),
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
                _deletePrompt(_selectedPromptId);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFolderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text(
              'Are you sure you want to delete this folder? All the prompts inside it will be deleted.'),
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
                if (_promptsController.selectedFolderId != null &&
                    _promptsController.selectedFolderId! > 0) {
                  _deleteFolder(_promptsController.selectedFolderId!);
                  setState(() {
                    _promptController.clear();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No valid folder selected for deletion')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFolder(int folderId) async {
    try {
      await _promptsController.deleteFolder(folderId);
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete prompt folder: $e')),
      );
    }
  }

  void _sendPromptAndAddPage() async {
    if (!mounted) return;

    // Show loading indicator with semi-transparent white background
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Container(
          color: Colors.white.withOpacity(0.5),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );

    if (_selectedNoteId != -1) {
      String? firstPageContent =
          await _notesController.getFirstPageContent(_selectedNoteId);
      if (firstPageContent != null) {
        String fullPrompt =
            "${_promptController.text}\n<input>\n$firstPageContent\n</input>";
        try {
          final result = await chatWithGpt(fullPrompt);
          if (!mounted) return;
          
          // Close loading indicator
          Navigator.of(context).pop();

          await _notesController.addPage(_selectedNoteId, result);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New page added to the note')),
          );
          Navigator.pop(context);
        } catch (e) {
          if (!mounted) return;
          
          // Close loading indicator
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error in chatWithGpt: ${e.toString()}')),
          );
        }
      } else {
        if (!mounted) return;
        
        // Close loading indicator
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No content found in the first page')),
        );
      }
    } else {
      if (!mounted) return;
      
      // Close loading indicator
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No note selected')),
      );
    }
  }

  void _showMoveFolderDialog(int promptId) async {
    final folders = await _promptsController.getFolders();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                title: Text(folder['name']),
                onTap: () async {
                  await _promptsController.movePromptToFolder(
                      promptId, folder['id']);
                  Navigator.of(context).pop();
                  await _loadData();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportPrompts() async {
    try {
      final jsonString = await _promptsController.exportPromptsToJson();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/prompts_export.json');
      await file.writeAsString(jsonString);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prompts exported to ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export prompts: $e')),
      );
    }
  }

  Future<void> _importPrompts() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        await _promptsController.importPromptsFromJson(jsonString);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prompts imported successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import prompts: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedPrompts = _promptsController.groupPrompts();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Prompts'),
            const SizedBox(width: 16),
            IconButton(
              icon: Image.asset('lib/icons/sidebar_icon.png',
                  width: 24, height: 24),
              // Icon(
              //     _isPromptFolderListVisible ? Icons.folder_off : Icons.folder),
              onPressed: () {
                setState(() {
                  _isPromptFolderListVisible = !_isPromptFolderListVisible;
                  _promptFolderListWidth = _isPromptFolderListVisible
                      ? _minPromptFolderListWidth
                      : 0;
                });
              },
              tooltip: _isPromptFolderListVisible
                  ? 'Hide prompt folders'
                  : 'Show prompt folders',
            ),
            const SizedBox(width: 50),
            IconButton(
              icon: Image.asset('lib/icons/delete_icon.png',
                  width: 24, height: 24),
              onPressed: _deleteSelectedItem,
              tooltip: 'Delete Selected',
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Image.asset('lib/icons/create_icon.png',
                  width: 24, height: 24),
              onPressed: () => _addPrompt(),
              tooltip: 'Create Prompt',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                Image.asset('lib/icons/import_icon.png', width: 24, height: 24),
            onPressed: _exportPrompts,
            tooltip: 'Export Prompts',
          ),
          IconButton(
            icon:
                Image.asset('lib/icons/export_icon.png', width: 24, height: 24),
            onPressed: _importPrompts,
            tooltip: 'Import Prompts',
          ),
          const SizedBox(width: 16),
          Container(
            width: 300,
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search prompts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              ),
              onChanged: (value) {
                _filterPrompts();
              },
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (_isPromptFolderListVisible) ...[
            SizedBox(
              width: _promptFolderListWidth,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[300],
                      child: ListView.builder(
                        itemCount: _promptsController.folders.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              title: const Text('All Prompts'),
                              selected:
                                  _promptsController.selectedFolderId == null,
                              onTap: () {
                                setState(() {
                                  _promptsController.setSelectedFolderId(null);
                                });
                                _loadData();
                              },
                            );
                          }
                          final folder = _promptsController.folders[index - 1];
                          return GestureDetector(
                            onSecondaryTapDown: (details) {
                              _showFolderContextMenu(context, folder['id'],
                                  folder['name'], details.globalPosition);
                            },
                            child: ListTile(
                              title: Text(folder['name']),
                              selected: _promptsController.selectedFolderId ==
                                  folder['id'],
                              onTap: () {
                                setState(() {
                                  _promptsController
                                      .setSelectedFolderId(folder['id']);
                                });
                                _loadData();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.grey[300],
                    child: ListTile(
                      leading: Image.asset('lib/icons/add_icon.png',
                          width: 18, height: 18),
                      title: const Text('New Folder'),
                      onTap: _addFolder,
                    ),
                  )
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onPanUpdate: (details) {
                  _updatePromptFolderListWidth(details.delta.dx);
                },
                child: Container(
                  width: 4,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
          SizedBox(
            width: _promptsListWidth,
            child: Container(
              color: Colors.grey[200],
              child: ListView.builder(
                controller: _scrollController,
                itemCount: groupedPrompts.length,
                itemBuilder: (context, index) {
                  final groupTitle = groupedPrompts.keys.elementAt(index);
                  final notes = groupedPrompts[groupTitle]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          groupTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...notes.map(
                        (prompt) => FutureBuilder<bool>(
                          future:
                              _promptsController.isFavoritePrompt(prompt.id!),
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data ?? false;
                            return GestureDetector(
                              onSecondaryTapDown: (details) {
                                _showPromptContextMenu(context, prompt.id!,
                                    prompt.title, details.globalPosition);
                              },
                              child: ListTile(
                                leading: isFavorite
                                    ? Image.asset('lib/icons/favorite_icon.png',
                                        width: 18, height: 18)
                                    : null,
                                title: Text(prompt.title),
                                subtitle: Text(
                                  DateFormat('dd/MM/yyyy HH:mm')
                                      .format(prompt.timestamp),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: prompt.id == _selectedPromptId,
                                onTap: () => _handlePromptSelection(prompt.id!),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onPanUpdate: (details) {
                _updatePromptsListWidth(details.delta.dx);
              },
              child: Container(
                width: 3,
                color: Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _promptController,
                    maxLines: null,
                    expands: true,
                    onChanged: (content) {
                      if (_selectedPromptId != -1) {
                        _updatePrompt(_selectedPromptId, content);
                        if (_newPromptId == _selectedPromptId &&
                            content.isNotEmpty) {
                          _newPromptId = null;
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Write your prompt here...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                right: 50,
                child: ElevatedButton.icon(
                  onPressed: _sendPromptAndAddPage,
                  icon: Image.asset('lib/icons/ai_icon.png',
                      width: 24, height: 24),
                  label: const Text(
                    'Apply',
                    style: TextStyle(
                        color: Color(
                            0xFF4A90E2)), // Assuming the icon color is #4A90E2
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF4A90E2),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
