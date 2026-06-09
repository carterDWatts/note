# Note

Jot a quick note under a title. Summarize later with claude.

## What it does

Stores short notes grouped by day and title. Each note is a plain file you can read with anything. When you want the gist, `note s` hands them to the `claude` CLI for a summary.

```
$ note standup "shipped the frog renumber fix"
noted (2026-06-09): standup  (shipped the frog renumber fix)

$ note standup "started on note plugin"
noted (2026-06-09): standup  (started on note plugin)

$ note s today
... claude summary of today's notes ...
```

## Commands

```bash
note <title> [message]      # Append a note (message optional)
note list [range]           # Print notes for a range (default today)
note s [range]              # Summarize notes for a range with claude
note help                   # Show usage
```

Ranges: `today`, `yesterday`, `this week`, `last week`, `this month`, `last month`, `march`, `2026`, `2026-05`, `2026-05-14`, or `<from> to <to>` (e.g. `2026-05-14 to 2026-06-01`, `march to june`).

## Storage

Notes live in `~/.note/<date>/<title>`, one file per title per day. Each line is `- [HH:MM] message`. Same title twice in a day appends to the same file.

```
~/.note/2026-06-09/standup
  - [09:14] shipped the frog renumber fix
  - [14:30] started on note plugin
```

Plain text on purpose, so other tools can read it.

## Installation

### Oh My Zsh
```bash
git clone https://github.com/carterDWatts/note.git ~/.oh-my-zsh/plugins/note
```

Add `note` to your plugins list in `~/.zshrc`:
```bash
plugins=(git note)
```

### Manual
```bash
git clone https://github.com/carterDWatts/note.git ~/note
echo 'source ~/note/note.plugin.zsh' >> ~/.zshrc
```

Restart your shell after installation.

## Notes

- Notes stored in `~/.note`, outside the repo
- Override the location with `NOTE_DIR` before sourcing
- `note s` needs the `claude` CLI on your PATH
