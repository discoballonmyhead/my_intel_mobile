import '../domain/entities/story_publication.dart';

/// Prompts and model for story text, kept word-for-word identical to the web
/// `useStoryComposer` so both apps write stories the same way. If you change
/// one, change the other.
class StoryAiPrompts {
  const StoryAiPrompts._();

  /// Same model id the web passes to the `anthropic-proxy` edge function.
  static const String model = 'claude-sonnet-4-6';
  static const int headlineMaxTokens = 60;
  static const int summaryMaxTokens = 300;

  static String _context(List<StorySourceText> sources) => [
        for (var i = 0; i < sources.length; i++)
          'Source #${i + 1} (@${sources[i].username ?? 'analyst'}): ${sources[i].body}',
      ].join('\n');

  static String headline(List<StorySourceText> sources) =>
      '''You are an OSINT intelligence analyst writing breaking news headlines.

Sources:
${_context(sources)}

Extract the primary ACTION and LOCATION from these sources, then write a single headline that:
- Leads with the action (verb-forward: "Indian Vessels Advance Toward...", "Explosion Reported at...", "Chinese Forces Mass Near...")
- Includes specific location if known
- Includes specific named entities (vessel names, unit designations, country names)
- Is 8-12 words max
- Is factual and neutral — no speculation, no sensationalism
- Does NOT start with "Breaking:" or similar prefixes

Output only the headline text. No punctuation at the end. No preamble.''';

  static String summary(String headline, List<StorySourceText> sources) =>
      '''You are an OSINT intelligence analyst writing a developing situation report.

Headline: "$headline"

Sources (in chronological order):
${_context(sources)}

Write a concise, neutral, intelligence-style summary that:
- Synthesises ALL sources into a single coherent narrative
- Preserves specific details (vessel names, locations, unit names)
- Reflects the LATEST state of the situation (sources added later may update earlier ones)
- Uses hedged language where appropriate (e.g. "reportedly", "sources indicate")
- Is 2-4 sentences max
- Does NOT include a headline — just the summary body

Output only the summary text. No preamble, no labels.''';
}
