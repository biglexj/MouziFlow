!macro NSIS_HOOK_PREINSTALL
  ; Attempt to close a running MouziFlow instance gracefully before installing.
  ; First try a soft terminate, wait a moment, then force-kill if still running.
  ExecWait '"$SYSDIR\taskkill.exe" /IM MouziFlow.exe /T' $0
  ExecWait '"$SYSDIR\taskkill.exe" /IM mouzi.exe /T' $0
  Sleep 500
  ExecWait '"$SYSDIR\taskkill.exe" /F /IM MouziFlow.exe /T' $0
  ExecWait '"$SYSDIR\taskkill.exe" /F /IM mouzi.exe /T' $0
!macroend
