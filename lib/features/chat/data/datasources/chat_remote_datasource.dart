import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_conversation.dart';

class ChatRemoteDataSource {
  final SupabaseClient supabaseClient;

  ChatRemoteDataSource(this.supabaseClient);

  String get _currentUserId => supabaseClient.auth.currentUser?.id ?? '';

  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final response = await supabaseClient
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    return (response as List<dynamic>)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return supabaseClient
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows
            .map((r) => ChatMessage.fromJson(r as Map<String, dynamic>))
            .toList());
  }

  Future<void> insertMessage({
    required String roomId,
    required String content,
  }) async {
    await supabaseClient.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': _currentUserId,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    });
  }

  Future<void> markMessageAsRead(String messageId) async {
    await supabaseClient
        .from('chat_messages')
        .update({'is_read': true}).eq('id', messageId);
  }

  Future<void> markRoomAsRead(String roomId) async {
    final userId = _currentUserId;
    await supabaseClient.from('chat_messages').update({'is_read': true}).eq(
        'room_id', roomId);
  }

  Future<List<ChatConversation>> fetchConversations() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return [];
    final response = await supabaseClient
        .from('chat_conversations')
        .select()
        .or('driver_id.eq.$userId,cooperativa_id.eq.$userId')
        .order('last_message_at', ascending: false);
    return (response as List<dynamic>)
        .map((c) => ChatConversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ChatConversation>> watchConversations() {
    final userId = _currentUserId;
    if (userId.isEmpty) return const Stream.empty();
    return supabaseClient
        .from('chat_conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) => rows
            .map((r) => ChatConversation.fromJson(r as Map<String, dynamic>))
            .where((c) => c.driverId == userId || c.cooperativaId == userId)
            .toList());
  }

  Future<void> upsertConversation({
    required String id,
    required String driverId,
    String? cooperativaId,
  }) async {
    await supabaseClient.from('chat_conversations').upsert({
      'id': id,
      'driver_id': driverId,
      'cooperativa_id': cooperativaId,
      'status': 'open',
    });
  }

  Future<String> ensureConversation({
    required String otherUserId,
    String? cooperativaId,
  }) async {
    final userId = _currentUserId;
    final existing = await supabaseClient
        .from('chat_conversations')
        .select('id')
        .or('and(driver_id.eq.$userId,cooperativa_id.eq.$otherUserId),and(driver_id.eq.$otherUserId,cooperativa_id.eq.$userId)')
        .limit(1);
    if ((existing as List).isNotEmpty) {
      return existing.first['id'] as String;
    }
    final newId = '${userId}_$otherUserId';
    await upsertConversation(
      id: newId,
      driverId: userId,
      cooperativaId: cooperativaId,
    );
    return newId;
  }
}
