# 受不了 ¥98/年的订阅，我用 Vibe Coding 自己写了个剪贴板工具

## 一、一个剪贴板工具，凭啥一年收我 ¥98？

过去一年多，我一直在用 Paste——macOS 上最知名的剪贴板管理工具。功能确实不错，界面也精致。但每次看到续费提醒，我都忍不住问自己：**我真的需要为「记录剪贴板历史并按 ⌘V 粘贴」这件事每年付 ¥98 吗？**

细看 Paste 的定价页，高级版捆绑了一大堆功能：iCloud 多设备同步、协作分享、模板库、自定义分类规则……坦率地说，我 90% 的时间只用两件事：

1. 打开面板，找到刚才复制的内容
2. 粘贴

其余的「高级功能」，一年也用不上三次。

这就很尴尬了——不是 Paste 不够好，而是**我需要的东西太简单，不值 ¥98/年**。我不打算用盗版，那是对开发者劳动的不尊重。但自己动手做一个，完全是另一回事。

转折来得恰好。最近半年 Vibe Coding 的概念大火——你不需要精通一门语言，只要描述清楚想要什么，AI 就能搭出八九成的架子。你负责决策，AI 负责实现。

于是我想：**既然干活间隙跟 AI 聊几句就能写代码，那为什么不花一个下午，给自己做一个刚刚好的剪贴板工具？**

「刚刚好」的意思是：

- 监听到剪贴板变化 → 存下来
- 按快捷键弹出面板 → 搜索 → 粘贴
- 数据留在本地，不上传任何服务器
- 不收我一分钱

然后就有了 **LocalPaste**。

---

## 二、成果展示：LocalPaste 一瞥

<!-- TODO: 在此插入 GIF 动图（打开面板 → 搜索 → 粘贴） -->

**LocalPaste** 是一个 macOS 原生的剪贴板历史管理器——100% 离线、永久免费、MIT 开源。

核心特性一览：

| 特性 | 说明 |
|---|---|
| 🧩 全类型支持 | 文本、RTF、HTML、图片、PDF、文件 URL、颜色 |
| ⌨️ 键盘即操作 | ⌥⌘V 弹出面板，↑↓ 导航，Enter 粘贴，Space 预览，Esc 关闭 |
| 🔍 打字即搜 | 打开面板直接输入，无需点击搜索框 |
| 📌 置顶收藏 | 常用片段钉在列表顶部，支持自定义分组 |
| 💾 本地持久化 | JSON 文件存储在 `~/Library/Application Support/LocalPaste/` |
| 🪶 极致轻量 | 约 30MB 内存，纯原生，零第三方依赖 |
| 🔒 完全离线 | 无网络请求、无统计上报、无账号系统 |

<!-- TODO: 插入面板截图 + 设置页截图 -->

安装只需一行：

```bash
brew tap huyikai/local-paste
brew install --cask localpaste
```

点开菜单栏的剪贴板图标（或按 ⌥⌘V），即刻使用。

---

## 三、技术方案选择：AI 出主意，我来拍板

这篇文章不打算逐行拆解源码——GitHub 上都有，感兴趣直接翻。我想分享的是 **Vibe Coding 模式下最有趣的部分：方案选择的过程**。

每次我问 AI「这部分怎么做」，它通常会给出 2-3 个选项。我的角色不是写代码，而是**做决策**。以下是我做出的几个关键选择。

### 3.1 语言与框架：SwiftUI + AppKit

**AI 给出的选项：**

- Electron（JS/TS）——一个空壳就 100MB+ 内存，先排除
- Tauri（Rust）——轻量但生态年轻，macOS API 桥接需要额外工作
- SwiftUI + AppKit——原生 API 直接调用，性能最优，不足 30MB

**我的决定：** SwiftUI + AppKit。

理由很直白：一个菜单栏工具，内存占用是最直观的体验指标。Electron 启动就吃掉 150MB，而 SwiftUI 原生渲染 + AppKit 做菜单栏集成，实测稳定在 30MB 左右。且 Apple 生态内 NSPasteboard、AX 权限、全局快捷键这些 API 都是现成的，不需要中间层。

