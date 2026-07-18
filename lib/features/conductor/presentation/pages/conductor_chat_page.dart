import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class ConductorChatPage extends ConsumerStatefulWidget {
  const ConductorChatPage({super.key});
  @override
  ConsumerState<ConductorChatPage> createState() => _ConductorChatPageState();
}

class _ConductorChatPageState extends ConsumerState<ConductorChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() { super.initState(); }
  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final coopName = user?.fullName ?? 'Cooperativa';
    final asyncMessages = ref.watch(messagesProvider('cooperativa'));
    final messages = asyncMessages.valueOrNull ?? [];
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(children: [
          Stack(children: [
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFF001B44),
                child: Text(coopName.isNotEmpty ? coopName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            const Positioned(right: 0, bottom: 0,
                child: CircleAvatar(radius: 5, backgroundColor: Colors.white,
                    child: CircleAvatar(radius: 4, backgroundColor: Colors.green))),
          ]),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(coopName, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontSize: 14)),
            const Text('En línea', style: TextStyle(fontSize: 10, color: Colors.green, fontFamily: 'Inter')),
          ]),
        ]),
        backgroundColor: const Color(0xFFF8F9FA), elevation: 0,
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final m = messages[i];
            final isMe = m.senderId == currentUserId;
            if (!isMe && messages[i - 1].senderId == currentUserId) _scrollToBottom();
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF001B44) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF001B44).withAlpha(isMe ? 0 : 12), blurRadius: 4)],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(m.content, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : const Color(0xFF001B44), fontFamily: 'Inter')),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_fmt(m.createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : const Color(0xFF434750))),
                      if (isMe) ...[const SizedBox(width: 4),
                        Icon(m.isRead ? Icons.done_all : Icons.done, size: 14, color: m.isRead ? Colors.lightBlue : Colors.white60)],
                    ]),
                  ],
                ),
              ),
            );
          },
        )),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, -1))]),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _msgCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (_msgCtrl.text.trim().isNotEmpty) {
                  ref.read(sendMessageAction('cooperativa'))(_msgCtrl.text.trim());
                  _msgCtrl.clear();
                }
              },
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: TextStyle(fontFamily: 'Inter', color: Color(0xFFBDBDBD)),
                filled: true, fillColor: Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )),
            const SizedBox(width: 6),
            CircleAvatar(backgroundColor: const Color(0xFF001B44),
              child: IconButton(
                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                onPressed: () {
                  if (_msgCtrl.text.trim().isNotEmpty) {
                    ref.read(sendMessageAction('cooperativa'))(_msgCtrl.text.trim());
                    _msgCtrl.clear();
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
