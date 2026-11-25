---
name: test
description: "Start a local Reckless Realms test game from the current session's reckless-realms checkout (worktree or main) with the client dev bridge enabled, connect to the bridge, and create and populate a new test character. Use whenever the user says 'start a test game', 'start a local test', 'launch a test game', 'spin up a local game', 'play-test this', or asks to try the current change in a running game client, even without naming the dev bridge."
---

# Start a local test game

Launches this session's Reckless Realms game (local server cluster plus one client) on an isolated
test save, with the client dev bridge on, creates a new character for the test, and
leaves it running so the user can play and you can drive, inspect and screenshot the client through `node tools/dev-bridge.mjs`.

Harness-specific details (how to run a long-lived background command and wait on a condition) are
in [references/harness-claude-code.md](references/harness-claude-code.md). Read it when running in
Claude Code.

## 1. Find the game checkout

Use the checkout this session works in, never a different worktree:

- Start from the session's working directory and take its git top level
  (`git rev-parse --show-toplevel`).
- It is the game if its `package.json` has `"name": "reckless-realms"` and it has
  `tools/play.mjs` and `tools/dev-bridge.mjs`.
- It must also have `tools/create-character.mjs`. If it doesn't, the checkout predates that tool: ask
  the user whether to update it or to create the character by hand in the client window. Never play
  the built-in characters (Aster, Bram).
- If the session is in `reckless-realms-content` or anywhere else, stop and ask the user which game
  checkout to use (the main one is usually `C:\Code\Reckless-Software\reckless-realms`). Don't
  guess a worktree.

Run every later command from that checkout. Call it `GAME` below.

## 2. Check what's already running

From `GAME`, run `node tools/dev-bridge.mjs status` and note every listed `pid` and its session file
path. It also lists clients from the installed release, which may be the user's live game. Only the
sessions whose file is under this checkout's `GAME/ai-work/` are yours to use; never drive any other.

If a client under `GAME/ai-work/` is already live, ask the user whether to reuse it or start a fresh
one. On "reuse", skip to step 5 with that pid. `create-character` refuses a client that is already
in the world, so a new character needs one at the character screen: if it is already in, either
keep its character with the user's agreement (it must not be Aster or Bram) and skip step 6, or stop
it and start fresh.

## 3. Pick the save and port

- **Save:** `test-<short name>`, where the short name comes from the branch or worktree (letters,
  numbers, `_`, `-` only; e.g. `test-hammer-template`). Never use the default `adventure` save, and
  reuse the same test save on later runs in this session so the world carries over. If the user
  asks for a fresh world, pick a new name rather than wiping.
- **Port:** other sessions may be running games, so don't assume `7010` is free. Find a free one:

  ```bash
  node -e "const s=require('net').createServer();s.listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close()})"
  ```

## 4. Launch with the dev bridge on

Create `GAME/ai-work/test-game/` and start the game as a **background** command (it runs until
stopped), logging to a file:

```bash
RR_DEV_BRIDGE=1 npm run play -- --content-offline --save <save> --no-companion --port <port> > ai-work/test-game/play.log 2>&1
```

PowerShell form: `$env:RR_DEV_BRIDGE='1'; npm run play -- ...` with the same arguments.

- `RR_DEV_BRIDGE=1` turns the bridge on for this client only (no `dev-bridge.cfg` change, so the
  installed release is unaffected).
- The client opens at the character screen; step 6 creates its character and makes it an admin.
  Don't enter the world by hand first. One client starts by default.
- `--content-offline` reuses the last prepared content. If it exits with `ENOENT` on
  `ai-work/content-source/current.json`, nothing has been prepared yet: relaunch without
  `--content-offline` (it then resolves content `main` first, which takes longer).
- **Game and content out of step:** if startup dies at "Preparing the Godot project and authored
  content" with `ENOENT` on a file under `ai-work/content-source/<sha>-…/` (say
  `vegetation/catalog.json`), content `main` needs game code this checkout doesn't have yet. Run
  `git fetch` and compare with `origin/main`. Don't pull or switch branches in a checkout another
  session may be using. Ask the user whether to update the checkout, or relaunch with
  `--content-ref <sha>` pinned to the last content commit before the change (find it in
  `../reckless-realms-content` with `git log`). `--content-ref` needs the **full 40-character
  SHA**: a short one fails with `content_git_failed: -c`. Say in the report which content commit
  you pinned.
- `--no-companion` skips the phone companion and its TLS setup. Drop it only if the user wants the
  companion.

## 5. Connect the dev bridge

Wait (up to about 3 minutes; the first run in a checkout stages the client and is slower) until
**both** hold:

- `play.log` contains `Join code:`, and
- `node tools/dev-bridge.mjs status` lists a pid that wasn't there in step 2 **and** whose session
  file is under this checkout's `GAME/ai-work/`. Match on that path, never on "newest": another
  game's client may have started in the meantime.

Fail fast instead of waiting out the timeout if the background command exits or the log shows a
crash (a line starting `Error` or `Node.js v`, which Node prints after an uncaught exception). Then
check step 4's known failures before reporting the last lines of `play.log` (skip the `at …` stack
lines).

