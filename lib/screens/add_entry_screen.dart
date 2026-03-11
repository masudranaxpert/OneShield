import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/vault_service.dart';
import '../services/crypto_service.dart';
import '../widgets/common_widgets.dart';

class AddEntryScreen extends StatefulWidget {
  final VaultService vaultService;

  const AddEntryScreen({super.key, required this.vaultService});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  String _selectedCategory = 'password';
  final _titleController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, bool> _obscureFields = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initFieldControllers();
  }

  void _initFieldControllers() {
    _fieldControllers.clear();
    _obscureFields.clear();
    final category = VaultCategory.getById(_selectedCategory);
    for (final field in category.defaultFields) {
      _fieldControllers[field] = TextEditingController();
      _obscureFields[field] = _isSecretField(field);
    }
  }

  bool _isSecretField(String field) {
    return ['password', 'cvv', 'pin', 'cardNumber'].contains(field);
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'username':
        return 'Username / Email';
      case 'password':
        return 'Password';
      case 'url':
        return 'Website URL';
      case 'notes':
        return 'Notes';
      case 'cardHolder':
        return 'Card Holder Name';
      case 'cardNumber':
        return 'Card Number';
      case 'expiryDate':
        return 'Expiry Date (MM/YY)';
      case 'cvv':
        return 'CVV';
      case 'pin':
        return 'PIN';
      case 'content':
        return 'Note Content';
      case 'firstName':
        return 'First Name';
      case 'lastName':
        return 'Last Name';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Phone Number';
      case 'address':
        return 'Address';
      case 'dateOfBirth':
        return 'Date of Birth';
      default:
        return field;
    }
  }

  IconData _getFieldIcon(String field) {
    switch (field) {
      case 'username':
        return Icons.person_outline;
      case 'password':
        return Icons.lock_outline;
      case 'url':
        return Icons.link;
      case 'notes':
        return Icons.note_outlined;
      case 'cardHolder':
        return Icons.person_outline;
      case 'cardNumber':
        return Icons.credit_card;
      case 'expiryDate':
        return Icons.calendar_today;
      case 'cvv':
        return Icons.security;
      case 'pin':
        return Icons.pin;
      case 'content':
        return Icons.edit;
      case 'firstName':
        return Icons.badge_outlined;
      case 'lastName':
        return Icons.badge_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'address':
        return Icons.home_outlined;
      case 'dateOfBirth':
        return Icons.cake_outlined;
      default:
        return Icons.text_fields;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fields = <String, String>{};
    for (final entry in _fieldControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        fields[entry.key] = entry.value.text;
      }
    }

    await widget.vaultService.addEntry(
      title: _titleController.text.trim(),
      category: _selectedCategory,
      fields: fields,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selector
            const Text(
              'CATEGORY',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VaultCategory.categories.map((cat) {
                return CategoryChip(
                  label: cat.label,
                  icon: cat.icon,
                  color: cat.color,
                  selected: _selectedCategory == cat.id,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat.id;
                      _initFieldControllers();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Title
            VaultTextField(
              label: 'TITLE',
              hint: 'e.g. Google Account',
              controller: _titleController,
              prefixIcon: Icons.title,
            ),
            const SizedBox(height: 20),

            // Dynamic fields
            ..._fieldControllers.entries.map((entry) {
              final field = entry.key;
              final controller = entry.value;
              final isObscure = _obscureFields[field] ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VaultTextField(
                      label: _getFieldLabel(field).toUpperCase(),
                      hint: _getFieldLabel(field),
                      controller: controller,
                      obscureText: isObscure,
                      showToggle: _isSecretField(field),
                      prefixIcon: _getFieldIcon(field),
                      maxLines: field == 'notes' || field == 'content'
                          ? 4
                          : 1,
                      onToggleVisibility: () {
                        setState(() {
                          _obscureFields[field] = !isObscure;
                        });
                      },
                      suffix: field == 'password'
                          ? IconButton(
                              icon: const Icon(Icons.casino,
                                  color: AppTheme.accentCyan, size: 20),
                              onPressed: () {
                                controller.text =
                                    CryptoService.generatePassword();
                              },
                              tooltip: 'Generate Password',
                            )
                          : null,
                    ),
                    if (field == 'password') ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder(
                        valueListenable: controller,
                        builder: (_, __, ___) => PasswordStrengthBar(
                          password: controller.text,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),
            GradientButton(
              text: 'Save Entry',
              icon: Icons.save,
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
