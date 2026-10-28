
import 'dart:math';

import 'package:flutter/material.dart';

class MiniGamePage extends StatefulWidget {
  const MiniGamePage({super.key});

  @override
  State<MiniGamePage> createState() => _MiniGamePageState();
}

class _CoffeeLevel {
  final String name;
  final String description;
  final String icon;
  final List<String> steps;
  final List<String> choices;

  const _CoffeeLevel({
    required this.name,
    required this.description,
    required this.icon,
    required this.steps,
    required this.choices,
  });
}

class _MiniGamePageState extends State<MiniGamePage> {
  static const Color coffee = Color(0xFF6F4E37);
  static const Color cream = Color(0xFFFFF8F0);
  static const Color caramel = Color(0xFFD6A574);

  final List<_CoffeeLevel> _levels = const [
    _CoffeeLevel(
      name: 'Espresso',
      description: 'Buat espresso dengan ekstraksi yang tepat.',
      icon: '☕',
      steps: [
        'Siapkan portafilter',
        'Masukkan bubuk kopi',
        'Padatkan bubuk kopi',
        'Ekstrak espresso',
        'Sajikan espresso',
      ],
      choices: [
        'Siapkan portafilter',
        'Masukkan bubuk kopi',
        'Padatkan bubuk kopi',
        'Ekstrak espresso',
        'Sajikan espresso',
        'Tambahkan susu',
        'Tambahkan es batu',
      ],
    ),
    _CoffeeLevel(
      name: 'Americano',
      description: 'Racik americano dengan espresso dan air.',
      icon: '🧊',
      steps: [
        'Siapkan cangkir',
        'Buat espresso',
        'Tambahkan air panas',
        'Aduk perlahan',
        'Sajikan americano',
      ],
      choices: [
        'Siapkan cangkir',
        'Buat espresso',
        'Tambahkan air panas',
        'Aduk perlahan',
        'Sajikan americano',
        'Tambahkan susu',
        'Tambahkan cokelat',
      ],
    ),
    _CoffeeLevel(
      name: 'Café Latte',
      description: 'Gabungkan espresso dan susu steamed.',
      icon: '🥛',
      steps: [
        'Siapkan cangkir',
        'Buat espresso',
        'Steam susu',
        'Tuangkan susu ke espresso',
        'Buat latte art',
      ],
      choices: [
        'Siapkan cangkir',
        'Buat espresso',
        'Steam susu',
        'Tuangkan susu ke espresso',
        'Buat latte art',
        'Tambahkan air panas',
        'Tambahkan sirup cokelat',
      ],
    ),
  ];

  int _levelIndex = 0;
  int _stepIndex = 0;
  int _score = 0;
  int _mistakes = 0;
  bool _finished = false;
  bool _gameOver = false;
  String? _feedback;
  bool? _lastAnswerCorrect;

  _CoffeeLevel get _level => _levels[_levelIndex];

  List<String> get _availableChoices {
    final remaining = _level.choices
        .where((choice) => !_level.steps.take(_stepIndex).contains(choice))
        .toList();

    // Acak pilihan setiap kali level dimulai.
    return remaining;
  }

  void _selectChoice(String choice) {
    if (_finished || _gameOver || _feedback != null) return;

    final expected = _level.steps[_stepIndex];

    setState(() {
      if (choice == expected) {
        _score += 10;
        _stepIndex++;
        _lastAnswerCorrect = true;

        if (_stepIndex == _level.steps.length) {
          _feedback = 'Mantap! Pesanan ${_level.name} selesai.';
          _lastAnswerCorrect = true;
        } else {
          _feedback = 'Benar! Lanjutkan ke langkah berikutnya.';
        }
      } else {
        _score = max(0, _score - 3);
        _mistakes++;
        _lastAnswerCorrect = false;
        _feedback = 'Belum tepat. Coba pikirkan urutan resepnya.';
      }
    });
  }

  void _continueGame() {
    setState(() {
      _feedback = null;
      _lastAnswerCorrect = null;

      if (_stepIndex >= _level.steps.length) {
        if (_levelIndex < _levels.length - 1) {
          _levelIndex++;
          _stepIndex = 0;
        } else {
          _finished = true;
        }
      }
    });
  }

