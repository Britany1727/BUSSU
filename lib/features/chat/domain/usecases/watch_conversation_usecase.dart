import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class WatchConversationUseCase {
  final ChatRepository _repo;
  WatchConversationUseCase(this._repo);
  Stream<Either<Failure, List<ChatMessage>>> execute(String roomId) {
    return _repo.watchMessages(roomId);
  }
}
