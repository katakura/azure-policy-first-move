# 共同利用 Azure サブスクリプションの「最初の一手」Policy セット

[English version / 英語版はこちら](README.md)

チームで 1 つのサブスクリプションを共同利用するときに、荒れる前に入れておく
Azure Policy の最小セット。main.bicep 1 ファイルをデプロイするだけ。

Zenn 記事: （公開後にリンクを貼る）

## 入っているもの

| # | Policy | 効果 | ねらい |
|---|---|---|---|
| 1 | RG 作成時に `projectName` / `owner` / `expires` タグを強制 | deny | 誰の何のためのリソースか分からない RG をなくす |
| 2 | RG のタグを配下リソースへ自動継承 | modify | リソース単位でもコスト集計・棚卸しできるように |
| 3 | リージョンを japaneast / japanwest に制限（RG とリソース両方） | deny (builtin) | 国外リージョンへの誤作成を防ぐ |

## デプロイ

```bash
az deployment sub create -l japaneast -f main.bicep
```

いきなり deny が怖い場合は Audit で様子見:

```bash
az deployment sub create -l japaneast -f main.bicep -p tagEffect=Audit
```

## expires 切れ RG の棚卸し

```bash
./find-expired-rgs.sh
```

owner タグの持ち主に「まだ使ってますか？」と聞いて回る。これだけで無駄な課金がかなり減る。

## 注意

- `modify` の既存リソースへの適用は修復タスク（remediation）の実行が必要
- ビルトインのリージョン制限は `location: global` のリソース（Front Door、DNS ゾーン等）を
  除外済みで、制限しない（= グローバルサービスの禁止には使えない。必要ならタイプ指定の deny を追加）
- ビルトイン定義 ID（Allowed locations）は割り当て前に `az policy definition show` で要確認
