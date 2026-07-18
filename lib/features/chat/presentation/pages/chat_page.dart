import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String roomId;
  final String? title;
  const ChatPage({super.key, required this.roomId, this.title});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    ref.read(sendMessageAction(widget.roomId))(t);
    _ctrl.clear();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(messagesProvider(widget.roomId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Chat'),
        backgroundColor: const Color(0xFF001B44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: msgs.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar chat')),
        data: (messages) {
          if (messages.isNotEmpty) _scrollToBottom();
          return Column(children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text('Envia un mensaje para empezar',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final me = m.senderId == currentUserId;
                        return _buildBubble(m, me);
                      },
                    ),
            ),
            _buildInputBar(),
          ]);
        },
      ),
    );
  }

  Widget _buildBubble(ChatMessage m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF001B44) : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.content,
                style: TextStyle(
                    fontSize: 15,
                    color: isMe ? Colors.white : Colors.black87,
                    fontFamily: 'Inter')),
            const SizedBox(height: 4),
            Text(
              '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                  fontFamily: 'Inter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 4)],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              hintText: 'Escribe un mensaje...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Color(0xFFF8F9FA),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF001B44),
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send, size: 18, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ]),
    );
  }
}
