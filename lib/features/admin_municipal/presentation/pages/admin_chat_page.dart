import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/domain/entities/chat_conversation.dart';
import '../providers/system_alerts_provider.dart';

class AdminChatPage extends ConsumerStatefulWidget {
  const AdminChatPage({super.key});
  @override
  ConsumerState<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends ConsumerState<AdminChatPage> {
  String? _activeChatId;
  String? _activeChatName;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() { super.initState(); }
  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_activeChatId != null) return _buildChatView();
    return _buildCooperativasList();
  }

  Widget _buildCooperativasList() {
    final cooperativas = ref.watch(cooperativasStatusProvider);
    final conversations = ref.watch(conversationsStreamProvider).valueOrNull ?? [];
    final totalUnread = conversations.fold(0, (sum, c) => sum + c.unreadCount);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Row(children: [
        const Icon(Icons.chat_outlined, color: Color(0xFF001B44), size: 22), const SizedBox(width: 8),
        const Text('Chat Municipal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF001B44), fontFamily: 'Inter')),
        const Spacer(),
        IconButton(onPressed: () {}, icon: Badge(isLabelVisible: totalUnread > 0, label: Text('$totalUnread', style: const TextStyle(fontSize: 10, color: Colors.white)), child: const Icon(Icons.notifications_outlined, color: Color(0xFF001B44)))),
      ])),
      const SizedBox(height: 4),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Icon(Icons.circle, size: 8, color: Colors.green), SizedBox(width: 4), Text('Supabase Realtime', style: TextStyle(fontSize: 12, color: Color(0xFF434750), fontFamily: 'Inter'))])),
      const SizedBox(height: 12),
      Expanded(child: cooperativas.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF001B44))),
        error: (_, __) => const Center(child: Text('Error al cargar')),
        data: (coops) {
          final convMap = <String, ChatConversation>{};
          for (final conv in conversations) { final cid = conv.cooperativaId; if (cid != null) convMap[cid] = conv; }
          return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: coops.map((c) {
            final conv = convMap[c.id];
            final lastMsg = conv?.lastMessage ?? '';
            final lastTime = conv?.lastMessageAt;
            final unreadCount = conv?.unreadCount ?? 0;
            final hasUnread = unreadCount > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x14002F6C), blurRadius: 4)]),
              child: ListTile(
                leading: Stack(children: [
                  CircleAvatar(radius: 24, backgroundColor: const Color(0xFF001B44), child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                  Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: (c.activeBuses > 0) ? Colors.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                ]),
                title: Text(c.name, style: TextStyle(fontSize: 15, fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600, color: const Color(0xFF001B44), fontFamily: 'Inter')),
                subtitle: Row(children: [
                  Expanded(child: Text(lastMsg.isNotEmpty ? lastMsg : 'Sin conversación', style: TextStyle(fontSize: 12, color: hasUnread ? const Color(0xFF001B44) : const Color(0xFF434750), fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (lastTime != null) ...[
                    const SizedBox(width: 4),
                    Text(_fmtTime(lastTime), style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD), fontFamily: 'Inter')),
                  ],
                ]),
                trailing: hasUnread ? Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle), child: Center(child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))) : null,
                onTap: () => setState(() { _activeChatId = c.id; _activeChatName = c.name; }),
              ),
            );
          }).toList());
        },
      )),
    ]);
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }

  Widget _buildChatView() {
    final messages = ref.watch(messagesProvider(_activeChatId!)).valueOrNull ?? [];
    final roomId = _activeChatId!;
    final currentUserId = ref.watch(currentUserIdProvider);

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 2, offset: const Offset(0, 1))]),
        child: SafeArea(bottom: false, child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF001B44)), onPressed: () => setState(() { _activeChatId = null; _activeChatName = null; })),
          Stack(children: [CircleAvatar(radius: 16, backgroundColor: const Color(0xFF001B44), child: Text((_activeChatName ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'))), const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 5, backgroundColor: Colors.white, child: CircleAvatar(radius: 4, backgroundColor: Colors.green)))]),
          const SizedBox(width: 8),
          Text(_activeChatName ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF001B44), fontFamily: 'Inter')),
        ])),
      ),
      Expanded(child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final m = messages[i];
          final isMe = m.senderId == currentUserId;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF001B44) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(m.content, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : const Color(0xFF001B44), fontFamily: 'Inter')),
                  const SizedBox(height: 4),
                  Text('${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : const Color(0xFF434750))),
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
                ref.read(sendMessageAction(roomId))(_msgCtrl.text.trim());
                _msgCtrl.clear();
              }
            },
            decoration: const InputDecoration(
              hintText: 'Escribe un mensaje...',
              hintStyle: TextStyle(fontFamily: 'Inter'),
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
                  ref.read(sendMessageAction(roomId))(_msgCtrl.text.trim());
                  _msgCtrl.clear();
                }
              },
            ),
          ),
        ]),
      ),
    ]);
  }
}
