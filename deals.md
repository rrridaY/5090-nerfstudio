# 現状まとめ：nerfstudio Docker ビルドエラー

## 環境

| 項目 | 内容 |
| --- | --- |
| PC | Windows（GPU：NVIDIA RTX 5090搭載） |
| 仮想環境 | WSL2（Ubuntu 22.04、推定） |
| コンテナ基盤 | Docker（WSL2経由で動作） |
| 対象イメージ | nerfstudio の公式 Docker イメージ |

---

## やろうとしていること

新しいPCにnerfstudioの開発環境を構築する。

具体的には、WSL2上のDockerを使ってnerfstudioのDockerイメージをビルドし、RTX 5090のGPUを活用できる環境を整えることが目標。

---

## 発生しているエラー

### タイミング

`docker build` コマンド実行中（イメージのビルドフェーズ）

### エラー内容

Dockerイメージのビルド時に、Pythonパッケージ `pkg_resources` が見つからないというエラーが発生し、ビルドが失敗する。

```
ModuleNotFoundError: No module named 'pkg_resources'
```

（※ 実際のエラーメッセージは上記と多少異なる場合あり）

---

## エラーの原因（判明済み）

### 根本原因：RTX 5090 と nerfstudio 公式イメージの CUDA バージョン不一致

これは「バージョンを下げる」問題ではなく、**上げ方向の互換性問題**。

|  | バージョン |
| --- | --- |
| nerfstudio 公式 Docker ベースイメージ | `nvidia/cuda:11.8.0-devel-ubuntu22.04`（Python 3.10） |
| RTX 5090（Blackwell）が要求する CUDA | **12.8 以上**（アーキテクチャ: `sm_120`） |

nerfstudio の公式イメージは CUDA 11.8 ベースで作られており、RTX 5090 が必要とする CUDA 12.8 とは根本的に食い違っている。nerfstudio の GitHub Issues でも RTX 5090 対応は**2025年7月時点で未対応**として Feature Request が上がっている状態。

### `pkg_resources` エラーとの関係

`pkg_resources` は Python の `setuptools` に含まれるモジュール。Python 3.12 以降では `setuptools` がデフォルトでインストールされなくなったため、ビルド環境の Python / pip が新しい場合にこのエラーが発生する。CUDA バージョン不一致問題の解決過程でも同様のエラーが出る。

---

## 対策の方向性

### 案A：即時回避策（`pkg_resources` エラーのみ解消）

Dockerfile に以下を追記してビルドを通す。ただし RTX 5090 で GPU が実際に動くかは別問題。

```docker
RUN pip install --upgrade pip setuptools
```

- 難易度：低
- 限界：CUDA 11.8 ベースのままなので、RTX 5090 の GPU は使えない可能性が高い

### 案B：CUDA 12.8 対応に全スタックを更新（本質的解決）

Dockerfile のベースイメージを差し替え、RTX 5090 対応の構成でビルドし直す。

```docker
# 変更前
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# 変更後
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04
```

合わせて以下も変更が必要：

- PyTorch を **2.7.0 以上**（`cu128` ビルド）に更新
- `CUDA_ARCHITECTURES=120` を指定してビルド
- `tiny-cuda-nn` など依存ライブラリの sm_120 対応状況を確認
- 難易度：高
- 効果：RTX 5090 の GPU を本来の性能で使える

### 案C：対応待ち

nerfstudio および依存ライブラリ（`tiny-cuda-nn` 等）が公式に sm_120 対応するまで待つ。

---

## 今後のアクション（TODO）

- [ ]  実際のエラーログ全文を記録・保存する
- [ ]  案A を試し、ビルドが通るか確認する
- [ ]  ビルドが通った場合、RTX 5090 の GPU が認識されるか確認する（`nvidia-smi` / PyTorch から）
- [ ]  案B として、Dockerfile のベースイメージを `cuda:12.8.0` に変更して再ビルドを試みる
- [ ]  `tiny-cuda-nn` の sm_120（Blackwell）対応状況を GitHub で確認する
- [ ]  nerfstudio Issue #3693 および #3732 の進捗を追う

思っていること

pipとcudaが新しいことがヒントだとおもっている。どちらのバージョンをどれだけ下げるべきかわかりません