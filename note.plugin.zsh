# note - jot a quick note under a title, summarize later with claude.
#
#   note <title> [message]       append a note (message can be empty)
#   note list [range]            print notes for a date range (default today)
#   note s|summarize [range]     summarize notes for a date range with claude
#   note help                    show usage
#
# Notes live in $NOTE_DIR/<YYYY-MM-DD>/<title>, one file per title per day,
# each line "- [HH:MM] message". Plain files so other tools can read them.

: ${NOTE_DIR:=$HOME/.note}

note() {
  emulate -L zsh
  local cmd="$1"
  case "$cmd" in
    list|ls)              shift; _note_list "$@" ;;
    s|summarize|summary)  shift; _note_summarize "$@" ;;
    help|-h|--help)       _note_help ;;
    "" )                  _note_help ;;
    *)                    _note_add "$@" ;;
  esac
}

# turn a title into a safe, stable filename: lowercase, runs of non-alphanumerics -> single -
_note_slug() {
  setopt local_options extendedglob
  local s="${(L)1}"
  s="${s//[^a-z0-9]##/-}"
  s="${s##-}"
  s="${s%%-}"
  print -r -- "$s"
}

_note_add() {
  local title="$1"; shift
  if [[ -z "$title" ]]; then echo "usage: note <title> [message]"; return 1; fi
  local msg="$*"
  local day=$(date +%Y-%m-%d) ts=$(date +%H:%M)
  local dir="$NOTE_DIR/$day"
  mkdir -p "$dir"
  local file="$dir/$(_note_slug "$title")"
  print -r -- "- [$ts] $msg" >> "$file"
  echo "noted ($day): $title${msg:+  ($msg)}"
}

# month name -> two-digit number, or return 1
_note_month_num() {
  case "${(L)1}" in
    jan|january)        print 01 ;;
    feb|february)       print 02 ;;
    mar|march)          print 03 ;;
    apr|april)          print 04 ;;
    may)                print 05 ;;
    jun|june)           print 06 ;;
    jul|july)           print 07 ;;
    aug|august)         print 08 ;;
    sep|sept|september) print 09 ;;
    oct|october)        print 10 ;;
    nov|november)       print 11 ;;
    dec|december)       print 12 ;;
    *)                  return 1 ;;
  esac
}

# resolve a single token to "lo hi" day bounds (inclusive, YYYY-MM-DD strings),
# or return 1 if it isn't a recognized token
#   today / yesterday        -> that day
#   march / mar / ...         -> that month, current year
#   2026                     -> whole year
#   2026-05                  -> whole month
#   2026-05-14               -> single day
_note_token_bounds() {
  local t="${(L)1}" m d y
  if [[ "$t" == today ]]; then
    d=$(date +%Y-%m-%d); print -r -- "$d $d"
  elif [[ "$t" == yesterday ]]; then
    d=$(date -v-1d +%Y-%m-%d); print -r -- "$d $d"
  elif m=$(_note_month_num "$t"); then
    y=$(date +%Y); print -r -- "$y-$m-00 $y-$m-99"
  elif [[ "$t" == [0-9][0-9][0-9][0-9] ]]; then
    print -r -- "$t-00-00 $t-99-99"
  elif [[ "$t" == [0-9][0-9][0-9][0-9]-[0-9][0-9] ]]; then
    print -r -- "$t-00 $t-99"
  elif [[ "$t" == [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
    print -r -- "$t $t"
  else
    return 1
  fi
}

# resolve a range (one or more args) to matching day directories, one path per line.
# accepts every token form above, plus: this week, last week, and "<from> to <to>".
_note_range_dirs() {
  setopt local_options null_glob
  local joined="${(L)*}" lo hi d dow b lb rb
  if [[ -z "$joined" || "$joined" == today ]]; then
    lo=$(date +%Y-%m-%d); hi=$lo
  elif [[ "$joined" == yesterday ]]; then
    lo=$(date -v-1d +%Y-%m-%d); hi=$lo
  elif [[ "$joined" == "this week" ]]; then
    dow=$(date +%u)                                   # 1=Mon .. 7=Sun
    lo=$(date -v-$((dow-1))d +%Y-%m-%d)
    hi=$(date -v+$((7-dow))d +%Y-%m-%d)
  elif [[ "$joined" == "last week" ]]; then
    dow=$(date +%u)
    lo=$(date -v-$((dow-1+7))d +%Y-%m-%d)
    hi=$(date -v-${dow}d +%Y-%m-%d)
  elif [[ "$joined" == "this month" ]]; then
    lo="$(date +%Y-%m)-00"; hi="$(date +%Y-%m)-99"
  elif [[ "$joined" == "last month" ]]; then
    lo="$(date -v1d -v-1m +%Y-%m)-00"; hi="$(date -v1d -v-1m +%Y-%m)-99"
  elif [[ "$joined" == *" to "* ]]; then
    b=(${(s: :)$(_note_token_bounds "${joined% to *}")}); lo=$b[1]
    b=(${(s: :)$(_note_token_bounds "${joined#* to }")}); hi=$b[2]
  else
    b=(${(s: :)$(_note_token_bounds "$joined")}); lo=$b[1]; hi=$b[2]
  fi
  [[ -n "$lo" && -n "$hi" ]] || return 1
  for d in "$NOTE_DIR"/*(/N); do
    [[ "${d:t}" < "$lo" || "${d:t}" > "$hi" ]] && continue
    print -r -- "$d"
  done
}

# gather every note in the matched range to stdout; return 1 if none
_note_collect() {
  setopt local_options null_glob
  local d f any=0
  local dirs=(${(f)"$(_note_range_dirs "$@")"})
  for d in $dirs; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*(N); do
      any=1
      print -r -- "## ${d:t} / ${f:t}"
      cat "$f"
      print -r --
    done
  done
  (( any )) || return 1
}

_note_list() {
  if ! _note_collect "$@"; then
    echo "no notes for ${*:-today}"
    return 0
  fi
}

_note_summarize() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "note: claude CLI not found on PATH"
    return 1
  fi
  local content
  content=$(_note_collect "$@") || { echo "no notes for ${*:-today}"; return 0; }
  print -r -- "$content" | claude -p "Summarize these notes. Group related items, keep it short and plain. Notes follow:"
}

_note_help() {
  cat <<'USAGE'
note - jot a quick note under a title, summarize later with claude.

  note <title> [message]      append a note (message optional)
  note list [range]           print notes for a range (default today)
  note s [range]              summarize notes for a range with claude
  note help                   show this

range: today, yesterday, this week, last week, this month,
       last month, march, 2026, 2026-05, 2026-05-14,
       or "<from> to <to>"
notes stored in ~/.note/<date>/<title>
USAGE
}
