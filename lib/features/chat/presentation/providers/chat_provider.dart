import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/datasources/chat_remote_datasource.dart';

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(Supabase.instance.client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remote = ref.watch(chatRemoteDataSourceProvider);
  return ChatRepositoryImpl(remote: remote);
});

final currentUserIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

final conversationsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final result = await repo.listConversations();
  return result.fold((_) => [], (list) => list);
});

final conversationsStreamProvider = StreamProvider<List<ChatConversation>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchConversations().map((either) => either.fold(
    (_) => <ChatConversation>[],
    (list) => list,
  ));
});

final unreadCountProvider = Provider<int>((ref) {
  final convs = ref.watch(conversationsStreamProvider).valueOrNull ?? [];
  return convs.fold(0, (sum, c) => sum + c.unreadCount);
});

Stream<List<ChatMessage>> _messageStream(ChatRepository repo, String roomId) async* {
  final initial = await repo.getMessages(roomId);
  final allMessages = initial.fold((_) => <ChatMessage>[], (msgs) => List<ChatMessage>.from(msgs));
  yield allMessages;

  await for (final either in repo.watchMessages(roomId)) {
    either.fold((_) {}, (msgs) {
      allMessages
        ..clear()
        ..addAll(msgs);
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    yield List<ChatMessage>.from(allMessages);
  }
}

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  final repo = ref.watch(chatRepositoryProvider);
  return _messageStream(repo, roomId);
});

final sendMessageAction = Provider.family<void Function(String), String>((ref, roomId) {
  return (String content) {
    ref.read(chatRepositoryProvider).sendMessage(roomId: roomId, content: content);
  };
});

final markAsReadAction = Provider<void Function(String)>((ref) {
  return (String msgId) {
    ref.read(chatRepositoryProvider).markAsRead(msgId);
  };
});
