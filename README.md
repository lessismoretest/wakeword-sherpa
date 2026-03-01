# 类似 Hey Siri，唤醒常见 ai

本项目用于唤醒词检测（基于sherpa-onnx）

## 当前默认

- 唤醒词（豆包）：`豆包豆包`/`嘿豆包`，打开豆包语音通话
- 唤醒词（Grok）：`hey grok/嘿 grok`，，打开 grok 语音通话
- 唤醒词（Jarvis）：`Jarvis/Javis/hey jarvis/嘿Jarvis/贾维斯/杰维斯`，默认也是打开 grok 语音通话，可配置。
- 唤醒词（ChatGPT）：`hey chatgpt`/`嘿，ChatGPT`，打开 `chatgpt.com` 并尝试点击语音按钮。
- 唤醒词（Gemini）：`hey gemini`，直接打开 `https://gemini.google.com/`。
- 唤醒词（OpenClaw/小龙虾）：`嘿 小龙虾`/`嘿 龙虾`/`嘿 大龙虾`/`嘿 openclaw`/`嘿，兄弟`，打开 Telegram 并向 `@xiaolin_clawdbot` 发送“唤醒词后”的语音转写文本。

## 启动

```bash
launchctl kickstart -k gui/$(id -u)/com.lessismore.wakeword-sherpa
```

说明：当前默认是 `launchd` 常驻后台，不需要手动前台运行脚本。

## 后台管理

重启监听服务：

```bash
launchctl kickstart -k gui/$(id -u)/com.lessismore.wakeword-sherpa
```

停止监听服务：

```bash
launchctl bootout gui/$(id -u)/com.lessismore.wakeword-sherpa
```

查看服务状态：

```bash
launchctl print gui/$(id -u)/com.lessismore.wakeword-sherpa | head -n 80
```

## 许可与素材说明

- 本项目使用 **MIT License**（见 [LICENSE](./LICENSE)）。
- 仓库中的语音/音频素材仅用于演示与学习。
- 如有侵权或授权问题，请联系仓库维护者，我会尽快删除或替换。
