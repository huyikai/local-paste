# LocalPaste 演示用剪贴板内容

按顺序逐条复制到剪贴板，每复制一条 LocalPaste 会自动记录。


## 第 1 条 — 纯文本（中文日常）
LocalPaste 真是太好用了！


## 第 2 条 — URL 链接
https://github.com/huyikai/local-paste


## 第 3 条 — 代码片段（Swift）
```swift
import SwiftUI

struct ContentView: View {
    @State private var searchText = ""

    var body: some View {
        List {
            ForEach(items.filter { $0.matches(query: searchText) }) { item in
                ItemRowView(item: item)
            }
        }
        .searchable(text: $searchText)
    }
}
```


## 第 4 条 — 英文短句
The best time to plant a tree was 20 years ago. The second best time is now.


## 第 5 条 — 命令/终端
brew tap huyikai/local-paste && brew install --cask localpaste


## 第 6 条 — macOS 快捷键提示
⌥⌘V 打开面板 | ↑↓ 导航 | Enter 粘贴 | Space 预览 | Esc 关闭 | ⌘⇧V 粘贴为纯文本


## 第 7 条 — 中文长句
剪贴板管理这个需求存在了十几年，解决方案只分两类：要么用免费的但功能简陋，要么付费订阅但功能过剩。当我意识到自己只需要其中 10% 的功能时，答案就很简单了——自己做。


## 第 8 条 — JSON/结构化数据
{
  "name": "LocalPaste",
  "version": "1.0.3",
  "license": "MIT",
  "platform": "macOS 13+",
  "memory": "~30MB"
}


## 第 9 条 — 混合 emoji
✅ 完成 CI 配置  ✅ 完成 Homebrew Cask  ✅ 完成 Release workflow  🚀 发布 v1.0.0


## 第 10 条 — 邮箱/联系方式
feedback@localpaste.app
