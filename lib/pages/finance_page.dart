
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';
import 'currency_converter_page.dart';

class FinancePage extends StatefulWidget {
  final AppUser user;

  const FinancePage({
    super.key,
    required this.user,
  });

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  DateTime _startDate = _weekStart(DateTime.now());
  DateTime _endDate = _weekStart(DateTime.now()).add(
    const Duration(days: 6),
  );

  Map<String, dynamic> _summary = {};
  List<dynamic> _expenses = [];

  final List<String> _categories = const [
    'Bahan Baku',
    'Listrik',
    'Air',
    'Gaji',
    'Sewa',
    'Peralatan',
    'Transportasi',
    'Operasional',
    'Lainnya',
  ];

  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  bool get _canManageExpenses {
    final role = widget.user.roleName.toLowerCase();
    return role.contains('manager') || role.contains('akuntan');
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  Future<void> _loadFinance() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/finance.php',
      ).replace(
        queryParameters: {
          'start_date': _dateString(_startDate),
          'end_date': _dateString(_endDate),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      final result =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 ||
          result['success'] != true) {
        throw Exception(
          result['message'] ?? 'Gagal memuat laporan keuangan.',
        );
      }

      final data = result['data'] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _summary =
            Map<String, dynamic>.from(data['summary'] as Map);
        _expenses = List<dynamic>.from(data['expenses'] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat keuangan: $e';
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      helpText: 'Pilih Periode Laporan',
      saveText: 'Terapkan',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });

    await _loadFinance();
  }

  void _openCurrencyConverter() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const CurrencyConverterPage(),
      ),
    );
  }

  Widget _buildCurrencyConverterCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE9E1D8),
        ),
      ),
      child: InkWell(
        onTap: _openCurrencyConverter,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFF1E4D5),
                child: Icon(
                  Icons.currency_exchange,
                  color: Color(0xFF6F4E37),
                  size: 27,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kurs & Konversi Mata Uang',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Konversi IDR, USD, SGD, EUR, dan lainnya',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Color(0xFF6F4E37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    String category = _categories.first;
    DateTime expenseDate = DateTime.now();

    await showDialog<void>(
      context: context,
      barrierDismissible: !_saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Input Pengeluaran'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: expenseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );

                                if (picked != null) {
                                  setDialogState(() {
                                    expenseDate = picked;
                                  });
                                }
                              },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(_displayDate(expenseDate)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    category = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan',
                          hintText: 'Contoh: Pembelian gula dan kopi',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization:
                            TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Keterangan wajib diisi.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Nominal (Rp)',
                          hintText: 'Contoh: 50000',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final normalized = (value ?? '')
                              .trim()
                              .replaceAll(',', '.');
                          final amount =
                              double.tryParse(normalized);

                          if (amount == null || amount <= 0) {
                            return 'Masukkan nominal yang valid.';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final normalized = amountController.text
                              .trim()
                              .replaceAll(',', '.');

                          final success = await _saveExpense(
                            expenseDate: expenseDate,
                            category: category,
                            description:
                                descriptionController.text.trim(),
                            amount: double.parse(normalized),
                          );

                          if (success && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: Text(
                    _saving ? 'Menyimpan...' : 'Simpan',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController.dispose();
    amountController.dispose();
  }

  Future<bool> _saveExpense({
    required DateTime expenseDate,
    required String category,
    required String description,
    required double amount,
  }) async {
    setState(() {
      _saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/finance.php'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode({
          'expense_date': _dateString(expenseDate),
          'category': category,
          'description': description,
          'amount': amount,
        }),
      );

      final result =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 201 ||
          result['success'] != true) {
        throw Exception(
          result['message'] ?? 'Gagal menyimpan pengeluaran.',
        );
      }

      if (!mounted) return false;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran berhasil disimpan.'),
        ),
      );

      await _loadFinance();
      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengeluaran: $e'),
        ),
      );

      return false;
    }
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRupiah(amount),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Belum ada pengeluaran pada periode ini.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final expense =
              Map<String, dynamic>.from(_expenses[index] as Map);

          final amount = _number(expense['amount']);
          final date =
              DateTime.tryParse('${expense['expense_date']}');

          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_long),
            ),
            title: Text(
              '${expense['description'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${expense['category'] ?? ''} • '
              '${date == null ? expense['expense_date'] : _displayDate(date)}',
            ),
            trailing: Text(
              _formatRupiah(amount),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManageExpenses) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Keuangan'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Akses laporan keuangan hanya untuk Manager dan Akuntan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final revenue = _number(_summary['total_revenue']);
    final expenses = _number(_summary['total_expenses']);
    final netBalance = _number(_summary['net_balance']);
    final cashRevenue = _number(_summary['cash_revenue']);
    final qrisRevenue = _number(_summary['qris_revenue']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadFinance,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _saving
            ? null
            : _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Input Pengeluaran'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadFinance,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFinance,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      100,
                    ),
                    children: [
                      // Fitur baru: konversi mata uang.
                      _buildCurrencyConverterCard(),
                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          '${_displayDate(_startDate)} - '
                          '${_displayDate(_endDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),

                      _summaryCard(
                        title: 'Pendapatan Penjualan',
                        amount: revenue,
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                      _summaryCard(
                        title: 'Total Pengeluaran',
                        amount: expenses,
                        icon: Icons.trending_down,
                        color: Colors.red,
                      ),
                      _summaryCard(
                        title: 'Saldo Bersih',
                        amount: netBalance,
                        icon: Icons.account_balance_wallet,
                        color: netBalance >= 0
                            ? Colors.blue
                            : Colors.red,
                      ),

                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rincian Pendapatan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.payments_outlined),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Cash')),
                                  Text(_formatRupiah(cashRevenue)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_2),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('QRIS')),
                                  Text(_formatRupiah(qrisRevenue)),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Jumlah Transaksi'),
                                  ),
                                  Text(
                                    '${_summary['transaction_count'] ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Jumlah Pengeluaran'),
                                  ),
                                  Text(
                                    '${_summary['expense_count'] ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Riwayat Pengeluaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildExpenseList(),
                    ],
                  ),
                ),
    );
  }
}