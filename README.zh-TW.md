<div align="center">

<img src="docs/images/icon.png?v=0.2.6" width="112" alt="Claude Switch 圖示">

# Claude Switch

**換個帳號，接著做事。**

常用的 Claude Desktop 帳號與剩餘額度，都在 Mac 選單列裡。切換帳號時，也能帶上需要繼續的 Code 對話。

[![最新版本](https://img.shields.io/badge/Download-latest_release-C9653F?style=flat-square)](https://github.com/torpedo2003/claude-desktop-switch/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?style=flat-square&logo=apple)
[![License: MIT](https://img.shields.io/badge/license-MIT-3B82F6?style=flat-square)](LICENSE)

[English](README.md) · [简体中文](README.zh-CN.md) · **繁體中文** · [日本語](README.ja.md)

[安裝](#安裝) · [快速上手](#快速上手) · [切換時會發生什麼](#切換時會發生什麼) · [移轉到另一台 Mac](#移轉到另一台-mac) · [常見問題](#常見問題)

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-zh-Hant-dark.jpg?v=0.2.6">
  <img src="docs/images/hero-zh-Hant-light.jpg?v=0.2.6" alt="Claude Switch：帳號視窗與選單列面板">
</picture>

</div>

## 為什麼需要它

個人帳號、工作帳號來回用，不該總是卡在重新登入、查看額度和找回對話上。Claude Switch 幫你保存常用帳號，看清哪個還有餘裕，換號後也能接著處理本機 Code 對話。

## 功能

- **切換不必重新登入**：常用帳號保存一次，之後直接從選單列選擇需要的帳號。
- **剩餘額度一眼看清**：把各個帳號的餘量放在一起，不必來回切換著查。
- **額度不足，及時提醒**：快用完時，有合適的備用帳號就會提醒你，讓你決定要不要切換。
- **換帳號，工作一起帶走**：Code 對話、子任務和附件一起轉到另一個帳號，已儲存的面板和檔案檢視也能保留。
- **新增帳號，保留原來的登入**：新帳號登入後一起保存，需要時隨時切回來。
- **看看自己的使用習慣**：查看本機 Code 的每日用量、常用模型與活躍趨勢。
- **移轉到另一台 Mac**：把帳號、已儲存的登入和設定匯出成一個有密碼保護的檔案，在新 Mac 上匯入。

## 截圖

**換帳號，對話跟著走。**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/conversations-zh-Hant-dark.png?v=0.2.6">
  <img src="docs/images/conversations-zh-Hant-light.png?v=0.2.6" alt="換帳號，對話跟著走。">
</picture>

**這次帶走哪些對話，由你選擇。**

在切換確認頁直接選擇對話。最近活躍的對話會預先勾選，確認後的選擇會在下次切換時記住。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/switch-selection-zh-Hant-dark.png?v=0.2.6">
  <img src="docs/images/switch-selection-zh-Hant-light.png?v=0.2.6" width="720" alt="這次帶走哪些對話，由你選擇。">
</picture>

<table>
  <tr>
    <td width="33%" valign="top">
      <p><b>額度不足，及時提醒。</b></p>
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/images/switch-reminder-menu-zh-Hant-dark.png?v=0.2.6">
        <img src="docs/images/switch-reminder-menu-zh-Hant-light.png?v=0.2.6" alt="額度不足，及時提醒。">
      </picture>
    </td>
    <td width="67%" valign="top">
      <p><b>看看自己的使用習慣。</b></p>
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/images/usage-zh-Hant-dark.png?v=0.2.6">
        <img src="docs/images/usage-zh-Hant-light.png?v=0.2.6" alt="看看自己的使用習慣。">
      </picture>
    </td>
  </tr>
</table>

<sub>所有截圖皆使用虛構的範例資料。</sub>

## 安裝

**系統需求**：macOS 14 Sonoma 或更新版本（Apple 晶片或 Intel 皆可），並已安裝 [Claude Desktop](https://claude.ai/download)。

1. 從 [最新版本](https://github.com/torpedo2003/claude-desktop-switch/releases/latest) 下載 `ClaudeSwitch-<版本>-macOS.zip`。
2. 解壓縮後把 **Claude Switch** 拖到「應用程式」資料夾。
3. 開啟它。App 尚未經過 Apple 公證，第一次開啟需要多一個步驟：
   - macOS 15 及以上：開啟 **系統設定 → 隱私權與安全性**，往下捲動，按 **強制打開**。
   - macOS 14：在 App 上按右鍵，選 **打開**，再確認一次。

   也可以在終端機移除下載隔離標記：

   ```sh
   xattr -dr com.apple.quarantine "/Applications/Claude Switch.app"
   ```

每個版本的下載旁都附有 SHA-256 檢查碼，可用來核對檔案。

### 更新

在 **設定 → 版本更新** 檢查新版本，或關閉自動檢查。按 **查看最新版本** 前往 [下載頁](https://github.com/torpedo2003/claude-desktop-switch/releases/latest)，下載與安裝由你手動完成。

取代「應用程式」中的舊版前，請先結束 Claude Switch。啟動時若出現授權提示，按 **允許存取**，再確認 macOS 對話框。選擇 **永遠允許** 可減少重複詢問。

## 快速上手

1. 像平常一樣**登入 Claude Desktop**，然後開啟 Claude Switch，依提示允許存取鑰匙圈，目前的帳號會自動保存。
2. 在選單列按 **新增帳號…**。Claude 會重新啟動到登入頁，用另一個帳號登入，它也會自動保存。
3. 在選單列或帳號視窗中**切換**，選好要帶走的 Code 對話，再確認即可。

對話歷史和已儲存的檢視會一起保留。請先結束正在執行的任務，切換後在 Claude 中繼續。

可在首次設定或 **設定 → 通知** 啟用切換推薦及操作結果通知。每次切換仍需你確認。

> [!IMPORTANT]
> 換帳號請使用 Claude Switch，不要用 Claude 裡的 **登出** 或 Claude Code 的 `/login`。
> 登出會讓這個登入在 Anthropic 那端失效，Claude Switch 保存的副本也就無法使用。
> 如果 Claude 無法恢復登入，在 Claude 裡重新登入一次即可再次保存。

主視窗快速鍵：`⌘1` `⌘2` `⌘3` 切換頁面，`⌘K` 搜尋帳號與對話，`⌘R` 更新本機帳號與對話；額度使用各帳號卡片上的更新按鈕。

## 切換時會發生什麼

1. Claude Switch 檢查所選帳號已儲存的登入。
2. Claude 正常結束，並儲存目前帳號。進行中的工作會中斷，請先完成。如果 Claude 沒有結束，切換會停止。
3. 換上所選帳號的登入，你選取的 Code 對話轉到這個帳號。
4. 重新開啟 Claude，此時已登入所選帳號。

如果某一步失敗，Claude 的原始檔案會還原，Claude 也會依原來的狀態重新開啟。

| 會變化 | 不會變化 |
| --- | --- |
| Claude Desktop 的登入 | Claude Code CLI 的登入 |
| 選取的 Code 對話所屬的帳號 | 你的專案和專案檔案 |
| | MCP 設定、技能、外掛和 Hooks |
| | Cowork 對話（無法在帳號之間轉移） |

## 移轉到另一台 Mac

兩台 Mac 都需要 Claude Switch 0.2.8 或更新版本。在新 Mac 上，先安裝 Claude Desktop 並開啟一次，再開啟 Claude Switch。

1. 在舊 Mac 上開啟 **設定 → 移轉到另一台 Mac → 匯出帳號…**，設定至少 12 位的密碼並儲存檔案。
2. 把檔案傳到新 Mac，例如用 AirDrop 或隨身碟。
3. 在新 Mac 上開啟 **設定 → 移轉到另一台 Mac → 匯入帳號…**，輸入同一個密碼並選擇檔案。

檔案裡包含帳號、已儲存的登入、額度紀錄、跟隨規則和偏好設定。Code 對話不包含在內，它們存放在 `~/.claude` 和 Claude Desktop 自己的資料夾裡。

- 取得檔案和密碼的人可以登入這些帳號，用完請刪除檔案。密碼忘記後無法找回。
- 新 Mac 上已儲存的登入會保留。無法轉換的帳號會被略過，並計入結果。
- 移轉後兩台 Mac 持有同一份登入，一台更新權杖後另一台可能登出。如果 Claude 不接受匯入的登入，在新 Mac 上重新登入一次該帳號，就會再次儲存。

## 隱私與安全

- 保存的登入在 Mac 上加密，由登入鑰匙圈保護。
- 沒有遙測、追蹤或自建伺服器，也不上傳本機對話。
- 額度查詢連線至 Anthropic，版本檢查連線至 GitHub；兩項自動檢查都可關閉。
- 切換中斷時可在設定中回復。你的專案與 Claude Code 命令列登入不會被改動。

詳細說明（英文）：[運作原理](docs/how-it-works.md) · [額度與用量資料](docs/usage-data.md) · [安全政策](.github/SECURITY.md)

## 常見問題

<details>
<summary><b>為什麼 macOS 會詢問是否允許 Claude Switch 使用「Claude Safe Storage」？</b></summary>

Claude Switch 需要這項權限來顯示帳號額度，另一項權限用於保護保存的登入。按 **允許存取** 後，在 macOS 對話框中確認；選擇 **永遠允許** 可減少重複詢問。
</details>

<details>
<summary><b>會一起切換 Claude Code 命令列嗎？</b></summary>

不會。Claude Switch 切換的是 Claude Desktop；Claude Code 命令列工具有自己獨立的登入。
</details>

<details>
<summary><b>為什麼有些帳號顯示「—」或較早的額度資料？</b></summary>

「—」表示暫時沒有可用的額度資訊。如果一直無法更新，請切換到這個帳號，確認在 Claude 中已登入，再更新一次。
</details>

<details>
<summary><b>可以把保存的帳號搬到另一台 Mac 嗎？</b></summary>

可以，請見[移轉到另一台 Mac](#移轉到另一台-mac)。手動複製資料夾行不通，因為解開它的金鑰留在舊 Mac 上。
</details>

<details>
<summary><b>啟動時停在「已儲存登入的加密金鑰遺失」</b></summary>

資料夾裡有已儲存的登入，但這台 Mac 的鑰匙圈裡沒有解開它們的金鑰，通常是因為這個資料夾是從另一台 Mac 複製過來的。點 **允許存取** 解決不了，這些資料在這台 Mac 上也讀不出來。

1. 結束 Claude Switch。
2. 在 Finder 裡把 `~/Library/Application Support/Claude Desktop Switch` 改名保留，例如改成 `Claude Desktop Switch 舊資料`。
3. 開啟 Claude Switch，選擇 **允許存取**。
4. 依照[移轉到另一台 Mac](#移轉到另一台-mac)把帳號帶過來。完成後可以刪除改名的資料夾。
</details>

<details>
<summary><b>Claude Desktop 更新後會不會失效？</b></summary>

Claude Desktop 更新後，偶爾也需要同步更新 Claude Switch。如果無法切換，請先檢查新版，或 [提交 Issue](https://github.com/torpedo2003/claude-desktop-switch/issues/new/choose)。
</details>

## 從原始碼建置

需要 Xcode 16 或更新版本（Swift 6 工具鏈）。

```sh
git clone https://github.com/torpedo2003/claude-desktop-switch.git
cd claude-desktop-switch
swift test                               # 單元測試
zsh scripts/build.sh                     # 產生 "dist/Claude Switch.app"
open "dist/Claude Switch.app" --args --demo   # 用範例資料試用
```

`scripts/build.sh --read-only` 會建置一個只能檢視、永遠不會改動 Claude 檔案的版本。更多內容請見 [架構說明](docs/architecture.md) 與 [貢獻指南](.github/CONTRIBUTING.md)（英文）。

## 介面語言

English、简体中文、繁體中文、日本語、한국어、Español、Français、Deutsch、Português (Brasil)、Русский。預設跟隨 macOS 語言，也可以在設定中更改。歡迎協助改進翻譯。

## 參與貢獻

歡迎回報 Bug、提出建議與送出 Pull Request。送出前請先閱讀 [貢獻指南](.github/CONTRIBUTING.md)；安全問題請依 [安全政策](.github/SECURITY.md) 私下回報。

如果你使用 Claude Code 或其他 AI 程式設計助手開發：[AGENTS.md](AGENTS.md) 與 [CLAUDE.md](CLAUDE.md) 提供專案規則、常用指令與斜線指令，[docs/claude-internals.md](docs/claude-internals.md) 記錄了本專案依賴的 Claude Desktop 與 Claude Code 本機資料格式（英文）。

## 授權

[MIT](LICENSE)

Claude Switch 是獨立的開源專案，與 Anthropic 沒有任何隸屬、背書或贊助關係。Claude 與 Claude Desktop 是 Anthropic, PBC 的商標。請只在你有權使用的帳號上使用，並遵守 Anthropic 的相關條款。
