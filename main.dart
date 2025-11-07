import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AIStudyHelperApp());
}

class AIStudyHelperApp extends StatefulWidget {
  const AIStudyHelperApp({Key? key}) : super(key: key);

  @override
  State<AIStudyHelperApp> createState() => _AIStudyHelperAppState();
}

class _AIStudyHelperAppState extends State<AIStudyHelperApp> {
  String? _language;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Study Helper',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(primarySwatch: Colors.blue),
      darkTheme: ThemeData.dark(),
      home: _language == null ? const LanguageSelectionScreen() : const HomeScreen(),
    );
  }
}

// ---------------- Language Selection ----------------
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  Future<void> _setLanguage(BuildContext context, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Language')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: () => _setLanguage(context, 'en'), child: const Text('English')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _setLanguage(context, 'hi'), child: const Text('हिन्दी')),
        ]),
      ),
    );
  }
}

// ---------------- Home ----------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Study Helper')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _menuButton(context, 'Ask AI', const AskAIScreen()),
          _menuButton(context, 'Notes', const NotesScreen()),
          _menuButton(context, 'Quiz', const QuizMainScreen()),
          _menuButton(context, 'Settings', const SettingsScreen()),
        ]),
      ),
    );
  }

  Widget _menuButton(BuildContext context, String title, Widget page) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(220, 50)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Text(title, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// ---------------- Ask AI ----------------
class AskAIScreen extends StatefulWidget {
  const AskAIScreen({Key? key}) : super(key: key);

  @override
  State<AskAIScreen> createState() => _AskAIScreenState();
}

class _AskAIScreenState extends State<AskAIScreen> {
  final TextEditingController _qController = TextEditingController();
  String _answer = '';
  bool _loading = false;

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openai_api_key');
  }

  Future<void> _ask() async {
    final question = _qController.text.trim();
    if (question.isEmpty) return;
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showMsg('Set OpenAI API key in Settings');
      return;
    }

    setState(() { _loading = true; _answer = ''; });

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final payload = {
      "model": "gpt-3.5-turbo",
      "messages": [
        {"role": "user", "content": question}
      ],
      "max_tokens": 500,
      "temperature": 0.2
    };

    try {
      final res = await http.post(url, headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }, body: jsonEncode(payload));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        setState(() { _answer = content.toString().trim(); });
      } else {
        setState(() { _answer = 'Error ${res.statusCode}: ${res.body}'; });
      }
    } catch (e) {
      setState(() { _answer = 'Request failed: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _saveNote() async {
    if (_answer.isEmpty) {
      _showMsg('No answer to save');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final notesRaw = prefs.getStringList('notes') ?? <String>[];
    final noteObj = {'q': _qController.text.trim(), 'a': _answer, 't': DateTime.now().toIso8601String()};
    notesRaw.add(jsonEncode(noteObj));
    await prefs.setStringList('notes', notesRaw);
    _showMsg('Saved note');
  }

  void _showMsg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask AI')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _qController, decoration: const InputDecoration(labelText: 'Type question', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(onPressed: _loading ? null : _ask, child: _loading ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Ask')),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _saveNote, child: const Text('Save Note')),
          ]),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Text(_answer)))
        ]),
      ),
    );
  }
}

// ---------------- Notes ----------------
class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notes') ?? [];
    setState(() {
      _notes = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      _notes = _notes.reversed.toList();
    });
  }

  Future<void> _deleteNote(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notes') ?? [];
    raw.removeAt(raw.length - 1 - index); // because reversed view
    await prefs.setStringList('notes', raw);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: _notes.isEmpty ? const Center(child: Text('No saved notes')) : ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (c,i){
          final note = _notes[i];
          return ListTile(
            title: Text(note['q'] ?? ''),
            subtitle: Text((note['t'] ?? '').toString().split('T').first),
            onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note))),
            trailing: IconButton(icon: const Icon(Icons.delete), onPressed: ()=> _deleteNote(i)),
          );
        },
      ),
    );
  }
}

class NoteDetailScreen extends StatelessWidget {
  final Map<String,dynamic> note;
  const NoteDetailScreen({Key? key, required this.note}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Q: ${note['q'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height:10),
          Expanded(child: SingleChildScrollView(child: Text('A:\n${note['a'] ?? ''}'))),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizFromNoteScreen(note: note))), child: const Text('Generate Quiz')),
        ]),
      ),
    );
  }
}

// ---------------- Quiz ----------------
// QuizMainScreen lets user choose a saved note for quiz generation
class QuizMainScreen extends StatefulWidget {
  const QuizMainScreen({Key? key}) : super(key: key);

  @override
  State<QuizMainScreen> createState() => _QuizMainScreenState();
}

