# ──────────────────────────────────────────────────────────────────────────────
# MCons Portable — Self-Contained Single .exe Builder (NSIS)
# Packs mcons-app.exe, mcons.exe, and all 20 bundled IconPacks into ONE .exe
# ──────────────────────────────────────────────────────────────────────────────
Unicode True
Name "MCons"
OutFile "..\output\MCons.exe"
RequestExecutionLevel user
SilentInstall silent
AutoCloseWindow true
ShowInstDetails nevershow

# Maximum solid compression using LZMA
SetCompressor /SOLID lzma

Section
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"

  # Pack all application binaries and resources inside the single executable
  File "..\staging\mcons-app.exe"
  File "..\staging\mcons.exe"
  File /r "..\staging\IconPacks"

  # Execute MCons Web UI server and wait until user closes it
  ExecWait '"$PLUGINSDIR\mcons-app.exe"'
SectionEnd
