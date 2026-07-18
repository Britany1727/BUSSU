import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<Either<Failure, List<ChatMessage>>> getMessages(String roomId);
  Stream<Either<Failure, List<ChatMessage>>> watchMessages(String roomId);
  Future<Either<Failure, void>> sendMessage({required String roomId, required String content});
  Future<Either<Failure, List<ChatConversation>>> listConversations();
  Stream<Either<Failure, List<ChatConversation>>> watchConversations();
  Future<Either<Failure, void>> markAsRead(String messageId);
}
