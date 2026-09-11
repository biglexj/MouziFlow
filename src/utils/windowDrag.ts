import { getCurrentWindow } from "@tauri-apps/api/window";
import { invoke } from "@tauri-apps/api/core";

let activeCleanup: (() => void) | null = null;

/**
 * Initiates window dragging when user clicks and holds on a designated header or drag handle.
 * 1. Invokes Tauri's native startDragging() immediately (native Win32 smooth drag loop).
 * 2. In parallel, starts a high-performance requestAnimationFrame throttled tracking
 *    fallback to guarantee movement even if the Windows OS / DWM drops the modal drag message
 *    on transparent/frameless/alwaysOnTop windows.
 */
export function handleWindowDrag(
  e: React.PointerEvent<HTMLElement> | React.MouseEvent<HTMLElement>
) {
  if (e.button !== 0) return;

  const target = e.target as HTMLElement | null;
  if (
    target &&
    target.closest(
      "button, a, input, select, textarea, [data-no-drag], [data-tauri-drag-region='false']"
    )
  ) {
    return;
  }

  // Clear any existing active drag
  if (activeCleanup) {
    activeCleanup();
    activeCleanup = null;
  }

  // 1. Always trigger native startDragging
  try {
    getCurrentWindow()
      .startDragging()
      .catch(() => {
        invoke("start_dragging_cmd").catch(() => {});
      });
  } catch {
    invoke("start_dragging_cmd").catch(() => {});
  }

  // 2. High-performance fallback with throttling
  const startScreenX = e.screenX;
  const startScreenY = e.screenY;
  const dpr = window.devicePixelRatio || 1;

  let initialWinX = 0;
  let initialWinY = 0;
  let hasPos = false;
  let isMoving = false;
  let isPendingIpc = false;
  let latestTargetX = 0;
  let latestTargetY = 0;

  invoke<[number, number]>("get_window_position_cmd")
    .then((pos) => {
      if (Array.isArray(pos)) {
        initialWinX = pos[0];
        initialWinY = pos[1];
        hasPos = true;
      }
    })
    .catch(() => {
      getCurrentWindow()
        .outerPosition()
        .then((pos) => {
          if (pos && typeof pos.x === "number") {
            initialWinX = pos.x;
            initialWinY = pos.y;
            hasPos = true;
          }
        })
        .catch(() => {});
    });

  const sendPositionUpdate = () => {
    if (isPendingIpc || !hasPos || !isMoving) return;
    isPendingIpc = true;
    invoke("set_window_position_cmd", { x: latestTargetX, y: latestTargetY })
      .catch(() => {})
      .finally(() => {
        isPendingIpc = false;
      });
  };

  const onPointerMove = (evt: PointerEvent | MouseEvent) => {
    if (evt.buttons !== 1) {
      cleanup();
      return;
    }

    const deltaX = Math.round((evt.screenX - startScreenX) * dpr);
    const deltaY = Math.round((evt.screenY - startScreenY) * dpr);

    if (!isMoving && (Math.abs(deltaX) > 1 || Math.abs(deltaY) > 1)) {
      isMoving = true;
    }

    if (isMoving && hasPos) {
      latestTargetX = initialWinX + deltaX;
      latestTargetY = initialWinY + deltaY;
      requestAnimationFrame(sendPositionUpdate);
    }
  };

  const cleanup = () => {
    window.removeEventListener("pointermove", onPointerMove);
    window.removeEventListener("pointerup", cleanup);
    window.removeEventListener("mousemove", onPointerMove);
    window.removeEventListener("mouseup", cleanup);
    if (activeCleanup === cleanup) {
      activeCleanup = null;
    }
  };

  activeCleanup = cleanup;
  window.addEventListener("pointermove", onPointerMove, { passive: true });
  window.addEventListener("pointerup", cleanup, { passive: true });
  window.addEventListener("mousemove", onPointerMove, { passive: true });
  window.addEventListener("mouseup", cleanup, { passive: true });
}
