# Flycast Dark (armeabi-v7a) – modification notes

Base: flyinghead/flycast, commit e88b0ced2243de137bcccac0072f0c1dd00d41bd (from the supplied source archive).

## Identity
- App name `Flycast Dark` (`res/values/donottranslate.xml`), application id `com.flycast.emulator.dark`
  (installs next to upstream Flycast). Java/JNI namespace `com.flycast.emulator` is unchanged on purpose.
- New dark launcher icon + TV banner. GPLv2 `LICENSE` and upstream attribution are untouched.

## ABI
- `ndk { abiFilters += "armeabi-v7a" }` in `shell/android-studio/flycast/build.gradle.kts`. The CMake project
  has no prebuilt per-ABI libraries; the ARM32 dynarec (`core/rec-ARM`) is selected by CMake for this ABI.

## Settings (all persisted in emu.cfg)
| Setting | Key | Default | Notes |
|---|---|---|---|
| Fast-forward speed | `[input] FastForwardSpeed` | 2 | 2/3/5/10 (x). Used only while fast-forward is on. |
| Show FPS Counter | `rend.ShowFPS` (existing) | off | Now a multi-line overlay. |
| Touch opacity | `VirtualGamepadTransparency` (existing) | 37 | Settings > Controls. |
Fast-forward itself is never persisted: `emulator.cpp` resets `fastForwardMode=false` on game start (1x).

## Fast-forward design / limits
- Upstream is paced by the audio backend blocking (`audiostream.cpp push(..., LimitFPS)`). Upstream fast-forward
  muted audio and disabled VSync, i.e. unthrottled. We keep that (audio muted, VSync off) and add a vblank limiter
  (`fastForwardPace()` in `core/hw/pvr/spg.cpp`): wall time per frame = Frame_Cycles / SH4_MAIN_CLOCK / multiplier.
  If the device is too slow it never sleeps and drops the backlog, so achieved speed < requested.
- Audio is muted while fast-forwarding (no resampling/time-stretch implemented). No separate "keep audio" option exists.
- Overlay "Speed %" = emulated SH4 cycles / wall clock over 1 s, so it reports what was achieved; the requested
  multiplier is shown separately. Disabled for netplay/multiboard (upstream rule).
- Rendering is not skipped during fast-forward; 5x/10x are usually GPU/CPU bound.
- Toggle (not hold) via the existing FastForward button binding / on-screen button.

## Overlay (`getFPSNotification` in `core/ui/gui.cpp`)
FPS, average frame time (1000/FPS over 1 s), measured speed %, renderer, vertical render resolution (`rend.Resolution`).
No CPU/GPU model or temperature (no reliable cross-device source was added). Position is fixed (bottom-left).

## Not done
Per-element touch-control restyling, hold-to-fast-forward, overlay position option, audio-on fast-forward.
