
import 'package:flutter/material.dart';

class TimeConverterPage extends StatefulWidget {
  const TimeConverterPage({super.key});

  @override
  State<TimeConverterPage> createState() =>
      _TimeConverterPageState();
}

class _TimeConverterPageState extends State<TimeConverterPage> {
  static const Color primaryBrown = Color(0xFF6D4C41);
  static const Color backgroundColor = Color(0xFFFFF8F0);

  final Map<String, int> _utcOffsets = {
    'WIB': 7,
    'WITA': 8,
    'WIT': 9,
  };

  String _sourceZone = 'WIB';

  DateTime _selectedDateTime = DateTime.now();

  String _formatDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // Mengubah waktu berdasarkan selisih UTC offset.
  DateTime _convertTime(String targetZone) {
    final sourceOffset = _utcOffsets[_sourceZone]!;
    final targetOffset = _utcOffsets[targetZone]!;

    final difference = targetOffset - sourceOffset;

    return _selectedDateTime.add(
      Duration(hours: difference),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (date == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDateTime,
      ),
      helpText: 'Pilih waktu',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _buildResultCard({
    required String zone,
    required DateTime dateTime,
    required bool isSource,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSource
              ? primaryBrown
              : const Color(0xFFE0D7D2),
          width: isSource ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryBrown.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule,
              color: primaryBrown,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      zone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: primaryBrown,
                      ),
                    ),
                    if (isSource) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'ASAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(dateTime),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(dateTime),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'UTC${_utcOffsets[zone]! >= 0 ? '+' : ''}'
                  '${_utcOffsets[zone]}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetZones = _utcOffsets.keys
        .where((zone) => zone != _sourceZone)
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Konversi Waktu Indonesia',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBrown,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.public,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Konversi Zona Waktu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Konversikan waktu antara WIB, WITA, '
                    'dan WIT dengan mudah.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Zona Waktu Asal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _sourceZone,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(
                  Icons.language,
                  color: primaryBrown,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _utcOffsets.keys.map((zone) {
                return DropdownMenuItem<String>(
                  value: zone,
                  child: Text(
                    '$zone (UTC+${_utcOffsets[zone]})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _sourceZone = value;
                });
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'Tanggal dan Waktu Asal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _formatDate(_selectedDateTime),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBrown,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_formatTime(_selectedDateTime)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBrown,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 10,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Text(
              'Hasil Konversi',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            _buildResultCard(
              zone: _sourceZone,
              dateTime: _selectedDateTime,
              isSource: true,
            ),

            for (final zone in targetZones)
              _buildResultCard(
                zone: zone,
                dateTime: _convertTime(zone),
                isSource: false,
              ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE7E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: primaryBrown,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'WIB adalah UTC+7, WITA UTC+8, '
                      'dan WIT UTC+9. Tanggal akan '
                      'menyesuaikan jika konversi melewati '
                      'tengah malam.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
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
}
