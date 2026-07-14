# AlbertLM Dashboard 1.2

A native macOS 14+ SwiftUI control center for the AlbertLM remote training node.

## Run

1. Open `AlbertLMDashboard.xcodeproj` in Xcode.
2. Select the **AlbertLM Dashboard** scheme and run it on **My Mac**.
3. The default SSH host is `ludan2` and the remote project paths are `/data/AlbertLM` and `/data/AI-Teachers`.

The app delegates authentication to the system `/usr/bin/ssh` client. Configure the host, key and agent in `~/.ssh/config`; the app never stores a password.

Every remote operation is routed through:

```text
bash /data/AlbertLM/scripts/albertlmctl.sh status|gpu|system|checkpoints|datasets|experiment status|metrics|system-log|logs|start|stop|tmux
/data/AlbertLM/scripts/system_status.sh
/data/AI-Teachers/scripts/teacherctl.sh qwen|deepseek|gptoss start|stop|status
/data/AI-Teachers/scripts/datagen.sh teacher input output
```

Training output is stored in `/data/AlbertLM/logs/train.log`. Structured training metrics are appended to `metrics.jsonl`, and the training-scoped hardware monitor appends a workstation snapshot to `system.jsonl` every 30 seconds. The matching deployable server files are kept in `ServerScripts/`.
