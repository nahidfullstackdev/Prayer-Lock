import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/dua_dhikr/data/models/dua_category_model.dart';
import 'package:prayer_lock/features/dua_dhikr/data/models/dua_model.dart';

/// Reads Dua data from the bundled JSON asset (assets/data/duas.json).
///
/// The JSON is loaded once and cached in memory for the app session.
/// All 11 categories (6 free + 5 pro) are stored locally — no network required.
class DuaLocalDataSource {
  static const String _assetPath = 'assets/data/duas.json';

  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _loadJson() async {
    if (_cache != null) return _cache!;
    AppLogger.info('Loading duas.json from asset bundle');
    final raw = await rootBundle.loadString(_assetPath);
    _cache = json.decode(raw) as Map<String, dynamic>;
    AppLogger.info('duas.json loaded and cached');
    return _cache!;
  }

  Future<List<DuaCategoryModel>> getCategories() async {
    final data = await _loadJson();
    final list = (data['categories'] as List<dynamic>?) ?? [];
    return list.asMap().entries.map((e) {
      return DuaCategoryModel.fromJson(e.value as Map<String, dynamic>, e.key);
    }).toList();
  }

  Future<List<DuaModel>> getDuasByCategory(String categoryId) async {
    final data = await _loadJson();
    final list = (data['categories'] as List<dynamic>?) ?? [];

    for (final item in list) {
      final cat = item as Map<String, dynamic>;
      if (cat['id'] == categoryId) {
        final duas = (cat['duas'] as List<dynamic>?) ?? [];
        return duas.asMap().entries.map((e) {
          return DuaModel.fromJson(
            e.value as Map<String, dynamic>,
            categoryId,
            orderIndex: e.key,
          );
        }).toList();
      }
    }

    AppLogger.warning('No duas found for category: $categoryId');
    return [];
  }

  Future<List<DuaModel>> searchDuas(String query) async {
    final data = await _loadJson();
    final categories = (data['categories'] as List<dynamic>?) ?? [];
    final lower = query.toLowerCase();
    final results = <DuaModel>[];

    for (final item in categories) {
      final cat = item as Map<String, dynamic>;
      final categoryId = cat['id'] as String;
      final duas = (cat['duas'] as List<dynamic>?) ?? [];

      for (var i = 0; i < duas.length; i++) {
        final d = duas[i] as Map<String, dynamic>;
        final translation = ((d['translation'] as String?) ?? '').toLowerCase();
        final translit =
            ((d['transliteration'] as String?) ?? '').toLowerCase();
        if (translation.contains(lower) || translit.contains(lower)) {
          results.add(DuaModel.fromJson(d, categoryId, orderIndex: i));
        }
      }
    }

    AppLogger.info('Dua search "$query" → ${results.length} results');
    return results;
  }
}
