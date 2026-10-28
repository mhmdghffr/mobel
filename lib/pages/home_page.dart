
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'profile_page.dart';
import 'employees_page.dart';
import 'shifts_page.dart';
import 'attendance_page.dart';
import 'payroll_page.dart';
import 'menu_cafe_page.dart';
import 'finance_page.dart';
import 'transaksi_page.dart';
import 'reports_page.dart';
import 'mini_game_page.dart';
import 'ai_assistant_page.dart';
import 'ai_strategy_page.dart';
import 'time_converter_page.dart';

class HomePage extends StatelessWidget {
  final AppUser user;

  const HomePage({
    super.key,
    required this.user,
  });

  bool get _canUseAi =>
      user.role == UserRole.manager ||
      user.role == UserRole.akuntan;

  @override
  Widget build(BuildContext context) {
    final menus = _getMenus(context, user);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text(
          'Café Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfilePage(user: user),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Anda masuk sebagai ${user.roleName}.',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menus.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final menu = menus[index];

                  return _buildMenuCard(
                    context,
                    title: menu.title,
                    icon: menu.icon,
                    description: menu.description,
                    onTap: menu.onTap,
                  );
                },
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Café Management System',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6F4E37),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.coffee_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            'Halo, ${user.fullName}!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selamat datang di sistem manajemen café.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.roleName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE9E1D8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Menu $title akan dibuat pada tahap berikutnya.',
                  ),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: const Color(0xFF6F4E37),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DashboardMenu> _getMenus(
    BuildContext context,
    AppUser user,
  ) {
    final role = user.role;

    // Asisten AI hanya untuk Manager dan Akuntan.
    final aiAssistantMenu = _DashboardMenu(
      title: 'Asisten AI',
      icon: Icons.smart_toy_outlined,
      description: 'Tanya AI tentang prosedur operasional café',
      onTap: () {
        if (!_canUseAi) {
          _showAccessDenied(context);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AiAssistantPage(user: user),
          ),
        );
      },
    );

    // Strategi Bisnis AI hanya untuk Manager dan Akuntan.
    final aiStrategyMenu = _DashboardMenu(
      title: 'Strategi Bisnis AI',
      icon: Icons.insights_outlined,
      description: 'Prediksi omzet dan penjualan menu',
      onTap: () {
        if (!_canUseAi) {
          _showAccessDenied(context);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AiStrategyPage(
              token: user.token,
            ),
          ),
        );
      },
    );

    final menuCafe = _DashboardMenu(
      title: 'Menu Café',
      icon: Icons.local_cafe_outlined,
      description: role == UserRole.manager
          ? 'Kelola menu dan harga'
          : 'Lihat menu dan lakukan transaksi',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MenuCafePage(user: user),
          ),
        );
      },
    );

    final transaksiMenu = _DashboardMenu(
      title: 'Transaksi',
      icon: Icons.point_of_sale_outlined,
      description: 'Catat penjualan Cash dan QRIS',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TransaksiPage(user: user),
          ),
        );
      },
    );

    final attendanceMenu = _DashboardMenu(
      title: 'Absensi',
      icon: Icons.fingerprint,
      description: role == UserRole.manager
          ? 'Pantau kehadiran'
          : 'Check-in, check-out, dan riwayat',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AttendancePage(user: user),
          ),
        );
      },
    );

    final shiftMenu = _DashboardMenu(
      title: 'Jadwal Shift',
      icon: Icons.calendar_month_outlined,
      description: role == UserRole.manager
          ? 'Atur jadwal kerja'
          : role == UserRole.akuntan
              ? 'Lihat jadwal kerja'
              : 'Lihat jadwal pribadi',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ShiftsPage(user: user),
          ),
        );
      },
    );

    final payrollMenu = _DashboardMenu(
      title: 'Penggajian',
      icon: Icons.payments_outlined,
      description: role == UserRole.manager
          ? 'Kelola gaji karyawan'
          : role == UserRole.akuntan
              ? 'Periksa perhitungan gaji'
              : 'Lihat informasi gaji',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PayrollPage(user: user),
          ),
        );
      },
    );

    final financeMenu = _DashboardMenu(
      title: 'Keuangan',
      icon: Icons.account_balance_wallet_outlined,
      description: 'Lihat pemasukan dan catat pengeluaran',
      onTap: () {
        if (role != UserRole.manager &&
            role != UserRole.akuntan) {
          _showAccessDenied(context);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FinancePage(user: user),
          ),
        );
      },
    );

    final reportsMenu = _DashboardMenu(
      title: 'Laporan',
      icon: Icons.bar_chart_outlined,
      description: role == UserRole.manager
          ? 'Periksa dan setujui laporan shift'
          : 'Lihat rekonsiliasi operasional',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ReportsPage(user: user),
          ),
        );
      },
    );

    final miniGame = _DashboardMenu(
      title: 'Coffee Academy',
      icon: Icons.sports_esports_outlined,
      description: 'Belajar meracik kopi dan raih skor',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const MiniGamePage(),
          ),
        );
      },
    );

    // Konversi waktu tersedia untuk semua role.
    final timeConverterMenu = _DashboardMenu(
      title: 'Konversi Waktu',
      icon: Icons.access_time,
      description: 'Konversi WIB, WITA, dan WIT',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const TimeConverterPage(),
          ),
        );
      },
    );

    switch (role) {
      case UserRole.manager:
        return [
          _DashboardMenu(
            title: 'Karyawan',
            icon: Icons.groups_outlined,
            description: 'Kelola data karyawan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const EmployeesPage(),
                ),
              );
            },
          ),
          shiftMenu,
          attendanceMenu,
          payrollMenu,
          financeMenu,
          menuCafe,
          transaksiMenu,
          reportsMenu,
          aiAssistantMenu,
          aiStrategyMenu,
          timeConverterMenu,
          miniGame,
        ];

      case UserRole.akuntan:
        return [
          attendanceMenu,
          shiftMenu,
          menuCafe,
          transaksiMenu,
          financeMenu,
          payrollMenu,
          reportsMenu,
          aiAssistantMenu,
          aiStrategyMenu,
          timeConverterMenu,
          miniGame,
        ];

      case UserRole.karyawan:
        return [
          attendanceMenu,
          shiftMenu,
          menuCafe,
          transaksiMenu,
          payrollMenu,
          reportsMenu,
          timeConverterMenu,
          miniGame,
        ];
    }
  }

  void _showAccessDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Fitur ini hanya dapat digunakan oleh Manager dan Akuntan.',
        ),
      ),
    );
  }
}

class _DashboardMenu {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback? onTap;

  const _DashboardMenu({
    required this.title,
    required this.icon,
    required this.description,
    this.onTap,
  });
}
