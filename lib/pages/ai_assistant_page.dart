
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';

class AiAssistantPage extends StatefulWidget {
  final AppUser user;

  const AiAssistantPage({
    super.key,
    required this.user,
  });

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _sending = false;
  String? _lastQuestion;

  static const List<String> _suggestions = [
    'Bagaimana mengelola operasional kafe?',
    'Bagaimana cara mencatat pengeluaran?',
    'Apa yang harus dilakukan jika kas tidak sesuai?',
    'Bagaimana meningkatkan penjualan menu?',
  ];

  @override
  void initState() {
    super.initState();

    _messages.add(
      _ChatMessage(
        text:
            'Halo! Saya Asisten Virtual Café Management ☕\n\n'
            'Saya dapat membantu menjelaskan prosedur operasional, '
            'penggunaan aplikasi, pencatatan keuangan, dan pengelolaan kafe.\n\n'
            'Silakan ajukan pertanyaan. Untuk angka transaksi atau '
            'jadwal aktual, saya hanya dapat menjawab setelah sistem '
            'menyediakan data tersebut.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? retryMessage}) async {
    if (_sending) return;

    final message = (retryMessage ?? _messageController.text).trim();

    if (message.isEmpty) return;

    if (message.length > 1000) {
      _showSnackBar('Pertanyaan maksimal 1000 karakter.');
      return;
    }

    if (retryMessage == null) {
      _messageController.clear();

      setState(() {
        _messages.add(
          _ChatMessage(
            text: message,
            isUser: true,
          ),
        );
      });
    }

    setState(() {
      _sending = true;
      _lastQuestion = message;
    });

    _scrollToBottom();

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/ai_assistant.php',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${widget.user.token}',
            },
            body: jsonEncode({
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 50));

      Map<String, dynamic> result;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Respons API tidak valid.');
        }

        result = decoded;
      } catch (_) {
        throw Exception(
          'Respons server tidak valid. Periksa endpoint PHP.',
        );
      }

      if (response.statusCode == 200 &&
          result['success'] == true) {
        final data = result['data'];

        final answer = data is Map
            ? (data['answer'] ?? '').toString().trim()
            : '';

        if (answer.isEmpty) {
          throw Exception('AI belum memberikan jawaban.');
        }

        if (!mounted) return;

        setState(() {
          _messages.add(
            _ChatMessage(
              text: answer,
              isUser: false,
            ),
          );
        });
      } else {
        final errorMessage =
            (result['message'] ?? 'Permintaan AI gagal.')
                .toString();

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;

      final error = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Maaf, pertanyaan belum berhasil diproses.\n$error',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });

        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearConversation() {
    if (_sending) return;

    setState(() {
      _messages
        ..clear()
        ..add(
          _ChatMessage(
            text:
                'Percakapan baru dimulai. Ada yang bisa saya bantu '
                'tentang operasional Café Management?',
            isUser: false,
          ),
        );

      _lastQuestion = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF176B52),
              child: Icon(
                Icons.support_agent,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asisten Virtual',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Café Management AI',
                    style: TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Percakapan baru',
            onPressed: _sending ? null : _clearConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == _messages.length) {
                  return const _TypingIndicator();
                }

                final message = _messages[index];

                return _MessageBubble(
                  message: message,
                  onRetry: message.isError &&
                          !_sending &&
                          _lastQuestion != null
                      ? () => _sendMessage(
                            retryMessage: _lastQuestion,
                          )
                      : null,
                );
              },
            ),
          ),

          if (_messages.length == 1 && !_sending)
            _buildSuggestions(theme),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pertanyaan...',
                        counterText: '',
                        filled: true,
                        fillColor:
                            theme.colorScheme.surfaceContainerHighest,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: IconButton.filled(
                      onPressed: _sending
                          ? null
                          : () => _sendMessage(),
                      tooltip: 'Kirim pesan',
                      icon: const Icon(Icons.send_rounded),
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

  Widget _buildSuggestions(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coba tanyakan:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return ActionChip(
                avatar: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                ),
                label: Text(suggestion),
                onPressed: _sending
                    ? null
                    : () {
                        _sendMessage(
                          retryMessage: suggestion,
                        );
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : message.isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest;

    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : message.isError
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError
                  ? theme.colorScheme.errorContainer
                  : const Color(0xFF176B52),
              child: Icon(
                message.isError
                    ? Icons.error_outline
                    : Icons.smart_toy_outlined,
                size: 18,
                color: message.isError
                    ? theme.colorScheme.onErrorContainer
                    : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      height: 1.45,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Coba lagi'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF176B52),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('AI sedang menjawab...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
