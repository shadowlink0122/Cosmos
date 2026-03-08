#!/usr/bin/env python3
"""QEMUモニター経由でキー入力を送信する自動テストスクリプト

使い方:
    python3 scripts/qemu_sendkeys.py "gen install bash:12" "exec bash --version:5"

各引数は "コマンド:待機秒数" 形式。
"""

import socket
import sys
import time

SOCK_PATH = "/tmp/cosmo_qemu_mon.sock"

# QEMUキーマッピング (特殊文字→sendkeyキー名)
KEY_MAP = {
    " ": "spc",
    "-": "minus",
    "_": "shift-minus",
    ".": "dot",
    "/": "slash",
    "=": "equal",
    ":": "shift-semicolon",
    ";": "semicolon",
    ",": "comma",
    "'": "apostrophe",
    '"': "shift-apostrophe",
    "(": "shift-9",
    ")": "shift-0",
    "[": "bracket_left",
    "]": "bracket_right",
    "!": "shift-1",
    "@": "shift-2",
    "#": "shift-3",
    "$": "shift-4",
    "%": "shift-5",
    "^": "shift-6",
    "&": "shift-7",
    "*": "shift-8",
    "+": "shift-equal",
    "~": "shift-grave_accent",
    "`": "grave_accent",
    "\\": "backslash",
    "|": "shift-backslash",
}


def send_command(sock, cmd, wait_secs):
    """コマンド文字列をQEMUモニターに1文字ずつsendkeyで送信"""
    for c in cmd:
        if c in KEY_MAP:
            key = KEY_MAP[c]
        elif c.isupper():
            key = f"shift-{c.lower()}"
        else:
            key = c
        sock.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.08)
        try:
            sock.recv(4096)
        except Exception:
            pass

    # Enter送信
    sock.sendall(b"sendkey ret\n")
    time.sleep(wait_secs)
    try:
        sock.recv(4096)
    except Exception:
        pass


def main():
    if len(sys.argv) < 2:
        print("使い方: qemu_sendkeys.py 'cmd1:wait1' 'cmd2:wait2' ...")
        sys.exit(1)

    # ソケット接続
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(SOCK_PATH)
    except ConnectionRefusedError:
        print(f"エラー: {SOCK_PATH} に接続できません")
        sys.exit(1)

    time.sleep(0.5)
    try:
        s.recv(4096)
    except Exception:
        pass

    # コマンド実行
    for arg in sys.argv[1:]:
        parts = arg.rsplit(":", 1)
        cmd = parts[0]
        wait = int(parts[1]) if len(parts) > 1 else 3
        print(f"[sendkeys] '{cmd}' (wait={wait}s)")
        send_command(s, cmd, wait)

    # QEMUを終了
    s.sendall(b"quit\n")
    s.close()


if __name__ == "__main__":
    main()
