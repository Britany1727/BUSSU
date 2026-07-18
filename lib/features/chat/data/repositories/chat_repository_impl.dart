import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource? _remote;

  ChatRepositoryImpl({ChatRemoteDataSource? remote}) : _remote = remote;

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(String roomId) async {
    if (_remote != null) {
      try {
        final msgs = await _remote.fetchMessages(roomId);
        return Right(msgs);
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
    return const Right([]);
  }

  @override
  Stream<Either<Failure, List<ChatMessage>>> watchMessages(String roomId) {
    if (_remote != null) {
      return _remote
          .watchMessages(roomId)
          .map((msgs) => Right<Failure, List<ChatMessage>>(msgs));
    }
    return const Stream.empty();
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String roomId,
    required String content,
  }) async {
    if (_remote != null) {
      try {
        await _remote.insertMessage(roomId: roomId, content: content);
        return const Right(null);
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ChatConversation>>> listConversations() async {
    if (_remote != null) {
      try {
        final convs = await _remote.fetchConversations();
        return Right(convs);
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
    return const Right([]);
  }

  @override
  Stream<Either<Failure, List<ChatConversation>>> watchConversations() {
    if (_remote != null) {
      return _remote
          .watchConversations()
          .map((c) => Right<Failure, List<ChatConversation>>(c));
    }
    return const Stream.empty();
  }

  @override
  Future<Either<Failure, void>> markAsRead(String messageId) async {
    if (_remote != null) {
      try {
        await _remote.markMessageAsRead(messageId);
        return const Right(null);
      } catch (e) {
        return Left(ServerFailure(e.toString()));
      }
    }
    return const Right(null);
  }

  Future<String> ensureConversation({
    required String otherUserId,
    String? cooperativaId,
  }) async {
    if (_remote != null) {
      return _remote.ensureConversation(
        otherUserId: otherUserId,
        cooperativaId: cooperativaId,
      );
    }
    return 'default';
  }
}
