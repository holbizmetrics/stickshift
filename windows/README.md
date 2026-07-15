# StickShift for Windows

A Windows port of StickShift following the five-step plan in [`docs/WINDOWS.md`](../docs/WINDOWS.md):
same architecture (pure decision core / OS layer / CLI / gearbox shell), the same fail-closed safety
*discipline* (with some upstream layers still owed — see Known issues), and the same `gearbox.html` —
hosted verbatim in WebView2, not forked.

> **Status: first working version — this definitely still contains bugs.**
> It shifts real Claude Code sessions on real hardware (Windows 11 + Windows Terminal), and every
> control in the gearbox drives the engine — but it has had one evening of live testing on one
> machine. Treat it as a working spike to build on, not a hardened release. Known issues below.

## Quick start

1. Inside your Claude Code session, give it a findable title: `/rename my claude session`
2. **Have the .NET 10 SDK?** Double-click `run.cmd` — or `run.cmd --target "my claude session"` to aim it.
3. **No .NET at all?** Run `publish.cmd` once on any machine that has the SDK: it produces
   self-contained `stickshift.exe` + `StickShiftGearbox.exe` in `windows/publish/` that run on any
   Windows 10/11 x64 machine — zip the folder and share it. (The gearbox additionally needs the
   WebView2 runtime, which is in-box on Windows 11 and a small install on Windows 10.)

Then pull a gear. Without `--target`, the gearbox auto-picks the first Claude session it can read —
prefer `--target`, it's what keeps you from shifting the wrong session.

## Layout

| Project | WINDOWS.md step | What it is |
|---|---|---|
| `StickShift.Core` | 3 | Pure logic, no OS calls: pane classifier, gear table, switch plans, per-frame decisions. Direct port of the macOS pure modules. |
| `StickShift.Core.Tests` | 3 | 52 tests over the classifier + decision layer (real TUI fixtures, macOS and Windows frame formats). |
| `StickShift.Os` | 1, 2, **4 (partial)** | UI Automation pane reader (Windows Terminal), SendInput injector (`KEYEVENTF_UNICODE`), window focus, and the fail-closed `SwitchDriver` pipeline: read → precheck → inject → verify. **Step 4 (attribution) is title-substring matching + the text classifier, *not* the full WT-UIA-tree + Toolhelp process walk `docs/WINDOWS.md` calls the safety-critical piece — see Known issues.** |
| `StickShift.Probe` | 1 | Tiny diagnostic that dumps what UIA can read from your terminal — useful when a machine behaves differently. |
| `StickShift.Cli` | — | `stickshift <gear> --target <title> [--commit]`, plus `--list`, `--dump`, `--clear-draft`. |
| `StickShift.App` | 5 | The gearbox: WebView2 shell hosting `src/app/gearbox.html` **verbatim** (linked, not copied), bridging `webkit.messageHandlers.*` → `chrome.webview.postMessage`. Applies the exact `{model, effort}` tuple the UI sends — same semantics as the macOS shell's `runModelToken:effort:`. |

## Build & run

Requirements: Windows 10/11, .NET 10 SDK, Windows Terminal, WebView2 runtime (in-box on Win 11),
Claude Code CLI.

```
cd windows
dotnet build StickShift.Windows.slnx
dotnet test  StickShift.Core.Tests/StickShift.Core.Tests.csproj
```

Give your target session a recognizable title first (`/rename my claude session` inside Claude Code).

CLI (dry-run by default; `--commit` performs the shift):

```
StickShift.Cli\bin\Debug\net10.0-windows\stickshift.exe --list
StickShift.Cli\bin\Debug\net10.0-windows\stickshift.exe 3 --target "my claude session" --commit
```

Gearbox:

```
StickShift.App\bin\Debug\net10.0-windows\StickShiftGearbox.exe --target "my claude session"
```

Pull a gate (1=Haiku, 2=Sonnet, 3=Opus, 4=Fable) or drag the throttle — the target session gets
`/model` / `/effort`, delivery-checked and verified. Esc closes; drag empty areas to move; the pin
button (Windows-shell addition, injected — not a `gearbox.html` edit) toggles always-on-top.

## Safety model — what's ported, and what isn't

