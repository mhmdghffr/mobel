
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/cafe_menu.dart';
import '../services/cafe_menu_service.dart';
import 'transaksi_page.dart';

class MenuCafePage extends StatefulWidget {
  final AppUser user;

  const MenuCafePage({
    super.key,
    required this.user,
  });

  @override
  State<MenuCafePage> createState() => _MenuCafePageState();
}

class _MenuCafePageState extends State<MenuCafePage> {
  late final CafeMenuService _service;

  List<CafeMenu> _menus = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  bool get _isManager => widget.user.role == UserRole.manager;

  @override
  void initState() {
    super.initState();
    _service = CafeMenuService(widget.user);
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final menus = await _service.fetchMenus();

      if (!mounted) return;

      setState(() {
        _menus = menus;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<CafeMenu> get _filteredMenus {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _menus;

    return _menus.where((menu) {
      return menu.name.toLowerCase().contains(query) ||
          menu.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showMenuForm({CafeMenu? menu}) async {
    if (!_isManager) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: menu?.name ?? '',
    );
    final categoryController = TextEditingController(
      text: menu?.category ?? '',
    );
    final priceController = TextEditingController(
      text: menu == null ? '' : menu.price.toString(),
    );

    bool isAvailable = menu?.isAvailable ?? true;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  menu == null ? 'Tambah Menu' : 'Edit Menu',
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Nama menu',
                            prefixIcon: Icon(Icons.local_cafe_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama menu wajib diisi.';
                            }
                            if (value.trim().length > 150) {
                              return 'Nama menu maksimal 150 karakter.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            hintText: 'Contoh: Kopi, Non-Kopi, Makanan',
                            prefixIcon: Icon(Icons.category_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Kategori wajib diisi.';
                            }
                            if (value.trim().length > 100) {
                              return 'Kategori maksimal 100 karakter.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Harga',
                            hintText: 'Contoh: 15000',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.payments_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final normalized =
                                value?.trim().replaceAll(',', '.');
                            final price = double.tryParse(
                              normalized ?? '',
                            );

                            if (normalized == null ||
                                normalized.isEmpty ||
                                price == null ||
                                !price.isFinite ||
                                price < 0) {
                              return 'Masukkan harga yang valid.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Menu tersedia'),
                          subtitle: Text(
                            isAvailable
                                ? 'Menu dapat dipesan'
                                : 'Menu tidak tersedia',
                          ),
                          value: isAvailable,
                          onChanged: (value) {
                            setDialogState(() {
                              isAvailable = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;

                      final price = double.parse(
                        priceController.text
                            .trim()
                            .replaceAll(',', '.'),
                      );

                      Navigator.of(dialogContext).pop({
                        'name': nameController.text.trim(),
                        'category': categoryController.text.trim(),
                        'price': price,
                        'is_available': isAvailable,
                      });
                    },
                    child: Text(menu == null ? 'Simpan' : 'Perbarui'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null || !mounted) return;

      try {
        if (menu == null) {
          await _service.addMenu(
            name: result['name'] as String,
            category: result['category'] as String,
            price: result['price'] as double,
            isAvailable: result['is_available'] as bool,
          );
        } else {
          await _service.updateMenu(
            id: menu.id,
            name: result['name'] as String,
            category: result['category'] as String,
            price: result['price'] as double,
            isAvailable: result['is_available'] as bool,
          );
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              menu == null
                  ? 'Menu berhasil ditambahkan.'
                  : 'Menu berhasil diperbarui.',
            ),
          ),
        );

        await _loadMenus();
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan menu: '
              '${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      nameController.dispose();
      categoryController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _deleteMenu(CafeMenu menu) async {
    if (!_isManager) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Menu'),
          content: Text(
            'Apakah kamu yakin ingin menghapus "${menu.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteMenu(menu.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu berhasil dihapus.'),
        ),
      );

      await _loadMenus();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus menu: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  void _openTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransaksiPage(user: widget.user),
      ),
    );
  }

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(0).split('');
    final formatted = StringBuffer();

    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) {
        formatted.write('.');
      }
      formatted.write(parts[i]);
    }

    return 'Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final menus = _filteredMenus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Café'),
        actions: [
          IconButton(
            onPressed: _openTransactions,
            tooltip: 'Transaksi',
            icon: const Icon(Icons.point_of_sale),
          ),
          IconButton(
            onPressed: _loadMenus,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              onPressed: () => _showMenuForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Menu'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama atau kategori menu...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          tooltip: 'Hapus pencarian',
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildBody(menus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<CafeMenu> menus) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 52,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadMenus,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (menus.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_cafe_outlined,
                size: 56,
                color: Color(0xFF6F4E37),
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty
                    ? 'Belum ada menu café.'
                    : 'Menu yang dicari tidak ditemukan.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (_isManager && _searchQuery.isEmpty) ...[
                const SizedBox(height: 8),
                const Text('Tekan "Tambah Menu" untuk mulai.'),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenus,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          final menu = menus[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: Color(0xFFE9E1D8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4E37)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_cafe_outlined,
                      color: Color(0xFF6F4E37),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          menu.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          menu.category,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(menu.price),
                          style: const TextStyle(
                            color: Color(0xFF6F4E37),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              menu.isAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 15,
                              color: menu.isAvailable
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              menu.isAvailable
                                  ? 'Tersedia'
                                  : 'Tidak tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: menu.isAvailable
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isManager)
                    PopupMenuButton<String>(
                      tooltip: 'Aksi menu',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showMenuForm(menu: menu);
                        } else if (value == 'delete') {
                          _deleteMenu(menu);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text('Hapus'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
