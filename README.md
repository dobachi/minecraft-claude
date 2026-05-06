# Claude × Minecraft Bedrock 連携セットアップ

Windows + Minecraft Bedrock Edition を Claude Desktop から操作するための環境構築ガイド。
[Mming-Lab/minecraft-bedrock-mcp-server](https://github.com/Mming-Lab/minecraft-bedrock-mcp-server) を利用する。

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
cd J:\minecraft\minecraft-claude\minecraft
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`server/` 配下にMCPサーバが clone & build される。

> `ExecutionPolicy` でブロックされるのを回避するため必ず `-ExecutionPolicy Bypass` を付けて起動する。恒久的に許可したい場合は管理者PowerShellで一度だけ：
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

### 3. Claude Desktop の設定ファイルを編集

`%APPDATA%\Claude\claude_desktop_config.json` を開いて、`claude_desktop_config.example.json` の内容を `mcpServers` にマージする。Claude Desktop を **完全終了 → 再起動**（タスクトレイ常駐も終了させる）。

### 4. Minecraft 側で接続

1. 動作確認用にシングルプレイのワールドを「チートON」で作成
2. ワールドに入ったらチャットを開いて以下を実行：
   ```
   /connect localhost:8001/ws
   ```
3. 「接続しました」と出れば成功

### 5. Claude から操作

Claude Desktop で「目の前に石のキューブを建てて」「半径10の球体を作って」などと指示。

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
# 選択: GitHub.com -> HTTPS -> Yes (Git操作も認証) -> Login with a web browser
```

`gh auth status` で認証済みになっていれば準備OK。

### git identityの方針：グローバルではなくローカル設定

**事故防止のため、git の `user.name` / `user.email` はグローバルには設定しない。** リポジトリごと（`--local`）に設定する。`github-push.ps1` がこのリポ用のidentityを自動で `--local` に書き込むので、ユーザ側で手動設定は不要。

もし過去にグローバル設定してしまっていたら解除しておく：

```powershell
git config --global --unset user.name
git config --global --unset user.email
```

スクリプト冒頭の `$LOCAL_GIT_USER` / `$LOCAL_GIT_EMAIL` を必要に応じて編集すれば、別の identity でコミットできる。

### 初回push

```powershell
cd J:\minecraft\minecraft-claude\minecraft
powershell -ExecutionPolicy Bypass -File .\github-push.ps1
```

スクリプトは以下を順に行う：

1. git / gh の存在と認証状態をチェック
2. `git init` → 全ファイル add → コミット
3. GitHub に `<自分のアカウント>/minecraft-claude` をPublicで作成（既にあればスキップ）
4. `origin` に push

`server/`（clone した Mming-Lab 本体）と `claude_desktop_config.json`（個人パス入り）は `.gitignore` で除外している。リポ名や公開範囲を変えたい場合は `github-push.ps1` 冒頭の `$REPO_NAME` / `$VISIBILITY` を編集。

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
