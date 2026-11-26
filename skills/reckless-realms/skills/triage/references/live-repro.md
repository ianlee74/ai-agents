# Live reproduction in a fresh worker worktree

Read this before W4 step 4's live run. A worker's worktree is new, so the first launch hits setup
gaps that a long-lived checkout doesn't. Each fix below is for this run only. Don't change the
machine's PATH or install anything.

## Before launching

1. Run `npm run setup` if `node_modules` is missing. It takes about 10 seconds.
2. Put the nested content checkout on content main, so the test game runs the content you're
   reading: `git -C content fetch origin` then `git -C content switch --detach origin/main`. The
   worktree has its own `content/` clone, so this doesn't touch anyone else's.
3. **Content source missing:** if `ai-work/content-source/current.json` doesn't exist, launch
   without `--content-offline` the first time. That launch resolves content main itself.

## Known launch failures

| Symptom in `play.log` | Fix for this run |
| --- | --- |
| `Error: spawn cmake ENOENT` while building `game/native/density` | cmake isn't on PATH. Prepend Visual Studio's bundled one for this command only: `C:\Program Files\Microsoft Visual Studio\2022\<edition>\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` (find `<edition>` with `ls`). |
| `AssertionError: Terrain texture generation failed. Use Python 3.11 …` | The machine has no matching Python. Copy the generated textures from the main checkout: `C:\Code\Reckless-Software\reckless-realms\ai-work\assets\terrain\<set>\` into the same path under this worktree's `ai-work/`. They are checksum-verified on load. If the main checkout has none, set `RR_TERRAIN_PYTHON` to a Python 3.11 with numpy 1.24.3 and Pillow 9.5.0. Otherwise give up the live run and say so. |

If something else fails, spend at most one more launch on it, then fall back to a code-level
trace and record the failure in the triage comment's Evidence.

## Capturing the subject

- **`dev-bridge eval`** takes a script file or `-e "<code>"`. A bare code string is read as a file
  name and fails with `ENOENT`.
- **NPCs and props:** your own character often blocks the default camera. Add a temporary camera,
  render, save, and free it. Write this to `ai-work/triage/<N>/shot.gd`, fill in the target, and
  run it with `node tools/dev-bridge.mjs eval ai-work/triage/<N>/shot.gd --pid <pid>`:

  ```gdscript
  # Finds the target node, frames it from the front, saves a PNG, then removes the camera.
  var target = <expression that finds the actor's Node3D>
  var cam := Camera3D.new()
  get_tree().root.add_child(cam)
  var p: Vector3 = target.global_position
  cam.global_position = p + target.global_transform.basis.z * 2.5 + Vector3.UP * 1.4
  cam.look_at(p + Vector3.UP * 1.0)
  cam.make_current()
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("<absolute worktree path>/ai-work/triage/<N>/front.png")
  cam.queue_free()
  ```

  Use an absolute path with forward slashes, since the client runs from a staged copy and `res://`
  isn't your worktree. Repeat with the side (`basis.x`) and back (`-basis.z`) offsets as the bug needs. Use `tree` and
  `inspect` first to find the target's path. Patrolling NPCs move, so take the shot right after
  finding them.
- Copy every screenshot you cite somewhere that survives archiving, or describe it fully in the
  comment: archiving deletes the worktree's `ai-work/`.

## Stopping

Stopping the background task can leave the whole game tree running. Find the
`with-content.mjs … --save test-triage-<N>` process with
`Get-CimInstance Win32_Process | Where-Object CommandLine -match 'test-triage-<N>'`, then run
`taskkill /PID <pid> /T /F`. In Git Bash `wmic` prints nothing. Confirm the port no longer listens
before archiving.
