import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import 'vault_service.dart';
import '../models/vault_entry.dart';

/// Handles Google Drive backup/restore using OAuth2 directly.
/// Uses the provided rclone client credentials for Google Drive API access.
class DriveBackupService {
  static const String _authUrl = 'https://accounts.google.com/o/oauth2/auth';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _driveApiUrl =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files';
  static const String _scope = 'https://www.googleapis.com/auth/drive';
  static const String _redirectUri = AppConstants.oauthRedirectUri;

  final VaultService vaultService;
  HttpServer? _callbackServer;

  DriveBackupService({required this.vaultService});

  /// Generate OAuth2 authorization URL
  String getAuthUrl() {
    final config = vaultService.backupConfig;
    return '$_authUrl?client_id=${config.clientId}'
        '&redirect_uri=$_redirectUri'
        '&response_type=code'
        '&scope=${Uri.encodeComponent(_scope)}'
        '&access_type=offline'
        '&prompt=consent';
  }

  /// Start local callback server to receive OAuth2 code
  /// On Android, this binds to 127.0.0.1 so the browser redirect
  /// from Google OAuth will reach this server on the same device.
  Future<String?> startCallbackServer() async {
    try {
      // Close any existing server first
      await _callbackServer?.close(force: true);

      _callbackServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        AppConstants.oauthPort,
      );
      final completer = Completer<String?>();

      _callbackServer!.listen((request) {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        if (error != null) {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <head><title>${AppConstants.appName} - Authorization Failed</title></head>
              <body style="font-family: sans-serif; text-align: center; padding: 50px; background: #1a1a2e; color: #e0e0e0;">
                <h1 style="color: #ff5252;">Authorization Failed</h1>
                <p>Error: $error</p>
                <p>Please close this window and try again in ${AppConstants.appName}.</p>
              </body>
              </html>
            ''');
          request.response.close();
          _closeServer();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html>
            <head>
              <title>${AppConstants.appName} - Authorization Complete</title>
              <meta name="viewport" content="width=device-width, initial-scale=1">
            </head>
            <body style="font-family: -apple-system, sans-serif; text-align: center; padding: 50px 20px; background: #0A0E21; color: #e0e0e0; margin: 0;">
              <div style="max-width: 400px; margin: 0 auto;">
                <div style="width: 80px; height: 80px; margin: 0 auto 24px; background: linear-gradient(135deg, #00D2FF, #7B2FFF); border-radius: 50%; display: flex; align-items: center; justify-content: center;">
                  <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                </div>
                <h1 style="color: #00D2FF; font-size: 24px; margin: 0 0 8px; font-weight: 700;">Authorization Successful!</h1>
                <p style="color: #8E92B0; font-size: 14px; margin: 0 0 24px;">Returning to ${AppConstants.appName}...</p>
                <div style="width: 40px; height: 4px; background: linear-gradient(90deg, #00D2FF, #7B2FFF); border-radius: 2px; margin: 0 auto; animation: pulse 1.5s infinite;">
                </div>
              </div>
              <style>@keyframes pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 1; } }</style>
              <script>
                // Auto-close this tab after a short delay
                setTimeout(function() {
                  window.close();
                  // If window.close() doesn't work (some browsers block it),
                  // show a message to close manually
                  document.querySelector('p').textContent = 'You can close this tab now.';
                }, 2000);
              </script>
            </body>
            </html>
          ''');
        request.response.close();
        _closeServer();
        if (!completer.isCompleted) {
          completer.complete(code);
        }
      });

      // Timeout after 3 minutes
      Future.delayed(const Duration(minutes: AppConstants.oauthTimeoutMinutes), () {
        if (!completer.isCompleted) {
          _closeServer();
          completer.complete(null);
        }
      });

      return completer.future;
    } catch (e) {
      return null;
    }
  }

  void _closeServer() {
    _callbackServer?.close(force: true);
    _callbackServer = null;
  }

  /// Exchange authorization code for tokens
  Future<bool> exchangeCode(String code) async {
    try {
      final config = vaultService.backupConfig;
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'code': code,
          'client_id': config.clientId,
          'client_secret': config.clientSecret,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        config.accessToken = data['access_token'];
        config.refreshToken = data['refresh_token'];
        config.tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in'] ?? 3600),
        );
        await vaultService.saveBackupConfig(config);

        // Fetch user info after successful login
        await fetchUserInfo();

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Login with code from redirect URL
  Future<bool> loginWithCode(String code) async {
    return await exchangeCode(code);
  }

  /// Refresh access token
  Future<bool> refreshAccessToken() async {
    try {
      final config = vaultService.backupConfig;
      if (config.refreshToken == null) return false;

      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'refresh_token': config.refreshToken,
          'client_id': config.clientId,
          'client_secret': config.clientSecret,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        config.accessToken = data['access_token'];
        config.tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in'] ?? 3600),
        );
        if (data['refresh_token'] != null) {
          config.refreshToken = data['refresh_token'];
        }
        await vaultService.saveBackupConfig(config);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Ensure valid access token
  Future<bool> ensureValidToken() async {
    final config = vaultService.backupConfig;
    if (config.accessToken == null) return false;
    if (config.isTokenExpired) {
      return await refreshAccessToken();
    }
    return true;
  }

  /// Fetch user info (email, name) and storage quota from Google Drive API
  Future<void> fetchUserInfo() async {
    try {
      if (!await ensureValidToken()) return;

      final config = vaultService.backupConfig;

      // Use Drive about API - returns user info + storage quota in one call
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/about?fields=user(displayName,emailAddress,photoLink),storageQuota(limit,usage)',
        ),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // User info
        final user = data['user'];
        if (user != null) {
          config.userEmail = user['emailAddress'];
          config.userName = user['displayName'];
        }

        // Storage quota
        final quota = data['storageQuota'];
        if (quota != null) {
          config.storageUsed = int.tryParse(quota['usage'] ?? '0');
          config.storageLimit = int.tryParse(quota['limit'] ?? '0');
        }

        await vaultService.saveBackupConfig(config);
      }
    } catch (e) {
      // Silently fail - user info is not critical
    }
  }

  /// Get backup folder ID (must be set by user in settings)
  String? _getBackupFolderId() {
    return vaultService.backupConfig.cachedBackupFolderId;
  }

  /// Get merge folder ID (must be set by user in settings)
  String? _getMergeFolderId() {
    return vaultService.backupConfig.cachedMergeFolderId;
  }

  /// Extract Google Drive folder ID from a URL or raw ID
  static String? extractFolderIdFromUrl(String input) {
    input = input.trim();
    if (input.isEmpty) return null;
    
    // If it's a Google Drive URL, extract the ID
    // Formats:
    //   https://drive.google.com/drive/folders/FOLDER_ID
    //   https://drive.google.com/drive/folders/FOLDER_ID?usp=sharing
    //   https://drive.google.com/drive/u/0/folders/FOLDER_ID
    final regex = RegExp(r'folders/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(input);
    if (match != null) {
      return match.group(1);
    }
    
    // If it looks like a raw folder ID (no slashes, no spaces)
    if (!input.contains('/') && !input.contains(' ') && input.length > 10) {
      return input;
    }
    
    return null;
  }

  /// Verify a folder ID still exists on Google Drive (not trashed)
  Future<bool> _verifyFolderExists(String folderId) async {
    final config = vaultService.backupConfig;
    if (!await ensureValidToken()) return false;
    try {
      final resp = await http.get(
        Uri.parse('$_driveApiUrl/$folderId?fields=id,trashed'),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['trashed'] != true;
      }
    } catch (_) {}
    return false;
  }

  /// Search Drive for a folder by name, create if not found.
  /// Uses orderBy=createdTime to always pick the oldest folder for consistency.
  Future<String?> _findOrCreateFolder(String folderName, String? parentId) async {
    final config = vaultService.backupConfig;
    if (!await ensureValidToken()) return null;

    // Build search query
    String q = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    if (parentId != null) q += " and '$parentId' in parents";

    final searchResp = await http.get(
      Uri.parse('$_driveApiUrl?q=${Uri.encodeComponent(q)}&fields=files(id,name)&orderBy=createdTime'),
      headers: {'Authorization': 'Bearer ${config.accessToken}'},
    );

    if (searchResp.statusCode == 200) {
      final files = jsonDecode(searchResp.body)['files'] as List;
      if (files.isNotEmpty) {
        // Return the OLDEST folder to be consistent across devices
        return files[0]['id'];
      }
    }

    // Not found -> create
    final metadata = {
      'name': folderName,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentId != null) 'parents': [parentId],
    };

    final createResp = await http.post(
      Uri.parse(_driveApiUrl),
      headers: {
        'Authorization': 'Bearer ${config.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(metadata),
    );

    if (createResp.statusCode == 200) {
      return jsonDecode(createResp.body)['id'];
    }
    return null;
  }

  /// Upload backup to Google Drive using simple upload
  Future<bool> uploadBackupSimple() async {
    try {
      if (!await ensureValidToken()) return false;

      final folderId = _getBackupFolderId();
      if (folderId == null) return false;

      final config = vaultService.backupConfig;
      final exportData = vaultService.exportData();
      final fileName =
          '${AppConstants.backupFilePrefix}_${DateTime.now().toIso8601String().replaceAll(':', '-')}${AppConstants.backupFileExtension}';

      await _cleanOldBackups(folderId);

      // Step 1: Create file metadata
      final metaResponse = await http.post(
        Uri.parse('$_driveApiUrl?fields=id'),
        headers: {
          'Authorization': 'Bearer ${config.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': fileName,
          'parents': [folderId],
        }),
      );

      if (metaResponse.statusCode != 200) return false;
      final fileId = jsonDecode(metaResponse.body)['id'];

      // Step 2: Upload content
      final uploadResponse = await http.patch(
        Uri.parse('$_driveUploadUrl/$fileId?uploadType=media'),
        headers: {
          'Authorization': 'Bearer ${config.accessToken}',
          'Content-Type': 'application/octet-stream',
        },
        body: utf8.encode(exportData),
      );

      if (uploadResponse.statusCode == 200) {
        config.lastBackup = DateTime.now();
        await vaultService.saveBackupConfig(config);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clean old backups, keep only last 5
  Future<void> _cleanOldBackups(String folderId) async {
    try {
      final config = vaultService.backupConfig;
      final response = await http.get(
        Uri.parse(
          '$_driveApiUrl?q=%27$folderId%27+in+parents+and+trashed%3Dfalse&orderBy=createdTime+desc&fields=files(id,name,createdTime)',
        ),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List;
        if (files.length > AppConstants.maxOldBackupsToKeep) {
          for (int i = AppConstants.maxOldBackupsToKeep; i < files.length; i++) {
            await http.delete(
              Uri.parse('$_driveApiUrl/${files[i]['id']}'),
              headers: {'Authorization': 'Bearer ${config.accessToken}'},
            );
          }
        }
      }
    } catch (e) {
      // Silently fail cleanup
    }
  }

  /// List available backups
  Future<List<Map<String, dynamic>>> listBackups() async {
    try {
      if (!await ensureValidToken()) return [];

      final folderId = _getBackupFolderId();
      if (folderId == null) return [];

      final config = vaultService.backupConfig;
      final response = await http.get(
        Uri.parse(
          '$_driveApiUrl?q=%27$folderId%27+in+parents+and+trashed%3Dfalse&orderBy=createdTime+desc&fields=files(id,name,createdTime,size)',
        ),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['files']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Download and restore a backup
  Future<String?> downloadBackup(String fileId) async {
    try {
      if (!await ensureValidToken()) return null;

      final config = vaultService.backupConfig;
      final response = await http.get(
        Uri.parse('$_driveApiUrl/$fileId?alt=media'),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save backup locally to custom path or default documents directory
  Future<String?> saveLocalBackup() async {
    try {
      final config = vaultService.backupConfig;
      final String dirPath;
      if (config.localBackupPath != null && config.localBackupPath!.isNotEmpty) {
        dirPath = config.localBackupPath!;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        dirPath = dir.path;
      }

      // Ensure directory exists
      final directory = Directory(dirPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName =
          '${AppConstants.backupFilePrefix}_${DateTime.now().toIso8601String().replaceAll(':', '-')}${AppConstants.backupFileExtension}';
      final file = File('$dirPath/$fileName');
      final data = vaultService.exportData();
      await file.writeAsString(data);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Cancel callback server
  void cancelServer() {
    _closeServer();
  }

  /// Logout from Google Drive
  Future<void> logout() async {
    final config = vaultService.backupConfig;
    config.refreshToken = null;
    config.accessToken = null;
    config.tokenExpiry = null;
    config.userEmail = null;
    config.userName = null;
    config.storageUsed = null;
    config.storageLimit = null;
    await vaultService.saveBackupConfig(config);
  }

  /// Perform smart synchronization with cloud (Pull -> Merge -> Push)
  /// Uses OneShield_Merge folder for cross-device sync
  Future<bool> syncWithCloud() async {
    try {
      if (!await ensureValidToken()) return false;
      
      final mergeFolderId = _getMergeFolderId();
      if (mergeFolderId == null) return false;

      final config = vaultService.backupConfig;
      const mergeFileName = 'oneshield_sync.vpb';

      // 1. Look for existing merge file in the Merge folder
      final searchResponse = await http.get(
        Uri.parse(
          '$_driveApiUrl?q=${Uri.encodeComponent("name='$mergeFileName' and '$mergeFolderId' in parents and trashed=false")}&fields=files(id,name,modifiedTime)',
        ),
        headers: {'Authorization': 'Bearer ${config.accessToken}'},
      );

      String? existingMergeFileId;
      if (searchResponse.statusCode == 200) {
        final data = jsonDecode(searchResponse.body);
        final files = data['files'] as List;
        if (files.isNotEmpty) {
          existingMergeFileId = files[0]['id'];
        }
      }

      // 2. Download existing merge data if available
      if (existingMergeFileId != null) {
        final encryptedData = await downloadBackup(existingMergeFileId);
        if (encryptedData != null && encryptedData.isNotEmpty) {
          final syncData = vaultService.parseSyncData(encryptedData);
          final remoteEntries = syncData['entries'] as List<VaultEntry>;
          final remoteDeleted = syncData['deleted'] as List<String>;
          
          if (remoteEntries.isNotEmpty || remoteDeleted.isNotEmpty) {
            // 3. Smart merge local vs remote (including deletions)
            await vaultService.syncWithEntries(remoteEntries, remoteDeleted);
          }
        }
      }

      // 4. Upload merged data to Merge folder (single file, overwrite)
      final exportData = vaultService.exportData();
      if (existingMergeFileId != null) {
        // Update existing file
        await http.patch(
          Uri.parse('$_driveUploadUrl/$existingMergeFileId?uploadType=media'),
          headers: {
            'Authorization': 'Bearer ${config.accessToken}',
            'Content-Type': 'application/octet-stream',
          },
          body: utf8.encode(exportData),
        );
      } else {
        // Create new merge file
        final metaResponse = await http.post(
          Uri.parse('$_driveApiUrl?fields=id'),
          headers: {
            'Authorization': 'Bearer ${config.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': mergeFileName,
            'parents': [mergeFolderId],
          }),
        );
        if (metaResponse.statusCode == 200) {
          final fileId = jsonDecode(metaResponse.body)['id'];
          await http.patch(
            Uri.parse('$_driveUploadUrl/$fileId?uploadType=media'),
            headers: {
              'Authorization': 'Bearer ${config.accessToken}',
              'Content-Type': 'application/octet-stream',
            },
            body: utf8.encode(exportData),
          );
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
