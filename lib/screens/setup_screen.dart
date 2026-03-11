import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/vault_service.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  final VaultService vaultService;

  const SetupScreen({super.key, required this.vaultService});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 1: Master password
  final _masterPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscureMaster = true;
  bool _obscureConfirm = true;

  // Page 2: Security questions - predefined list with dropdown
  final int _requiredQuestions = 3;
  final List<String?> _selectedQuestions = [null, null, null];
  final List<TextEditingController> _answerControllers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _requiredQuestions; i++) {
      _answerControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _masterPassController.dispose();
    _confirmPassController.dispose();
    for (final c in _answerControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  /// Get available questions for a dropdown (exclude already selected ones)
  List<String> _getAvailableQuestions(int currentIndex) {
    final selected = <String>{};
    for (int i = 0; i < _requiredQuestions; i++) {
      if (i != currentIndex && _selectedQuestions[i] != null) {
        selected.add(_selectedQuestions[i]!);
      }
    }
    return VaultService.predefinedSecurityQuestions
        .where((q) => !selected.contains(q))
        .toList();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_masterPassController.text.length < AppConstants.minPasswordLength) {
        _showSnackBar('Password must be at least ${AppConstants.minPasswordLength} characters');
        return;
      }
      if (_masterPassController.text != _confirmPassController.text) {
        _showSnackBar('Passwords do not match');
        return;
      }
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _setupVault() async {
    // Validate questions and answers
    for (int i = 0; i < _requiredQuestions; i++) {
      if (_selectedQuestions[i] == null) {
        _showSnackBar('Please select all 3 security questions');
        return;
      }
      if (_answerControllers[i].text.trim().isEmpty) {
        _showSnackBar('Please answer all security questions');
        return;
      }
    }

    // Check for duplicate questions
    final uniqueQuestions = _selectedQuestions.toSet();
    if (uniqueQuestions.length != _requiredQuestions) {
      _showSnackBar('Please select 3 different questions');
      return;
    }

    setState(() => _isLoading = true);

    final questionsAndAnswers = <Map<String, String>>[];
    for (int i = 0; i < _requiredQuestions; i++) {
      questionsAndAnswers.add({
        'question': _selectedQuestions[i]!,
        'answer': _answerControllers[i].text.trim(),
      });
    }

    final success = await widget.vaultService.setupMasterPassword(
      _masterPassController.text,
      questionsAndAnswers,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(vaultService: widget.vaultService),
        ),
      );
    } else {
      _showSnackBar('Failed to set up vault. Please try again.');
    }
  }

  /// Import backup on fresh install - replaces everything
  Future<void> _importBackupFresh() async {
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

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup'),
          content: const Text(
            'This will restore your vault from the backup file. '
            'After import, you will need to login with the backup\'s '
            'master password.\n\n'
            'Continue?',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      setState(() => _isLoading = true);

      final success =
          await widget.vaultService.importFullBackupWithoutPassword(content);

      setState(() => _isLoading = false);

      if (success && mounted) {
        _showSnackBar('Backup imported! Please login with your password.');
        // Go to login screen since vault is now set up
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(vaultService: widget.vaultService),
          ),
        );
      } else if (mounted) {
        _showSnackBar('Import failed. Invalid backup file.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error reading backup file');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only allow pop on page 0 (prevent accidental exit on page 1)
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If on questions page, go back to password page
        if (_currentPage > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        // On page 0 of setup, do nothing (setup is mandatory)
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: List.generate(2, (index) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? AppTheme.accentCyan
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) =>
                      setState(() => _currentPage = page),
                  children: [
                    _buildPasswordPage(),
                    _buildQuestionsPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Logo / Icon
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppConstants.logoAsset,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Create Master Password',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'This password will encrypt all your data.\nMake it strong and memorable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          VaultTextField(
            label: 'MASTER PASSWORD',
            hint: 'Enter your master password',
            controller: _masterPassController,
            obscureText: _obscureMaster,
            showToggle: true,
            prefixIcon: Icons.lock_outline,
            onToggleVisibility: () =>
                setState(() => _obscureMaster = !_obscureMaster),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: _masterPassController,
            builder: (_, __, ___) => PasswordStrengthBar(
              password: _masterPassController.text,
            ),
          ),
          const SizedBox(height: 24),
          VaultTextField(
            label: 'CONFIRM PASSWORD',
            hint: 'Confirm your master password',
            controller: _confirmPassController,
            obscureText: _obscureConfirm,
            showToggle: true,
            prefixIcon: Icons.lock_outline,
            onToggleVisibility: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          const SizedBox(height: 40),
          GradientButton(
            text: 'Continue',
            icon: Icons.arrow_forward,
            onPressed: _nextPage,
          ),
          const SizedBox(height: 20),
          // Import backup option on setup page
          Center(
            child: Column(
              children: [
                const Text(
                  'Already have a backup?',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _importBackupFresh,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import Backup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentCyan,
                    side: const BorderSide(color: AppTheme.accentCyan),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline,
                size: 48,
                color: AppTheme.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Security Questions',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Select 3 questions from the list below.\nThese are the ONLY way to recover your password.\nAnswers are case-insensitive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          for (int i = 0; i < _requiredQuestions; i++) ...[
            _buildQuestionDropdown(i),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 20),
          GradientButton(
            text: 'Set Up Vault',
            icon: Icons.check_circle_outline,
            onPressed: _setupVault,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('← Go Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionDropdown(int index) {
    final availableQuestions = _getAvailableQuestions(index);

    return GlassCard(
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
            initialValue: _selectedQuestions[index],
            isExpanded: true,
            dropdownColor: AppTheme.surfaceDark,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Select a security question...',
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
                _selectedQuestions[index] = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _answerControllers[index],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Your answer (case-insensitive)',
              hintStyle: TextStyle(
                color: AppTheme.textMuted.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              prefixIcon:
                  const Icon(Icons.edit, size: 18, color: AppTheme.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
