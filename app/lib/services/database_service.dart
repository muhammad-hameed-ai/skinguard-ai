// ═══════════════════════════════════════════════════════════════
//  DatabaseService — SQLite via sqflite (§4, Task 6)
//
//  Tables: users, scans
//  Images copied into app documents via path_provider.
//  Gallery paths are temporary and will break history.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan_result.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'skinguard.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            full_name TEXT,
            age INTEGER,
            contact TEXT,
            address TEXT,
            fitzpatrick INTEGER,
            notes TEXT,
            security_question TEXT,
            security_answer_hash TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            scan_id TEXT UNIQUE NOT NULL,
            image_path TEXT NOT NULL,
            body_site TEXT,
            melanoma_prob REAL NOT NULL,
            cancer_prob REAL NOT NULL,
            melanoma_flagged INTEGER NOT NULL,
            cancer_flagged INTEGER NOT NULL,
            risk_level TEXT NOT NULL,
            gate_valid REAL,
            cam_data TEXT,
            low_confidence INTEGER DEFAULT 0,
            inference_ms INTEGER,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id)
          )
        ''');
      },
    );
  }

  // ── Scan operations ───────────────────────────────────────

  /// Generates a unique scan ID like "SG-2418".
  String _generateScanId() {
    final num = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'SG-$num';
  }

  /// Copies the image to app documents and saves the scan record.
  Future<int> saveScan({
    int? userId,
    required File imageFile,
    required ScanResult result,
    String? bodySite,
    bool lowConfidence = false,
  }) async {
    final db = await database;

    // Copy image to persistent app storage
    final appDir = await getApplicationDocumentsDirectory();
    final scanDir = Directory(p.join(appDir.path, 'scans'));
    if (!await scanDir.exists()) await scanDir.create(recursive: true);

    final ext = p.extension(imageFile.path);
    final scanId = _generateScanId();
    final newPath = p.join(scanDir.path, '$scanId$ext');
    await imageFile.copy(newPath);

    return db.insert('scans', {
      'user_id': userId,
      'scan_id': scanId,
      'image_path': newPath,
      'body_site': bodySite,
      'melanoma_prob': result.melanomaProb,
      'cancer_prob': result.cancerProb,
      'melanoma_flagged': result.melanomaFlagged ? 1 : 0,
      'cancer_flagged': result.cancerFlagged ? 1 : 0,
      'risk_level': result.risk.name,
      'gate_valid': result.gateValidProb,
      'cam_data': result.camMap != null ? jsonEncode(result.camMap) : null,
      'low_confidence': lowConfidence ? 1 : 0,
      'inference_ms': result.inferenceMs,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns all scans for a user, newest first.
  Future<List<Map<String, dynamic>>> getScans({int? userId}) async {
    final db = await database;
    if (userId != null) {
      return db.query('scans',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC');
    }
    return db.query('scans',
        where: 'user_id IS NULL',
        orderBy: 'created_at DESC');
  }

  /// Returns scans filtered by risk level.
  Future<List<Map<String, dynamic>>> getScansByRisk({
    int? userId,
    required String riskLevel,
  }) async {
    final db = await database;
    final where = userId != null
        ? 'user_id = ? AND risk_level = ?'
        : 'user_id IS NULL AND risk_level = ?';
    final args = userId != null ? [userId, riskLevel] : [riskLevel];
    return db.query('scans',
        where: where, whereArgs: args, orderBy: 'created_at DESC');
  }

  /// Deletes a scan and its image file.
  Future<void> deleteScan(int scanId) async {
    final db = await database;
    final rows = await db.query('scans', where: 'id = ?', whereArgs: [scanId]);
    if (rows.isNotEmpty) {
      final imagePath = rows.first['image_path'] as String?;
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) await file.delete();
      }
    }
    await db.delete('scans', where: 'id = ?', whereArgs: [scanId]);
  }

  // ── User operations ───────────────────────────────────────

  Future<int> createUser(Map<String, dynamic> userData) async {
    final db = await database;
    return db.insert('users', userData);
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query('users',
        where: 'username = ?', whereArgs: [username]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('users', data, where: 'id = ?', whereArgs: [id]);
  }
}