A healthy start takes about a minute and ends with `[Startup] World services ready.`,
`Join code: …` and `Save: …`. A `[Request rejected] … calendar_unavailable` line right after
startup is harmless.

Then run `node tools/dev-bridge.mjs ping --pid <pid>`. Always pass `--pid` for this client in every
later bridge command, since the default (newest session) may belong to another game.

`joined` is `false` while the client is at the character screen; that is expected here.

## 6. Create and populate a character

Every test run gets a new character. Never play the built-in ones (Aster, Bram). From `GAME`:

```bash
node tools/create-character.mjs --pid <pid> --admin [--name <name>] [--background <id>] [--attributes vigor=6,reason=3] [--run "<chat command>"]...
```

- Choose the parameters for what this test exercises: for example
  `--run "time set 18:00" --run "teleport harbor" --run "give fishing_pole"`. Anything left out gets
  a valid default (a unique name, the first background, the creation points spread out). If the
  user only wants to play, `--pid <pid> --admin` is enough.
- `--admin` makes the character an administrator with `adminPassword` from this checkout's
  `game-settings.json`. It doesn't print the password; don't print it or pass it yourself (a
  `--run "/admin …"` is refused).
- `--run` is repeatable and runs in order. Leave off the leading `/`, which Git Bash rewrites.
- Longer setups: pass a JSON `--file` with the same keys, kept under `GAME/ai-work/`. `--help` lists
  everything.
- The tool waits for the character screen itself and returns once the character is in the world. It
  exits 1 at the first refusal. If creation was refused, fix the parameters and run it again. If a
  `--run` command was refused, the character is already in the world and the later commands did not
  run: report it (don't rerun the tool on that client, it would be refused).
- A save holds at most 10 characters for this client. If creation is refused because the roster is
  full, relaunch on a new save name; don't wipe or delete characters.
- If the user asks to create or pick the character themselves, skip this step and wait until `ping`
  reports `joined: true`.

Afterwards, `ping --pid <pid>` should report `joined: true`. See "Test characters" in
`GAME/docs/Dev-Bridge.md`.

## 7. Label the window with the session name

So the user can tell test games apart, prefix the client's window title with this session's name.

- **Label:** the session's title from the harness when it has one (see the harness reference).
  Otherwise use the short name from step 3 (branch or worktree). Use the user's wording instead if
  they gave a label. Trim it to about 40 characters and drop `"` and `\`.
- **Why an install, not one eval:** `main.gd` sets the title itself at startup and again when a
  character enters the world, which would overwrite a one-time change. A persistent bridge install
  re-applies the label twice a second and keeps the game's own character-name suffix.

Write this to `GAME/ai-work/test-game/window-title.gd`, with `<label>` replaced:

```gdscript
extends Node
var main
const LABEL = "<label>"
var _wait := 0.0

func _process(delta):
	_wait -= delta
	if _wait > 0.0: return
	_wait = 0.5
	var who := ""
	if main != null and main.get("joined") and str(main.get("actor_id")) != "":
		who = " — " + str(main.call("_name", main.get("actor_id")))
	DisplayServer.window_set_title("[" + LABEL + "] Reckless Realms" + who)
```

Then install it:

```bash
node tools/dev-bridge.mjs install window-title ai-work/test-game/window-title.gd --pid <pid>
```

A successful install prints nothing. Confirm it with `list --pid <pid>` (it shows `window-title`).
To read the real title, ask Windows rather than Godot, which has no title getter:
`powershell -NoProfile -Command "(Get-Process -Id <pid>).MainWindowTitle"`. If the install fails, report the error and carry on: the
label is a convenience, so a failure here doesn't stop the test game. `reset` removes the install,
so after a `reset` run the same `install` again to restore the label.

## 8. Report

Tell the user, briefly:

- the checkout, save name and port, and the join code;
- the bridge pid and that `ping` answered (engine version, joined state);
- the window label (or why it couldn't be set);
- the log path (`GAME/ai-work/test-game/play.log`) and that the game keeps running in the
  background;
- the new character's name, that it is an admin, and the setup commands that ran or were refused;
- what you can do next: `screenshot`, `tree`, `inspect`, `eval`, `install` and `drive` (see
  `GAME/docs/Dev-Bridge.md`).

## Stopping

Closing the client window does **not** stop the game: the server and its services keep running
with the character left in the world. To restart after the user closes it, stop the game, then go
through steps 4–7 again on the same save and port, with a new character.

To stop it, stop the background command. On Windows that can leave the whole game tree running,
because Git Bash doesn't pass Ctrl+C on to it. If the port is still listening afterwards, find the
`node tools/with-content.mjs tools/play.mjs … --save <save>` process (match the save name in its
command line) and run `taskkill /PID <that pid> /T /F`. Don't kill node processes by name: other
sessions' games use them too. A forced stop skips the final save, but the world is checkpointed
every 5 seconds, so the next launch picks up where it was. Don't run `npm run wipe` or delete saves unless
the user asks. If you installed mockups the user didn't ask to keep, `remove` each by name before
stopping, rather than `reset`, which would also drop the window label.
