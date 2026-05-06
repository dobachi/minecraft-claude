# Claude × Minecraft Bedrock 連携セットアップ

Windows + Minecraft Bedrock Edition を Claude Desktop から操作するための環境構築ガイド。
[Mming-Lab/minecraft-bedrock-mcp-server](https://github.com/Mming-Lab/minecraft-bedrock-mcp-server) を利用する。

> **本READMEの表記について**
> このREADMEとサンプルファイルでは、各自が clone / 配置するフォルダのフルパスを **`<PROJECT_DIR>`** と表記しています。実行時はあなたの環境のパス（例：`C:\Users\<USER>\projects\minecraft-claude` や `D:\workspace\minecraft-claude` など、自由）に読み替えてください。

## 仕組み（先に理解してください）

```
[Claude Desktop] ──MCP──▶ [Node.js MCPサーバ] ──WebSocket──▶ [Minecraft Bedrockクライアント（自分）]
```

- MCPサーバが PC のローカルポート（既定 8001）で WebSocket を待ち受ける。
- Minecraft 起動後、チャットに `/connect localhost:8001/ws` と打って接続する。
- Claude が出すコマンドは「**自分のキャラクター**」として実行される（別人格Botではない）。

### 友人サーバ参加についての重要な制約

このMCP方式は「自分のクライアント」を介してコマンドを送る仕組みのため、友人のサーバで使うには **次のいずれか** が必要です。

1. 友人のサーバで `/connect` コマンドの実行が許可されている（多くの公開サーバではブロックされる）
2. 友人のサーバでチート（cheats）が有効、かつ自分にOP権限がある
3. 友人のサーバが「Education Edition」または `allow-cheats: true` のローカル/専用サーバ

公開サーバ（Realms含む）では `/connect` がほぼ確実に拒否されます。試したい場合はまず **シングルプレイのワールドで動作確認** → **友人にサーバ設定を相談** の順で進めるのが安全です。

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

`server/` 配下にMCPサーバが clone & build される。

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

Claude Desktop アプリで自然言語で指示するだけ。次節の動作確認を順に試すと、各ツール群（読み取り系→書き込み系→建築系）が一通り動くか確認できる。

## 動作確認シナリオ

セットアップ完了後、Claude Desktop の新規チャットで以下を順に試す。各手順の **Claude側の応答** はモデルや会話の流れで多少変わるが、ツールが呼び出されて結果が返ってくれば成功。

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

### Step 4. Agent系（任意・要 Education機能）

`agent_*` 系は Education Edition の Agent（プログラミング教育用ロボット）の機能。Bedrock Retail版のシングルワールドでは Agent が出現しないので、このグループは**スキップしてOK**。Education機能を有効にしたワールドで「Agentを召喚して」「Agentを5マス前進させて」などを試す。

### 失敗時の切り分け

- **Step1も失敗する** → Minecraft↔MCPサーバの接続切れ。`/connect localhost:8001/ws` 再実行
- **Step1は成功、Step2〜3で失敗** → ワールドのチートがOFF／OP権限なし
- **Claude側でツールが選択されない** → `mcp__minecraft-bedrock__*` ツールが Claude Desktop に登録されているか確認。Claude Desktop を完全終了→再起動
- **特定のbuild系だけ失敗** → 範囲が大きすぎてサーバ側がタイムアウトしている可能性。サイズを小さくして試す

## 主なツール

MCPサーバが提供する主な機能：

- `agent_*` … Agent（ロボット）の移動・採掘・設置
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

`server/`（clone した Mming-Lab 本体）と `claude_desktop_config.json`（個人パス入り）は `.gitignore` で除外している。

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
