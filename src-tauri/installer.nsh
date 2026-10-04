!macro NSIS_HOOK_PREINSTALL
  ; Attempt to close a running MouziFlow or legacy Mouzi instance gracefully before installing.
  ; First try a soft terminate, wait a moment, then force-kill if still running.
  ExecWait '"$SYSDIR\taskkill.exe" /IM MouziFlow.exe /T' $0
  ExecWait '"$SYSDIR\taskkill.exe" /IM mouzi.exe /T' $0
  Sleep 500
  ExecWait '"$SYSDIR\taskkill.exe" /F /IM MouziFlow.exe /T' $0
  ExecWait '"$SYSDIR\taskkill.exe" /F /IM mouzi.exe /T' $0

  ; Clean up legacy autostart registry entry from old "Mouzi"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Mouzi"

  ; Clean up legacy shortcuts from old "Mouzi"
  Delete "$DESKTOP\Mouzi.lnk"
  Delete "$SMPROGRAMS\Mouzi.lnk"

  ; Clean up legacy installation directory from old "Mouzi"
  RMDir /r "$LOCALAPPDATA\Mouzi"
!macroend
