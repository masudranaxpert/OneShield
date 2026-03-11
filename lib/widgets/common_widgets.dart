import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Gradient button with glow effect
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final LinearGradient? gradient;
  final double? width;
  final bool isLoading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient,
    this.width,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          if (!widget.isLoading) widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: widget.width ?? double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient ?? AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.glowShadow(AppTheme.accentCyan),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism card
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? const EdgeInsets.only(bottom: 12),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor ?? AppTheme.surfaceLight.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Animated text field with label
class VaultTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final bool showToggle;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const VaultTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.onToggleVisibility,
    this.showToggle = false,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.textMuted, size: 20)
                : null,
            suffixIcon: showToggle
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : suffix,
          ),
        ),
      ],
    );
  }
}

/// Category chip
class CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppTheme.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppTheme.surfaceLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : AppTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated password strength indicator
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  int _getStrength() {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return (score.clamp(0, 5));
  }

  Color _getColor(int strength) {
    switch (strength) {
      case 0:
        return AppTheme.textMuted;
      case 1:
        return AppTheme.accentRed;
      case 2:
        return AppTheme.accentOrange;
      case 3:
        return Colors.yellow;
      case 4:
        return AppTheme.accentGreen;
      case 5:
        return AppTheme.accentCyan;
      default:
        return AppTheme.textMuted;
    }
  }

  String _getLabel(int strength) {
    switch (strength) {
      case 0:
        return '';
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Fair';
      case 4:
        return 'Strong';
      case 5:
        return 'Very Strong';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _getStrength();
    final color = _getColor(strength);
    final label = _getLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index < strength ? color : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, size: 48, color: AppTheme.accentCyan.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GradientButton(
                text: actionLabel!,
                onPressed: onAction!,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
