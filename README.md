# AlbertLM Dashboard 1.2

A native macOS 14+ SwiftUI control center for the AlbertLM remote training node.

## Run

1. Open `AlbertLMDashboard.xcodeproj` in Xcode.
2. Select the **AlbertLM Dashboard** scheme and run it on **My Mac**.
3. The default SSH host is `ludan2` and the default remote project path is `~/AlbertLM`.

The app delegates authentication to the system `/usr/bin/ssh` client. Configure the host, key and agent in `~/.ssh/config`; the app never stores a password.

Every remote operation is routed through:

```text
~/AlbertLM/scripts/albertlmctl.sh status|gpu|system|checkpoints|datasets|experiment status|start|stop|tmux
~/AI-Teachers/scripts/teacherctl.sh qwen|deepseek|gptoss start|stop|status
~/AI-Teachers/scripts/datagen.sh teacher input output
```
