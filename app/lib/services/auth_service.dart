// ═══════════════════════════════════════════════════════════════
//  AuthService — offline-only authentication (§3.3)
//
//  SHA-256 + per-user random salt via `crypto`.
//  Never stores plaintext passwords.
//  "Continue as guest" gives full functionality with local storage.
//  Password recovery via security question — no server.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  int? _currentUserId;
  String? _currentUsername;
  String? _currentFullName;
  bool _isGuest = false;

  int? get currentUserId => _currentUserId;
  String? get currentUsername => _currentUsername;
  String? get currentFullName => _currentFullName;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _currentUserId != null || _isGuest;

  /// Generates a cryptographically random salt.
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Hashes password with salt using SHA-256.
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Creates a new user account.
  /// Returns null on success, or an error message.
  Future<String?> createAccount({
    required String username,
    required String password,
    required String fullName,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    if (username.trim().isEmpty) return 'Username is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (fullName.trim().isEmpty) return 'Full name is required';

    final db = DatabaseService.instance;
    final existing = await db.getUserByUsername(username.trim());
    if (existing != null) return 'Username already exists';

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    String? answerHash;
    if (securityAnswer != null && securityAnswer.isNotEmpty) {
      answerHash = _hashPassword(securityAnswer.toLowerCase().trim(), salt);
    }

    final userId = await db.createUser({
      'username': username.trim(),
      'password_hash': hash,
      'salt': salt,
      'full_name': fullName.trim(),
      'security_question': securityQuestion,
      'security_answer_hash': answerHash,
      'created_at': DateTime.now().toIso8601String(),
    });

    _currentUserId = userId;
    _currentUsername = username.trim();
    _currentFullName = fullName.trim();
    _isGuest = false;

    await _saveSession();
    return null;
  }

  /// Logs in with username and password.
  /// Returns null on success, or an error message.
  Future<String?> login(String username, String password) async {
    final db = DatabaseService.instance;
    final user = await db.getUserByUsername(username.trim());
    if (user == null) return 'User not found';

    final salt = user['salt'] as String;
    final storedHash = user['password_hash'] as String;
    final hash = _hashPassword(password, salt);

    if (hash != storedHash) return 'Incorrect password';

    _currentUserId = user['id'] as int;
    _currentUsername = user['username'] as String;
    _currentFullName = user['full_name'] as String?;
    _isGuest = false;

    await _saveSession();
    return null;
  }

  /// Continues as guest — full functionality, local-only.
  Future<void> continueAsGuest() async {
    _currentUserId = null;
    _currentUsername = 'Guest';
    _currentFullName = 'Guest User';
    _isGuest = true;
    await _saveSession();
  }

  /// Recovers password using security question.
  Future<String?> verifySecurityAnswer(String username, String answer) async {
    final db = DatabaseService.instance;
    final user = await db.getUserByUsername(username.trim());
    if (user == null) return 'User not found';

    final salt = user['salt'] as String;
    final storedHash = user['security_answer_hash'] as String?;
    if (storedHash == null) return 'No security question set for this account';

    final hash = _hashPassword(answer.toLowerCase().trim(), salt);
    if (hash != storedHash) return 'Incorrect answer';

    return null; // Success — caller can now allow password reset
  }

  /// Resets password after security question verification.
  Future<String?> resetPassword(String username, String newPassword) async {
    if (newPassword.length < 6) return 'Password must be at least 6 characters';

    final db = DatabaseService.instance;
    final user = await db.getUserByUsername(username.trim());
    if (user == null) return 'User not found';

    final salt = _generateSalt();
    final hash = _hashPassword(newPassword, salt);

    await db.updateUser(user['id'] as int, {
      'password_hash': hash,
      'salt': salt,
    });

    return null;
  }

  /// Logs out and clears session.
  Future<void> logout() async {
    _currentUserId = null;
    _currentUsername = null;
    _currentFullName = null;
    _isGuest = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('is_guest');
  }

  /// Restores session from SharedPreferences.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool('is_guest') ?? false;

    if (isGuest) {
      _isGuest = true;
      _currentUsername = 'Guest';
      _currentFullName = 'Guest User';
      return true;
    }

    final userId = prefs.getInt('user_id');
    if (userId == null) return false;

    final db = DatabaseService.instance;
    final user = await db.getUserById(userId);
    if (user == null) return false;

    _currentUserId = userId;
    _currentUsername = user['username'] as String;
    _currentFullName = user['full_name'] as String?;
    _isGuest = false;
    return true;
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isGuest) {
      await prefs.setBool('is_guest', true);
      await prefs.remove('user_id');
    } else if (_currentUserId != null) {
      await prefs.setInt('user_id', _currentUserId!);
      await prefs.setString('username', _currentUsername ?? '');
      await prefs.setBool('is_guest', false);
    }
  }
}
