# プロセスモデル

## 概要

CosmOSのプロセスモデルは、syscall（`int $0x80`）経由でプロセスの生成・終了・待機・PID取得を行う。

## syscall一覧

| syscall番号 | 名前 | 引数 | 戻り値 |
|---|---|---|---|
| 30 | SYS_SPAWN | rdi=entry_fn | pid |
| 31 | SYS_KILL | rdi=pid | 0 |
| 34 | SYS_WAIT | rdi=pid | exit_code |
| 35 | SYS_GETPID | - | pid |

## TCBレイアウト (128B)

| Offset | フィールド | 説明 |
|--------|-----------|------|
| 0 | task_id | タスクID |
| 8 | state | READY(0)/RUNNING(1)/BLOCKED(2)/TERMINATED(3) |
| 16 | rsp | 保存RSP |
| 24 | stack_base | スタックベース |
| 32 | stack_size | スタックサイズ |
| 40 | entry | エントリポイント |
| 48 | next | 循環リスト次ID |
| 56 | timeslice | タイムスライス残り |
| 64 | process_type | 0=kernel, 1=user |
| 72 | parent_id | 親タスクID |
| 80 | exit_code | 終了コード |
| 88 | wait_for | 待機対象タスクID |

## タスク状態遷移

```
READY → RUNNING → TERMINATED
  ↑                    |
  |    BLOCKED ←───────┘ (sys_wait)
  |      |
  └──────┘ (wake_waiting_parent)
```

## 使用例

```cm
// カーネル内からのプロセス生成
ulong pid = sched_spawn(fn_addr(my_task as void*));

// syscall経由（ユーザープロセスから）
ulong sc_spawn = 30;
ulong entry = fn_addr(my_task as void*);
ulong pid = 0;
__asm__(`
    movq ${r:sc_spawn}, %rax;
    movq ${r:entry}, %rdi;
    int $$0x80;
    movq %rax, ${=r:pid}
`);
```

## 実装ファイル

- `kernel/sched/task.cm` — TCB定義とタスク生成
- `kernel/sched/scheduler.cm` — ラウンドロビンスケジューラ
- `kernel/sys/process.cm` — プロセスsyscallハンドラ
- `kernel/sys/syscall_table.cm` — syscall番号定義
- `kernel/sys/syscall.cm` — syscallディスパッチャ
