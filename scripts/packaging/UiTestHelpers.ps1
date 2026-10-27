# Utilidades de prueba de interfaz (Win32) compartidas por los scripts de
# verificacion del instalador de MouziFlow.
# No forma parte de la app: solo se usa en las pruebas automatizadas.

if (-not ('UiTest' -as [type])) {
    Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class UiTest {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct GUITHREADINFO {
    public int cbSize; public int flags; public IntPtr hwndActive, hwndFocus, hwndCapture, hwndMenuOwner, hwndMoveSize, hwndCaret;
    public RECT rcCaret;
  }
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO gti);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool c);
  [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hwnd, bool fAltTab);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();

  // GetWindowText NO cruza procesos para un control EDIT: devuelve el texto
  // cacheado en la creacion del control. Para leer el valor vivo hay que
  // enviar WM_GETTEXT con un buffer.
  public static string LiveText(IntPtr hwnd) {
    var sb = new StringBuilder(4096);
    SendMessage(hwnd, 0x000D, (IntPtr)sb.Capacity, sb);
    return sb.ToString();
  }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);

  // Envia una tecla directamente al control indicado. No depende del primer
  // plano, asi que la prueba es determinista aunque otra ventana robe el foco.
  public static void PostKey(IntPtr h, int vk, bool shift) {
    IntPtr lParam = (IntPtr)(1 | (shift ? 0x1000000 : 0));
    PostMessage(h, 0x0100, (IntPtr)vk, lParam);
    PostMessage(h, 0x0101, (IntPtr)vk, lParam);
  }

  public static void PostChar(IntPtr h, char c) {
    PostMessage(h, 0x0102, (IntPtr)(int)c, (IntPtr)1);
  }

  // Sube la ventana por encima de las demas para poder tomar el primer plano.
  public static void MakeTopmost(IntPtr h) {
    SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x0003);
  }

  public static void RestoreZ(IntPtr h) {
    SetWindowPos(h, new IntPtr(-2), 0, 0, 0, 0, 0x0003);
  }

  public static void ForceFocus(IntPtr target, uint targetThread) {
    uint cur = GetCurrentThreadId();
    AttachThreadInput(cur, targetThread, true);
    SetFocus(target);
    AttachThreadInput(cur, targetThread, false);
  }

  // Cambia el primer plano de forma efectiva. Windows restringe
  // SetForegroundWindow: se intenta primero el metodo habitual con
  // AttachThreadInput y, si no basta, el pulso de ALT (que habilita el cambio
  // de primer plano) y SwitchToThisWindow.
  public static bool ForceForeground(IntPtr h) {
    IntPtr fg = GetForegroundWindow();
    uint fgThread = 0, hThread = 0;
    GetWindowThreadProcessId(fg, out fgThread);
    GetWindowThreadProcessId(h, out hThread);
    uint cur = GetCurrentThreadId();
    AttachThreadInput(cur, fgThread, true);
    AttachThreadInput(cur, hThread, true);
    BringWindowToTop(h);
    SetForegroundWindow(h);
    AttachThreadInput(cur, hThread, false);
    AttachThreadInput(cur, fgThread, false);
    if (GetForegroundWindow() == h) return true;

    // Pulso de ALT: el sistema permite cambiar el primer plano justo despues.
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
    AttachThreadInput(cur, fgThread, true);
    AttachThreadInput(cur, hThread, true);
    BringWindowToTop(h);
    SetForegroundWindow(h);
    AttachThreadInput(cur, hThread, false);
    AttachThreadInput(cur, fgThread, false);
    if (GetForegroundWindow() == h) return true;

    SwitchToThisWindow(h, true);
    return GetForegroundWindow() == h;
  }

  public static string ClassOf(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
  public static string TextOf(IntPtr h) { var s = new StringBuilder(1024); GetWindowText(h, s, 1024); return s.ToString(); }

  public static List<string> TopWindows() {
    var res = new List<string>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      res.Add(pid + "|" + h.ToInt64() + "|" + ClassOf(h) + "|" + TextOf(h) + "|" + IsWindowVisible(h));
      return true;
    }, IntPtr.Zero);
    return res;
  }

  public static List<string> Children(IntPtr parent) {
    var res = new List<string>();
    EnumChildWindows(parent, (h, l) => {
      var r = new RECT(); GetWindowRect(h, out r);
      res.Add(h.ToInt64() + "|" + ClassOf(h) + "|" + TextOf(h) + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom + "|" + IsWindowVisible(h));
      return true;
    }, IntPtr.Zero);
    return res;
  }

  public static IntPtr FocusOf(uint threadId) {
    GUITHREADINFO gti = new GUITHREADINFO();
    gti.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
    if (!GetGUIThreadInfo(threadId, ref gti)) return IntPtr.Zero;
    return gti.hwndFocus;
  }

  // Rectangulo del cursor de texto del control enfocado. Sirve para
  // comprobar que el campo de ruta muestra el cursor de insercion, que es el
  // indicador de foco visual de un TEdit sin bordes.
  public static bool CaretVisible(uint threadId, out RECT caret) {
    GUITHREADINFO gti = new GUITHREADINFO();
    gti.cbSize = Marshal.SizeOf(typeof(GUITHREADINFO));
    caret = new RECT();
    if (!GetGUIThreadInfo(threadId, ref gti)) return false;
    caret = gti.rcCaret;
    return gti.hwndFocus != IntPtr.Zero && caret.Right > caret.Left && caret.Bottom > caret.Top;
  }

  public static void Key(byte vk, bool shift) {
    if (shift) keybd_event(0x10, 0, 0, UIntPtr.Zero);
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    keybd_event(vk, 0, 2, UIntPtr.Zero);
    if (shift) keybd_event(0x10, 0, 2, UIntPtr.Zero);
  }

  // Pulsacion mantenida: es lo que hace falta para Shift+Tab, donde el
  // estado del modificador debe seguir activo durante la tecla principal.
  public static void KeyDown(byte vk) { keybd_event(vk, 0, 0, UIntPtr.Zero); }
  public static void KeyUp(byte vk) { keybd_event(vk, 0, 2, UIntPtr.Zero); }

  public static void Type(string text) {
    foreach (char c in text) {
      byte vk = 0; bool shift = false;
      if (c >= 'a' && c <= 'z') vk = (byte)char.ToUpperInvariant(c);
      else if (c >= 'A' && c <= 'Z') { vk = (byte)c; shift = true; }
      else if (c >= '0' && c <= '9') vk = (byte)c;
      else if (c == '\\') { vk = 0xDC; shift = true; }
      else if (c == ':') { vk = 0xBA; shift = true; }
      else if (c == '.') vk = 0xBE;
      else if (c == ' ') vk = 0x20;
      else continue;
      Key(vk, shift);
      System.Threading.Thread.Sleep(15);
    }
  }
}
"@
}