  void _restartGame() {
    setState(() {
      _levelIndex = 0;
      _stepIndex = 0;
      _score = 0;
      _mistakes = 0;
      _finished = false;
      _gameOver = false;
      _feedback = null;
      _lastAnswerCorrect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Coffee Academy'),
        backgroundColor: coffee,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _finished ? _buildResult() : _buildGame(),
      ),
    );
  }

  Widget _buildGame() {
    final progress = _stepIndex / _level.steps.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildScoreCard(),
              const SizedBox(height: 22),
              _buildOrderCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Langkah Peracikan',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: coffee,
                      ),
                    ),
                  ),
                  Text(
                    '${min(_stepIndex + 1, _level.steps.length)}'
                    '/${_level.steps.length}',
                    style: const TextStyle(
                      color: coffee,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE9DDD0),
                  color: caramel,
                ),
              ),
              const SizedBox(height: 16),
              if (_feedback != null) ...[
                _buildFeedback(),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _continueGame,
                  style: FilledButton.styleFrom(
                    backgroundColor: coffee,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _stepIndex >= _level.steps.length
                        ? (_levelIndex == _levels.length - 1
                            ? 'Lihat Hasil'
                            : 'Pesanan Berikutnya')
                        : 'Lanjutkan',
                  ),
                ),
              ] else ...[
                const Text(
                  'Pilih tindakan yang benar untuk menyelesaikan pesanan.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ..._availableChoices.map(
                  (choice) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: () => _selectChoice(choice),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: coffee,
                        side: const BorderSide(color: caramel),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(15),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.coffee_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(choice)),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _restartGame,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Ulangi Permainan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [coffee, Color(0xFF956B4A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('☕', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COFFEE ACADEMY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Level ${_levelIndex + 1}: ${_level.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _level.description,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.stars_rounded,
            label: 'SKOR',
            value: '$_score',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_outlined,
            label: 'KESALAHAN',
            value: '$_mistakes',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.school_outlined,
            label: 'LEVEL',
            value: '${_levelIndex + 1}/3',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9DDD0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: coffee, size: 25),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: coffee,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E4D5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'PESANAN PELANGGAN',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: coffee,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _level.icon,
            style: const TextStyle(fontSize: 54),
          ),
          const SizedBox(height: 8),
          Text(
            _level.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: coffee,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Racik pesanan sesuai urutan yang benar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.brown.shade700),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Riwayat racikan',
              style: TextStyle(
                color: Colors.brown.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_stepIndex == 0)
            const Text(
              'Belum ada langkah. Mulai meracik!',
              style: TextStyle(color: Colors.black54),
            )
          else
            ..._level.steps.take(_stepIndex).toList().asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF56805A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    final correct = _lastAnswerCorrect ?? false;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFFE4F3E5)
            : const Color(0xFFFFE9DF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.lightbulb_outline,
            color: correct ? Colors.green.shade800 : Colors.deepOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedback ?? '',
              style: TextStyle(
                color: correct
                    ? Colors.green.shade900
                    : Colors.brown.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final maxScore = _levels.fold<int>(
      0,
      (sum, level) => sum + level.steps.length * 10,
    );

    final rating = _score >= maxScore * 0.85
        ? 'Coffee Master'
        : _score >= maxScore * 0.6
            ? 'Junior Barista'
            : 'Barista Trainee';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE9DDD0)),
            ),
            child: Column(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 76)),
                const SizedBox(height: 12),
                const Text(
                  'Academy Selesai!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: coffee,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kamu telah menyelesaikan semua tantangan kopi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  '$_score poin',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: coffee,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.workspace_premium),
                  label: Text(rating),
                  backgroundColor: const Color(0xFFF1E4D5),
                ),
                const SizedBox(height: 16),
                Text('Kesalahan: $_mistakes'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _restartGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Main Lagi'),
                    style: FilledButton.styleFrom(
                      backgroundColor: coffee,
                      padding: const EdgeInsets.all(15),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali ke Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