Side note：项目只依赖了 Foundation 和 AppKit，没有任何第三方包——Package.swift 里 dependencies 是空的。

### 3.2 剪贴板监听：0.5 秒 Timer 轮询

NSPasteboard 有一个反直觉的设计：**它没有事件回调**。

你不能「订阅」剪贴板变化——只能主动去查。我问 AI 怎么办，它给出了标准答案：

```swift
// 核心思路：轮询 changeCount
let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    guard pasteboard.changeCount != lastChangeCount else { return }
    // 捕获新内容...
}
```

0.5 秒的间隔是个经验值——人眼对 <0.5 秒的延迟几乎无感知，同时 CPU 几乎不受影响。这也是 Maccy、CopyQ 等同类工具的统一做法。

### 3.3 数据存储：一个 JSON 文件就够了

AI 问我要不要上 CoreData 或 SQLite。我看了下需求：

- 只追加写入（新剪贴板内容）
- 偶尔按时间顺序查询
- 极少删除（清理旧记录或手动删除）
- 单线程操作

这不就是 `Codable` + JSON 文件的完美场景吗？几行代码搞定：

```swift
// HistoryStore.swift 核心逻辑
private let fileURL: URL = {
    let dir = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    ).first!.appendingPathComponent("LocalPaste")
    try? FileManager.default.createDirectory(at: dir, ...)
    return dir.appendingPathComponent("history.json")
}()
```

额外好处：用户可以直接打开 JSON 文件查看、备份、甚至用脚本处理。不需要任何数据库工具。

### 3.4 浮动面板：NSPanel + SwiftUI 的混合方案

浮动面板是用户体验的核心——它必须：
- 悬浮在所有窗口之上
- 失焦自动消失
- 支持键盘导航和输入

这就不能只用 SwiftUI 的 `Window` 了——`Window` 的生命周期由系统管理，无法精细控制浮动和消失行为。实际做法是：**用 AppKit 的 `NSPanel` 做壳，内部嵌入 SwiftUI 视图**。

```swift
// FloatingHistoryPanel 初始化核心
init(appState: AppState) {
    let panelRect = NSRect(x: 0, y: 0, width: 420, height: 500)

    super.init(
        contentRect: panelRect,
        styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )

    self.isFloatingPanel = true       // 浮动面板行为
    self.level = .floating            // 层级高于普通窗口
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    // 内部嵌入 SwiftUI 视图
    let hostingView = NSHostingView(
        rootView: HistoryPanelContentView().environmentObject(appState)
    )
    self.contentView = hostingView
}
```

关键设计决策：

- `.nonactivatingPanel` — 点击面板不会让 Dock 上的其他应用图标跳动，保持安静
- `.canJoinAllSpaces` — 切换桌面空间时面板跟随，不会丢失
- `NSHostingView` — 把 SwiftUI 视图桥接到 AppKit，享受两边的好处：原生窗口控制 + SwiftUI 声明式 UI
- 失焦隐藏用 `windowDidResignKey` 通知手动处理，比 `hidesOnDeactivate` 可控性更高（比如快速预览 Sheet 打开时不关闭面板）

### 3.5 质量怎么保证？两条链路，各司其职

Vibe Coding 最容易被质疑的一点是：AI 写的代码，你敢用吗？

我的答案是：**敢，因为有两套不同的协作链路在兜底。**

#### 链路 A：核心功能 → TDD 驱动

对于我知道「正确行为应该是什么」的部分——比如数据存储、搜索结果过滤、键盘导航——我用 TDD 约束 AI。流程是：

1. 我描述期望行为：「输入关键词后只显示匹配的条目，不区分大小写」
2. AI 先写测试
3. `swift test` → 红灯
4. AI 写实现 → 绿灯

