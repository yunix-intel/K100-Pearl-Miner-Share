[English](README.md) | [简体中文](README.zh-CN.md) | [한국어](README.ko.md) | **日本語**

# K100 Pearl (PRL) マイナー

Hygon K100_AI (gfx928 DCU) 用の Pearl (PRL) 採掘ソフトウェアです。
**バイナリのみの配布で、ソースコードは含まれません。**

---

## 📦 ダウンロード

**[➡️ v1.0.3 をダウンロード](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/tag/v1.0.3)**

| | |
|---|---|
| パッケージ | `k100-miner-v1.0.3-linux-x64.tar.gz` |
| サイズ | 31.3 MB |
| SHA256 | `217cbab42e38311b0b23e7fcab938f7e150b20c968be34d240189c16cb9a8665` |

```bash
wget https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases/download/v1.0.3/k100-miner-v1.0.3-linux-x64.tar.gz
sha256sum k100-miner-v1.0.3-linux-x64.tar.gz          # 上記の SHA256 と一致する必要があります
tar xzf k100-miner-v1.0.3-linux-x64.tar.gz
cd k100-miner-v1.0.3-linux-x64
sudo ./install.sh
```

> **このリポジトリにはドキュメントのみが含まれます。** バイナリは
> [Releases ページ](https://github.com/yunix-intel/K100-Pearl-Miner-Share/releases) でのみ配布しており、ミラーは公開していません。

---


> ## ⚠️ 開発者手数料の開示 — 使用前に必ずお読みください
>
> **本ソフトウェアは採掘時間の 2.0% を開発者に充てます。**
>
> | | |
> |---|---|
> | **率** | **2.0%**、*時間*で厳密に精算（72時間シミュレーション: 1.991%）|
> | **開発者ウォレット** | **バイナリ内で XOR 難読化 + チェックサム — 平文のコピーなし** |
> | **ウォレット指紋** | `sha256:6050486ad79f`（先頭 12 桁の 16 進数）|
> | **起動時** | `[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)` を出力 |
> | **採掘中** | アカウント切替のたびに累積比率を出力 — 2.0% 付近かを確認できます |
> | **無効化** | `DEV_FEE_PERMILLE=0`（自己テスト用。無効時は手数料なし）|
>
> ### 検証可能性についての正直な説明
>
> ウォレットは **XOR 難読化 + チェックサム**で保存されており、**暗号学的な意味での
> 暗号化ではありません。** `strings` では見つかりませんが、バイナリのペイロードを
> 展開すれば数分でアドレスを復元できます。**隠せているとは主張しません。**
>
> **実際に強制しているのは完全性です**: ウォレット暗号文・鍵・チェックサムの
> いずれかを改変すると、プログラムは起動を拒否します(`exit code 3`)。
> したがって手数料の宛先を変えることも、パッチで無効化することもできません。
>
> ログから検証できること: **率が実際に 2.0% であること**(アカウント切替のたびに累積統計を出力)。
>
> **暗号学的に隠された受取人が必要なら、このソフトウェアを使用しないでください。**
>
> **この率を受け入れられない場合は、このソフトウェアを使用しないでください。**

---

## 目次

- [📦 ダウンロード](#-ダウンロード)
- [概要](#概要)
- [動作要件](#動作要件)
- [インストール](#インストール)
- [使い方](#使い方)
- [状態の確認](#状態の確認)
- [停止](#停止)
- [開発者手数料の仕組み](#開発者手数料の仕組み)
- [よくある質問](#よくある質問)
- [トラブルシューティング](#トラブルシューティング)
- [バージョンとライセンス](#バージョンとライセンス)

---

## 概要

8 枚の K100_AI システム向けの完全な Pearl 採掘ソリューションです。
実測 **620 TH/s**（8 枚、プール集計基準）。

| 項目 | 値 |
|---|---|
| カードあたりハッシュレート | 72 TH/s |
| 8 枚合計 | 620 TH/s（プール表示値。ローリングウィンドウが埋まるにつれ上昇）|
| attempt あたり | 15.38 ms |
| 消費電力 | 400 W/カード（`power1_cap_max` — ハードウェア上限）|
| 温度 | Tj 78–82 °C |

> **⚠️ プール表示のハッシュレート ≈ 実値 × (稼働分 / 60)。**
> 起動直後は約 1/3 しか表示されず、1 時間経って初めて正確になります。

### 動作の概要

```
1. プールから job（header + target）を解析し job key を導出
2. GPU 上で A/B ノイズ行列を生成
3. attempt ごと: A 側の選択集合を準備し、MMA カーネルを実行
4. ヒット時: GPU が計算した chunk CV を再利用して proof をローカル生成・送信
5. プールは ~43 秒ごとに新 job を発行。B 側は job 単位でキャッシュ（reuse-B）
```

---

---

## ダウンロードの検証

**このリポジトリの Release ページが唯一の公式配布チャネルです。** ミラーはありません。

```bash
sha256sum k100-miner-v1.0.3-linux-x64.tar.gz
```

v1.0.1 の正しい値:

```
217cbab42e38311b0b23e7fcab938f7e150b20c968be34d240189c16cb9a8665
```

**チェックサムが一致しない場合は実行しないでください。** 誰かが再パッケージ
したものです。削除して Release ページから再ダウンロードしてください。

完全な整合性ポリシーとサプライチェーン問題の報告方法は
[SECURITY.md](SECURITY.md) を参照してください。

## 動作要件

| 項目 | 要件 |
|---|---|
| **ハードウェア** | Hygon K100_AI (gfx928) DCU、8 枚推奨 |
| **ドライバ** | Hygon DTK **26.04**（`/opt/dtk/dtk-26.04`）|
| **OS** | Linux x86_64、glibc **≥ 2.14**(バイナリ要件; Kylin V10 / glibc 2.28 で実測)|
| **メモリ** | ≥ 16 GB |
| **ディスク** | ≥ 200 MB(インストールツリー)|
| **`/tmp`** | カードあたり約 130 MB(Nuitka がプロセスごとに約 123 MB 展開); 8 枚で約 1 GB |
| **CPU** | チューニング済みのコア固定表は ≥116 論理コアが必要; それ未満なら均等割り当てに自動フォールバック |
| **ネットワーク** | プールへの外向き TCP 8048 |
| **権限** | root（`/opt/vllm-fork` へインストール）|

### 対応プール

```
prl-hk.kryptex.network:8048   (TLS, type:v2 / gzip proof)
```

> プールのエンドポイントはコンパイル済みです。アカウント
> （`--account WALLET/WORKER`）のみ利用者が指定します。

---

## インストール

### 手順 1 — DTK の確認

```bash
ls /opt/dtk/dtk-26.04/bin/hipcc    # 存在すること
/opt/dtk/dtk-26.04/bin/rocm-smi    # K100_AI が 8 枚見えること
```

失敗する場合は先に Hygon DTK 26.04 を導入してください。
**これがないとマイナーは起動しません。**

### 手順 2 — 展開

> まだダウンロードしていない場合は、上部の [📦 ダウンロード](#-ダウンロード) をご覧ください。


```bash
tar xzf k100-miner-v1.0.3-linux-x64.tar.gz
cd k100-miner-v1.0.3-linux-x64
```

内容:

```
k100-miner        マイナー本体（単一実行ファイル）
libpearl5.so      GPU カーネルライブラリ
install.sh        インストーラ
README.md         本ファイル
LICENSE           ライセンス条項
CHANGELOG.md      変更履歴
```

### 手順 3 — インストール

```bash
sudo ./install.sh
```

インストーラは最初に **7 項目の依存性チェック**(DTK 26.04、`hipcc`、`rocm-smi`、
検出カード数、glibc ≥ 2.14、`python3`、パッケージ内ファイル)を実行します。
いずれかが失敗すると**何もインストールせずに中止**し、終了コードは 2 です。

インストーラが配置するもの:

```
/opt/vllm-fork/k100-miner          実行ファイル
/opt/vllm-fork/libpearl5.so        GPU ライブラリ
/opt/vllm-fork/start.sh            8 枚ランチャー（CPU ピン留め込み）
/opt/vllm-fork/stop.sh             全停止
/opt/vllm-fork/stat.sh             状態レポート
/var/log/vllm-fork/                ログディレクトリ
```

確認:

```bash
ls -l /opt/vllm-fork/
/opt/vllm-fork/k100-miner --help
```

---

## 使い方

### 単一カードのスモークテスト（まずこれ）

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH

HIP_VISIBLE_DEVICES=0 /opt/vllm-fork/k100-miner \
    --account YOUR_WALLET/YOUR_WORKER \
    --m 8192 --n 65536 --k 2048
```

**10 秒以内に表示されるべき出力:**

```
[init] m=8192 n=65536 k=2048
[devfee] 2.0% 用于开发者 (钱包指纹 sha256:6050486ad79f)
[transport] TLS prl-hk.kryptex.network:8048 (TLSv1.3)
[transport] gzip proof negotiated (type:v2)
[transport] authorize id=3 result=True error=None
[session] {"header": "...", "height": "...", "job_id": "...", "target": "..."}
[init] nbits=0x... cert=3 sess_key=...
[session] backend ready ...
[compute] #10 hit=0 15.4ms MAC 71.8 TH/s
```

**✅ `authorize ... result=True` と `[compute]` 行が出ていれば、接続して計算中です。**

> ⚠️ `authorize result=True` は、渡した**文字列**をプールが受け付けたという意味だけです。
> ウォレットが実在するかは検証されません。`TEST/TESTW` のようなプレースホルダでも
> `result=True` になり、share も受理されます。**必ず自分の実ウォレットを使ってください。**
> 残高はプールのダッシュボードで確認するのが唯一の確実な方法です。

**❌ `target` が全て 0、または `[compute]` 行が無い場合は中止し、
[トラブルシューティング](#トラブルシューティング) を参照してください。**

### 8 枚での本番運用

```bash
# ランチャーが各カードを重複しない論理 CPU コア 4 個に固定します
sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

任意: 電力上限の変更（既定 400 W = ハードウェア最大）

```bash
POWER_W=350 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

### パラメータ

| パラメータ | 既定値 | 説明 |
|---|---|---|
| `--account` | **必須** | プールアカウント、形式 `WALLET/WORKER` |
| `--m` | 8192 | A 行列の行数（128 の倍数）|
| `--n` | 65536 | B 行列の列数（128 の倍数）|
| `--k` | 2048 | 共通次元（32 の倍数。≥ 16 × rank = 2048）|
| `--attempts` | 0 | 指定回数で終了。0 = 無制限 |
| `--dry-run` | off | 実際には送信せず表示のみ |
| `--test-job` | off | **プールに接続しない**。`target = 0` の偽 job を使用 |

> **⚠️ 実際の採掘では絶対に `--test-job` を使わないでください。**
> 偽 job（`target = 0`、ヒット確率 0）を掘るため、プールにはオフラインと表示され
> 収益はゼロになります。

### 環境変数

| 変数 | 説明 |
|---|---|
| `HIP_VISIBLE_DEVICES` | カード選択。例 `0` または `0,1,2,3` |
| `DEV_FEE_PERMILLE` | 開発者手数料（千分率、既定 `20` = 2.0%）。`0` で無効 |
| `LD_LIBRARY_PATH` | `/opt/dtk/dtk-26.04/lib64` を含めること |

### 正常な性能の目安

| 指標 | 期待値 |
|---|---|
| attempt あたり | 15.0 – 16.5 ms |
| カードあたり | 68 – 73 TH/s |
| 8 枚 | 550 – 580 TH/s（ローカル実測）|
| 消費電力 | 400 W 上限でカードあたり約 395 – 400 W |
| Tj | 78 – 82 °C |

---

## 状態の確認

```bash
/opt/vllm-fork/stat.sh
```

出力例:

```
=== カード別ハッシュレート ===
  gpu0   72.1 TH/s
  gpu1   71.8 TH/s
  ...
  ═══════════════
  合計 574 TH/s

=== share ===
  ローカル命中(MATCH)= 386
  送信(publish)=       384
  受理=                383
  拒否=                3

=== devfee 状態 ===
  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 2 次
```

### 手動確認

```bash
# 本当にプールへ接続しているか
grep 'authorize id=3 result=True' /var/log/vllm-fork/gpu0.log | head -1

# share の集計
# 注意: authorize の応答にも result=True が付きます — '◀ id=' で実際の share 応答のみ抽出
grep -c '\[MATCH\] ★★★'  /var/log/vllm-fork/gpu*.log                        # ローカル命中
grep -c '\[publish\] job='  /var/log/vllm-fork/gpu*.log                      # 送信済み
grep '◀ id=' /var/log/vllm-fork/gpu*.log | grep -c 'result=True'    # 受理
grep '◀ id=' /var/log/vllm-fork/gpu*.log | grep -c 'result=False'   # 拒否

# 開発者手数料 — 2.0% 付近か確認
grep 'devfee' /var/log/vllm-fork/gpu*.log | tail -5
```

> **プール表示のハッシュレートについて:** 約 60 分のローリング平均です。
> 起動直後は実値の約 1/3 しか見えません。**これは正常**で、
> share が失われているわけではありません。

---

## 停止

```bash
sudo /opt/vllm-fork/stop.sh
```

確認:

```bash
ps -ef | grep -c '[k]100-miner'    # 0 であること
```

---

## 開発者手数料の仕組み

**隠していません。以下が全機制です。**

### 1. share 数ではなく時間ベースのクォータ

```
あなたのために 49 秒採掘するごとに、開発者へ 1 秒を割り当てます（2%）
need = user_s × p/(1−p) の式で長期的な比率を偏らせません
```

素朴な方式は失敗します:

- 「owed > 0 で切替」は過払い（ユーザーの job 1 回の後に dev の job 1 回 ≈ 50%）
- 「dev 秒で減算」は過少払い（dev 区間自体も積算されるべき）

### 2. job 境界でのみ切替

```
プールは ~43 秒ごとに新 job を発行します。開発者アカウントへ切り替える際は
再認証し、ログで確認できます:

  [devfee] 切到开发者账户  devfee: dev 43s / user 2150s = 2.00% (目标 2.00%), 切换 1 次
```

### 3. ウォレットは難読化であり暗号化ではない

```
開発者ウォレットは平文の定数ではありません: XOR 難読化暗号文 + SHA256 整合性検査。

- バイナリに `strings` をかけてもアドレスの断片は出ません
- 暗号文 / 鍵 / チェックサムを 1 バイトでも変えると起動時に exit code 3

⚠️ これは難読化であり暗号化ではありません。バイナリのペイロードを展開すれば
   数分でアドレスを復元できます — 上部の「検証可能性についての正直な説明」参照。
   実際に強制しているのは完全性です: 手数料の宛先変更も無効化もできません。
```

### 4. 検証できること・できないこと

| | |
|---|---|
| ✅ **検証できる** | 率が実際に 2.0% であること（ログの累積統計）|
| ⚠️ **手間をかければ復元可能** | アドレスは XOR 難読化であり暗号学的な隠蔽ではない — ペイロードを展開すれば数分で復元 |
| ✅ **ただし改変は不可** | 暗号文 / 鍵 / チェックサムのいずれかを変更すると起動拒否 (`exit 3`) |

**⇒ 暗号学的に隠された受取先が必要なら、本ソフトウェアを使用しないでください。**

---

## よくある質問

### Q1. `libpearl5.so: cannot open shared object file`

GPU ライブラリが `/opt/vllm-fork/libpearl5.so` にありません。
`sudo ./install.sh` を再実行するか、`libpearl5.so` を手動でコピーしてください。

### Q2. `hipGetDeviceCount() = 0`

`LD_LIBRARY_PATH` に `lib64` が欠けています:

```bash
export LD_LIBRARY_PATH=/opt/dtk/dtk-26.04/lib64:/opt/dtk/dtk-26.04/lib:$LD_LIBRARY_PATH
```

### Q3. プールでオフライン表示 / ハッシュレート 0

1. ログに `authorize ... result=True` があるか確認
2. `--account` が `WALLET/WORKER`（間にスラッシュ）か確認
3. **`--test-job` を付けていないか確認** — 偽 job を掘るためプールには何も見えません

### Q4. `integrity check failed` で終了

埋め込み開発者ウォレットの SHA256 検査に失敗 — バイナリが改変されています。
公式リリースから再ダウンロードしてください。

### Q5. 電力が 280 W までしか上がらずハッシュレートが低い

手動起動ではなく `start.sh` を使ってください — 各カードを重複しない論理 CPU
コア 4 個に固定し、GPU が CPU 側の準備処理に飢えないようにします。
これだけでカードあたり 280 W → 399 W になります。

### Q6. 開発者手数料の率を変更できますか

`DEV_FEE_PERMILLE=0` で無効化できます。他の値も有効です（`=10` は 1%）。
**率を変えてもウォレットの整合性検査には影響しません。**

### Q7. 8 枚未満で動かせますか

可能です。`HIP_VISIBLE_DEVICES=0,1` なら 2 枚です。ほぼ線形にスケールします。

### Q8. プール表示が `stat.sh` より低いのはなぜ

プールは約 60 分のローリング平均です。また、プールは 1 hash = 1 MAC (M·N·K) で
集計しますが、一部ツールは 2·M·N·K (MADD) で報告します — 2 倍の差です。
本マイナーは MAC 基準で記録し、プールと一致します。

---

## トラブルシューティング

### 何も出力されない

```bash
/opt/vllm-fork/k100-miner --help     # バイナリ自体は動くか
ldd /opt/vllm-fork/k100-miner        # 共有ライブラリは解決するか
```

### `authorize ... result=False`

アカウント文字列が誤っています。厳密に `WALLET/WORKER` である必要があります
（kryptex は回線上 `wallet.worker` を使い、マイナーがスラッシュを変換します）。

### share は受理されるが `result=False` が多い（> 6%）

share が古くなっています。プールは ~43 秒ごとに job を変え、マイナーは 50
attempt ごとに新 job をポーリングします。少量の拒否（< 6%）は正常です。
それより大幅に高い場合は、プールへのネットワーク遅延を確認してください。

### 温度が 90 °C を超える

電力上限を下げてください:

```bash
POWER_W=300 sudo /opt/vllm-fork/start.sh YOUR_WALLET/YOUR_WORKER
```

> このカードの `power1_cap_max` は 400 W で、超える値はドライバに拒否されます。

### ログの場所

```
/var/log/vllm-fork/gpu0.log … gpu7.log
```

---

## バージョンとライセンス

[CHANGELOG.md](CHANGELOG.md) と [LICENSE](LICENSE) を参照。

**バイナリ配布のみ — ソースコードは提供されません。**

ライセンスはリバースエンジニアリング、整合性検査の改変、
開発者手数料機構の除去を禁止します。

| バージョン | 日付 | 備考 |
|---|---|---|
| 1.0.3 | 2026-11-24 | **セキュリティリリース.** プールへの TLS を**厳格検証**(v1.0.0–v1.0.2 は `CERT_NONE` で MITM 可能)。ライブラリパスのハードコードを廃止; `stat.sh` は `[MATCH]` で集計(出力されない `[HIT]` の代わり)、`authorize` を share として数えない; コア固定表を自動検出; インストール前に既存ファイルをバックアップ; `--account` 形式検証。ドキュメントを実バイナリに合わせて修正。|
| 1.0.2 | 2026-11-24 | **バイナリ再ビルド** (`ea683cbf`)。`--help` から未使用の `--model`/`--tensor-parallel-size` 等 8 引数を削除。`stop.sh` は `/proc/<pid>/exe` で厳密一致(無関係プロセスの誤殺を防止)。ログディレクトリ 700/600。インストール前依存性チェック。`start.sh` は `$DST` に追従。|
| 1.0.1 | 2026-11-24 | ドキュメント更新。バイナリは変更なし (md5 `7d2a12e5`)。同梱 README を更新; 再現可能ビルド用 `make_release.sh` を追加。|
| 1.0.0 | 2026-11-10 | 初のバイナリリリース。カードあたり 72 TH/s、8 枚で 620 TH/s。開発者手数料 2.0%。 |
