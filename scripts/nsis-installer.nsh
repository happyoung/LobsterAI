!macro customInit
  ; Best-effort: terminate a running app instance before install/uninstall
  ; to avoid NSIS "app cannot be closed" errors during upgrades.
  nsExec::ExecToLog 'taskkill /IM "${APP_EXECUTABLE_FILENAME}" /F /T'
  Pop $0
  Sleep 800
!macroend

!macro customInstall
  ; ─── V8 Compile Cache Warmup ───
  ; After files are extracted to $INSTDIR, load the gateway bundle once using
  ; Electron's own Node runtime (ELECTRON_RUN_AS_NODE=1) so V8 compiles and
  ; caches the bytecode.  This turns the user's first gateway startup from
  ; ~95s (cold V8 compile) into ~15s (cached bytecode).
  ;
  ; The warmup script is a no-op when the bundle is missing and exits 0 on
  ; any error, so it cannot block or break the installer.

  DetailPrint "Optimizing first-launch performance..."

  ; Build the cache dir path: <APPDATA>\LobsterAI\openclaw\state\.compile-cache
  ; This matches Electron's app.getPath('userData') = %APPDATA%\LobsterAI,
  ; and the engine manager sets OPENCLAW_STATE_DIR = <userData>\openclaw\state.
  StrCpy $1 "$APPDATA\LobsterAI\openclaw\state\.compile-cache"

  ; Set env vars for the warmup process:
  ;   ELECTRON_RUN_AS_NODE=1  — Electron acts as plain Node.js
  ;   NODE_COMPILE_CACHE      — enables V8 compile cache for both CJS and ESM
  System::Call 'Kernel32::SetEnvironmentVariable(t "ELECTRON_RUN_AS_NODE", t "1")i'
  System::Call 'Kernel32::SetEnvironmentVariable(t "NODE_COMPILE_CACHE", t "$1")i'

  ; Run the warmup script.  Use nsExec for silent execution.
  ; $INSTDIR is the app install dir (e.g. C:\Users\<user>\AppData\Local\Programs\LobsterAI)
  ; The warmup script lives at resources/cfmind/warmup-compile-cache.cjs
  nsExec::ExecToLog '"$INSTDIR\${APP_EXECUTABLE_FILENAME}" "$INSTDIR\resources\cfmind\warmup-compile-cache.cjs" --cache-dir "$1"'
  Pop $0
  DetailPrint "Compile cache warmup finished (exit=$0)."

  ; Unset env vars so the app launches normally after install
  System::Call 'Kernel32::SetEnvironmentVariable(t "ELECTRON_RUN_AS_NODE", t "")i'
  System::Call 'Kernel32::SetEnvironmentVariable(t "NODE_COMPILE_CACHE", t "")i'
!macroend
