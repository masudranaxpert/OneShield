import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'vault_service.dart';

/// Bridge between Flutter and native Android Autofill Service.
/// Syncs vault credentials to native storage so the autofill
/// service can fill them in browsers and other apps.
class AutofillBridge {
  static const _channel = MethodChannel('com.oneshield.app/autofill');

  final VaultService vaultService;

  AutofillBridge({required this.vaultService});

  /// Sync all password credentials to native autofill storage.
  /// Call this after vault unlock or when entries change.
  Future<void> syncCredentials() async {
    try {
      final credentials = vaultService.getAutofillCredentials();
      dev.log('AutofillBridge: syncing ${credentials.length} credentials');
      final encoded = jsonEncode(credentials);
      await _channel.invokeMethod('syncCredentials', {
        'credentials': encoded,
      });
      dev.log('AutofillBridge: syncCredentials success');
    } catch (e) {
      dev.log('AutofillBridge: syncCredentials error: $e');
    }
  }

  /// Clear all autofill credentials from native storage.
  /// Call this when vault is locked.
  Future<void> clearCredentials() async {
    try {
      await _channel.invokeMethod('clearCredentials');
    } catch (e) {
      dev.log('AutofillBridge: clearCredentials error: $e');
    }
  }

  /// Check if this app is set as the autofill provider.
  Future<bool> isAutofillEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAutofillEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open the autofill provider selection dialog.
  Future<void> openAutofillSettings() async {
    try {
      await _channel.invokeMethod('openAutofillSettings');
    } catch (e) {
      dev.log('AutofillBridge: openAutofillSettings error: $e');
    }
  }

  /// Open system settings page for autofill configuration.
  /// This navigates to the actual system settings (not the selection dialog).
  Future<void> openSystemAutofillSettings() async {
    try {
      await _channel.invokeMethod('openSystemAutofillSettings');
    } catch (e) {
      dev.log('AutofillBridge: openSystemAutofillSettings error: $e');
    }
  }

  /// Get debug info about autofill state
  Future<Map<String, dynamic>> debugAutofill() async {
    try {
      final result = await _channel.invokeMethod<Map>('debugAutofill');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {'error': 'null result'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
