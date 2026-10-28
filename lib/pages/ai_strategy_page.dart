
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Sesuaikan lokasi import ini dengan struktur folder proyekmu.
import '../config/api_config.dart';

class AiStrategyPage extends StatefulWidget {
  final String token;

  const AiStrategyPage({
    super.key,
    required this.token,
  });

  @override
  State<AiStrategyPage> createState() => _AiStrategyPageState();
}

class _AiStrategyPageState extends State<AiStrategyPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/ai_sales_forecast.php',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Format respons server tidak valid.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Gagal mengambil prediksi penjualan.',
        );
      }

      final result = decoded['data'];

      if (result is! Map<String, dynamic>) {
        throw Exception('Data prediksi tidak ditemukan.');
      }

      if (!mounted) return;

      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _rupiah(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    final rounded = amount.round();
    final text = rounded.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      final remaining = text.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }

    return 'Rp$buffer';
  }

  String _number(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategi Bisnis AI'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadForecast,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang prediksi',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme)
              : _buildContent(theme),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'Prediksi belum dapat dimuat',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadForecast,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final summary =
        _data?['forecast_summary'] as Map<String, dynamic>? ?? {};
    final recent =
        _data?['recent_actual'] as Map<String, dynamic>? ?? {};

    final daily = (_data?['daily_forecast'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final products = (_data?['menu_forecast'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return RefreshIndicator(
      onRefresh: _loadForecast,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeading(
            'Ringkasan bisnis',
            'Data aktual dan estimasi penjualan',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Estimasi omzet',
                  value: _rupiah(summary['predicted_revenue']),
                  subtitle: '7 hari mendatang',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  title: 'Estimasi transaksi',
                  value: _number(summary['predicted_transactions']),
                  subtitle: '7 hari mendatang',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryCard(
            title: 'Omzet aktual',
            value: _rupiah(recent['revenue']),
            subtitle:
                '${_number(recent['transactions'])} transaksi dalam 7 hari terakhir',
            icon: Icons.payments_outlined,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          _sectionHeading(
            'Prediksi omzet harian',
            'Perkiraan untuk setiap hari',
          ),
          const SizedBox(height: 12),
          _dailyForecastCard(daily),
          const SizedBox(height: 24),
          _sectionHeading(
            'Prediksi penjualan menu',
            'Estimasi jumlah item untuk 7 hari',
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada data penjualan menu yang cukup untuk '
                  'menampilkan prediksi. Catat transaksi terlebih dahulu.',
                ),
              ),
            )
          else
            ...products.take(10).map(_productCard),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text(
                        'Catatan AI',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Angka ini merupakan estimasi berdasarkan riwayat '
                    'penjualan, bukan jaminan hasil. Periksa stok bahan, '
                    'promosi, hari libur, dan perubahan harga sebelum '
                    'mengambil keputusan pembelian.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyForecastCard(List<Map<String, dynamic>> daily) {
    final maxRevenue = daily.fold<double>(
      0,
      (maxValue, item) {
        final value =
            (item['predicted_revenue'] as num?)?.toDouble() ?? 0;
        return value > maxValue ? value : maxValue;
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: daily.isEmpty
            ? const Text('Data prediksi harian belum tersedia.')
            : Column(
                children: daily.map((item) {
                  final revenue =
                      (item['predicted_revenue'] as num?)?.toDouble() ?? 0;

                  final fraction = maxRevenue <= 0
                      ? 0.0
                      : (revenue / maxRevenue).clamp(0.0, 1.0);

                  final date = item['date']?.toString() ?? '-';
                  final weekday = item['weekday']?.toString() ?? date;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('$weekday · $date'),
                            ),
                            Text(
                              _rupiah(revenue),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimasi ${_number(item['predicted_transactions'])} transaksi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> item) {
    final name = item['product_name']?.toString() ?? 'Menu';
    final quantity = item['predicted_quantity_7_days'];
    final revenue = item['predicted_item_revenue_7_days'];

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.coffee),
        ),
        title: Text(name),
        subtitle: Text(
          'Estimasi omzet menu: ${_rupiah(revenue)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _number(quantity),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'item / 7 hari',
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
