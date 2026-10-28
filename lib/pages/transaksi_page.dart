import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';
import '../models/cafe_menu.dart';
import '../services/cafe_menu_service.dart';

class TransaksiPage extends StatefulWidget {
  final AppUser user;

  const TransaksiPage({
    super.key,
    required this.user,
  });

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  late final CafeMenuService _menuService;

  List<CafeMenu> _menus = [];
  final Map<int, int> _quantities = {};

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  // Metode pembayaran default
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _menuService = CafeMenuService(widget.user);
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final menus = await _menuService.fetchMenus();

      if (!mounted) return;

      setState(() {
        _menus = menus.where((menu) => menu.isAvailable).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat menu: $e';
      });
    }
  }

  void _changeQuantity(CafeMenu menu, int change) {
    setState(() {
      final current = _quantities[menu.id] ?? 0;
      final next = current + change;

      if (next <= 0) {
        _quantities.remove(menu.id);
      } else {
        _quantities[menu.id] = next;
      }
    });
  }

  double get _totalPayment {
    double total = 0;

    for (final menu in _menus) {
      final quantity = _quantities[menu.id] ?? 0;
      total += menu.price * quantity;
    }

    return total;
  }

  String _formatRupiah(num amount) {
    final value = amount.round().toString();
    final result = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      result.write(value[i]);

      final remaining = value.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        result.write('.');
      }
    }

    return 'Rp$result';
  }

  Future<void> _saveTransaction() async {
    final items = _quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {
              'product_id': entry.key,
              'quantity': entry.value,
            })
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu menu terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/transactions.php'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode({
          'items': items,
          'payment_method': _paymentMethod,
        }),
      );

      final Map<String, dynamic> result =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && result['success'] == true) {
        if (!mounted) return;

        final data = result['data'];
        final total = data is Map
            ? (num.tryParse('${data['total_payment']}') ??
                _totalPayment)
            : _totalPayment;

        final paymentLabel =
            _paymentMethod == 'qris' ? 'QRIS' : 'Cash';

        setState(() {
          _quantities.clear();
          _saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaksi berhasil disimpan. '
              'Pembayaran: $paymentLabel. '
              'Total: ${_formatRupiah(total)}',
            ),
          ),
        );
      } else {
        throw Exception(
          result['message'] ?? 'Transaksi gagal disimpan.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan transaksi: $e'),
        ),
      );
    }
  }

  Widget _buildPaymentMethod() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metode Pembayaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'cash',
              groupValue: _paymentMethod,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
              title: const Row(
                children: [
                  Icon(Icons.payments_outlined),
                  SizedBox(width: 10),
                  Text('Cash'),
                ],
              ),
              subtitle: const Text('Pembayaran tunai'),
            ),

            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'qris',
              groupValue: _paymentMethod,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
              title: const Row(
                children: [
                  Icon(Icons.qr_code_2),
                  SizedBox(width: 10),
                  Text('QRIS'),
                ],
              ),
              subtitle: const Text('Pembayaran melalui QRIS'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadMenus,
            tooltip: 'Muat ulang menu',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadMenus,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _menus.isEmpty
                  ? const Center(
                      child: Text('Belum ada menu yang tersedia.'),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _menus.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final menu = _menus[index];
                              final quantity =
                                  _quantities[menu.id] ?? 0;
                              final subtotal =
                                  menu.price * quantity;

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              menu.name,
                                              style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRupiah(menu.price),
                                            ),
                                            if (quantity > 0) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Subtotal: '
                                                '${_formatRupiah(subtotal)}',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: quantity > 0
                                            ? () => _changeQuantity(
                                                  menu,
                                                  -1,
                                                )
                                            : null,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text(
                                        '$quantity',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _changeQuantity(menu, 1),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildPaymentMethod(),
                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Pembayaran',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(_totalPayment),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                ElevatedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : _saveTransaction,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(
                                    _saving
                                        ? 'Menyimpan...'
                                        : 'Simpan Transaksi',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}