class _QuizMainScreenState extends State<QuizMainScreen> {
  List<Map<String,dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notes') ?? [];
    setState(() {
      _notes = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      _notes = _notes.reversed.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: _notes.isEmpty ? const Center(child: Text('No notes to generate quiz')) : ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (c,i){
          final note = _notes[i];
          return ListTile(
            title: Text(note['q'] ?? ''),
            subtitle: Text((note['t'] ?? '').toString().split('T').first),
            onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => QuizFromNoteScreen(note: note))),
          );
        },
      ),
    );
  }
}

class QuizFromNoteScreen extends StatefulWidget {
  final Map<String,dynamic> note;
  const QuizFromNoteScreen({Key? key, required this.note}) : super(key: key);

  @override
  State<QuizFromNoteScreen> createState() => _QuizFromNoteScreenState();
}

class _QuizFromNoteScreenState extends State<QuizFromNoteScreen> {
  bool _loading = false;
  List<dynamic> _questions = [];
  int _current = 0;

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('openai_api_key');
  }

  Future<void> _generateQuiz() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set API key in Settings')));
      return;
    }
    setState(() { _loading = true; _questions = []; _current = 0; });

    final prompt = """
Create 5 multiple choice questions (MCQ) based on the following study note. 
Return your answer as JSON array of objects: [{"q":"question","options":["a","b","c","d"],"correct":1}, ...]
Study note:
${widget.note['a']}
""";
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final payload = {
      "model": "gpt-3.5-turbo",
      "messages": [{"role":"user", "content": prompt}],
      "max_tokens": 700,
      "temperature": 0.2
    };

    try {
      final res = await http.post(url, headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }, body: jsonEncode(payload));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        // Try to extract JSON array from content
        final start = content.indexOf('[');
        final end = content.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          final jsonText = content.substring(start, end + 1);
          final parsed = jsonDecode(jsonText);
          setState(() { _questions = parsed; });
        } else {
          // fallback: show raw content as a single 'question'
          setState(() { _questions = [{'q': 'Unable to parse MCQs. Raw output:', 'options': [content], 'correct': 0}]; });
        }
      } else {
        setState(() { _questions = [{'q': 'Error ${res.statusCode}: ${res.body}', 'options': ['OK'], 'correct': 0}]; });
      }
    } catch (e) {
      setState(() { _questions = [{'q': 'Request failed: $e', 'options': ['OK'], 'correct': 0}]; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _answer(int index) {
    final q = _questions[_current];
    final correct = q['correct'] ?? 0;
    final correctText = (q['options'] as List)[correct];
    final chosenText = (q['options'] as List)[index];
    final isCorrect = index == correct;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCorrect ? 'Correct' : 'Wrong. Correct: $correctText')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading ? const Center(child: CircularProgressIndicator()) : _questions.isEmpty ? Column(
          children: [
            Text('Note: ${widget.note['q']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height:12),
            ElevatedButton(onPressed: _generateQuiz, child: const Text('Generate Quiz (5 MCQs)')),
            const SizedBox(height:12),
            Expanded(child: SingleChildScrollView(child: Text(widget.note['a'] ?? '')))
          ],
        ) : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q${_current+1}: ${_questions[_current]['q']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height:8),
            ...List.generate((_questions[_current]['options'] as List).length, (i) {
              return Padding(padding: const EdgeInsets.symmetric(vertical:6.0), child: ElevatedButton(
                onPressed: () => _answer(i),
                child: Text((_questions[_current]['options'] as List)[i].toString()),
              ));
            }),
            const SizedBox(height:12),
            Row(children: [
              ElevatedButton(onPressed: _current>0 ? () => setState(() => _current--) : null, child: const Text('Prev')),
              const SizedBox(width:12),
              ElevatedButton(onPressed: _current < _questions.length -1 ? () => setState(() => _current++) : null, child: const Text('Next')),
            ])
          ],
        ),
      ),
    );
  }
}

// ---------------- Settings ----------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiController = TextEditingController();
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiController.text = prefs.getString('openai_api_key') ?? '';
    setState(() { _lang = prefs.getString('language') ?? 'en'; });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', _apiController.text.trim());
    await prefs.setString('language', _lang);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        TextField(controller: _apiController, decoration: const InputDecoration(labelText: 'OpenAI API Key', hintText: 'sk-...')),
        const SizedBox(height:12),
        Row(children: [
          const Text('Language: '),
          const SizedBox(width:8),
          DropdownButton<String>(value: _lang, items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
          ], onChanged: (v) => setState(() => _lang = v ?? 'en')),
        ]),
        const SizedBox(height:12),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height:12),
        const Text('Notes and quizzes are stored locally in this prototype.')
      ])),
    );
  }
}
