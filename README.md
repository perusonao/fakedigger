# FakeDigger

Flutterで制作する、ローカルファーストの推理カードゲームUIプロトタイプです。

## 技術構成

- Flutter / Dart
- Riverpod（ゲームUIの状態管理）
- go_router（画面遷移）
- Firebaseはオンライン対戦を追加する段階で導入予定

## 起動

Flutter SDKをインストール後、次のコマンドを実行します。

```sh
flutter pub get
flutter run -d chrome
```

### Dev Container（推奨）

ローカルにFlutter SDKを入れずに実行する場合は、DockerとVS Codeの
Dev Containers拡張機能を用意し、このリポジトリを **Reopen in Container** で
開いてください。安定版Flutter、Dart/Flutter拡張機能、Web用ポート8080が
自動で構成されます。

コンテナのターミナルで次を実行すると、ブラウザから確認できます。

```sh
make run
```

VS Codeを使わない場合も、`.devcontainer/devcontainer.json` に記載された
Flutterイメージからコンテナを起動し、`make setup` と `make run` を実行できます。

## チェック

```sh
flutter analyze
flutter test
```

同じチェックは次のコマンドにまとめています。

```sh
make check
make build
```

プッシュおよびPull RequestではGitHub Actionsがフォーマット、静的解析、
Widgetテスト、Webビルドを自動実行します。

## 現在の実装

- デスクトップとモバイルに対応するレスポンシブなゲームボード
- プレイヤー、ラウンド、8つの山札、ターゲット、推理メモ
- 選択可能な山札と戦略カード
- 推理メモ編集ダイアログ
- 操作説明と得点結果のサンプル表示

現在はモックデータによるローカルUIです。ゲームルール処理、Firebase接続、オンライン対戦は今後の段階で追加します。
