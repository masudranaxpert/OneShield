import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/common_widgets.dart';
import '../services/vault_service.dart';
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
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  // Recovery questions
  final List<String> _selectedQuestions = List.filled(3, '');
  final List<TextEditingController> _answerControllers =
      List.generate(3, (_) => TextEditingController());
  final int _requiredQuestions = 3;

  final List<String> _questions = VaultService.predefinedSecurityQuestions;

  @override
  void dispose() {
    _pageController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _setupVault() async {
    // Basic validation
    if (_passController.text.isEmpty) {
      _showSnackBar('Master password cannot be empty');
      return;
    }
    if (_passController.text != _confirmPassController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (_passController.text.length < 8) {
      _showSnackBar('Master password must be at least 8 characters');
      return;
    }

    // Question validation
    for (int i = 0; i < _requiredQuestions; i++) {
      if (_selectedQuestions[i].isEmpty || _answerControllers[i].text.isEmpty) {
        _showSnackBar('Please answer all 3 security questions');
        return;
      }
    }

    // Check for duplicate questions
    final uniqueQuestions = _selectedQuestions.toSet();
    if (uniqueQuestions.length < _requiredQuestions) {
      _showSnackBar('Please select 3 different questions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qa = List.generate(_requiredQuestions, (i) => {
        'question': _selectedQuestions[i],
        'answer': _answerControllers[i].text,
      });

      final success = await widget.vaultService.setupMasterPassword(
        _passController.text,
        qa,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(vaultService: widget.vaultService),
          ),
        );
      } else if (mounted) {
        _showSnackBar('Failed to set up vault. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<String> _getAvailableQuestions(int index) {
    final others = <String>{};
    for (int i = 0; i < _selectedQuestions.length; i++) {
      if (i != index && _selectedQuestions[i].isNotEmpty) {
        others.add(_selectedQuestions[i]);
      }
    }
    return _questions.where((q) => !others.contains(q)).toList();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(vaultService: widget.vaultService),
          ),
        );
      } else {
        _showSnackBar('Import failed. Check the file format.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error reading backup file');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomePage(),
            _buildPasswordPage(),
            _buildQuestionsPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DesktopResponsiveWrapper(
        child: Column(
          children: [
            const SizedBox(height: 60),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                AppConstants.logoAsset,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Welcome to OneShield',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your secure digital fortress',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            const GlassCard(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _FeatureItem(
                    icon: Icons.security,
                    title: 'AES-256 Encryption',
                    desc: 'Military-grade encryption for your passwords.',
                  ),
                  SizedBox(height: 20),
                  _FeatureItem(
                    icon: Icons.cloud_off,
                    title: 'Offline First',
                    desc: 'Your data never leaves your device unless you backup.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GradientButton(
              text: 'Create New Vault',
              icon: Icons.add_moderator,
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _importBackup,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import Existing Backup'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: AppTheme.surfaceLight),
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DesktopResponsiveWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  AppConstants.logoAsset,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Set Master Password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This password encrypts your entire vault. Don\'t lose it!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
            VaultTextField(
              label: 'MASTER PASSWORD',
              hint: 'Min 8 characters',
              controller: _passController,
              obscureText: _obscure,
              showToggle: true,
              prefixIcon: Icons.lock_outline,
              onToggleVisibility: () => setState(() => _obscure = !_obscure),
            ),
            const SizedBox(height: 20),
            VaultTextField(
              label: 'CONFIRM PASSWORD',
              hint: 'Re-enter master password',
              controller: _confirmPassController,
              obscureText: _obscure,
              prefixIcon: Icons.lock_reset,
            ),
            const SizedBox(height: 40),
            GradientButton(
              text: 'Continue',
              icon: Icons.arrow_forward,
              onPressed: () {
                if (_passController.text.length < 8) {
                  _showSnackBar('Password must be at least 8 characters');
                  return;
                }
                if (_passController.text != _confirmPassController.text) {
                  _showSnackBar('Passwords do not match');
                  return;
                }
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
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
      ),
    );
  }

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: DesktopResponsiveWrapper(
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
            value: _selectedQuestions[index].isEmpty ? null : _selectedQuestions[index],
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
                _selectedQuestions[index] = value ?? '';
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: AppTheme.accentCyan),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
