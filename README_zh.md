# LocalPaste 🗂️

[![CI](https://github.com/huyikai/local-paste/actions/workflows/release.yml/badge.svg)](https://github.com/huyikai/local-paste/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-orange)](https://github.com/huyikai/local-paste)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

中文 | [English](README.md) | [日本語](README_ja.md)

轻量级 macOS 剪贴板历史管理器，纯本地运行。

所有数据保存在你的机器上。无需订阅、无云端同步、无需 App Store。

## 截图

<!-- TODO: 添加截图 / GIF -->
<!-- ![screenshot](screenshots/panel.png) -->

## 特性

- **全格式支持** — 文本、富文本 (RTF/RTFD)、HTML、图片、PDF、文件路径、颜色
- **菜单栏常驻** — 点击图标或按 `⌥⌘V` 呼出浮动面板
- **键盘导航** — `↑↓` 移动高亮、`Enter` 粘贴、`Space` 预览、`Esc` 关闭
- **打即搜** — 直接输入即可过滤，无需先点击搜索框
- **富文本预览** — HTML/RTF 在历史列表和预览窗中渲染样式
- **分组收藏** — 右键或点击书签图标将条目收藏到自定义分组
- **纯文本粘贴** — `⌘⇧V` 或右键菜单
- **颜色色块展示** — hex 颜色值自动识别并以背景色块显示，Space 预览纯色大色块
- **持久化存储** — `~/Library/Application Support/LocalPaste/` 下的 JSON 文件
- **可配置上限** — 50–2000 条历史记录，支持开机自启
- **100% 离线** — 无需联网、无数据收集、无账号

## 系统要求

- macOS 13.0 (Ventura) 及以上
- Apple Silicon 或 Intel Mac

## 安装

### Homebrew（推荐）

```bash
brew tap huyikai/local-paste
brew install --cask localpaste
```

如果不想添加 tap，也可直接安装：

```bash
brew install --cask huyikai/local-paste/localpaste
```

#### 更新

```bash
brew update
brew upgrade --cask localpaste
```

#### 卸载

```bash
brew uninstall --cask localpaste
brew untap huyikai/local-paste   # 可选：移除 tap
```

### 手动下载

从 [最新 Release](https://github.com/huyikai/local-paste/releases/latest) 下载 `LocalPaste.dmg`，打开后将 **LocalPaste** 拖入 **应用程序**。

> 如果 macOS 提示「无法验证开发者」，右键点击应用 → **打开** 即可绕过。

## 使用

| 操作 | 快捷键 |
|---|---|
| 打开 / 关闭面板 | 点击菜单栏图标，或 `⌥⌘V` |
| 上下导航 | `↑` `↓` |
| 粘贴选中项 | `Enter` |
| 预览选中项 | `Space`（切换开/关） |
| 搜索历史 | 直接输入任意字符 |
| 退出搜索 | `Esc` |
| 关闭面板 | `Esc` 或点击面板外区域 |
| Pin / Unpin | 点击书签按钮或右键 |
| 纯文本粘贴 | `⌘⇧V` 或右键菜单 |

### 自动粘贴（Enter 后自动 ⌘V）

`Enter` 会将内容写入剪贴板。如需自动粘贴到当前应用：

1. 在任意条目上按 `Enter` → 按照提示操作
2. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中启用 **LocalPaste**
3. 重启 LocalPaste

## 为什么选择 LocalPaste？

| | LocalPaste | 云端竞品 |
|---|---|---|
| 需要联网 | ❌ 不需要 | ✅ 通常需要 |
| 需要账号 | ❌ 不需要 | ✅ 通常需要 |
| 数据存在本地 | ✅ 是 | ❌ 在云端服务器 |
| 订阅费 | ❌ 永久免费 | 💰 按月付费 |
| 开源 | ✅ MIT | ❌ 大多闭源 |
| 资源占用 | ~30 MB 内存 | 100–500 MB (Electron) |

## 从源码构建

```bash
make build           # 当前架构 Release 构建
make build-universal # 通用二进制 (arm64 + x86_64)
make app             # 生成 .app 包
make dmg             # .app → DMG 安装包
make install         # .app → /Applications
make run             # 命令行直接运行
```

## 发布

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 会自动构建通用 DMG 并创建 Release。Homebrew cask 始终指向最新版本 — 用户只需 `brew upgrade --cask localpaste`。

## FAQ

<details>
<summary><strong>提示「无法验证开发者」？</strong></summary>

这是因为应用使用 ad-hoc 签名（未经 Apple 公证）。
在 Finder 中右键点击应用 → <strong>打开</strong> 即可，或执行：

<pre>sudo xattr -d com.apple.quarantine /Applications/LocalPaste.app</pre>
</details>

<details>
<summary><strong>自动粘贴不生效？</strong></summary>

请确认在<br>
<strong>系统设置 → 隐私与安全性 → 辅助功能</strong> 中已启用 LocalPaste。<br>
授权后需重启应用。
</details>

<details>
<summary><strong>数据存在哪里？</strong></summary>

<code>~/Library/Application Support/LocalPaste/</code> — 一个 JSON 文件。
你可以备份它、删除它以重置历史，或软链接到云盘目录。
</details>

## License

[MIT](LICENSE)
