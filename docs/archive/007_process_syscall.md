# Phase 2: プロセス管理 + syscall 設計

## 概要

Linuxのプロセス管理とシステムコール機構をCmで再実装する。
参照: `linux/kernel/sched/`, `linux/arch/x86/entry/`

## コンポーネント

### 1. task_struct (Process) — プロセス構造体

Linux の task_struct に相当。各プロセスの状態を保持。

```cm
struct Process {
    Pid pid;
    ulong state;         // RUNNING / READY / BLOCKED / ZOMBIE
    VirtAddr stack_ptr;   // カーネルスタックポインタ
    PhysAddr page_table;  // CR3値
    Pid parent_pid;
    long exit_code;
    // ... レジスタ保存域
}
```

### 2. Scheduler interface + CFS実装

```cm
interface Scheduler {
    void add_process(Process* proc);
    Process* pick_next();
    void remove_process(Pid pid);
}
```

### 3. Linux x86_64 syscall ABI

- `syscall` 命令で遷移 (STAR/LSTAR MSR設定)
- RAX=syscall番号, RDI/RSI/RDX/R10/R8/R9=引数
- 主要syscall: read(0), write(1), open(2), close(3), exit(60), fork(57)

## ファイル構成

```
cosmo-linux/
├── include/
│   └── scheduler.cm    # Scheduler interface
├── sched/
│   ├── process.cm      # Process struct + impl
│   ├── scheduler.cm    # impl RoundRobinScheduler for Scheduler
│   └── context.cm      # コンテキストスイッチ (ASM)
└── sys/
    ├── syscall.cm       # syscall エントリ (LSTAR設定)
    └── syscall_table.cm # syscall番号テーブル
```