```swift
// 测试先行：核心逻辑都有对应测试
func testSearchMatchesPlainText() { ... }
func testStoreSaveAndLoad() { ... }
func testFilteredItemsWithSearch() { ... }
func testKeyboardSelectionNavigation() { ... }
// 共 20+ 个测试用例，覆盖核心逻辑
```

每次改动跑一遍测试套件，5 秒出结果。AI 改错了马上知道，不会带着 bug 往前走。

#### 链路 B：Bug 修复 → 描述—确认—实施

但不是所有问题我都能说清楚「正确行为」。有些 bug 的原理我压根不懂——比如 NSPasteboard 类型系统内部的优先级规则、`NSPanel` 焦点与键盘事件的交互时序。

这时候的流程完全不同：

1. **我发现 bug** — 比如「复制一段富文本，历史面板显示的是纯文本」
2. **我描述现象** — 把看到的问题告诉 AI，附上复现步骤
3. **AI 提出方案** — 它解释可能的原因（如「RTF 类型在 typeOrder 中的优先级低于纯文本」），给出修改方案
4. **我确认** — 判断方案逻辑是否合理，无需理解底层原理
5. **AI 实施** — 改完跑测试，确认修复

整个过程我对 NSPasteboard 类型解析的内部机制一知半解，但不妨碍我做出正确的决策。**人的价值不是知道答案，而是能判断一个答案是否合理。**

举一个实际的 bug：`Enter` 粘贴到前台应用后偶尔无反应。我完全不知道是 Accessibility 权限回调的问题还是事件发送时序的问题。我把复现步骤描述给 AI，它排查出是 `NSAppleScript` 执行时未等待完成就关闭了面板，提出在脚本执行完毕后再调用 `hide()`。我确认逻辑合理，它改完——问题解决。

这两种链路覆盖了整个项目：核心逻辑靠 TDD 证明正确性，边缘 bug 靠描述—确认—实施循环推进。我没有手写一行代码，但也没有一行代码是未经审查就留下的。

---

## 四、开源分发实战：Homebrew Cask + GitHub Actions 一条龙

这是本文的重点——把工具装进用户的终端里，只需要两行命令。

### 4.1 Homebrew Cask 配方

要让用户 `brew install --cask localpaste`，需要一个 Cask 文件。我把它直接放在仓库的 `Casks/` 目录下：

```ruby
# Casks/localpaste.rb
cask "localpaste" do
  version :latest
  sha256 :no_check

  url "https://github.com/huyikai/local-paste/releases/latest/download/LocalPaste.dmg",
      verified: "github.com/huyikai/local-paste/"
  name "LocalPaste"
  desc "Lightweight, local-only clipboard history manager for macOS"
  homepage "https://github.com/huyikai/local-paste"

  app "LocalPaste.app"

  zap trash: [
    "~/Library/Application Support/LocalPaste",
    "~/Library/Preferences/com.localpaste.app.plist",
  ]
end
```

关键点解读：

- `version :latest` + `sha256 :no_check` — 适合快速迭代阶段，每次 `brew upgrade` 都拉取最新 DMG，不需要每次发布都改 SHA
- `url` 指向 GitHub Release 的 `latest/download/` 永久链接
- `zap trash` — 卸载时清理数据目录和偏好文件，不留残留

Homebrew 官方 tap 审核较严，可以先用自己的 tap（`huyikai/local-paste`），后续稳定了再提交到 homebrew-cask。

### 4.2 GitHub Actions 全自动发布

