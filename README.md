# ortho32-desktop

**ORTHO-32 Swift Desktop**

Native desktop application for Windows 11. Swift on Windows, OpenSwiftUI + Win32/Direct2D compositor, full routing spine, ORTHOMessages chat surface, ConPTY terminal.

## What This Is

The user-facing application layer of the ORTHO platform. Connects to `ortho32-host` (C#/.NET named pipe service) for all system calls. Never talks to hardware, providers, or provers directly.

## Architecture

```
Swift Desktop (this repo)
        |
        | \\.\pipe\ortho-host  (named pipe)
        v
ortho32-host (C#/.NET)
        |
        +-- InferenceService --> \\.\pipe\ortho-ai --> ortho32-ai-gateway (MUMPS)
        +-- BuildService     --> real compiler process
        +-- DeviceService    --> ortho32-bridge C ABI --> ORTHO-32 hardware/sim
```

## Layer Map

```
Sources/
  ORTHOHost/          Win32 named pipe client (HostConnection.swift)
  ORTHOMessages/      Chat surface (ConversationModel, MessageBubble, Composer)
  ORTHORouting/       Single entry point for all actions (ORTHORouter)
  ORTHOServices/      Session, AppRegistry, WorkspaceService, EventBus, etc.
  ORTHOIntegration/   Bridge/Verify/Audit event adapters
  ORTHO32Desktop/
    App/              Entry point, Win32 host, Direct2D renderer, ConPTY
    Shell/            ORTHOShell, MenuBar, Dock, Search, Notifications
    Views/            PipelineMonitor, TensorMonitor, CycleLedger, ProofExplorer
    Apps/             Files, Terminal, IDE, Settings, Hardware, AgentCenter

ORTHODesignSystem/    Single token source: Color Typography Spacing Radius Motion Material
ORTHOCompositor/      Win32 window manager, SurfaceMixer (SurfaceFlinger pattern), Direct2D
ORTHOShell/           Window, Sidebar, Toolbar, Inspector, Table, Modal, Search
ORTHOControls/        Button Toggle TextField Picker Slider List Form
ORTHOComponents/      PipelineStageView TensorPipelineView CycleLedgerRow ProofBadge FabricStatusBar
ORTHOSecurity/        PermissionSheet AuthSheet DestructiveConfirm GateAlert LockScreen
```

## Key Invariants

- `HostConnection` uses Win32 named pipe. No localhost sockets in production.
- `ConversationModel` never imports any AI provider SDK. Sends `INFERENCE_SUBMIT` intent only.
- `CycleLedgerRow.cycle` is `UInt64`. Never wall-clock milliseconds.
- `ProofBadge`: Lean and HOL Light are always separate indicators. Never merged.
- All values from `ORTHODesignSystem` tokens. No per-view hardcoded colors or spacing.
- `ORTHORouter` is the single entry point for every action. No bypasses.

## Build

Requires Swift toolchain for Windows (swift.org/download).

```powershell
cd ortho32-desktop
swift build
```

Needs `ortho32-host` running first:

```powershell
# Terminal 1 — start host
cd C:\path\to\ortho32-host
dotnet run

# Terminal 2 — build and run desktop
cd C:\path\to\ortho32-desktop
swift run ORTHO32Desktop
```

## Design System

Tokens in `ORTHODesignSystem/`. CSS equivalents in `web/tokens.css` — same values, different binding.

Apple-class visual grammar: quiet, native-feeling, keyboard-first, dark-mode complete.
Reference: `APPLE_STYLE_OBSERVATIONS.json` — observed selectors classified OBSERVED/RECONSTRUCTED/ORTHO_SPECIFIC.

## Related Repos

| Repo | What |
|---|---|
| `ORTHO32` | Processor ISA, RTL, Lean 4 formal proofs |
| `ortho32-host` | Windows runtime spine (C#/.NET, named pipe IPC) |
| `ortho32-sdk-java` | JVM developer SDK |
| `ortho32-api` | REST/SSE API (Python/FastAPI) |
| `ortho32-ai-gateway` | AI inference layer (MUMPS) |
| `ortho32-mcp` | MCP server for VS Code / Claude Code |
| `ortho32-isolation` | Hypervisor + formal isolation proofs |
