import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint/features/feed/domain/entities/post_extras.dart';
import 'package:mint/features/feed/presentation/widgets/post_poll_view.dart';

PostPoll _poll({int? mine, bool closed = false, int hoursLeft = 5}) => PostPoll(
      postId: 1,
      endsAt: DateTime.now().toUtc().add(Duration(hours: hoursLeft, minutes: 30)),
      isClosed: closed,
      totalVotes: 4,
      myOptionId: mine,
      options: const [
        PollOption(id: 5, position: 0, label: 'Yes', votes: 3),
        PollOption(id: 6, position: 1, label: 'No', votes: 1),
      ],
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows vote buttons without counts before voting', (tester) async {
    int? voted;
    await tester.pumpWidget(_wrap(PostPollView(
      poll: _poll(),
      onVote: (id) async {
        voted = id;
        return true;
      },
    )));
    expect(find.text('75%'), findsNothing);
    expect(find.textContaining('4 votes · 5h left'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pump();
    expect(voted, 6);
  });

  testWidgets('shows results with the viewer pick after voting', (tester) async {
    await tester.pumpWidget(_wrap(PostPollView(poll: _poll(mine: 5), onVote: (_) async => true)));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('shows final results once closed', (tester) async {
    await tester.pumpWidget(_wrap(PostPollView(poll: _poll(closed: true), onVote: (_) async => true)));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('Final results'), findsOneWidget);
  });
}
