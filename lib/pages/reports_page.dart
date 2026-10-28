import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../config/api_config.dart';

class ReportsPage extends StatefulWidget {
  final AppUser user;

  const ReportsPage({
    super.key,
    required this.user,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  bool _processing = false;

  Map<String, dynamic>? _session;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _report;

  List<dynamic> _reports = [];

  String _selectedBranch = 'A';
  String _selectedStatus = 'submitted';

  final TextEditingController _cashController =
      TextEditingController();

  final TextEditingController _qrisController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  bool get _isManager =>
      widget.user.roleName.toLowerCase() == 'manager';

  String get _baseUrl =>
      '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/reports.php';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _qrisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${widget.user.token}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>> _requestGet(
    Map<String, String> query,
  ) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: query,
    );

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respons server tidak valid.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Gagal mengambil data.',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _requestPost(
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respons server tidak valid.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Permintaan gagal.',
      );
    }

    return decoded;
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      if (_isManager) {
        await _loadManagerReports();
      } else {
        await _loadEmployeeStatus();
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadEmployeeStatus() async {
    final response = await _requestGet({
      'action': 'status',
    });

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('Format status shift tidak valid.');
    }

    if (!mounted) return;

    setState(() {
      _session = data['session'] is Map<String, dynamic>
          ? data['session'] as Map<String, dynamic>
          : null;

      _summary = data['summary'] is Map<String, dynamic>
          ? data['summary'] as Map<String, dynamic>
          : null;

      _report = data['report'] is Map<String, dynamic>
          ? data['report'] as Map<String, dynamic>
          : null;

      if (_report != null) {
        _cashController.text =
            _moneyInput(_report!['cash_actual']);

        _qrisController.text =
            _moneyInput(_report!['qris_actual']);

        _notesController.text =
            (_report!['notes'] ?? '').toString();
      } else if (_session?['session_status'] == 'closed') {
        _cashController.clear();
        _qrisController.clear();
        _notesController.clear();
      }
    });
  }

  Future<void> _loadManagerReports() async {
    final response = await _requestGet({
      'action': 'reports',
      'status': _selectedStatus,
    });

    final data = response['data'];

    if (!mounted) return;

    setState(() {
      _reports = data is List ? data : [];
    });
  }

  Future<void> _startShift() async {
    setState(() => _processing = true);

    try {
      final response = await _requestPost({
        'action': 'start_shift',
        'branch': _selectedBranch,
      });

      if (!mounted) return;

      _showMessage(
        response['message'] ?? 'Shift berhasil dimulai.',
      );

      await _loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _endShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutup Shift?'),
        content: const Text(
          'Pastikan semua transaksi telah dicatat. '
          'Setelah shift ditutup, kamu dapat memasukkan '
          'uang aktual dan mengirim laporan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup Shift'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await _requestPost({
        'action': 'end_shift',
      });

      if (!mounted) return;

      _showMessage(
        response['message'] ?? 'Shift berhasil ditutup.',
      );

      await _loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  double? _parseMoney(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) return null;

    final number = double.tryParse(normalized);

    if (number == null ||
        !number.isFinite ||
        number < 0 ||
        number > 9999999999.99) {
      return null;
    }

    return number;
  }

  String _moneyInput(dynamic value) {
    if (value == null) return '';

    final number = double.tryParse(value.toString()) ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  Future<void> _submitReport() async {
    final cash = _parseMoney(_cashController.text);
    final qris = _parseMoney(_qrisController.text);

    if (cash == null || qris == null) {
      _showMessage(
        'Masukkan nominal Cash dan QRIS yang valid. '
        'Gunakan angka tanpa pemisah ribuan.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Laporan?'),
        content: const Text(
          'Pastikan nominal aktual sesuai dengan '
          'uang fisik dan laporan pembayaran QRIS. '
          'Laporan akan dikirim kepada Manager.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Periksa Lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await _requestPost({
        'action': 'submit_report',
        'cash_actual': cash,
        'qris_actual': qris,
        'notes': _notesController.text.trim(),
      });

      if (!mounted) return;

      _showMessage(
        response['message'] ?? 'Laporan berhasil dikirim.',
      );

      await _loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _reviewReport(
    Map<String, dynamic> report,
    String decision,
  ) async {
    final notesController = TextEditingController();

    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          decision == 'approve'
              ? 'Setujui Laporan'
              : 'Minta Revisi',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambahkan catatan pemeriksaan. '
              'Jika meminta revisi, alasan wajib diisi.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Manager',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (decision == 'revision' &&
                  notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan revisi wajib diisi.'),
                  ),
                );
                return;
              }

              Navigator.pop(
                context,
                notesController.text.trim(),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    notesController.dispose();

    if (notes == null || !mounted) return;

    setState(() => _processing = true);

    try {
      final response = await _requestPost({
        'action': 'review_report',
        'report_id': report['report_id'],
        'decision': decision,
        'review_notes': notes,
      });

      if (!mounted) return;

      _showMessage(
        response['message'] ?? 'Pemeriksaan selesai.',
      );

      await _loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  String _currency(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    final rounded = number.round().toString();
    final formatted = rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _dateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }

    return value.toString().replaceAll('T', ' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'match':
        return Colors.green;
      case 'revision':
      case 'short':
        return Colors.red;
      case 'over':
        return Colors.orange.shade800;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Menunggu Persetujuan';
      case 'revision':
        return 'Perlu Revisi';
      case 'approved':
        return 'Disetujui';
      case 'match':
        return 'Sesuai';
      case 'short':
        return 'Kurang';
      case 'over':
        return 'Lebih';
      default:
        return status;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF795548).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF795548),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    dynamic value,
    IconData icon, {
    Color color = const Color(0xFF795548),
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currency(value ?? 0),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeePage() {
    final session = _session;
    final summary = _summary;
    final report = _report;

    final active = session?['session_status'] == 'active';
    final closed = session?['session_status'] == 'closed';

    final reportStatus = report?['status']?.toString() ?? '';
    final canSubmit = closed &&
        (report == null || reportStatus == 'revision');

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle(
            'Rekonsiliasi Shift',
            'Catat uang aktual dan cocokkan dengan transaksi sistem.',
            Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 20),

          if (session == null) ...[
            _buildStartShiftCard(),
          ] else ...[
            _buildSessionCard(session, active),
            const SizedBox(height: 16),

            if (summary != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 520;

                  return GridView.count(
                    crossAxisCount: twoColumns ? 2 : 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: twoColumns ? 2.0 : 2.8,
                    children: [
                      _summaryCard(
                        'Penjualan Cash',
                        summary['cash_recorded'],
                        Icons.payments_outlined,
                      ),
                      _summaryCard(
                        'Penjualan QRIS',
                        summary['qris_recorded'],
                        Icons.qr_code_2,
                        color: Colors.blue,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _summaryCard(
                'Total Transaksi',
                summary['total_recorded'],
                Icons.point_of_sale,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: Colors.brown.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF795548),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Jumlah transaksi'),
                      ),
                      Text(
                        '${summary['transaction_count'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (active) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _processing ? null : _endShift,
                icon: const Icon(Icons.lock_clock),
                label: const Text('Tutup Shift'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Setelah shift ditutup, transaksi baru tidak '
                'seharusnya dicatat ke shift ini.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],

            if (closed && reportStatus.isEmpty) ...[
              const SizedBox(height: 20),
              _buildActualForm(summary),
            ],

            if (closed && reportStatus == 'revision') ...[
              const SizedBox(height: 20),
              _buildRevisionNotice(report!),
              const SizedBox(height: 12),
              _buildActualForm(summary),
            ],

            if (report != null && reportStatus != 'revision') ...[
              const SizedBox(height: 20),
              _buildSubmittedReport(report, summary),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStartShiftCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.storefront,
              size: 38,
              color: Color(0xFF795548),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mulai Shift',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih cabang tempat kamu bekerja. '
              'Sistem akan memeriksa jadwal shift dan waktu mulai.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              decoration: const InputDecoration(
                labelText: 'Cabang',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'A',
                  child: Text('Cabang A'),
                ),
                DropdownMenuItem(
                  value: 'B',
                  child: Text('Cabang B'),
                ),
              ],
              onChanged: _processing
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedBranch = value);
                      }
                    },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _processing ? null : _startShift,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mulai Shift'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF795548),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
    bool active,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFF795548).withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.store,
                  color: Color(0xFF795548),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cabang ${session['branch'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(
                  active ? 'active' : 'closed',
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(
              'Karyawan',
              session['employee_name']?.toString() ?? '-',
            ),
            _infoRow(
              'Tanggal jadwal',
              session['shift_date']?.toString() ?? '-',
            ),
            _infoRow(
              'Jadwal',
              '${session['start_time'] ?? '-'} - '
                  '${session['end_time'] ?? '-'}',
            ),
            _infoRow(
              'Mulai aktual',
              _dateTime(session['started_at']),
            ),
            _infoRow(
              'Selesai aktual',
              _dateTime(session['ended_at']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualForm(Map<String, dynamic>? summary) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporan Uang Aktual',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masukkan jumlah yang benar-benar diterima. '
              'Untuk nominal rupiah, gunakan angka tanpa '
              'titik pemisah ribuan.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cash Aktual (Rp)',
                hintText: 'Contoh: 1500000',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
                helperText:
                    'Tercatat: ${_currency(summary?['cash_recorded'] ?? 0)}',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qrisController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'QRIS Aktual (Rp)',
                hintText: 'Contoh: 800000',
                prefixIcon: const Icon(Icons.qr_code_2),
                border: const OutlineInputBorder(),
                helperText:
                    'Tercatat: ${_currency(summary?['qris_recorded'] ?? 0)}',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Tuliskan penjelasan jika ada selisih.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _processing ? null : _submitReport,
                icon: const Icon(Icons.send),
                label: const Text('Kirim Laporan'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF795548),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionNotice(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusChip('revision'),
          const SizedBox(height: 10),
          const Text(
            'Manager meminta laporan diperbaiki.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            report['review_notes']?.toString().isNotEmpty == true
                ? report['review_notes'].toString()
                : 'Tidak ada catatan tambahan.',
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedReport(
    Map<String, dynamic> report,
    Map<String, dynamic>? summary,
  ) {
    final status = report['status']?.toString() ?? 'submitted';

    final cashDifference =
        double.tryParse(report['cash_difference']?.toString() ?? '') ??
            ((double.tryParse(
                        report['cash_actual']?.toString() ?? '') ??
                    0) -
                (double.tryParse(
                        summary?['cash_recorded']?.toString() ?? '') ??
                    0));

    final qrisDifference =
        double.tryParse(report['qris_difference']?.toString() ?? '') ??
            ((double.tryParse(
                        report['qris_actual']?.toString() ?? '') ??
                    0) -
                (double.tryParse(
                        summary?['qris_recorded']?.toString() ?? '') ??
                    0));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _statusChip(status),
            const Divider(height: 24),
            _infoRow(
              'Cash aktual',
              _currency(report['cash_actual']),
            ),
            _infoRow(
              'Selisih Cash',
              _currency(cashDifference.abs()),
              valueColor:
                  cashDifference == 0 ? Colors.green : Colors.red,
            ),
            _infoRow(
              'QRIS aktual',
              _currency(report['qris_actual']),
            ),
            _infoRow(
              'Selisih QRIS',
              _currency(qrisDifference.abs()),
              valueColor:
                  qrisDifference == 0 ? Colors.green : Colors.red,
            ),
            if (report['notes'] != null &&
                report['notes'].toString().isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Catatan karyawan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(report['notes'].toString()),
            ],
            if (report['review_notes'] != null &&
                report['review_notes'].toString().isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Catatan Manager',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(report['review_notes'].toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManagerPage() {
    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle(
            'Pemeriksaan Laporan',
            'Periksa penjualan tercatat dan nominal aktual per shift.',
            Icons.fact_check_outlined,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Filter Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'submitted',
                child: Text('Menunggu Persetujuan'),
              ),
              DropdownMenuItem(
                value: 'revision',
                child: Text('Revisi'),
              ),
              DropdownMenuItem(
                value: 'approved',
                child: Text('Disetujui'),
              ),
            ],
            onChanged: _processing
                ? null
                : (value) async {
                    if (value == null) return;

                    setState(() {
                      _selectedStatus = value;
                      _loading = true;
                    });

                    await _loadData(showLoading: false);
                  },
          ),
          const SizedBox(height: 16),
          if (_reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('Tidak ada laporan pada status ini.'),
                ],
              ),
            )
          else
            ..._reports.map((item) {
              final report =
                  Map<String, dynamic>.from(item as Map);

              return _buildManagerReportCard(report);
            }),
        ],
      ),
    );
  }

  Widget _buildManagerReportCard(
    Map<String, dynamic> report,
  ) {
    final status = report['status']?.toString() ?? 'submitted';

    final cashDifference =
        double.tryParse(report['cash_difference']?.toString() ?? '') ??
            0;

    final qrisDifference =
        double.tryParse(report['qris_difference']?.toString() ?? '') ??
            0;

    final canReview = status == 'submitted';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${report['employee_name'] ?? 'Karyawan'} '
                    '• Cabang ${report['branch'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kode karyawan: ${report['employee_code'] ?? '-'}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            _infoRow(
              'Tanggal shift',
              report['shift_date']?.toString() ?? '-',
            ),
            _infoRow(
              'Mulai shift',
              _dateTime(report['started_at']),
            ),
            _infoRow(
              'Tutup shift',
              _dateTime(report['ended_at']),
            ),
            _infoRow(
              'Jumlah transaksi',
              '${report['transaction_count'] ?? 0}',
            ),
            const Divider(height: 24),
            const Text(
              'Cash',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _infoRow(
              'Tercatat',
              _currency(report['cash_recorded']),
            ),
            _infoRow(
              'Aktual',
              _currency(report['cash_actual']),
            ),
            _infoRow(
              'Selisih',
              '${cashDifference > 0 ? '+' : cashDifference < 0 ? '-' : ''}'
              '${_currency(cashDifference.abs())}',
              valueColor: cashDifference == 0
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(height: 8),
            const Text(
              'QRIS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _infoRow(
              'Tercatat',
              _currency(report['qris_recorded']),
            ),
            _infoRow(
              'Aktual',
              _currency(report['qris_actual']),
            ),
            _infoRow(
              'Selisih',
              '${qrisDifference > 0 ? '+' : qrisDifference < 0 ? '-' : ''}'
              '${_currency(qrisDifference.abs())}',
              valueColor: qrisDifference == 0
                  ? Colors.green
                  : Colors.red,
            ),
            const Divider(height: 24),
            _infoRow(
              'Total tercatat',
              _currency(report['total_recorded']),
            ),
            _infoRow(
              'Total aktual',
              _currency(report['total_actual']),
            ),
            _infoRow(
              'Selisih total',
              '${(double.tryParse(report['total_difference']?.toString() ?? '') ?? 0) > 0 ? '+' : ''}'
              '${_currency(report['total_difference'] ?? 0)}',
              valueColor:
                  (double.tryParse(
                              report['total_difference']?.toString() ??
                                  '') ??
                          0) ==
                      0
                  ? Colors.green
                  : Colors.red,
            ),
            if (report['notes'] != null &&
                report['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Catatan karyawan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(report['notes'].toString()),
            ],
            if (report['review_notes'] != null &&
                report['review_notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Catatan pemeriksaan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(report['review_notes'].toString()),
            ],
            if (canReview) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _reviewReport(report, 'approve'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Setujui'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _reviewReport(report, 'revision'),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Minta Revisi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: Text(
          _isManager
              ? 'Pemeriksaan Laporan'
              : 'Rekonsiliasi Shift',
        ),
        backgroundColor: const Color(0xFF795548),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading || _processing
                ? null
                : () => _loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _isManager
              ? _buildManagerPage()
              : _buildEmployeePage(),
    );
  }
}