#!/bin/bash

# Environment Variables
ARG_WORLD_SIZE=${1:-1}
ARG_NPROC_PER_NODE=${2:-8}
ARG_MASTER_ADDR="127.0.0.1"
ARG_MASTER_PORT=16666
ARG_RANK=${3:-0}

# Multiple conditions
if [ ! -n "$WORLD_SIZE" ] || [ ! -n "$NPROC_PER_NODE" ]; then
    WORLD_SIZE=$ARG_WORLD_SIZE
    NPROC_PER_NODE=$ARG_NPROC_PER_NODE
fi
if [ ! -n "$MASTER_ADDR" ] || [ ! -n "$MASTER_PORT" ] || [ ! -n "$RANK" ]; then
    MASTER_ADDR=$ARG_MASTER_ADDR
    MASTER_PORT=$ARG_MASTER_PORT
    RANK=$ARG_RANK
fi

echo "WORLD_SIZE: $WORLD_SIZE"
echo "NPROC_PER_NODE: $NPROC_PER_NODE"

# Training Arguments
GLOBAL_BATCH_SIZE=256
LOCAL_BATCH_SIZE=8
GRADIENT_ACCUMULATION_STEPS=$[$GLOBAL_BATCH_SIZE/($WORLD_SIZE*$NPROC_PER_NODE*$LOCAL_BATCH_SIZE)]

# Log Arguments
export TRANSFORMERS_OFFLINE=1
export WANDB_PROJECT=videorefer_qwen2
RUN_NAME=videorefer
OUTP_DIR=./work_dirs

torchrun --nproc_per_node 2 \
    videorefer/train.py \
    --deepspeed scripts/zero2.json \
    --model_type videorefer_qwen2 \
    --model_path Qwen/Qwen2-7B-Instruct \
    --vision_tower google/siglip-so400m-patch14-384 \
    --mm_projector_type stc_connector_v35 \
    --data_path ./data/stage2.json \
    --data_folder ./data \
    --pretrain_mm_mlp_adapter DAMO-NLP-SG/VideoLLaMA2.1-7B-16F-Base/mm_projector.bin \
    --image_aspect_ratio square \
    --mm_vision_select_layer -2 \
    --tune_region_encoder True \
    --mm_region_encoder_type pooling \
    --num_frames 16 \
    --bf16 True \
    --tf32 True \
    --fp16 False \
    --output_dir ./work_dirs/videorefer_stage2 \
    --num_train_epochs 1 \
    --per_device_train_batch_size 1 \
    --per_device_eval_batch_size 4 \
    --gradient_accumulation_steps 1 \
    --evaluation_strategy "no" \
    --save_strategy "steps" \
    --save_steps 5000 \
    --save_total_limit 99 \
    --learning_rate 1e-3 \
    --weight_decay 0. \
    --warmup_ratio 0.03 \
    --lr_scheduler_type "cosine" \
    --logging_steps 1 \
    --model_max_length 2048 \
    --gradient_checkpointing True \
    --dataloader_num_workers 4 \
    --report_to tensorboard \
    --run_name $RUN_NAME 