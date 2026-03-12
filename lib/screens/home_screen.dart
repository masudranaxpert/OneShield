import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/vault_entry.dart';
import '../services/vault_service.dart';
import '../services/crypto_service.dart';
import '../services/autofill_bridge.dart';
import '../services/drive_backup_service.dart';
import '../widgets/common_widgets.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final VaultService vaultService;

  const HomeScreen({super.key, required this.vaultService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showSearch = false;

  // Nested navigator for Windows so sidebar stays persistent
  final GlobalKey<NavigatorState> _contentNavigatorKey = GlobalKey<NavigatorState>();

  bool _isSyncing = false;

  late AnimationController _fabAnimController;
  late AutofillBridge _autofillBridge;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimController.forward();
    _autofillBridge = AutofillBridge(vaultService: widget.vaultService);
    _autofillBridge.syncCredentials();
    
    // Listen for background sync changes to refresh UI in real-time
    widget.vaultService.addListener(_onVaultDataChanged);
  }

  void _onVaultDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.vaultService.removeListener(_onVaultDataChanged);
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  List<VaultEntry> _getFilteredEntries() {
    List<VaultEntry> entries;
    if (_selectedCategory == 'all') {
      entries = widget.vaultService.getAllEntries();
    } else if (_selectedCategory == 'favorites') {
      entries = widget.vaultService.getFavorites();
    } else {
      entries = widget.vaultService.getEntriesByCategory(_selectedCategory);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      entries = entries.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }



  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return _buildWindowsLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildVaultTab(),
              _buildGeneratorTab(),
              SettingsScreen(vaultService: widget.vaultService),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: _selectedIndex == 0
            ? ScaleTransition(
                scale: _fabAnimController,
                child: FloatingActionButton(
                  onPressed: _addNewEntry,
                  child: const Icon(Icons.add),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildWindowsLayout() {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Navigator(
                key: _contentNavigatorKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => _buildWindowsContent(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? ScaleTransition(
              scale: _fabAnimController,
              child: FloatingActionButton(
                onPressed: _addNewEntry,
                mouseCursor: SystemMouseCursors.click,
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  Widget _buildWindowsContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildVaultTab(),
        _buildGeneratorTab(),
        SettingsScreen(vaultService: widget.vaultService),
      ],
    );
  }

  Widget _buildVaultTab() {
    final entries = _getFilteredEntries();

    return DesktopResponsiveWrapper(
      maxWidth: 800,
      child: CustomScrollView(
      slivers: [
        // App bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _showSearch
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search vault...',
                            prefixIcon: const Icon(Icons.search,
                                color: AppTheme.textMuted),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppTheme.textMuted),
                              onPressed: () {
                                setState(() {
                                  _showSearch = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    AppConstants.logoAsset,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  AppConstants.appName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${widget.vaultService.entryCount} items secured',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
                if (!_showSearch)
                  IconButton(
                    onPressed: () =>
                        setState(() => _showSearch = true),
                    icon: const Icon(Icons.search,
                        color: AppTheme.textSecondary),
                  ),
                // Sync button
                if (!_showSearch && widget.vaultService.backupConfig.isLoggedIn)
                  _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: _performSync,
                          icon: const Icon(Icons.sync,
                              color: AppTheme.accentCyan),
                          tooltip: 'Sync with cloud',
                        ),
              ],
            ),
          ),
        ),

        // Category filter
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip('all', 'All', Icons.apps),
                _buildFilterChip(
                    'favorites', 'Favorites', Icons.star_outline),
                ...VaultCategory.categories.map((cat) =>
                    _buildFilterChip(cat.id, cat.label, cat.icon)),
              ],
            ),
          ),
        ),

        // Entries
        if (entries.isEmpty)
          SliverFillRemaining(
            child: EmptyState(
              icon: _selectedCategory == 'favorites'
                  ? Icons.star_outline
                  : Icons.lock_outline,
              title: _searchQuery.isNotEmpty
                  ? 'No Results'
                  : _selectedCategory == 'favorites'
                      ? 'No Favorites'
                      : 'Vault is Empty',
              subtitle: _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Tap + to add your first entry',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  return _buildEntryCard(entry, index);
                },
                childCount: entries.length,
              ),
            ),
          ),
      ],
    ),
    );
  }

  Widget _buildFilterChip(String id, String label, IconData icon) {
    final selected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentCyan.withValues(alpha: 0.15)
                : AppTheme.surfaceMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.accentCyan : AppTheme.surfaceLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? AppTheme.accentCyan
                      : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppTheme.accentCyan
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(VaultEntry entry, int index) {
    final category = VaultCategory.getById(entry.category);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: GlassCard(
        onTap: () => _openEntry(entry),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: category.color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Favorite & more
            if (entry.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.star,
                  size: 18,
                  color: AppTheme.accentOrange,
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorTab() {
    return _PasswordGeneratorView();
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: AppTheme.surfaceLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.shield_outlined, Icons.shield, 'Vault'),
              _buildNavItem(
                  1, Icons.casino_outlined, Icons.casino, 'Generator'),
              _buildNavItem(
                  2, Icons.settings_outlined, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          right: BorderSide(
            color: AppTheme.surfaceLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // App Logo & Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    AppConstants.logoAsset,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'OneShield',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(0, Icons.shield_outlined, Icons.shield, 'Vault'),
          _buildSidebarItem(
              1, Icons.casino_outlined, Icons.casino, 'Generator'),
          _buildSidebarItem(
              2, Icons.settings_outlined, Icons.settings, 'Settings'),
          const Spacer(),
          // Logout at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _logout,
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentRed.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.accentRed),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    widget.vaultService.lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(vaultService: widget.vaultService)),
      (route) => false,
    );
  }

  Widget _buildSidebarItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentCyan.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentCyan.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                letterSpacing: isSelected ? 0.3 : 0,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isSelected ? 20 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.accentCyan,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentCyan.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewEntry() async {
    final nav = Platform.isWindows
        ? _contentNavigatorKey.currentState!
        : Navigator.of(context);
    final result = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(vaultService: widget.vaultService),
      ),
    );
    if (result == true) {
      setState(() {});
      // Re-sync credentials to autofill after adding new entry
      _autofillBridge.syncCredentials();
    }
  }

  void _openEntry(VaultEntry entry) async {
    final nav = Platform.isWindows
        ? _contentNavigatorKey.currentState!
        : Navigator.of(context);
    await nav.push(
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(
          vaultService: widget.vaultService,
          entry: entry,
        ),
      ),
    );
    setState(() {});
    // Re-sync after possible edit or delete
    _autofillBridge.syncCredentials();
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final driveService = DriveBackupService(vaultService: widget.vaultService);
      await driveService.syncWithCloud();
      if (mounted) {
        setState(() {});
        _showSyncNotification(context, 'Synced with cloud successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showSyncNotification(context, 'Sync failed: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Show a styled notification that works well on both mobile and Windows
  void _showSyncNotification(BuildContext context, String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF00C853)
            : const Color(0xFFFF5252),
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
}

// Password Generator view
class _PasswordGeneratorView extends StatefulWidget {
  @override
  State<_PasswordGeneratorView> createState() => _PasswordGeneratorViewState();
}

class _PasswordGeneratorViewState extends State<_PasswordGeneratorView> {
  String _generatedPassword = '';
  double _length = 20;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _special = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    setState(() {
      _generatedPassword = CryptoService.generatePassword(
        length: _length.round(),
        includeUppercase: _uppercase,
        includeLowercase: _lowercase,
        includeNumbers: _numbers,
        includeSpecial: _special,
      );
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Password copied (auto-clear in 30s)', style: TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: Platform.isWindows
            ? EdgeInsets.only(
                bottom: 20,
                left: MediaQuery.of(context).size.width * 0.6,
                right: 20,
              )
            : const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
    // Auto-clear clipboard after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: DesktopResponsiveWrapper(
        maxWidth: 600,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Password Generator',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate strong, unique passwords',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Generated password display
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: AppTheme.accentCyan.withValues(alpha: 0.3),
            child: Column(
              children: [
                SelectableText(
                  _generatedPassword,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyan,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                PasswordStrengthBar(password: _generatedPassword),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Regenerate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Length slider
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Length',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_length.round()}',
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _length,
                  min: 8,
                  max: 64,
                  divisions: 56,
                  activeColor: AppTheme.accentCyan,
                  inactiveColor: AppTheme.surfaceLight,
                  onChanged: (v) {
                    setState(() => _length = v);
                    _generate();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Character options
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildToggle('Uppercase (A-Z)', _uppercase, (v) {
                  setState(() => _uppercase = v);
                  _generate();
                }),
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildToggle('Lowercase (a-z)', _lowercase, (v) {
                  setState(() => _lowercase = v);
                  _generate();
                }),
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildToggle('Numbers (0-9)', _numbers, (v) {
                  setState(() => _numbers = v);
                  _generate();
                }),
                const Divider(color: AppTheme.surfaceLight, height: 24),
                _buildToggle('Special (!@#\$%)', _special, (v) {
                  setState(() => _special = v);
                  _generate();
                }),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.accentCyan,
          activeTrackColor: AppTheme.accentCyan.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
