import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/vault_service.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';


class LoginScreen extends StatefulWidget {
  final VaultService vaultService;

  const LoginScreen({super.key, required this.vaultService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _showRecovery = false;
  final _localAuth = LocalAuthentication();

  // Recovery state
  List<String?> _recoverySelectedQuestions = [];
  List<TextEditingController> _recoveryAnswerControllers = [];

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    // Try biometric on start
    _tryBiometric();
  }

  @override
  void dispose() {
    _passController.dispose();
    _animController.dispose();
    for (final c in _recoveryAnswerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    // Skip biometrics on Windows
    if (Platform.isWindows) return;
    if (widget.vaultService.masterConfig?.biometricEnabled != true) return;

    try {
      // Check if device supports any auth (biometric + device credentials)
      final canAuth = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) {
        debugPrint('OneShield: Device does not support authentication');
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: AppConstants.biometricReason,
        biometricOnly: false, // Allow PIN/pattern/password fallback
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        // Device auth unlock the vault (reads key from secure storage)
        final success = await widget.vaultService.unlockWithBiometricAsync();
        if (success) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  HomeScreen(vaultService: widget.vaultService),
            ),
          );
        } else {
          debugPrint('OneShield: Vault unlock with biometric key failed');
          if (mounted) {
            _showSnackBar(
              'Authentication key not found. Please disable and re-enable '
              'Device Authentication in Settings.',
            );
          }
        }
      }
    } catch (e) {
      // Device auth not available or failed
      debugPrint('OneShield: Biometric/Device auth error: $e');
    }
  }

  void _unlock() {
    if (_passController.text.isEmpty) {
      _showSnackBar('Please enter your master password');
      return;
    }

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 300), () async {
      final success = widget.vaultService.unlock(_passController.text);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        // Auto re-save biometric key if device auth is enabled
        // This fixes the case where the key was lost from secure storage
        if (widget.vaultService.masterConfig?.biometricEnabled == true) {
          try {
            await widget.vaultService.setBiometric(true);
            debugPrint('OneShield: Biometric key re-saved after master password login');
          } catch (e) {
            debugPrint('OneShield: Failed to re-save biometric key: $e');
          }
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(vaultService: widget.vaultService),
          ),
        );
      } else {
        _showSnackBar('Invalid master password');
        _passController.clear();
      }
    });
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      final content = await file.readAsString();

      if (!mounted) return;

      setState(() => _isLoading = true);

      // Import without password - user will login with the backup's master password
      final success = await widget.vaultService.importFullBackupWithoutPassword(content);

      setState(() => _isLoading = false);

      if (success && mounted) {
        _showSnackBar('Backup imported! Please login with your master password.');
        // Stay on login screen - user must enter backup's master password to unlock
      } else {
        _showSnackBar('Import failed. Check the file format.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error reading backup file');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: Platform.isWindows
            ? EdgeInsets.only(
                bottom: 20,
                left: MediaQuery.of(context).size.width * 0.6,
                right: 20,
              )
            : const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Resets recovery state and goes back to login view
  void _goBackToLogin() {
    // Dispose controllers before clearing
    for (final c in _recoveryAnswerControllers) {
      c.dispose();
    }
    setState(() {
      _showRecovery = false;
      _recoverySelectedQuestions = [];
      _recoveryAnswerControllers = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only intercept back when recovery is showing
      canPop: !_showRecovery,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showRecovery) {
          _goBackToLogin();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: DesktopResponsiveWrapper(
                child: _showRecovery ? _buildRecoveryView() : _buildLoginView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      children: [
        const SizedBox(height: 60),
        // Animated logo
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              AppConstants.logoAsset,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppConstants.appTagline,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
        VaultTextField(
          label: 'MASTER PASSWORD',
          hint: 'Enter your master password',
          controller: _passController,
          obscureText: _obscure,
          showToggle: true,
          prefixIcon: Icons.lock_outline,
          onToggleVisibility: () =>
              setState(() => _obscure = !_obscure),
          onSubmitted: (_) => _unlock(),
          textInputAction: TextInputAction.go,
        ),
        const SizedBox(height: 32),
        GradientButton(
          text: 'Unlock Vault',
          icon: Icons.lock_open,
          onPressed: _unlock,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showRecovery = true),
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Forgot Password?'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _importBackup,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Import Backup'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.surfaceLight),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (!Platform.isWindows && widget.vaultService.masterConfig?.biometricEnabled == true) ...[
          const SizedBox(height: 24),
          IconButton(
            onPressed: _tryBiometric,
            icon: const Icon(
              Icons.lock_person,
              size: 48,
              color: AppTheme.accentCyan,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecoveryView() {
    final requiredCount =
        widget.vaultService.masterConfig?.securityQuestions.length ?? 3;
    final remaining = widget.vaultService.getRemainingRecoveryAttempts();
    final canAttempt = widget.vaultService.canAttemptRecovery();

    // Initialize selection state if not already done
    if (_recoverySelectedQuestions.isEmpty) {
      _recoverySelectedQuestions = List<String?>.filled(requiredCount, null);
      _recoveryAnswerControllers =
          List.generate(requiredCount, (_) => TextEditingController());
    }

    return Column(
      children: [
        // Top back button (mobile style)
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _goBackToLogin,
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textSecondary,
            ),
            tooltip: 'Back to Login',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: canAttempt
                ? AppTheme.accentOrange.withValues(alpha: 0.2)
                : AppTheme.accentRed.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            canAttempt ? Icons.security : Icons.lock,
            size: 48,
            color: canAttempt ? AppTheme.accentOrange : AppTheme.accentRed,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Password Recovery',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          canAttempt
              ? 'Select the security questions you chose\nduring setup and provide your answers.'
              : 'Too many failed attempts today.\nPlease try again tomorrow.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        // Remaining attempts indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: remaining > 5
                ? AppTheme.accentGreen.withValues(alpha: 0.1)
                : remaining > 2
                    ? AppTheme.accentOrange.withValues(alpha: 0.1)
                    : AppTheme.accentRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: remaining > 5
                  ? AppTheme.accentGreen.withValues(alpha: 0.3)
                  : remaining > 2
                      ? AppTheme.accentOrange.withValues(alpha: 0.3)
                      : AppTheme.accentRed.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: remaining > 5
                    ? AppTheme.accentGreen
                    : remaining > 2
                        ? AppTheme.accentOrange
                        : AppTheme.accentRed,
              ),
              const SizedBox(width: 6),
              Text(
                '$remaining attempts remaining today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: remaining > 5
                      ? AppTheme.accentGreen
                      : remaining > 2
                          ? AppTheme.accentOrange
                          : AppTheme.accentRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (canAttempt) ...[
          for (int i = 0; i < requiredCount; i++) ...[
            _buildRecoveryQuestionCard(i),
          ],
          const SizedBox(height: 24),
          GradientButton(
            text: 'Recover Access',
            icon: Icons.lock_open,
            gradient: const LinearGradient(
              colors: [AppTheme.accentOrange, AppTheme.accentPink],
            ),
            onPressed: () async {
              // Validate all questions selected and answered
              for (int i = 0; i < requiredCount; i++) {
                if (_recoverySelectedQuestions[i] == null) {
                  _showSnackBar('Please select all $requiredCount security questions');
                  return;
                }
                if (_recoveryAnswerControllers[i].text.trim().isEmpty) {
                  _showSnackBar('Please answer all security questions');
                  return;
                }
              }

              // Check for duplicate question selections
              final uniqueQuestions = _recoverySelectedQuestions.toSet();
              if (uniqueQuestions.length != requiredCount) {
                _showSnackBar('Please select $requiredCount different questions');
                return;
              }

              // Build question-answer pairs
              final questionAnswerPairs = <Map<String, String>>[];
              for (int i = 0; i < requiredCount; i++) {
                questionAnswerPairs.add({
                  'question': _recoverySelectedQuestions[i]!,
                  'answer': _recoveryAnswerControllers[i].text.trim(),
                });
              }

              final result = await widget.vaultService
                  .recoverWithAnswersLimited(questionAnswerPairs);

              if (!mounted) return;

              if (result['success'] == true) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        HomeScreen(vaultService: widget.vaultService),
                  ),
                );
              } else if (result['error'] == 'limit_exceeded') {
                setState(() {}); // Refresh UI to show blocked state
                _showSnackBar(
                    'Daily limit exceeded. Try again tomorrow.');
              } else {
                setState(() {}); // Refresh remaining count
                _showSnackBar(
                    'Incorrect questions or answers. ${result['remaining']} attempts remaining.');
              }
            },
          ),
        ],
      ],
    );
  }

  /// Get available questions for a recovery dropdown (exclude already selected)
  List<String> _getAvailableRecoveryQuestions(int currentIndex) {
    final selected = <String>{};
    for (int i = 0; i < _recoverySelectedQuestions.length; i++) {
      if (i != currentIndex && _recoverySelectedQuestions[i] != null) {
        selected.add(_recoverySelectedQuestions[i]!);
      }
    }
    return VaultService.predefinedSecurityQuestions
        .where((q) => !selected.contains(q))
        .toList();
  }

  Widget _buildRecoveryQuestionCard(int index) {
    final availableQuestions = _getAvailableRecoveryQuestions(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION ${index + 1}',
              style: const TextStyle(
                color: AppTheme.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recoverySelectedQuestions[index],
              isExpanded: true,
              dropdownColor: AppTheme.surfaceDark,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Select your security question...',
                hintStyle: TextStyle(
                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(Icons.help_outline,
                    size: 18, color: AppTheme.accentPurple),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: availableQuestions.map((question) {
                return DropdownMenuItem<String>(
                  value: question,
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _recoverySelectedQuestions[index] = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recoveryAnswerControllers[index],
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Your answer',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
