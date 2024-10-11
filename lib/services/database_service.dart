import 'dart:convert';
import '../models/prompt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/note.dart';
import '../models/pages.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<void> initDatabase() async {
    if (_database != null) return;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'notes_with_ai.db');
    // print('Database path: $path');

    _database = await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await _createNotesTable(db);
        await _createFoldersTable(db);
        await _createPagesTable(db);
        await _createPromptsTable(db);
        await _createPromptFoldersTable(db);
        await _createFavoritePromptsTable(db);
        print('Database created');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE notes ADD COLUMN title TEXT');
        }
        if (oldVersion < 3) {
          await _createFoldersTable(db);
          await db.execute(
              'ALTER TABLE notes ADD COLUMN folder_id INTEGER REFERENCES folders(id)');
        }
        if (oldVersion < 4) {
          await _createPagesTable(db);
        }
        if (oldVersion < 5) {
          await _createPromptsTable(db);
          await _createPromptFoldersTable(db);
        }
        if (oldVersion < 6) {
          await _createFavoritePromptsTable(db);
        }
        print('Database upgraded from version $oldVersion to $newVersion');
      },
    );
  }

  Future<void> _createFoldersTable(Database db) async {
    await db.execute('''
      CREATE TABLE folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    // print('Folders table created');
  }

  Future<Database> get database async {
    if (_database == null) {
      await initDatabase();
    }
    return _database!;
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        timestamp INTEGER,
        title TEXT,
        folder_id INTEGER REFERENCES folders(id)
      )
    ''');
    // print('Notes table created');
  }

  Future<void> _createPagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE pages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        timestamp INTEGER,
        pageindex INTEGER,
        note_id INTEGER REFERENCES notes(id)
      )
    ''');
    // print('Pages table created');
  }

  Future<void> _ensureTableExists() async {
    final db = await database;
    final tables = await db
        .query('sqlite_master', where: 'name = ?', whereArgs: ['notes']);
    if (tables.isEmpty) {
      await _createNotesTable(db);
    }
  }

  Future<List<Note>> getNotes({int? folderId}) async {
    await _ensureTableExists();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: folderId != null ? 'folder_id = ?' : null,
      whereArgs: folderId != null ? [folderId] : null,
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> insertNote(Note note) async {
    await _ensureTableExists();
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<void> updateNote(Note note) async {
    await _ensureTableExists();
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> updateFolder(int id, String newName) async {
    final db = await database;
    await db.update(
      'folders',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
    // print('Updated folder with id: $id, new name: $newName');
  }

  Future<int> insertFolder(String name) async {
    final db = await database;
    final id = await db.insert(
      'folders',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // print('Inserted folder with id: $id, name: $name');
    return id;
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await database;
    final folders = await db.query('folders', orderBy: 'name');
    // print('Retrieved ${folders.length} folders from database');
    return folders;
  }

  Future<void> deleteNote(int id) async {
    await _ensureTableExists();
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    // print('Deleted note with id: $id');
  }

  Future<void> deleteFolder(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all notes in the folder
      await txn.delete('notes', where: 'folder_id = ?', whereArgs: [id]);
      // Delete the folder
      await txn.delete('folders', where: 'id = ?', whereArgs: [id]);
    });
    // print('Deleted folder with id: $id and all its notes');
  }

  // CRUD operations for Page model
  Future<void> _ensurePagesTableExists() async {
    final db = await database;
    final tables = await db
        .query('sqlite_master', where: 'name = ?', whereArgs: ['pages']);
    if (tables.isEmpty) {
      await _createPagesTable(db);
    }
  }

  Future<List<Pages>> getPages({int? noteId}) async {
    await _ensurePagesTableExists();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pages',
      where: noteId != null ? 'note_id = ?' : null,
      whereArgs: noteId != null ? [noteId] : null,
      orderBy: 'pageindex ASC',
    );
    return List.generate(maps.length, (i) => Pages.fromMap(maps[i]));
  }

  Future<int> insertPage(Pages page) async {
    await _ensurePagesTableExists();
    final db = await database;
    // print('page inserted');
    return await db.insert('pages', page.toMap());
  }

  Future<void> updatePage(Pages page) async {
    await _ensurePagesTableExists();
    final db = await database;
    await db.update(
      'pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
    // print('page updated');
  }

  Future<void> deletePage(int id) async {
    await _ensurePagesTableExists();
    final db = await database;
    await db.delete('pages', where: 'id = ?', whereArgs: [id]);
    // print('Deleted page with id: $id');
  }

  Future<void> deletePagesByNoteId(int noteId) async {
    await _ensurePagesTableExists();
    final db = await database;
    await db.delete('pages', where: 'note_id = ?', whereArgs: [noteId]);
    // print('Deleted pages for note with id: $noteId');
  }

  Future<void> _createPromptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE prompts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT,
        timestamp INTEGER,
        title TEXT,
        folder_id INTEGER REFERENCES folders(id)
      )
    ''');
    // print('Prompts table created');
  }

  Future<void> _ensurePromptsTableExists() async {
    final db = await database;
    final tables = await db
        .query('sqlite_master', where: 'name = ?', whereArgs: ['prompts']);
    if (tables.isEmpty) {
      await _createPromptsTable(db);
    }
  }

  Future<List<Prompt>> getPrompts({int? folderId}) async {
    await _ensurePromptsTableExists();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'prompts',
      where: folderId != null ? 'folder_id = ?' : null,
      whereArgs: folderId != null ? [folderId] : null,
    );
    return List.generate(maps.length, (i) => Prompt.fromMap(maps[i]));
  }

  Future<int> insertPrompt(Prompt prompt) async {
    await _ensurePromptsTableExists();
    final db = await database;
    return await db.insert('prompts', prompt.toMap());
  }

  Future<void> updatePrompt(Prompt prompt) async {
    await _ensurePromptsTableExists();
    final db = await database;
    await db.update(
      'prompts',
      prompt.toMap(),
      where: 'id = ?',
      whereArgs: [prompt.id],
    );
  }

  Future<void> updatePromptName(int id, String newName) async {
    final db = await database;
    await db.update(
      'prompts',
      {'title': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
    // print('Updated prompt with id: $id, new name: $newName');
  }

  Future<void> deletePrompt(int id) async {
    await _ensurePromptsTableExists();
    final db = await database;
    await db.delete('prompts', where: 'id = ?', whereArgs: [id]);
    // print('Deleted prompt with id: $id');
  }

  Future<int> insertPromptFolder(String name) async {
    final db = await database;
    final id = await db.insert(
      'prompt_folders',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // print('Inserted prompt folder with id: $id, name: $name');
    return id;
  }

  Future<void> updatePromptFolder(int id, String newName) async {
    final db = await database;
    await db.update(
      'prompt_folders',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
    // print('Updated prompt folder with id: $id, new name: $newName');
  }

Future<void> deletePromptFolder(int id) async {
  final db = await database;
  await db.transaction((txn) async {
    // Delete prompts in the folder
    await txn.delete('prompts', where: 'folder_id = ?', whereArgs: [id]);
    // Delete the folder
    await txn.delete('prompt_folders', where: 'id = ?', whereArgs: [id]);
  });
  // print('Deleted prompt folder with id: $id and its prompts');
}

  Future<List<Map<String, dynamic>>> getPromptFolders() async {
    final db = await database;
    final folders = await db.query('prompt_folders', orderBy: 'name');
    // print('Retrieved ${folders.length} prompt folders from database');
    return folders;
  }

  Future<void> _createPromptFoldersTable(Database db) async {
    await db.execute('''
      CREATE TABLE prompt_folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
    // print('Prompt folders table created');
  }

  Future<void> _ensurePromptFoldersTableExists() async {
    final db = await database;
    final tables = await db.query('sqlite_master',
        where: 'name = ?', whereArgs: ['prompt_folders']);
    if (tables.isEmpty) {
      await _createPromptFoldersTable(db);
    }
  }

 Future<void> _createFavoritePromptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE favorite_prompts(
        id INTEGER PRIMARY KEY,
        prompt_id INTEGER REFERENCES prompts(id)
      )
    ''');
    // Insert two rows for favorite prompts
    await db.insert('favorite_prompts', {'id': 1, 'prompt_id': null});
    await db.insert('favorite_prompts', {'id': 2, 'prompt_id': null});
    await db.insert('favorite_prompts', {'id': 3, 'prompt_id': null});
    // print('Favorite prompts table created');
  }

  Future<void> setFavoritePrompt(int favoriteId, int? promptId) async {
    final db = await database;
    await db.update(
      'favorite_prompts',
      {'prompt_id': promptId},
      where: 'id = ?',
      whereArgs: [favoriteId],
    );
    // print('Set favorite prompt $favoriteId to prompt $promptId');
  }

  Future<int?> getFavoritePromptId(int favoriteId) async {
    final db = await database;
    final result = await db.query(
      'favorite_prompts',
      columns: ['prompt_id'],
      where: 'id = ?',
      whereArgs: [favoriteId],
    );
    return result.isNotEmpty ? result.first['prompt_id'] as int? : null;
  }

Future<String?> getPromptTitle(int? promptId) async {
  await _ensureTableExists();
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'prompts',
    columns: ['title'],
    where: 'id = ?',
    whereArgs: [promptId],
  );

  if (maps.isNotEmpty) {
    return maps.first['title'] as String?;
  } else {
    return null;
  }
}

Future<String?> getFavoritePromptTitle(int favoriteId) async {
  final promptId = await getFavoritePromptId(favoriteId);
  if (promptId != null) {
    return await getPromptTitle(promptId);
  } else {
    return null;
  }
}

  Future<void> movePromptToFolder(int promptId, int folderId) async {
    final db = await database;
    await db.update(
      'prompts',
      {'folder_id': folderId},
      where: 'id = ?',
      whereArgs: [promptId],
    );
    // print('Moved prompt $promptId to folder $folderId');
  }

  // Add this method to the DatabaseService class
Future<void> moveNoteToFolder(int noteId, int folderId) async {
  final db = await database;
  await db.update(
    'notes',
    {'folder_id': folderId},
    where: 'id = ?',
    whereArgs: [noteId],
  );
  // print('Moved note $noteId to folder $folderId');
}

Future<String> exportPromptsToJson() async {
  final db = await database;
  final prompts = await db.query('prompts');
  final promptFolders = await db.query('prompt_folders');
  final exportData = {
    'prompt_folders': promptFolders,
    'prompts': prompts,
  };
  return jsonEncode(exportData);
}

Future<void> importPromptsFromJson(String jsonString) async {
  final db = await database;
  final Map<String, dynamic> importData = jsonDecode(jsonString);
  final List<dynamic> promptFolders = importData['prompt_folders'];
  final List<dynamic> prompts = importData['prompts'];
  

  // Insert prompt folders first
  for (var folder in promptFolders) {
    await db.insert('prompt_folders', folder, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Insert prompts
  for (var prompt in prompts) {
    await db.insert('prompts', prompt, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

}
