# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

Build a working nerfstudio Docker environment that runs on **RTX 5090 (Blackwell, sm_120)** under Windows 11 + WSL2 + Docker.

The official nerfstudio Docker image is based on `nvidia/cuda:11.8.0-devel-ubuntu22.04`, which is incompatible with the RTX 5090. This repo provides a patched Dockerfile and supporting scripts to make nerfstudio work with CUDA 12.8+.

## Environment

| Layer | Detail |
|---|---|
| Host OS | Windows 11 |
| Virtualization | WSL2 (Ubuntu 22.04) |
| Container runtime | Docker (WSL2 backend) |
| GPU | NVIDIA RTX 5090 (Blackwell, `sm_120`) |
| Required CUDA | 12.8+ |

## Key Technical Constraints

- RTX 5090 (Blackwell) requires **CUDA 12.8 or later** and compute capability **sm_120**
- nerfstudio's official image uses CUDA 11.8 — this must be replaced
- `tiny-cuda-nn` and other native extensions must be compiled with `CUDA_ARCHITECTURES=120`
- Python 3.12+ no longer ships `setuptools` by default, so `pkg_resources` errors require an explicit `pip install setuptools`
- PyTorch must be **2.7.0+** built against `cu128`

## Repository Structure

```
5090-nerfstudio/
├── nerfstudio/        # official nerfstudio repo (cloned)
│   └── Dockerfile     # ← patched for RTX 5090
├── CLAUDE.md
└── deals.md
```

## What Was Changed in `nerfstudio/Dockerfile`

| Line(s) | Before | After |
|---|---|---|
| `NVIDIA_CUDA_VERSION` | `11.8.0` | `12.8.0` |
| `CUDA_ARCHITECTURES` | `"90;89;86;80;75;70;61"` | `"120;90;89;86;80;75;70;61"` |
| `setuptools` | `'setuptools<70.0.0'` | `setuptools wheel` (no upper bound) |
| PyTorch | `torch==2.1.2+cu118` | `torch==2.7.0+cu128` |
| torchvision | `torchvision==0.16.2+cu118` | `torchvision==0.22.0+cu128` |
| PyTorch index URL | `cu118` | `cu128` |
| tiny-cuda-nn | pinned commit hash | HEAD (sm_120 対応のため最新) |
| `TORCH_CUDA_ARCH_LIST` awk | `substr($0,1,1)"."substr($0,2)` | 3桁アーキ（120→"12.0"）に対応した式 |

`CUDA_ARCHITECTURES` の先頭に `120` を追加するだけで COLMAP・GLOMAP・gsplat・tiny-cuda-nn 全て sm_120 でビルドされる（CMake フラグ・TCNN 環境変数がいずれもこの ARG を参照している）。

## Build Commands

すべて WSL2 上で実行する。`nerfstudio/` ディレクトリをビルドコンテキストに指定する点に注意。

```bash
cd ~/path/to/5090-nerfstudio/nerfstudio

# ローカルのソースをコンテキストに含めてビルド（推奨）
docker build -t nerfstudio-5090 .

# アーキテクチャを RTX 5090 専用に絞って高速ビルド
docker build --build-arg CUDA_ARCHITECTURES="120" -t nerfstudio-5090 .
```

## Verification After Build

```bash
# GPU 認識確認
docker run --gpus all --rm nerfstudio-5090 nvidia-smi

# PyTorch から CUDA / sm_120 確認
docker run --gpus all --rm nerfstudio-5090 python -c \
  "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_capability())"
```

## Tracked Upstream Issues

- nerfstudio RTX 5090 / sm_120 support: issue #3693, #3732
- `tiny-cuda-nn` Blackwell support: check the tiny-cuda-nn GitHub for sm_120 status before building

## Open Questions / TODOs

- [ ] Confirm `tiny-cuda-nn` sm_120 support and minimum version
- [ ] Verify `nerfacc`, `torchtyping`, and other native deps build cleanly against CUDA 12.8
- [ ] Test an actual nerfstudio training run end-to-end on RTX 5090
- [ ] Document final working version pins (CUDA, PyTorch, tiny-cuda-nn, nerfstudio)
