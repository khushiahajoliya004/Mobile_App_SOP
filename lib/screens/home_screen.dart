import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'call_upload_screen.dart';
import 'call_recorder_screen.dart';
import 'call_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  UserModel? _user;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getUser();
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  List<_MenuItem> _getMenuItems() {
    final items = <_MenuItem>[
      _MenuItem(icon: Icons.mic_rounded, activeIcon: Icons.mic, label: 'Record', permission: null, screen: const CallRecorderScreen()),
      _MenuItem(icon: Icons.upload_file_outlined, activeIcon: Icons.upload_file_rounded, label: 'Upload', permission: 'CALL_CREATE', screen: const CallUploadScreen()),
      _MenuItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History', permission: 'CALL_VIEW', screen: const CallHistoryScreen()),
    ];
    return items.where((item) {
      if (item.permission == null) return true;
      if (_user == null) return true;
      if (_user!.isSuperAdmin) return true;
      return _user!.hasPermission(item.permission!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _getMenuItems();
    if (_currentIndex >= menuItems.length) _currentIndex = 0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: AppBar(
            title: Text(menuItems[_currentIndex].label),
            backgroundColor: Colors.transparent,
            actions: [
              if (_user != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.accent, AppColors.primaryLight],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _user!.firstName.isNotEmpty ? _user!.firstName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_user!.userType, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                tooltip: 'Logout',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        FilledButton(
                          onPressed: () { Navigator.pop(ctx); _logout(); },
                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: menuItems[_currentIndex].screen,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 70,
            animationDuration: const Duration(milliseconds: 400),
            destinations: menuItems.map((item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: item.label,
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? permission;
  final Widget screen;
  _MenuItem({required this.icon, required this.activeIcon, required this.label, required this.permission, required this.screen});
}
