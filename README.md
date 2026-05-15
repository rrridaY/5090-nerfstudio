# nerfstudio-5090

このリポジトリは [nerfstudio](https://github.com/nerfstudio-project/nerfstudio) のフォークです。

nerfstudio の詳細については、[nerfstudio の公式ページ](https://github.com/nerfstudio-project/nerfstudio) をご覧ください。

---

## このフォークについて

**NVIDIA RTX 5090 (Blackwell, sm_120)** で nerfstudio を動かすことを目標としています。現在実装中です。

Windows 11 + WSL2 + Docker 環境での動作を想定しています。

## 主な変更点

| 項目 | 変更内容 |
|---|---|
| CUDA バージョン | 11.8 → **12.8** |
| PyTorch | 2.1.2+cu118 → **2.7.0+cu128** |
| `CUDA_ARCHITECTURES` | `120` を先頭に追加 |
| tiny-cuda-nn | HEAD (sm_120 対応のため最新) |
| setuptools | バージョン上限を撤廃 |

## ビルド方法

WSL2 上で実行してください。

```bash
cd nerfstudio

# ビルド
docker build -t nerfstudio-5090 .

# RTX 5090 専用に絞って高速ビルド
docker build --build-arg CUDA_ARCHITECTURES="120" -t nerfstudio-5090 .
```

## 動作確認

```bash
# GPU 認識確認
docker run --gpus all --rm nerfstudio-5090 nvidia-smi

# PyTorch から CUDA / sm_120 確認
docker run --gpus all --rm nerfstudio-5090 python -c \
  "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_capability())"
```