每次打 tag 推送，CI 自动完成：编译 → 打包 DMG → 发布 Release。完整 workflow：

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set version from tag
        id: version
        run: |
          TAG="${GITHUB_REF#refs/tags/}"
          VERSION="${TAG#v}"
          echo "tag=$TAG" >> $GITHUB_OUTPUT
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Sync Info.plist version
        run: |
          /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
          /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RUN_NUMBER" Info.plist

      - name: Build
        run: swift build -c release --disable-sandbox

      - name: Create .app bundle
        run: |
          BIN_PATH=$(swift build --show-bin-path -c release)
          mkdir -p LocalPaste.app/Contents/MacOS LocalPaste.app/Contents/Resources
          cp "$BIN_PATH/LocalPaste" LocalPaste.app/Contents/MacOS/
          cp Info.plist LocalPaste.app/Contents/
          codesign --force --sign - LocalPaste.app

      - name: Create DMG
        run: |
          mkdir -p .dmg-staging
          cp -R LocalPaste.app .dmg-staging/
          ln -sf /Applications .dmg-staging/Applications
          hdiutil create -volname "LocalPaste" \
            -srcfolder .dmg-staging -ov -format UDZO \
            "LocalPaste-${VERSION}.dmg"

      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          name: "LocalPaste ${{ steps.version.outputs.tag }}"
          files: LocalPaste*.dmg
          generate_release_notes: true
```

整条链路跑下来不超过 5 分钟。发布一个版本只需：

```bash
git tag v1.0.4
git push origin v1.0.4
```

剩下的 CI 全包了。

---

## 五、Vibe Coding 真实体验：效率复盘

### AI 哪些地方超好用

- **模板代码**：Timer 轮询、SwiftUI List + ForEach、设置页表单、Makefile、GitHub Actions workflow——这类「有明确模式」的代码，AI 一次生成，几乎不用改
- **API 查询**：「NSPasteboard 怎么判断内容类型？」AI 直接给出代码示例和类型对照表，省去了在 Apple 文档和 Stack Overflow 之间来回跳转的时间
- **踩坑经验**：「Homebrew cask version :latest 和固定版本有什么区别？」AI 直接给对比，不用搜帖子 

### AI 哪里容易出错（以及怎么修）

- **macOS 特有的交互语义**：比如浮动面板的焦点行为、`NSPanel` 的 `nonactivatingPanel` 与键盘事件监听之间的协调——AI 第一版通常不对，但你有测试验证，跑不过就让它改
- **Accessibility 权限引导流程**：macOS 的权限弹窗、用户授权引导的 UI/UX——需要你把场景拆成步骤描述给 AI，它才能生成正确代码
- **性能直觉**：「这段轮询代码耗不耗电？」AI 给的答案偏理论，实际在 Activity Monitor 里盯 CPU 占用才靠谱——但一旦你告诉它实测结果，它能立即优化

### 投入产出比

| 维度 | 数据 |
|---|---|
| 投入时间 | 一个下午 |
| AI 参与的代码量 | 100%——所有代码由 AI 生成，我负责审查和决策 |
| 质量保障 | 双链路：核心功能 TDD 驱动（先写测试再实现）；Bug 修复走「描述→确认方案→实施」|
| 年度节省 | ¥98 × N 年，且永远不用为云同步、订阅过期焦虑 |
| 额外收益 | 每一行代码都经过我审查，随时可改；一个 GitHub 开源项目；这篇分享文章 |

---

## 六、结语：有痛点就动手

Vibe Coding 最大的改变不是让你「不写代码」，而是把门槛削到足够低，低到 **「我就想试试能不能做」** 变成可行的选项。

剪贴板管理这个需求存在了十几年，解决方案只分两类：要么用免费的但功能简陋，要么付费订阅但功能过剩。当我意识到自己只需要其中 10% 的功能时，答案就很简单了——**自己做**。

一个下午换一个完全符合自己习惯的剪贴板工具。开源的，MIT 协议，放心用到地老天荒。

如果你也有类似的「小痛点」，不妨跟 AI 聊着试试。vibe coding 时代，**不需要你是全栈——只需要你开始**。

---

🔗 GitHub：[https://github.com/huyikai/local-paste](https://github.com/huyikai/local-paste)

📦 安装：

```bash
brew tap huyikai/local-paste
brew install --cask localpaste
```

欢迎 Star ⭐ / Issue / PR。如果你是第一次读到这里，不妨想想——你桌面上那些按月付费的小工具，哪个值得你用一个下午换掉？

---

> 📝 这篇文章同样由 AI 生成——我提供大纲、事实和观点，AI 负责组织成文。正如 LocalPaste 本身一样：人做决策，AI 做执行。
