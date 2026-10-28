
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() =>
      _CurrencyConverterPageState();
}

class _CurrencyConverterPageState
    extends State<CurrencyConverterPage> {
  static const Color coffee = Color(0xFF6F4E37);
  static const Color cream = Color(0xFFFFF8F0);

  final TextEditingController _amountController =
      TextEditingController(text: '100000');

  final Map<String, String> _currencies = const {
    'IDR': 'Rupiah Indonesia',
    'USD': 'Dolar Amerika Serikat',
    'SGD': 'Dolar Singapura',
    'EUR': 'Euro',
    'MYR': 'Ringgit Malaysia',
    'JPY': 'Yen Jepang',
    'AUD': 'Dolar Australia',
    'GBP': 'Pound Sterling',
  };

  String _from = 'IDR';
  String _to = 'USD';

  double? _rate;
  String? _rateDate;
  String? _error;
  bool _loading = false;

  double get _amount {
    final normalized = _amountController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    return double.tryParse(normalized) ?? 0;
  }

  double? get _convertedAmount {
    if (_rate == null || _amount < 0) return null;
    return _amount * _rate!;
  }

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    final amount = _amount;

    if (amount < 0) {
      setState(() {
        _error = 'Nominal tidak boleh negatif.';
        _rate = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _rate = null;
      _rateDate = null;
    });

    try {
      double rate;
      String? date;

      if (_from == _to) {
        rate = 1;
        date = DateTime.now().toIso8601String().substring(0, 10);
      } else {
        final uri = Uri.https(
          'api.frankfurter.dev',
          '/v2/rate/$_from/$_to',
        );

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          throw Exception(
            'Kurs tidak tersedia. Coba mata uang lain.',
          );
        }

        final data =
            jsonDecode(response.body) as Map<String, dynamic>;

        rate = (data['rate'] as num).toDouble();
        date = data['date']?.toString();
      }

      if (!mounted) return;

      setState(() {
        _rate = rate;
        _rateDate = date;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Tidak dapat mengambil kurs. Periksa koneksi internet '
            'lalu coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _swapCurrencies() async {
    setState(() {
      final previousFrom = _from;
      _from = _to;
      _to = previousFrom;
    });

    await _loadRate();
  }

  String _formatNumber(double value, String currency) {
    final decimals = currency == 'IDR' || currency == 'JPY' ? 0 : 2;

    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final negative = integerPart.startsWith('-');
    final digits = negative ? integerPart.substring(1) : integerPart;

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    final formattedInteger =
        '${negative ? '-' : ''}${buffer.toString()}';

    if (decimals == 0) return formattedInteger;

    return '$formattedInteger,${parts[1]}';
  }

  void _copyResult() {
    final result = _convertedAmount;

    if (result == null) return;

    final text =
        '${_formatNumber(_amount, _from)} $_from = '
        '${_formatNumber(result, _to)} $_to';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hasil konversi disalin.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Kurs & Konversi'),
        backgroundColor: coffee,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntro(),
                  const SizedBox(height: 22),
                  _buildConverterCard(),
                  const SizedBox(height: 18),
                  _buildRateInformation(),
                  const SizedBox(height: 20),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: coffee,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.currency_exchange,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currency Converter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Hitung nilai mata uang untuk kebutuhan café.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConverterCard() {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE9E1D8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nominal yang ingin dikonversi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[0-9.,]'),
                ),
              ],
              decoration: InputDecoration(
                hintText: 'Masukkan nominal',
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                  color: coffee,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
            _buildCurrencyDropdown(
              label: 'Dari mata uang',
              value: _from,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _from = value);
                _loadRate();
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: IconButton.filled(
                onPressed: _loading ? null : _swapCurrencies,
                tooltip: 'Tukar mata uang',
                style: IconButton.styleFrom(
                  backgroundColor: coffee,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.swap_vert),
              ),
            ),
            const SizedBox(height: 8),
            _buildCurrencyDropdown(
              label: 'Ke mata uang',
              value: _to,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _to = value);
                _loadRate();
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _loading ? null : _loadRate,
                style: FilledButton.styleFrom(
                  backgroundColor: coffee,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.currency_exchange),
                label: const Text('Konversi Sekarang'),
              ),
            ),
            const SizedBox(height: 22),
            _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: _currencies.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                '${entry.key} — ${entry.value}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _loading ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            CircularProgressIndicator(color: coffee),
            SizedBox(height: 12),
            Text('Mengambil kurs terbaru...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_off,
              color: Colors.deepOrange,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadRate,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final result = _convertedAmount;

    if (_rate == null || result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E4D5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'HASIL KONVERSI',
            style: TextStyle(
              color: coffee,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatNumber(result, _to)} $_to',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: coffee,
              fontWeight: FontWeight.bold,
              fontSize: 29,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatNumber(_amount, _from)} $_from',
            style: const TextStyle(color: Colors.black54),
          ),
          const Divider(height: 28),
          Text(
            '1 $_from = ${_formatNumber(_rate!, _to)} $_to',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: coffee,
            ),
          ),
          if (_rateDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tanggal kurs: $_rateDate',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _copyResult,
            icon: const Icon(Icons.copy),
            label: const Text('Salin Hasil'),
          ),
        ],
      ),
    );
  }

  Widget _buildRateInformation() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: coffee),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang kurs',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: coffee,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Kurs diambil dari layanan Frankfurter. '
                    'Tanggal yang ditampilkan adalah tanggal data '
                    'kurs yang digunakan, bukan jaminan waktu '
                    'pembaruan secara real-time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Text(
      'Catatan: hasil ini adalah estimasi berdasarkan kurs referensi. '
      'Nilai yang diterapkan bank atau penyedia pembayaran dapat berbeda. '
      'Konversi ini tidak mengubah transaksi atau saldo café.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.black54,
        fontSize: 12,
      ),
    );
  }
}
