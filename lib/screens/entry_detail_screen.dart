import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/vault_entry.dart';
import '../services/vault_service.dart';
import '../services/crypto_service.dart';
import '../widgets/common_widgets.dart';

class EntryDetailScreen extends StatefulWidget {
  final VaultService vaultService;
  final VaultEntry entry;

  const EntryDetailScreen({
    super.key,
    required this.vaultService,
    required this.entry,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late Map<String, String> _decryptedFields;
  final Map<String, bool> _visibleFields = {};
  bool _isEditing = false;
  final Map<String, TextEditingController> _editControllers = {};
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _decryptedFields = widget.vaultService.decryptFields(widget.entry);
    _titleController.text = widget.entry.title;

    for (final key in _decryptedFields.keys) {
      _visibleFields[key] = false;
      _editControllers[key] =
          TextEditingController(text: _decryptedFields[key]);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _editControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _copyField(String key, String value) {
    Clipboard.setData(ClipboardData(text: value));

    final isSensitive = _isSecretField(key);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSensitive
              ? '${_getFieldLabel(key)} copied (auto-clear in 30s)'
              : '${_getFieldLabel(key)} copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Auto-clear clipboard after 30 seconds for sensitive fields
    if (isSensitive) {
      Future.delayed(const Duration(seconds: 30), () {
        Clipboard.setData(const ClipboardData(text: ''));
      });
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
        return 'Expiry Date';
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
        return 'Phone';
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
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'address':
        return Icons.home_outlined;
      default:
        return Icons.text_fields;
    }
  }

  Future<void> _saveEdits() async {
    final newFields = <String, String>{};
    for (final entry in _editControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        newFields[entry.key] = entry.value.text;
      }
    }

    widget.entry.title = _titleController.text.trim();
    await widget.vaultService.updateEntry(widget.entry, newFields);
    _decryptedFields = widget.vaultService.decryptFields(widget.entry);

    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated successfully!')),
      );
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
            'Are you sure you want to delete "${widget.entry.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.vaultService.deleteEntry(widget.entry);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleFavorite() async {
    await widget.vaultService.updateEntryMeta(
      widget.entry,
      isFavorite: !widget.entry.isFavorite,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final category = VaultCategory.getById(widget.entry.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'Details'),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              widget.entry.isFavorite ? Icons.star : Icons.star_outline,
              color: widget.entry.isFavorite
                  ? AppTheme.accentOrange
                  : AppTheme.textSecondary,
            ),
          ),
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (!_isEditing)
            IconButton(
              onPressed: _deleteEntry,
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.accentRed),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DesktopResponsiveWrapper(
          maxWidth: 600,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isEditing
                      ? TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.entry.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: category.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fields
            ..._decryptedFields.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;
              final isSecret = _isSecretField(key);
              final isVisible = _visibleFields[key] ?? false;

              if (_isEditing) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: VaultTextField(
                    label: _getFieldLabel(key).toUpperCase(),
                    controller: _editControllers[key]!,
                    prefixIcon: _getFieldIcon(key),
                    obscureText: isSecret && !isVisible,
                    showToggle: isSecret,
                    maxLines:
                        key == 'notes' || key == 'content' ? 4 : 1,
                    onToggleVisibility: () {
                      setState(() {
                        _visibleFields[key] = !isVisible;
                      });
                    },
                    suffix: key == 'password'
                        ? IconButton(
                            icon: const Icon(Icons.casino,
                                color: AppTheme.accentCyan, size: 20),
                            onPressed: () {
                              _editControllers[key]!.text =
                                  CryptoService.generatePassword();
                            },
                          )
                        : null,
                  ),
                );
              }

              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getFieldIcon(key),
                            size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          _getFieldLabel(key),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isSecret && !isVisible
                                ? '•' * value.length.clamp(8, 20)
                                : value,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              fontFamily:
                                  isSecret ? 'monospace' : null,
                            ),
                          ),
                        ),
                        if (isSecret)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _visibleFields[key] = !isVisible;
                              });
                            },
                            icon: Icon(
                              isVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: AppTheme.textMuted,
                            ),
                            constraints: const BoxConstraints(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        IconButton(
                          onPressed: () => _copyField(key, value),
                          icon: const Icon(Icons.copy,
                              size: 18, color: AppTheme.textMuted),
                          constraints: const BoxConstraints(),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Meta info
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMetaRow(
                      'Created',
                      _formatDate(widget.entry.createdAt),
                      Icons.add_circle_outline,
                    ),
                    const Divider(
                        color: AppTheme.surfaceLight, height: 20),
                    _buildMetaRow(
                      'Last Modified',
                      _formatDate(widget.entry.updatedAt),
                      Icons.update,
                    ),
                  ],
                ),
              ),
            ],

            if (_isEditing) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        // Reset controllers
                        for (final kv in _decryptedFields.entries) {
                          _editControllers[kv.key]?.text = kv.value;
                        }
                        _titleController.text = widget.entry.title;
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(
                            color: AppTheme.surfaceLight),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      text: 'Save',
                      icon: Icons.check,
                      onPressed: _saveEdits,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
