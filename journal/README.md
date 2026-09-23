# Undercurrent — a journal that notices

A private iPhone journal. You write in it or talk to it. It keeps track of the people,
places, themes and activities in your life, draws them as a map coloured by how you
feel about each one, and writes a reflection every week, month, quarter and year.

**The plan, ideas and roadmap are in [PLAN.html](PLAN.html).** This file covers the code.

## Run it

1. On a Mac with Xcode 16 or newer, open `Undercurrent.xcodeproj`.
2. Choose the Undercurrent target, open *Signing & Capabilities*, and set Team to your Apple ID.
3. Plug in your iPhone (iOS 17 or later), select it at the top, and press Run.
4. In the app: **You → Settings → Load a sample journal** to see the map straight away.
5. For Claude, paste an API key from console.anthropic.com into Settings and tap **Save and test**.

If the project file won't open for some reason, `brew install xcodegen && xcodegen`
in this folder rebuilds it from `project.yml`.

## How it's organised

```
Undercurrent/
  App/            the app entry point and the five tabs
  Model/          SwiftData models, Store (every write), questionnaires, sample journal
  Intelligence/   reading entries and finding connections
    LocalReader     on the phone: names, places, starter themes, sentence feeling
    ClaudeClient    the Messages API, with structured JSON output
    Prompts         everything Claude is told, in one place
    Patterns        the arithmetic: mood effect, pairs, weekdays, gone quiet
    Intelligence    runs the above, writes reflections, answers questions
  Services/       dictation, Keychain, reminders
  Design/         palette, type, cards, chips
  Views/          Today, Journal, Connections (the map), Insights, You
```

Feelings run from -1 (heavy) through 0 (even) to +1 (light) everywhere: in an entry's
mood, in each mention, and in the colours.

## What happens when you save an entry

1. The entry is read on the phone at once, so it shows up on the map and in patterns immediately.
2. If Claude is set up, it reads the entry again with context: the people and themes it
   already knows, your last dozen entries, what you've told it about yourself and your
   questionnaire results. It replaces the phone's reading with a deeper one and sometimes
   adds a "Noticed" insight.
3. The pattern finder runs over the whole journal and updates the Pattern insights.

When a week, month, quarter or year ends, its reflection is written the next time the app opens.

## Privacy

Everything is stored on the phone. The API key is in the Keychain. **Keep everything on
this iPhone** in Settings turns off every Claude call. **Export** writes the whole journal
to one JSON file.