**Ported and working:** never inject unless the pane is a recognized agent, idle, no dialog open, and
the composer is provably empty (`DRAFT_PRESENT` otherwise — `--clear-draft` is the deliberate way
out). Every typed command must appear as a **new** occurrence in the pane before Return (scrollback
can't fake it). Verification is needle-based on fresh confirmation lines, with occurrence baselines
taken before injection so stale lines can't false-pass. Foreground is re-asserted **and its success
verified** before *every* keystroke — if the target isn't foreground (you alt-tabbed mid-shift), the
run aborts with `NO_FOCUS` rather than blind-type into the wrong window. A session-local named mutex
serializes shifts so two clients (CLI + GUI, or two quick pulls) can't interleave keystrokes.

**Not yet ported (the upstream macOS shell has these; this port does not):**

- **Per-batch identity / geometry / frame-age revalidation** (`STALE_FRAME`, the 150ms frame clock).
  The port re-reads the pane and re-verifies *foreground* before each keystroke, but does not re-check
  the target's window identity/geometry between check and act the way `Switch.m` does.
- **Full step-4 attribution** — the WT-UIA-tree + Toolhelp child-process walk. The port targets by
  window-title substring + the text classifier; a title collision is guarded only by the classifier.
- **Manifest (model, effort) qualification precheck** (`UNSUPPORTED_EFFORT` at precheck). The port
  relies on runtime "Invalid argument" detection instead.

None of these are one-evening fixes; they're named here so the gap is explicit rather than implied.

## Windows-specific findings (why some code looks paranoid)

- **Windows Claude Code renders a different TUI than macOS**: status line is `<Model> · ctx …`
  (no `📂 cwd` footer), composer is `> ` (not `❯`), effort shows as `<effort> · /effort` — the
  classifier handles both formats.
- **Stale banners lie.** Window resizes redraw startup banners into scrollback naming whatever
  model/effort was current *then*. The classifier therefore anchors on the bottom-most live
  footer and treats banner text as display-only fallback — never as proof of current state.
- **UIA reads can transiently drop foreground focus**, so the driver re-asserts focus immediately
  before every keystroke (with no UIA call in between) *and verifies the re-assert landed* before
  typing — a failed re-assert aborts with `NO_FOCUS` instead of typing into the wrong window.
- **`TextPattern.GetText(maxLen)` truncates from the *start*.** On long scrollback that would return
  the top of history, not the live screen, so the reader takes the full range and keeps the tail.
- **The effort chip is not always rendered** on Windows; when current effort can't be proven from
  the live footer, the port re-types `/effort` (idempotent) rather than trust a stale read.

## Known issues / not done yet

- **Codex path is ported but not live-tested on Windows.** The gearbox's Codex provider tab is also
  not wired (the host pushes an empty Codex profile); Codex is CLI-reachable only for now.
- **Attribution is title-substring + classifier, not the full WT-UIA/Toolhelp walk** (see Safety
  model). Two visible windows whose titles both match the `--target` substring are disambiguated only
  by the text classifier — give the target a unique `/rename` title.
- **`ReadActiveAgentPane` prefers the on-screen pane**; if UIA's off-screen flag is wrong for a
  background tab, a valid shift can be refused (`NO_AGENT`) rather than mis-injected — fail-closed,
  but occasionally over-cautious. Make the target the visible tab.
- Windows Terminal only; VS Code integrated terminals and WSL-hosted sessions are untested.
- Dialog auto-answer: the **gearbox** defaults to auto-confirm (pulling a gear *is* the confirmation,
  matching the macOS app); the **CLI** stays conservative (Ask). Little live exercise on Windows.
- GUI parity gaps vs macOS shell: policy choice not persisted to config and not acknowledged back to
  the UI (`window.policySaved`/`setPolicy` not driven); no continuous live refresh (state updates on
  launch and after shifts); no global hotkeys; no tray presence; the gearbox is an activating window
  rather than `WS_EX_NOACTIVATE` (it steals foreground on a pull and steals it back, instead of never
  taking it).
- One machine, one DPI, one evening of testing. Expect timing-sensitive edges in UIA reads.

## Provenance of this list

Most of the Known issues above were surfaced by a four-lens adversarial audit of this port (injection
safety, hostile-input, cross-file consistency, and contract-fidelity vs the macOS shell). The
highest-severity findings — per-keystroke focus verification, the injection lock, the `GetText`
truncation, an exact-match composer-draft check, and the outcome-bucketing so a committed-but-slow
shift no longer renders as an error — are fixed in this branch; the rest are named here rather than
left implied.
