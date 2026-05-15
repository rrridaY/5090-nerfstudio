#!/bin/bash
# RTX 5090 nerfstudio セットアップスクリプト
# 実行環境: WSL2 (Ubuntu 22.04) + Docker + NVIDIA RTX 5090
# 使い方: bash setup.sh

set -e

REPO_URL="https://github.com/rrridaY/5090-nerfstudio.git"
IMAGE_NAME="nerfstudio-5090"
CONTAINER_NAME="nerfstudio"

# ─────────────────────────────────────────
# 1. リポジトリのクローン（すでにリポジトリ内にいる場合はスキップ）
# ─────────────────────────────────────────
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "==> すでにリポジトリ内にいるためクローンをスキップ"
    cd "$(git rev-parse --show-toplevel)"
else
    echo "==> リポジトリをクローン中..."
    git clone "$REPO_URL"
    cd 5090-nerfstudio
fi

# ─────────────────────────────────────────
# 2. Docker イメージのビルド
#    RTX 5090 専用（sm_120 のみ）にするとビルドが速い
#    全アーキテクチャ対応にしたい場合は --build-arg を省略する
# ─────────────────────────────────────────
echo "==> Docker イメージをビルド中... (時間がかかります)"
sudo docker build \
    --build-arg CUDA_ARCHITECTURES="120" \
    -t "$IMAGE_NAME" \
    .

# ─────────────────────────────────────────
# 3. 動作確認
# ─────────────────────────────────────────
echo "==> GPU 認識確認..."
sudo docker run --gpus all --rm "$IMAGE_NAME" nvidia-smi

echo "==> PyTorch / CUDA / sm_120 確認..."
sudo docker run --gpus all --rm "$IMAGE_NAME" python -c \
    "import torch; print('CUDA available:', torch.cuda.is_available()); print('Device capability:', torch.cuda.get_device_capability())"

# ─────────────────────────────────────────
# 4. コンテナを起動して作業
#    データディレクトリは ~/nerfstudio-data にマウントする
# ─────────────────────────────────────────
echo "==> コンテナを起動..."
mkdir -p ~/nerfstudio-data

sudo docker run --gpus all -it \
    --name "$CONTAINER_NAME" \
    --rm \
    -p 7007:7007 \
    -v ~/nerfstudio-data:/workspace/data \
    "$IMAGE_NAME"

# ─────────────────────────────────────────
# コンテナ内での主なコマンド（参考）
# ─────────────────────────────────────────
# データのダウンロードとトレーニング:
#   ns-download-data nerfstudio --capture-name=poster
#   ns-train nerfacto --data data/nerfstudio/poster
#
# ビューワーのみ起動:
#   ns-viewer --load-config outputs/.../config.yml
#
# ブラウザで http://localhost:7007 にアクセス
# ─────────────────────────────────────────
