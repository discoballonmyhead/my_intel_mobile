import 'package:get_it/get_it.dart';

import '../../../features/auth/presentation/providers/auth_cubit.dart';
import '../../../features/messaging/data/datasources/messaging_remote_data_source.dart';
import '../../../features/messaging/data/repositories/messaging_repository_impl.dart';
import '../../../features/messaging/domain/repositories/messaging_repository.dart';
import '../../../features/messaging/domain/usecases/messaging_usecases.dart';
import '../../../features/messaging/presentation/cubits/chat_cubit.dart';
import '../../../features/messaging/presentation/cubits/inbox_cubit.dart';
import '../../../features/messaging/presentation/cubits/new_conversation_cubit.dart';
import '../../../features/profile/domain/usecases/search_profiles.dart';

/// Direct messages and group chats.
void registerMessagingModule(GetIt sl) {
  String? currentUserId() => sl<AuthCubit>().state.user?.id;

  sl
    ..registerLazySingleton<MessagingRemoteDataSource>(
        () => MessagingRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<MessagingRepository>(
        () => MessagingRepositoryImpl(sl(), sl()))

    // Use cases
    ..registerLazySingleton(() => GetInbox(sl()))
    ..registerLazySingleton(() => GetUnreadTotal(sl()))
    ..registerLazySingleton(() => GetConversation(sl()))
    ..registerLazySingleton(() => GetMessages(sl()))
    ..registerLazySingleton(() => OpenDirectConversation(sl()))
    ..registerLazySingleton(() => CreateGroupConversation(sl()))
    ..registerLazySingleton(() => UpdateGroup(sl()))
    ..registerLazySingleton(() => AddGroupMembers(sl()))
    ..registerLazySingleton(() => RemoveGroupMember(sl()))
    ..registerLazySingleton(() => LeaveConversation(sl()))
    ..registerLazySingleton(() => DeleteConversation(sl()))
    ..registerLazySingleton(() => SetConversationMuted(sl()))
    ..registerLazySingleton(() => SendMessage(sl()))
    ..registerLazySingleton(() => EditMessage(sl()))
    ..registerLazySingleton(() => DeleteMessage(sl()))
    ..registerLazySingleton(() => MarkConversationRead(sl()))
    ..registerLazySingleton(() => WatchConversation(sl()))
    ..registerLazySingleton(() => WatchInbox(sl()))
    ..registerLazySingleton(() => SearchProfiles(sl()))

    // Session-wide inbox (drives the tab badge).
    ..registerLazySingleton<InboxCubit>(() => InboxCubit(
          getInbox: sl(),
          getUnreadTotal: sl(),
          watchInbox: sl(),
          deleteConversation: sl(),
          setConversationMuted: sl(),
          openDirectConversation: sl(),
        ))

    // One per open chat: sl<ChatCubit>(param1: conversationId)
    ..registerFactoryParam<ChatCubit, String, void>(
      (conversationId, _) => ChatCubit(
        conversationId: conversationId,
        myUserId: currentUserId(),
        getConversation: sl(),
        getMessages: sl(),
        sendMessage: sl(),
        editMessage: sl(),
        deleteMessage: sl(),
        markRead: sl(),
        watchConversation: sl(),
        leaveConversation: sl(),
        deleteConversation: sl(),
        setMuted: sl(),
        updateGroup: sl(),
        removeMember: sl(),
      ),
    )

    // sl<NewConversationCubit>(param1: const NewConversationArgs()) for a new
    // chat, or with addToConversationId set to add group members.
    ..registerFactoryParam<NewConversationCubit, NewConversationArgs, void>(
      (args, _) => NewConversationCubit(
        myUserId: currentUserId(),
        addToConversationId: args.addToConversationId,
        searchProfiles: sl(),
        openDirect: sl(),
        createGroup: sl(),
        addMembers: sl(),
        getConversation: sl(),
      ),
    );
}