function Get-WizardWindow {
    <#
      Devuelve el HWND de la ventana del asistente (TWizardForm) que pertenece
      al proceso lanzado. El lanzador de Inno Setup crea un proceso hijo, asi
      que se aceptan el PID lanzador y sus descendientes directos.
    #>
    param([int]$LauncherPid)

    $pids = @()
    if ($LauncherPid) {
        $pids += $LauncherPid
        try {
            $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$LauncherPid" -ErrorAction SilentlyContinue
            $pids += @($children | ForEach-Object { [int]$_.ProcessId })
        } catch {}
    }

    foreach ($l in [UiTest]::TopWindows()) {
        $p = $l -split '\|', 5
        if ($p[2] -match 'TWizardForm' -and $p[4] -eq 'True') {
            if (-not $pids.Count -or $pids -contains [int]$p[0]) { return [IntPtr][int64]$p[1] }
        }
    }
    return [IntPtr]::Zero
}

function Get-ProcessTreeIds {
    param([int]$LauncherPid)
    $ids = @($LauncherPid)
    try {
        $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$LauncherPid" -ErrorAction SilentlyContinue
        $ids += @($children | ForEach-Object { [int]$_.ProcessId })
    } catch {}
    return $ids
}

function Stop-SetupTree {
    <#  Cierra el lanzador y el proceso real del instalador (nombre .tmp). #>
    param([int]$LauncherPid)
    $ids = Get-ProcessTreeIds -LauncherPid $LauncherPid
    foreach ($id in $ids) {
        Get-Process -Id $id -ErrorAction SilentlyContinue | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force } catch {}
        }
    }
}
