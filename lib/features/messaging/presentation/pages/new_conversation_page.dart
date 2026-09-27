import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../cubits/new_conversation_cubit.dart';

/// Pick people for a new DM / group, or (in add mode) for an existing group.
class NewConversationPage extends StatelessWidget {
  const NewConversationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewConversationCubit, NewConversationState>(
      listenWhen: (a, b) =>
          a.resultConversationId != b.resultConversationId ||
          (b.failure != null && a.failure != b.failure),
      listener: (context, state) {
        final id = state.resultConversationId;
        if (id != null) {
          if (state.isAddMode) {
            context.pop();
          } else {
            context.pushReplacement(AppRoutes.chatFor(id));
          }
          return;
        }
        if (state.failure != null) {
          AppDialogs.snack(context, state.failure!.message);
        }
      },
      builder: (context, state) {
        final cubit = context.read<NewConversationCubit>();
        final palette = context.palette;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.isAddMode ? 'ADD MEMBERS' : 'NEW MESSAGE'),
            actions: [
              TextButton(
                onPressed: state.canSubmit ? cubit.submit : null,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.isAddMode
                        ? 'ADD'
                        : state.isGroup
                            ? 'CREATE'
                            : 'CHAT'),
              ),
            ],
          ),
          body: ContentColumn(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                TextField(
                  autofocus: true,
                  onChanged: cubit.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search people by username',
                  ),
                ),
                if (state.selected.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: state.selected
                          .map((p) => Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: InputChip(
                                  label: Text(p.username),
                                  onDeleted: () => cubit.toggle(p),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
                if (!state.isAddMode && state.selected.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    onChanged: cubit.setGroupTitle,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.groups_2_outlined),
                      hintText: 'Group name (optional)',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: state.isSearching
                      ? const AppLoader()
                      : ListView.builder(
                          itemCount: state.results.length,
                          itemBuilder: (context, index) {
                            final profile = state.results[index];
                            final selected = state.isSelected(profile);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: UserAvatar(name: profile.username),
                              title: Text(profile.username),
                              subtitle: Align(
                                alignment: Alignment.centerLeft,
                                child: RoleBadge(role: profile.role),
                              ),
                              trailing: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected ? palette.accent : palette.muted,
                              ),
                              onTap: () => cubit.toggle(profile),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
