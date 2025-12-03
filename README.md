# retropad

A Petzold-style Win32 Notepad clone written in mostly plain C. It keeps the classic menus, accelerators, word wrap toggle, status bar, find/replace, font picker, time/date insertion, and BOM-aware load/save. Printing is intentionally omitted.

## Prerequisites (Windows)
- Git
- Visual Studio 2022 (or Build Tools) with the "Desktop development with C++" workload
- Use a "x64 Native Tools Command Prompt for VS 2022" (or any Developer Command Prompt) so `cl`, `rc`, and `nmake` are on your `PATH`.

Optional: MinGW-w64 for `make` + `gcc` (a separate POSIX-style `Makefile` is included).

## Get the code
```bat
git clone https://github.com/your/repo.git retropad
cd retropad
```

## Build with MSVC (`nmake`)
From a Developer Command Prompt:
```bat
nmake /f makefile
```
This runs `rc` then `cl` and produces `retropad.exe` in the repo root. Clean with:
```bat
nmake /f makefile clean
```

## Build with MinGW (optional)
If you have `gcc`, `windres`, and `make` on PATH:
```bash
make
```
Artifacts end up in the repo root (`retropad.exe`, object files, and `retropad.res`). Clean with `make clean`.

## Build on macOS (Cocoa port)
The Windows UI stays unchanged; macOS uses a small Cocoa implementation in `retropad_mac.m`.
- Prerequisite: Xcode Command Line Tools (`xcode-select --install`), which provide `clang` and the Cocoa framework headers.
- Build Apple Silicon (default): `make -f Makefile.macos` (outputs `binaries/retropad_macos_arm64`)
- Build Intel: `make -f Makefile.macos ARCH=x86_64` (outputs `binaries/retropad_macos_x86_64`)
- Or build manually: `clang -Wall -Wextra -O2 -fobjc-arc -arch arm64 retropad_mac.m -framework Cocoa -framework UniformTypeIdentifiers -o binaries/retropad_macos_arm64` (swap `-arch x86_64` and the output name for Intel)
- Run: `./binaries/retropad_macos_arm64` or `./binaries/retropad_macos_x86_64`
- Notes: Word wrap and status bar toggles are supported; Go To Line is disabled while word wrap is on (like Notepad). Find/replace uses the standard macOS find panel. Files open with the encoding Cocoa detects; saves default to UTF-8 if no BOM/encoding was detected.

## Run
Double-click `retropad.exe` or start from a prompt:
```bat
.\retropad.exe
```

## Features & notes
- Menus/accelerators: File, Edit, Format, View, Help; classic Notepad key bindings (Ctrl+N/O/S, Ctrl+F, F3, Ctrl+H, Ctrl+G, F5, etc.).
- Word Wrap toggles horizontal scrolling; status bar auto-hides while wrapped, restored when unwrapped.
- Find/Replace dialogs (standard `FINDMSGSTRING`), Go To (disabled when word wrap is on).
- Font picker (ChooseFont), time/date insertion, drag-and-drop to open files.
- File I/O: detects UTF-8/UTF-16 BOMs, falls back to UTF-8/ANSI heuristic; saves with UTF-8 BOM by default.
- Printing/page setup menu items show a “not implemented” notice by design.
- Icon: linked as the main app icon from `res/retropad.ico` via `retropad.rc`.

## Project layout
- `retropad.c` — WinMain, window proc, UI logic, find/replace, menus, layout.
- `file_io.c/.h` — file open/save dialogs and encoding-aware load/save helpers.
- `resource.h` — resource IDs.
- `retropad.rc` — menus, accelerators, dialogs, version info, icon.
- `res/retropad.ico` — application icon.
- `makefile` — MSVC `nmake` build script.
- `Makefile` — MinGW/GNU make build script.

## Common build hiccups
- If `nmake` is missing, use a Developer Command Prompt (it sets up `PATH`).
- If you see RC4204 warnings about ASCII/virtual keys, they’re benign and come from control-key accelerator lines.
- If `rc`/`cl` aren’t found, rerun `vcvarsall.bat` or reopen the Developer Command Prompt.
