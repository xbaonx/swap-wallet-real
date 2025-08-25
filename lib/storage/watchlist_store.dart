import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WatchlistStore {
  static const String _keyWatchlist = 'watchlist';
  
  final Set<String> _bases = <String>{};

  Set<String> get bases => Set.unmodifiable(_bases);

  void loadFromPrefs(SharedPreferences prefs) {
    final watchlistJson = prefs.getString(_keyWatchlist);
    if (watchlistJson != null) {
      try {
        final List<dynamic> basesList = jsonDecode(watchlistJson);
        _bases.clear();
        _bases.addAll(basesList.cast<String>().map((base) => base.toUpperCase()));
      } catch (e) {
        print('Error loading watchlist: $e');
        _bases.clear();
      }
    }
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    try {
      final watchlistJson = jsonEncode(_bases.toList());
      await prefs.setString(_keyWatchlist, watchlistJson);
    } catch (e) {
      print('Error saving watchlist: $e');
    }
  }

  bool isPinned(String base) {
    return _bases.contains(base.toUpperCase());
  }

  void toggle(String base) {
    final upperBase = base.toUpperCase();
    if (_bases.contains(upperBase)) {
      _bases.remove(upperBase);
    } else {
      _bases.add(upperBase);
    }
  }

  void add(String base) {
    _bases.add(base.toUpperCase());
  }

  void remove(String base) {
    _bases.remove(base.toUpperCase());
  }

  void addAll(Iterable<String> bases) {
    _bases.addAll(bases.map((base) => base.toUpperCase()));
  }

  void clear() {
    _bases.clear();
  }

  String exportJson() {
    try {
      final Map<String, dynamic> export = {
        'watchlist': _bases.toList(),
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'count': _bases.length,
      };
      return jsonEncode(export);
    } catch (e) {
      print('Error exporting watchlist: $e');
      return '{"watchlist":[],"exportedAt":0,"count":0}';
    }
  }

  void importJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> basesList = data['watchlist'] as List<dynamic>? ?? [];
      
      _bases.clear();
      _bases.addAll(basesList.cast<String>().map((base) => base.toUpperCase()));
    } catch (e) {
      print('Error importing watchlist: $e');
      // Don't clear existing watchlist on import error
    }
  }

  List<String> getSortedBases() {
    final sortedList = _bases.toList();
    sortedList.sort();
    return sortedList;
  }

  int get count => _bases.length;

  bool get isEmpty => _bases.isEmpty;
  bool get isNotEmpty => _bases.isNotEmpty;
}
