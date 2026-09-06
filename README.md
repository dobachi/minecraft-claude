# Claude × Minecraft Bedrock 連携セットアップ

Windows + Minecraft Bedrock Edition を Claude Desktop から操作するための環境構築ガイド。
[Mming-Lab/minecraft-bedrock-education-mcp](https://github.com/Mming-Lab/minecraft-bedrock-education-mcp) を利用する。

ただし直接は使わず、[dobachi/minecraft-bedrock-education-mcp](https://github.com/dobachi/minecraft-bedrock-education-mcp) の `legacy-chat-receive` ブランチを **git submodule** として `server/` に固定している。理由は「[なぜ上流を直接使わないのか](#なぜ上流を直接使わないのか)」を参照。

> **本READMEの表記について**
> このREADMEとサンプルファイルでは、各自が clone / 配置するフォルダのフルパスを **`<PROJECT_DIR>`** と表記しています。実行時はあなたの環境のパス（例：`C:\Users\<USER>\projects\minecraft-claude` や `D:\workspace\minecraft-claude` など、自由）に読み替えてください。

## 仕組み（先に理解してください）

```
[Claude Desktop アプリのチャット] ──MCP──▶ [Node.js MCPサーバ] ──WebSocket──▶ [Minecraft Bedrockクライアント（自分）]
```

- MCPサーバが PC のローカルポート（既定 8001）で WebSocket を待ち受ける。
- Minecraft 起動後、チャットに `/connect localhost:8001/ws` と打って接続する。
- Claude が出すコマンドは「**自分のキャラクター**」として実行される（別人格Botではない）。

> ### ⚠ どの「Claude」から操作するのか
>
> Anthropic の Claude にはいくつか入口があり、**MCPサーバが見えるのはこのうち一部だけ** です。本プロジェクトで操作するのは **Claude Desktop アプリ（通常の対話チャット）** です。
>
> | 入口 | このMCPが使えるか |
> | --- | --- |
> | **Claude Desktop アプリの通常チャット** | ✅ 使える（このプロジェクトのターゲット） |
> | Claude Desktop の **Cowork モード**（ファイル作業・自動化用の別モード） | ❌ 使えない（別のツールセット） |
> | claude.ai（ブラウザ版） | ❌ 使えない（ローカルMCP非対応） |
> | Claude Code（CLIツール） | ✅ 使える（`install-claude-code.ps1` + 同梱の `.mcp.json` で構成済み。後述「Claude Code から使う」参照） |
>
> 「いまどこにいる？」と聞くなら、**Claude Desktop のアプリを開いて、左上「+」で新規チャットを開始してそこで質問する**こと。Cowork のような別モードでは Minecraft の状態は見えない。

### 友人サーバ参加についての重要な制約

このMCP方式は「自分のクライアント」を介してコマンドを送る仕組みのため、友人のサーバで使うには **次のいずれか** が必要です。

1. 友人のサーバで `/connect` コマンドの実行が許可されている（多くの公開サーバではブロックされる）
2. 友人のサーバでチート（cheats）が有効、かつ自分にOP権限がある
3. 友人のサーバが「Education Edition」または `allow-cheats: true` のローカル/専用サーバ

公開サーバ（Realms含む）では `/connect` がほぼ確実に拒否されます。試したい場合はまず **シングルプレイのワールドで動作確認** → **友人にサーバ設定を相談** の順で進めるのが安全です。

> **実績**: チートが有効な友人のサーバ（他プレイヤーが同時接続中）で `/connect` の成功を確認済み。ただし**マルチプレイでは未対策の socket-be が接続直後にクラッシュする**ため、「[socket-be のクラッシュ対策](#socket-be-のクラッシュ対策)」を適用した状態で使ってください。未対策だと「繋がったように見えて実は MCP サーバのプロセスが死んでいる」という紛らわしい状態になります。

「別アカウントで友人のサーバに同時参加するBot」が欲しい場合は別方式（`bedrock-protocol` ライブラリで自前Bot構築、Microsoftアカウント認証必要、サーバ規約に注意）になるので、その方向に切り替えたいときは知らせてください。

## 必要なもの

- Windows 10/11
- Minecraft for Windows (Bedrock Edition)
- Node.js 18 以上
- Git for Windows
- Claude Desktop アプリ

## セットアップ手順

### 1. 前提ツールのインストール（初回のみ）

PowerShell を開いて、未導入のものを `winget` で入れる：

```powershell
winget install OpenJS.NodeJS.LTS
winget install Git.Git
```

`winget` が使えない環境では公式インストーラから導入：
- Node.js: https://nodejs.org/ の「LTS」をDL
- Git: https://git-scm.com/download/win

**重要：** インストール後は **PowerShell を一度閉じて新しいウィンドウを開く**（PATHが新セッションで読み込まれるため）。新ウィンドウで以下が通れば準備完了：

```powershell
node --version    # v20.x や v22.x 等
git --version
```

### 2. このフォルダで `setup.ps1` を実行

```powershell
cd <PROJECT_DIR>     # 例: cd C:\Users\<USER>\projects\minecraft-claude
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`server/` の submodule が checkout され、build される。

> `ExecutionPolicy` でブロックされるのを回避するため必ず `-ExecutionPolicy Bypass` を付けて起動する。恒久的に許可したい場合は管理者PowerShellで一度だけ：
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

### 3. Claude Desktop の設定ファイルを編集

`apply-config.ps1` が `<PROJECT_DIR>` を実フォルダパスに置換し、JSON構文を検証して、`claude_desktop_config.resolved.json` の生成 + クリップボードコピーまで一気にやる。

```powershell
# このリポのルートで実行
powershell -ExecutionPolicy Bypass -File .\apply-config.ps1
```

実行後は2通りの貼り付け方：

- **A. クリップボードから貼付（推奨）**：`notepad "$env:APPDATA\Claude\claude_desktop_config.json"` を開いてCtrl+V。既に他のMCPが入っている場合は `mcpServers` 内の `"minecraft-bedrock": {...}` 部分だけマージ
- **B. 既存設定が無い／上書きで構わない**：`-Apply` を付けて実行すると `%APPDATA%\Claude\claude_desktop_config.json` を直接上書き（既存があれば `.bak` にバックアップしてから）

```powershell
powershell -ExecutionPolicy Bypass -File .\apply-config.ps1 -Apply
```

> **既存MCPがいる場合は `-Apply` を使わないこと。** 既存エントリは保持されない。

設定編集後は Claude Desktop を **完全終了 → 再起動**（タスクトレイ常駐も終了させる）。

> **JSONエラーが出た時のチェック：** `\U`, `\p` のように **`\` の後ろが `"` `\` `/` `b` `f` `n` `r` `t` `u` 以外** になっていないか確認。Windowsパスは必ず `C:\\Users\\...` のように `\\` で書く。`apply-config.ps1` は `ConvertFrom-Json` で事前検証する。

> **PowerShell 5.x のUTF-8注意点：** `Get-Content` は既定で Shift-JIS で読み、`Set-Content -Encoding UTF8` は BOM付きで書く。両方とも文字化けやJSONパース失敗の原因になる。`apply-config.ps1` は `Get-Content -Encoding UTF8` と `[System.IO.File]::WriteAllText(..., UTF8NoBom)` で対処済み。

> `claude_desktop_config.resolved.json` は個人の絶対パスを含むため `.gitignore` で除外している。

### 4. Minecraft 側で接続

#### 4-a. ループバック分離の解除（初回のみ・**ほぼ全員必要**）

Minecraft for Windows は UWP アプリで、既定では `localhost` への接続が OS によって遮断される（`/connect` がタイムアウト／無反応の主因）。**管理者として開いた**PowerShellで一度だけ：

```powershell
cd <PROJECT_DIR>
powershell -ExecutionPolicy Bypass -File .\enable-connect.ps1
```

スクリプトは Retail Bedrock / Preview / Education の3種類のパッケージにループバック例外を一括登録する。手動コマンドは：

```powershell
CheckNetIsolation LoopbackExempt -a -n="Microsoft.MinecraftUWP_8wekyb3d8bbwe"
```

確認：

```powershell
CheckNetIsolation LoopbackExempt -s | Select-String "Minecraft"
```

#### 4-b. 暗号化WebSocket要求の解除（初回のみ）

Minecraft Bedrock は既定で TLS 暗号化された WebSocket (`wss://`) しか受け付けない。MCPサーバはローカル通信なので平文 (`ws://`) で動作するため、この要求を OFF にする必要がある。

Minecraft 内で：

1. **設定 (Settings)** を開く
2. **一般 (General)** タブ → **プロフィール (Profile)** セクション
3. **「暗号化された Websockets を必須にする」（Require Encrypted Websockets）** を **OFF**

未解除の場合「Websocket サーバーへの要求が拒否されました。設定に移動して有効にしてください」と表示される。

#### 4-c. ワールド側の準備

1. 動作確認用にシングルプレイのワールドを「**チート: ON**」で作成
2. ワールドに入ったらチャットを開いて以下を実行：
   ```
   /connect localhost:8001/ws
   ```
3. 「接続しました」と出れば成功

#### 4-d. うまくいかない時のチェックリスト

| 症状 | 確認項目 |
| --- | --- |
| 「Websocketサーバーへの要求が拒否されました」 | **4-b** の暗号化WebSocket要求がOFFか |
| 何も応答がない／タイムアウト | **4-a** のループバック例外が入っているか（`enable-connect.ps1 -List`） |
| 「コマンドが見つかりません」 | ワールドのチートがONか／OP権限があるか |
| 「Connection refused」 | MCPサーバ（Node.js）が起動しているか／ポート8001が空いているか（`netstat -ano \| findstr :8001`） |
| Claude にツールが出ない | Claude Desktop ログで `minecraft-bedrock` が緑になっているか |
| Preview版を使っている | `enable-connect.ps1` がBeta/Educationも自動で網羅する |

### 5. Claude から操作

**Claude Desktop アプリの通常チャット**（左上の「+」で開く新規会話）で、自然言語で指示するだけ。Cowork やブラウザ版 claude.ai ではこのMCPは見えない（→ 冒頭「⚠ どの『Claude』から操作するのか」参照）。

次節の動作確認を順に試すと、各ツール群（読み取り系→書き込み系→建築系）が一通り動くか確認できる。

## 動作確認シナリオ

セットアップ完了後、**Claude Desktop アプリの通常チャット**（左上「+」で新規会話）で以下を順に試す。Cowork モードや claude.ai ブラウザ版では Minecraft が見えないので、間違えないように注意。各手順の **Claude側の応答** はモデルや会話の流れで多少変わるが、ツールが呼び出されて結果が返ってくれば成功。

### Step 1. 読み取り系（一番安全・副作用なし）

Minecraft内で動かなくても安全な、状態取得だけのテスト。

| プロンプト例 | 呼ばれるツール（目安） | 期待される確認ポイント |
| --- | --- | --- |
| 「いまどこにいる？座標を教えて」 | `player_*` | 現在のXYZ座標が返る |
| 「いまの体力と空腹度は？」 | `player_*` | HP・空腹値が返る |
| 「いまの天気と時刻を教えて」 | `world_*` | 天気・時刻（tick）が返る |
| 「ダイヤモンドのレシピを調べて」 | `minecraft_wiki` | Wiki検索結果が返る |

ここで全部失敗するなら、Minecraft↔MCPサーバの接続自体が切れている可能性が高い。Minecraft側で `/connect localhost:8001/ws` をやり直す。

### Step 2. 書き込み系（ワールドへの軽い変更）

シングルプレイのテスト用ワールドで実行する。**重要なワールドでは試さない**こと。

| プロンプト例 | 呼ばれるツール（目安） | 期待される確認ポイント |
| --- | --- | --- |
| 「天気を晴れにして時刻を昼にして」 | `world_*` | 即座に晴れ・昼に切り替わる |
| 「いまの足元から1ブロック上にダイヤモンドブロックを置いて」 | `blocks_*` | 指定位置にブロックが出現 |
| 「足元から東に5マス進んだ位置のブロック種類を教えて」 | `blocks_*` | ブロック名が返る |

### Step 3. 建築系（派手だが範囲は限定的）

足元の周囲が更地である場所で実行。

| プロンプト例 | 呼ばれるツール（目安） | 期待される確認ポイント |
| --- | --- | --- |
| 「目の前に石のキューブを5×5×5で建てて」 | `build_cube` | 立方体が出現 |
| 「いまの位置の上空20ブロックに半径8の球体をガラスで作って」 | `build_sphere` | 空中に球体が出現 |
| 「足元から北に50マス先までガラスで一直線の橋を作って」 | `build_line` | 直線状の橋ができる |
| 「半径10、高さ20の円柱を石レンガで建てて」 | `build_cylinder` | 円柱が出現 |

### Step 4. Agent系（要：ワールド作成時に「Education」機能ON）

`agent_*` 系は Agent（プログラミング教育用ロボット）の機能。**Bedrock Retail版でもワールド作成時に「Education」実験機能をONにすれば使える**（Education Edition本体は不要）。**ただし既存ワールドには後付けできない**ので、Agent を試したいなら新規ワールドを作る。

ワールド作成時の設定：

1. 新規ワールドを作成 → **ゲーム設定**
2. 「**実験的なゲームプレイ (Experimental Gameplay)**」を有効化（または「**Education Edition**」トグル）
3. チートも ON にしておく
4. ワールド入場後、`/connect localhost:8001/ws` で接続
5. Claude側で「Agentを足元に召喚して」「Agentを5マス前進させて」「Agentに足元のブロックを採掘させて」などを試す

| プロンプト例 | 呼ばれるツール（目安） | 期待される確認ポイント |
| --- | --- | --- |
| 「Agentを足元に召喚して」 | `agent_*`（spawn系） | Agentがプレイヤー近くに出現 |
| 「Agentを北に5マス前進させて」 | `agent_*`（move系） | Agentが移動 |
| 「Agentに足元のブロックを掘らせて」 | `agent_*`（destroy系） | ブロックが撤去される |
| 「Agentに石を1個設置させて」 | `agent_*`（place系） | ブロックが置かれる |

> Agentコマンドは仕様上 WebSocket 側からのみ実行可能（プレイヤーがチャットで `/agent ...` を直接打つことはNPC経由でないとできない）。MCPサーバ経由でのこのプロジェクトの構成はその要件を満たす。

### 失敗時の切り分け

- **Step1も失敗する** → Minecraft↔MCPサーバの接続切れ。`/connect localhost:8001/ws` 再実行
- **Step1は成功、Step2〜3で失敗** → ワールドのチートがOFF／OP権限なし
- **Claude側でツールが選択されない** → `mcp__minecraft-bedrock__*` ツールが Claude Desktop に登録されているか確認。Claude Desktop を完全終了→再起動
- **特定のbuild系だけ失敗** → 範囲が大きすぎてサーバ側がタイムアウトしている可能性。サイズを小さくして試す

## Claude Code から使う

Claude Desktop の代わりに、ターミナル（PowerShell）から `claude` コマンドで操作することもできる。同じ MCP サーバを Claude Desktop と Claude Code で使い回せるので、慣れたツールで作業できる。

### 仕組み

```
[PowerShell の claude CLI] ──MCP(stdio)──▶ [Node.js MCPサーバ(run-server.cmd)] ──WebSocket──▶ [Minecraft Bedrock]
```

Claude Desktop 版と同じ構成。違いは MCP サーバを spawn する親プロセスが Claude Desktop ではなく `claude` CLI になる点だけ。

### セットアップ

1. **Claude Code 本体のインストール（初回のみ）**

   ```powershell
   cd <PROJECT_DIR>
   powershell -ExecutionPolicy Bypass -File .\install-claude-code.ps1
   ```

   `npm install -g @anthropic-ai/claude-code` を裏で実行してバージョン確認まで行う。Node.js 18+ が必要（`setup.ps1` の前提と同じ）。完了後は **新しい PowerShell ウィンドウ** で `claude --version` が通る。

   > **`claude` 実行時に「スクリプトの実行が無効」エラーが出たら**：npm が `claude.ps1` ラッパを `%APPDATA%\npm\` に置くが、Windows PowerShell の既定 ExecutionPolicy (`Restricted`) では `.ps1` が一切実行できないため弾かれる。一度だけ次を実行してポリシーを `RemoteSigned` に緩める（CurrentUser スコープなので**管理者権限不要**）：
   >
   > ```powershell
   > Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   > ```
   >
   > ローカル作成スクリプトは無署名で実行可、ネット由来は署名必須、というバランス設定。これを変えたくない場合は `claude.cmd --version` のように `.cmd` ラッパを直接呼べば回避できる（`.cmd` は ExecutionPolicy の対象外）。

2. **プロジェクトスコープの MCP 設定（同梱済み）**

   このリポには `.mcp.json` が同梱されており、`claude_desktop_config.resolved.json` と同じ `minecraft-bedrock` サーバ定義が入っている。Claude Code は起動時のカレントディレクトリ直下の `.mcp.json` を自動で読む。

   ```json
   {
     "mcpServers": {
       "minecraft-bedrock": {
         "command": "cmd",
         "args": ["/c", "J:\\minecraft\\minecraft-claude\\minecraft\\run-server.cmd"]
       }
     }
   }
   ```

   別環境では絶対パスを書き換える。`.gitignore` で除外しているので、`apply-config.ps1` 相当を作るか、各自で書き換える運用。

3. **CLAUDE.md（同梱済み）**

   プロジェクトルートの `CLAUDE.md` には Claude Desktop の Project カスタム指示と同じ Minecraft 行動原則が入っている。Claude Code は起動時にこれを自動で読む。Claude Desktop の Project 機能と等価の効果が得られる。

4. **起動と接続順序**

   起動順序を **Claude Code 先 → Minecraft `/connect` 後** にすること。Claude Code が `claude` 起動時に MCP サーバ（`run-server.cmd`）を spawn してポート 8001 を listen するため、それより先に Minecraft 側で `/connect` してもサーバが居なくて失敗する。

   ```powershell
   cd <PROJECT_DIR>
   claude
   ```

   起動後の流れ：

   1. 初回認証（Anthropic アカウントのブラウザログイン or API キー）
   2. `.mcp.json` の `minecraft-bedrock` サーバ承認プロンプト → **Yes / Always** を選ぶ
   3. CLAUDE.md が自動で読まれて行動原則が効く
   4. Minecraft 側でワールドに入り、チャットで `/connect localhost:8001/ws`
   5. Claude Code 側で「いまどこにいる？座標を教えて」など `player_*` 系の読み取り操作で疎通確認

   再起動するときも同じ順序を守る。Minecraft をワールドから抜けると WebSocket が切れるので、戻ったら `/connect` をやり直す。

### Claude Desktop と同居する場合の重要な注意

MCP サーバはポート 8001 で WebSocket をバインドする。**Claude Desktop と Claude Code が両方同時に起動すると、後発側が `EADDRINUSE` で起動失敗する**。

| 状況 | どうなるか |
| --- | --- |
| Claude Desktop だけ起動 | OK（既存のフロー） |
| Claude Code だけ起動 | OK |
| 両方同時に起動 | ❌ 後発が落ちる、または既存接続が切れる |

回避策はどちらかを完全終了してからもう一方を起動すること。タスクトレイに残っている Claude Desktop は **完全終了**（タスクトレイ右クリック → Quit）するまで MCP サーバを掴んでいる点に注意。

恒久的に両方同居させたい場合は、片方のポートを変えればよい。**サーバの改造は不要** — `server/src/server.ts` は最初から `--port=8002` 形式のコマンドライン引数を受け付ける（`--lang=ja` も同様）。Linux 側なら `./apply-config.sh --port 8002`、Windows 側なら `.mcp.json` / `claude_desktop_config.json` の `args` に `--port=8002` を足す。

### Claude Code で詰まりやすいポイント

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| `claude` 実行時に「スクリプトの実行が無効」 | PowerShell の ExecutionPolicy が `Restricted` で `claude.ps1` が弾かれる | `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`（管理者不要）。または `claude.cmd` を直接呼ぶ |
| `claude` 起動時に MCP サーバが緑にならない | `run-server.cmd` のパスが環境と合っていない／Node.js の build が完了していない | `.mcp.json` の絶対パスを確認、`setup.ps1` 完了済みか確認 |
| Minecraft で `/connect` しても無応答 | `claude` を起動する前に `/connect` した、またはループバック例外未設定 | まず `claude` を起動してから Minecraft で `/connect`。初回はループバック例外（`enable-connect.ps1`）も必要 |
| Claude Code 起動直後に `EADDRINUSE` | Claude Desktop が裏で生きていてポート 8001 を掴んでいる | Claude Desktop をタスクトレイから完全終了 |
| `install-claude-code.ps1` 等のリポ内 `.ps1` を編集したら「文字列に終端記号 `"` がありません」 | PowerShell 5.x は BOMなし UTF-8 を Shift-JIS と誤認して日本語コメントが文字化けする | エディタで「UTF-8 with BOM」で保存し直す（VS Code なら右下の `UTF-8` → `Save with Encoding`） |

### Claude Code で得をする場面

- ターミナルとエディタの隣で動かしたい（チャットウィンドウを切り替えなくていい）
- ファイル操作と Minecraft 操作を同じセッションでやりたい（建築ログを `.md` に書きながら建築するなど）
- スクリプト化したい（`claude -p "天気を晴れにして" --print` のような非対話実行）

逆に Claude Desktop が向いているのは: 雑談を挟みながらゆっくり進める、複数の Project を切り替える、画像を貼って指示する、など。

## WSL2 / Linux から使う

Windows 側の Minecraft はそのままに、**MCP サーバだけを WSL2（Linux）で動かす**構成。Claude Code を WSL2 のターミナルから使いたい場合はこちら。

### 仕組み

```
[WSL2 の claude CLI] ──MCP(stdio)──▶ [Node.js MCPサーバ (run-server.sh)] ──WebSocket──▶ [Windows の Minecraft]
```

Windows 版との違いは MCP サーバの居場所だけ。Minecraft は Windows 側のまま動く。

### セットアップ

```bash
./setup.sh          # submodule 同期 + npm install + パッチ + build
./apply-config.sh   # .mcp.json を生成
claude              # 起動してから Minecraft 側で /connect
```

`.ps1` 版と1対1で対応する：

| Windows | WSL2 / Linux |
| --- | --- |
| `setup.ps1` | `setup.sh` |
| `run-server.cmd` | `run-server.sh` |
| `apply-config.ps1` | `apply-config.sh` |
| （なし） | `scripts/wsl-ip.sh` — 接続先アドレスの取得 |
| （なし） | `scripts/patch-socket-be.js` — 後述のクラッシュ対策 |

`enable-connect.ps1`（ループバック例外）は Windows 側の設定なので、WSL2 構成でも**そのまま Windows 側で一度実行しておく**。

### localhost では繋がらない（重要）

Minecraft は Windows 側の UWP アプリなので、**`/connect localhost:8001/ws` は WSL2 のサーバに届かない**。ループバック例外を入れても同じ。WSL2 の NAT アドレスを直接指定する。

```bash
./scripts/wsl-ip.sh     # 例: 172.29.198.82
```

```
/connect 172.29.198.82:8001/ws
```

このアドレスは **WSL を再起動するたびに変わる**ので、固定で覚えず毎回 `wsl-ip.sh` で取得する。`setup.sh` と `apply-config.sh` は完了時に現在のアドレス入りのコマンドを表示する。

実測環境: Windows 11 build 26200 / WSL 2.4.13 / カーネル 5.15.167.4、`.wslconfig` なし（NAT モード）。**ミラーモード（`networkingMode=mirrored`）への変更は不要**だった。

### 複数プロジェクトのワークスペースで使う

Claude Code は**起動ディレクトリの `.mcp.json` しか読まない**。このリポジトリを大きなワークスペースの一部（例: `projects/` 配下）として使っている場合、ここで `claude` を起動すると他のプロジェクトが見えないセッションになる。設定をワークスペースのルートに置けばよい。

```bash
./apply-config.sh --output-dir /path/to/workspace
cd /path/to/workspace && claude
```

MCP サーバは絶対パスで参照されるので、`.mcp.json` はどこに置いても動く。ただしその絶対パスはマシン固有なので、置き先のリポジトリでは `.gitignore` に `.mcp.json` を加えること（ignore されていなければ `apply-config.sh` が警告する）。

なお `CLAUDE.md`（この後の「Project に入れておくと便利な指示」と同内容）も**起動ディレクトリのものしか読まれない**。ルートで起動する構成にした場合は、ルートの `CLAUDE.md` から「Minecraft ツールを使う前に `<このリポ>/CLAUDE.md` を読むこと」と参照させないと、行動原則が効かないまま操作することになる。

### なぜ上流を直接使わないのか

`server/` は上流そのものではなく、[dobachi/minecraft-bedrock-education-mcp](https://github.com/dobachi/minecraft-bedrock-education-mcp) の `legacy-chat-receive` ブランチを submodule として**コミット単位で固定**している。

理由は 2 つある。

**1. 上流が 2026-08 に全面書き換えされた**

アドオン経由のブリッジ方式に作り替えられ（ポート 19131、チャット行を転送路として使用）、このドキュメントが前提にしているツール群（`build_cube` / `agent` / `world` など）は**残っていない**。上流の最新に追従すると環境ごと別物になる。移行するかどうかは、必要になった時点で改めて判断する。

**2. ゲーム内チャットの受信を足してある**

上流（書き換え前）はチャットの送信しかできず、プレイヤーの発言は MCP クライアントに届かない。フォーク側で `PlayerChat` / `PlayerMessage` を購読して上限付きバッファに溜め、`world get_chat` として取り出せるようにしている。

ブランチ先端ではなく submodule で SHA を固定しているのは、知らないうちに中身が変わるのを防ぐため。版を上げるときは `server/` で目的のコミットに切り替え、親リポジトリで `git add server` してコミットする。

### socket-be のクラッシュ対策

**socket-be 2.6.0 以上**という下限は submodule 側の `package.json` に入れてある。加えて `setup.sh` が `scripts/patch-socket-be.js` でパッチを当てる。理由は 2 つある。

**1. マルチプレイで接続直後に落ちる（2.3.1）**

上流の lockfile が固定している 2.3.1 は、`World.getPlayerDetail()` が `listd stats` の応答を**コマンドの成否を確認する前に**パースする。マルチプレイサーバではこのコマンドが失敗するため `res.details` が undefined になり、`.match()` で TypeError。上流もこの危険を認識していて、**2.6.0 では `getPlayerDetail` / `Player.load` / `getDetails` を「マルチプレイでワールドをクラッシュさせうる」として意図的に無効化**している。

**2. 切断時にプロセスごと死ぬ（2.6.0 でも未修正）**

`Network.onConnectionClose()` が、World 登録の済んでいない接続に対して `world.onDisconnect()` を nil チェックなしで呼ぶ。`ws` の close イベントから投げられるので誰も catch できず、**MCP サーバのプロセス全体が落ちる**（＝ Claude Code の MCP 接続も切れる）。`scripts/patch-socket-be.js` がこれをガードする。冪等なので何度実行してもよく、上流が修正してコードの形が変われば `MISS` で失敗して知らせる。

**副作用**: 上記の無効化により、プレイヤーの `uuid` / `deviceId` は空、`isLoaded` は常に false になる。`world get_players` の `isLocal` も当てにならない（全員 false になる）。ローカルプレイヤーの判定には `player get_info` の `isLocalPlayer` を使うこと。

### ゲームが重いと感じたら（プレイヤー一覧のポーリング）

socket-be は接続中のワールドごとに、入退室を検知するため定期的に `list` コマンドをゲームへ実行する。**上流の既定値は 1 秒間隔**で、繋いでいる間ずっと走り続ける。

WSL2 構成では 1 往復がおよそ 150ms（`world get_connection_info` の `averagePing` で実測）かかり、コマンドは直列化されるため、この常時ポーリングがゲーム側の体感を重くする。複数人がそれぞれ `/connect` すると接続数の分だけ倍になる。

そこで submodule 側で**既定を 10 秒に緩めてある**。変えたい場合は `--list-interval=<ミリ秒>` を渡す（`--port=` と同じ形式）。

```bash
./apply-config.sh --output-dir .   # 生成後、.mcp.json の args に --list-interval=1000 を足す
```

代償は入退室の検知が最大でその間隔ぶん遅れること。再接続への追従はこれとは別に 30 秒ごとのチェックが見ているので、そちらは影響を受けない。

### 繋がらないときの切り分け

`/connect` が無反応・失敗するとき、原因を「サーバ側の禁止」と「こちら側の設定」に分ける。**上から順に進めると、疑わしい範囲が段階的に狭まる。**

**1. MCP サーバは動いているか**

```bash
ss -tln | grep 8001
```

`*:8001` と出れば全インターフェースで待ち受けている。何も出なければ Claude Code が起動していないか、MCP サーバが落ちている。

**2. Windows から WSL2 に TCP が通るか**

```bash
powershell.exe -NoProfile -Command "(Test-NetConnection -ComputerName $(./scripts/wsl-ip.sh) -Port 8001).TcpTestSucceeded"
```

`True` なら経路は生きている。ここで失敗するならアドレス違いかファイアウォール。

**3. シングルプレイで繋がるか**

チート ON のシングルプレイワールドで `/connect` を試す。ここで成功して友人サーバで失敗するなら、**原因はサーバ側**（`/connect` の禁止、チート無効、OP 権限なし）と確定し、こちら側の設定は白。この対照実験を先にやらないと、以降の調査が無駄になる。

**4. エラーメッセージで切り分ける**

| 表示 | 原因 |
| --- | --- |
| 「Websocketサーバーへの要求が拒否されました」 | 暗号化WebSocket要求が ON（→ 4-b） |
| 無反応・タイムアウト | アドレスが `localhost` になっている／サーバが起動していない |
| 「構文エラー」 | そのワールドでコマンドが無効（チート OFF） |
| 繋がった直後に切れる | socket-be のクラッシュ（→ `logs/server.log` を確認） |

**5. サーバ側のログを見る**

```bash
tail -f logs/server.log
```

接続後にスタックトレースが出て止まっていれば MCP サーバのクラッシュ。プロセスの生死は `ss -tln | grep 8001` で分かる（LISTEN が消えていれば死んでいる）。

> **Minecraft の画面表示は接続状態の証拠にならない。** WebSocket が切れても Minecraft は明示的に知らせないことがある。ワールド内に Agent が見えていても接続とは無関係（Agent は Education 機能のエンティティで、MCP 接続とは独立して存在する）。必ずサーバ側で確認すること。

### ポートを掴めるのは1プロセスだけ

Claude Code は起動時に MCP サーバを spawn する。そのため**検証目的で `run-server.sh` を手動起動したまま `claude` を起動すると、後発が `EADDRINUSE` で失敗する**。手動起動したら必ず止めること。

```bash
pgrep -af "server/dist/server.js"    # 動いているものを確認
```

## Claude Desktop の Project に入れておくと便利な指示

Claude Desktop には **Project** 機能があり、プロジェクト単位で「カスタム指示（custom instructions / system prompt）」を設定できる。Minecraft操作専用のプロジェクトを作ってこの指示を貼っておくと、毎回前置きを書かなくても期待通りの挙動になる。

### Project の作り方

1. Claude Desktop アプリ左メニュー **Projects → New project**
2. 名前を例えば「Minecraft Bedrock 操作」にする
3. プロジェクト画面の **Custom instructions** に下の指示を貼る
4. 必要なら **Project knowledge** にこのリポの `README.md` をアップロード（ツール一覧やコマンド規則をClaudeが参照できるようになる）

### カスタム指示のサンプル

そのまま貼って使える日本語版：

````markdown
あなたはMinecraft Bedrock Editionをローカル接続経由で操作するアシスタントです。Mming-Lab の minecraft-bedrock-mcp-server（WebSocket経由）が接続済みである前提で動作してください。

# 行動原則

1. **状態確認を先にする**：建築や移動の前に、`player_*` 系で現在位置・体力・ディメンション・ゲームモードを取得してから計画を立てる。座標を仮定で進めない。
2. **小さく作って広げる**：`build_cube` などのサイズは初回は5×5×5以内、確認できたら段階的に大きくする。一度に50×50×50を超えるリクエストはタイムアウトの可能性があるので、ユーザに分割を提案する。

3. **往復数を最小化（重要）**：WebSocketは1コマンド=1ラウンドトリップで直列化されるため、コマンド数を減らすことが体感速度に直結する：
   - 同じ素材の連続範囲は必ず `/fill` 1個に集約（個別 `setblock` のループは避ける）
   - 離散配置でも同素材なら `sequence` ツールで束ねる（存在する場合）
   - 一塊の建築は `build_cube` / `build_sphere` / `build_cylinder` / `build_line` を最優先（内部で `/fill` 化される）
   - 応答が30秒返らないツール呼び出しは再試行せず、範囲を縮小して再構成する
4. **足元を埋めない**：ユーザのキャラクター位置（X,Y,Z）に直接ブロックを置かない。窒息やめり込みを起こす。最低でもY+2以上、または周囲1ブロックずらす。
5. **既存構造の上書きを警告**：`blocks_*` で対象範囲のブロックを下調べし、空気以外が含まれる場合は「既存ブロックを上書きするが進めてよいか」を確認する。
6. **破壊的コマンドの確認**：プレイヤーキル、爆発、`/fill` の大範囲、天候・難易度の永続変更など、戻しにくい操作はユーザに一度確認する。
7. **座標系の前提**：BedrockはYが上方向、Xが東(+)/西(-)、Zが南(+)/北(-)。「前」「後ろ」は向き依存なので、ユーザが「前」と言ったら一度向き（rotation）を取得するか、東西南北で確認を取る。
8. **ブロック名はBedrock ID**：`minecraft:stone`、`minecraft:glass`、`minecraft:diamond_block` のような正式IDを使う。日本語の通称（「石」「ガラス」）はIDに変換してから呼び出す。
9. **Agent系の前提確認**：`agent_*` 系のツールは、ワールドが「Education」実験機能ONで作成されている必要がある。最初に Agent 関連の依頼を受けたら、まず召喚を試して反応がなければ「このワールドは Education 機能がOFFの可能性がある。新規ワールド作成時にONにする必要がある」と説明する。
10. **Wikiは積極活用**：レシピ・mob挙動・ブロック特性が必要な時は `minecraft_wiki` を先に引く。記憶に頼らない。

# 応答スタイル

- 各ツール呼び出しの前に「これから何をするか」を1〜2行で予告する
- 実行後は「何が起きたか（座標・個数・結果）」を要約する
- 失敗時は推測で繰り返さず、エラー内容を共有してユーザに次の判断を仰ぐ
- 大規模な建築リクエストは、最初に**設計案（材質・サイズ・配置）と概算ブロック数**を提示してから着手する

# 不明確な要求への対応

- 「目の前」「あっち」など曖昧な方向指示は、現在の rotation を取得して東西南北で言い換える
- 「派手にして」「いい感じに」など抽象的な要求は、2〜3案（モダン/古城/有機的 など）を提示して選んでもらう
````

### 軽量版（短い方が良ければ）

````markdown
あなたはMinecraft Bedrockをminecraft-bedrock-mcp-server経由で操作するアシスタント。

- 建築前に必ず `player_*` で現在位置と向きを取得する
- 初回は5×5×5以内で試し、問題なければ拡大する
- **往復数を最小化**：連続範囲は `/fill` 1個、一塊の形状は `build_*` を使い、個別 `setblock` ループは避ける
- 応答が30秒返らないツール呼び出しは再試行せず、範囲を縮小して再構成する
- ユーザの足元には絶対にブロックを置かない（Y+2以上）
- ブロックは `minecraft:stone` 形式のBedrock IDで指定する
- 戻しにくい操作（広範囲fill、天候永続変更、kill）は事前確認する
- Agent系を依頼されたら最初に召喚を試し、無反応なら「ワールド作成時に Education 機能 ON が必要」と説明する
- 不明な仕様は記憶ではなく `minecraft_wiki` を引く
````

### Project knowledge に入れると効くもの

- このリポの `README.md`（ツール一覧・接続前提）
- 自分のワールド固有の情報（建築ルール、座標メモ、テクスチャパック制約 など）を別ファイルに書いて追加

## `scripts/` フォルダ

`scripts/` は **ユーザが自由にスクリプトを置ける作業スペース**。リポジトリには空のまま含めてある（`.gitkeep` で維持）。用途は限定していないので、例えば次のような使い方を想定している：

- 自作の建築用 PowerShell / Node スクリプト
- 定型コマンドを束ねたバッチ（`/connect` 後に決まった天候・時刻にする手順など）
- Claude に「`scripts/build-castle.ps1` を実行して」のように呼ばせる固定置き場

中身の管理（コミットするか、`.gitignore` に追加するか）は各自の運用に任せる。**個人用のコミットしたくないスクリプトは `scripts/private/` 以下に置けば自動で gitignore される**（`.gitignore` に `scripts/private/` を登録済み）。

## ログを見る

MCPサーバの動作確認・遅延要因の特定には、サーバが出す stderr ログを残しておくのが有効。`claude_desktop_config.example.json` は **`run-server.cmd` 経由で node を起動**するように構成されており、stderr が `logs/server.log` に追記される（stdout は MCPプロトコルが使うので触らない）。

### ログの場所

```
<PROJECT_DIR>\logs\server.log
```

セッション境界には `=== YYYY/MM/DD HH:MM:SS server start (pid=...) ===` のヘッダが入る。

### リアルタイムで眺める

PowerShell で別ウィンドウを開いて：

```powershell
cd <PROJECT_DIR>
Get-Content -Wait -Tail 50 .\logs\server.log
```

`-Wait` で `tail -f` 相当。Minecraftで `/connect` した瞬間や、Claudeから建築コマンドを叩いた時にどんなWebSocketメッセージが流れているかが見える。

### ログをリセット／圧縮

ログは追記なので長くなりがち。気になったら手動でリネーム：

```powershell
Move-Item .\logs\server.log .\logs\server-$(Get-Date -Format 'yyyyMMdd-HHmmss').log
```

> Claude Desktop が MCPサーバを使用中はファイルがロックされる可能性あり。一度 Claude Desktop を完全終了してから操作するのが安全。

### よくある手がかり

| ログに出る内容（例） | 意味 |
| --- | --- |
| `WebSocket client connected` | Minecraft 側の `/connect` が成功 |
| `WebSocket client disconnected` | Minecraft が落ちた／ワールドを離れた |
| `executing command: /fill ...` | `build_*` 系が一括 fill コマンドに展開された |
| `executing command: /setblock ...` がループ | 単発 setblock の繰り返し → 体感が遅い原因 |
| `Connection refused` | ポート8001がふさがっている／別プロセスが先に起動済み |
| `EADDRINUSE` | 同上 |

## 動作が遅い時の対処

### 構造的な原因

1. **1コマンド=1往復**：WebSocketの `commandRequest`/`commandResponse` は requestId で対応付けて応答待ちで直列化される。窓を11個 `setblock` で配置 = 11ラウンドトリップ。一方 `/fill` で外殻637ブロックは1往復で完了する。
2. **Bedrock のコマンドキューがティック単位で消化**：50ms/tick。並列に投げ込んでも内部で順番待ちになる。
3. **応答取りこぼし → 4分タイムアウト**：MCPクライアントの既定タイムアウトは240秒。サーバが `commandResponse` を取りこぼすとClaude側は無言で待ち続けてセッションが落ちる。

### プロンプト側でできる高速化

| 悪い例 | 良い例 | 理由 |
| --- | --- | --- |
| 「(x1,y,z),(x2,y,z),(x3,y,z) にガラスを置いて」 | 「`/fill x1 y z x3 y z glass` で一括」 | 3往復→1往復 |
| 「足元から順に1ブロックずつ円形に積んで」 | 「`build_cylinder` で半径Rの円柱を建てて」 | 内部で fill 化される |
| 「窓を4枚、北側に間隔3で空けて」 | 「`/fill` で4箇所の `air` を順に打って」もしくは「sequence ツールで4回まとめ送信」 | 個別 setblock を避ける |

### Project カスタム指示への追記推奨

[後述のカスタム指示](#claude-desktop-の-project-に入れておくと便利な指示)に以下を加えると、Claudeが自動的に往復数を減らす方向で計画してくれる：

```markdown
- **往復数を最小化**：同じ素材の連続範囲は必ず `/fill` 1コマンドに集約。離散配置でも同素材なら sequence ツールで束ねる
- **一塊の建築は build_* を最優先**：build_cube / build_sphere / build_cylinder / build_line は内部で /fill 化されるため最速
- **応答が30秒返らないツール呼び出しは諦める**：再試行ではなく、範囲を縮小して再構成する
```

### サーバ側で確認したい点（中期改善）

- `server\src\` 内で `requestId` と `commandResponse` の対応付けロジック
- Bedrockが `commandResponse` を返さないコマンド（例：失敗した setblock）のフォールバック
- 連続送信時のフロー制御（応答待ちでブロックする vs パイプライン化）

これらは Mming-Lab 上流リポへの issue/PR 案件。とりあえず実利重視ならプロンプト側の工夫で十分回避可能。

## 主なツール

MCPサーバが提供する主な機能：

- `agent_*` … Agent（ロボット）の召喚・移動・採掘・設置（ワールドで Education 機能を有効にした場合に利用可）
- `player_*` … プレイヤー位置・体力・インベントリ取得
- `world_*` … 天気・時間・難易度
- `blocks_*` … ブロック取得・設置
- `build_cube`, `build_sphere`, `build_cylinder`, `build_line` … 幾何建築
- `minecraft_wiki` … Wiki検索

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `setup.ps1 : スクリプトの実行が無効` | `powershell -ExecutionPolicy Bypass -File .\setup.ps1` で起動する |
| `node not found` / `git not found` | `winget install OpenJS.NodeJS.LTS` / `winget install Git.Git` 後、**PowerShellを開き直す** |
| `/connect` で「コマンドが見つかりません」 | チートが有効か確認。Realmsや一部サーバでは使えません |
| Claude にツールが出ない | Claude Desktop を完全終了→再起動。`claude_desktop_config.json` のJSONが壊れていないか確認 |
| ポート8001が使えない | `setup.ps1` で別ポートを指定して再ビルド |
| 文字化け | PowerShell を `chcp 65001` でUTF-8にする |

## GitHubに公開する（任意）

このセットアップ一式を自分のGitHubに上げるには、`github-push.ps1` を使う。

### 前提：gh の初期設定

```powershell
# gh CLI の導入（未導入なら）
winget install GitHub.cli
# 入れたら PowerShell を開き直す

# GitHubアカウントでログイン（ブラウザが開くのでデバイスコードを入力）
gh auth login
# 選択: GitHub.com -> SSH -> Generate a new SSH key (or use existing) -> Login with a web browser
```

`gh auth status` で認証済みになっていれば準備OK。`github-push.ps1` がSSH鍵の生成・登録・known_hosts追加まで自動でやるので、手動セットアップは不要。

> **メモ：** このプロジェクトはSSH方式でpushする。HTTPS方式に変えたい場合はスクリプトの該当箇所（`gh config set git_protocol`、remote URLの組み立て）を `https://github.com/...` に書き換える。

### git identityの方針：グローバルではなくローカル設定

**事故防止のため、git の `user.name` / `user.email` はグローバルには設定しない。** リポジトリごと（`--local`）に設定する。`github-push.ps1` がこのリポ用のidentityを自動で `--local` に書き込むので、ユーザ側で手動設定は不要。

もし過去にグローバル設定してしまっていたら解除しておく：

```powershell
git config --global --unset user.name
git config --global --unset user.email
```

スクリプト冒頭の `$LOCAL_GIT_USER` / `$LOCAL_GIT_EMAIL` を必要に応じて編集すれば、別の identity でコミットできる。

### 初回push

`github-push.ps1` 冒頭の以下を **必ず自分の値に編集してから**実行する：

```powershell
$REPO_NAME       = "minecraft-claude"           # GitHub上のリポ名
$VISIBILITY      = "public"                     # public または private
$LOCAL_GIT_USER  = "your-github-username"       # コミット署名のユーザ名
$LOCAL_GIT_EMAIL = "you@example.com"            # コミット署名のメール
```

その後：

```powershell
cd <PROJECT_DIR>
powershell -ExecutionPolicy Bypass -File .\github-push.ps1
```

スクリプトは以下を順に行う：

1. git / gh の存在と認証状態をチェック
2. SSH鍵の生成・GitHub登録・known_hosts追加（必要なら）
3. `git init` → このリポ専用の identity を `--local` 設定 → 全ファイル add → コミット
4. GitHub に `<自分のアカウント>/<REPO_NAME>` を作成（既にあればスキップ）
5. `origin` に push

`claude_desktop_config.json`（個人パス入り）は `.gitignore` で除外している。`server/` は submodule として追跡しているので、clone するときは `--recurse-submodules` を付けるか、後から `git submodule update --init` を実行する。

### 2回目以降の更新

```powershell
git add -A
git commit -m "メッセージ"
git push
```

## 参考リンク

- [Mming-Lab/minecraft-bedrock-mcp-server (GitHub)](https://github.com/Mming-Lab/minecraft-bedrock-mcp-server)
- [PulseMCP紹介ページ](https://www.pulsemcp.com/servers/mming-lab-minecraft-bedrock)
- [Glama紹介ページ](https://glama.ai/mcp/servers/@Mming-Lab/minecraft-bedrock-mcp-server)
