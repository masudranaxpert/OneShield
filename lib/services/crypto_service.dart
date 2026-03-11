import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Handles all encryption/decryption using AES-256.
/// Master password is used to derive the encryption key.
class CryptoService {
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits
  static const int _saltLength = 32;
  static const int _iterations = 100000;

  /// Generate a random salt
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Generate a random IV
  static String generateIV() {
    final random = Random.secure();
    final bytes = List<int>.generate(_ivLength, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Derive key from master password using PBKDF2-like approach
  /// Uses iterated HMAC-SHA256 for key derivation
  static Uint8List deriveKey(String password, String salt) {
    final saltBytes = base64Decode(salt);
    // PBKDF2-like key derivation using HMAC-SHA256
    Uint8List result = Uint8List.fromList(
      utf8.encode(password) + saltBytes,
    );

    for (int i = 0; i < _iterations; i++) {
      final hmac = Hmac(sha256, result);
      final digest = hmac.convert(saltBytes + [i & 0xff, (i >> 8) & 0xff]);
      result = Uint8List.fromList(digest.bytes);
    }

    return Uint8List.fromList(result.sublist(0, _keyLength));
  }

  /// Hash password with salt using SHA-256
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash security answer (case-insensitive, trimmed)
  static String hashAnswer(String answer) {
    final normalized = answer.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Encrypt data using AES-256-CBC
  static String encryptData(String plainText, Uint8List key, String ivBase64) {
    if (plainText.isEmpty) return '';
    final keyObj = encrypt.Key(key);
    final iv = encrypt.IV.fromBase64(ivBase64);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(keyObj, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  /// Decrypt data using AES-256-CBC
  static String decryptData(
      String encryptedBase64, Uint8List key, String ivBase64) {
    if (encryptedBase64.isEmpty) return '';
    try {
      final keyObj = encrypt.Key(key);
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(keyObj, mode: encrypt.AESMode.cbc),
      );
      final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
      return decrypted;
    } catch (e) {
      return '[Decryption Failed]';
    }
  }

  /// Derive key from security answers for master password recovery
  static Uint8List deriveKeyFromAnswers(
      List<String> answers, String salt) {
    final combined = answers.map((a) => a.trim().toLowerCase()).join('|');
    return deriveKey(combined, salt);
  }

  /// Generate a strong random password
  static String generatePassword({
    int length = 20,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    String chars = '';
    if (includeLowercase) chars += 'abcdefghijklmnopqrstuvwxyz';
    if (includeUppercase) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (includeNumbers) chars += '0123456789';
    if (includeSpecial) chars += '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    if (chars.isEmpty) chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }
}
