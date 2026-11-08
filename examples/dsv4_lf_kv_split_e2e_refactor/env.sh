#!/usr/bin/env bash
# 唯一配置入口。按实际环境修改标记为「需修改」的默认值。

export MODEL_PATH="${MODEL_PATH:-/mnt/paas/weights/DeepSeek-V4-Flash-w8a8-mtp}"  # 需修改
export TRAIN_PATH="${TRAIN_PATH:-/path/to/gsm8k_train.jsonl}"                   # 需修改
export TEST_PATH="${TEST_PATH:-/path/to/gsm8k_test.jsonl}"                     # 需修改
export SGLANG_ROOT="${SGLANG_ROOT:-/path/to/sglang}"                           # 需修改
export KERNEL_ROOT="${KERNEL_ROOT:-/path/to/sgl-kernel-npu}"                   # 需修改

export NPU_DEVICES="${NPU_DEVICES:-0,1,2,3,4,5,6,7}"   # 需修改：八张空闲物理卡
export PORT="${PORT:-32420}"
export DP_RANK="${DP_RANK:-0}"

# Ascend 运行环境；这些脚本会引用未定义变量，source 期间临时关闭 -u。
set +u
source /usr/local/Ascend/ascend-toolkit/latest/opp/vendors/customize/bin/set_env.bash
source /usr/local/Ascend/ascend-toolkit/latest/opp/vendors/custom_transformer/bin/set_env.bash
source /usr/local/Ascend/ascend-toolkit/latest/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh
set -u
export ASCEND_RT_VISIBLE_DEVICES="$NPU_DEVICES"

export NUM_QUESTIONS="${NUM_QUESTIONS:-3}"
export TEST_OFFSET="${TEST_OFFSET:-5}"
export MIN_PROMPT_TOKENS="${MIN_PROMPT_TOKENS:-8192}"
export MAX_SHOTS="${MAX_SHOTS:-128}"
export MAX_NEW_TOKENS="${MAX_NEW_TOKENS:-512}"
export EVICTION_TOKENS="${EVICTION_TOKENS:-65536}"
export STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-3600}"
export AUDIT_TIMEOUT="${AUDIT_TIMEOUT:-30}"

export QUANTIZATION="${QUANTIZATION:-modelslim}"  # 需修改：非量化权重留空

export SGLANG_HICACHE_HOST_MEM_BACKEND="${SGLANG_HICACHE_HOST_MEM_BACKEND:-memfabric}"
export SGLANG_DSV4_FP4_EXPERTS="${SGLANG_DSV4_FP4_EXPERTS:-False}"  # 需修改：FP4 权重设 True

export PYTORCH_NPU_ALLOC_CONF="${PYTORCH_NPU_ALLOC_CONF:-expandable_segments:True}"
export STREAMS_PER_DEVICE="${STREAMS_PER_DEVICE:-32}"
export SGLANG_SET_CPU_AFFINITY="${SGLANG_SET_CPU_AFFINITY:-1}"
export HCCL_BUFFSIZE="${HCCL_BUFFSIZE:-2048}"
export HCCL_SOCKET_IFNAME="${HCCL_SOCKET_IFNAME:-lo}"
export GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-lo}"
export HCCL_INTRA_DMA_ENABLE="${HCCL_INTRA_DMA_ENABLE:-1}"
export DEEPEP_HCCL_BUFFSIZE="${DEEPEP_HCCL_BUFFSIZE:-1024}"
export SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK="${SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK:-128}"
export SGLANG_OPT_USE_OVERLAP_STORE_CACHE="${SGLANG_OPT_USE_OVERLAP_STORE_CACHE:-False}"
export FORCE_DRAFT_MODEL_NON_QUANT="${FORCE_DRAFT_MODEL_NON_QUANT:-1}"
export SGLANG_OPT_FUSE_WQA_WKV="${SGLANG_OPT_FUSE_WQA_WKV:-0}"
export SGLANG_OPT_BF16_FP32_GEMM_ALGO="${SGLANG_OPT_BF16_FP32_GEMM_ALGO:-torch}"
export SGLANG_OPT_USE_FUSED_HASH_TOPK="${SGLANG_OPT_USE_FUSED_HASH_TOPK:-False}"
export SGLANG_OPT_USE_TILELANG_MHC_PRE="${SGLANG_OPT_USE_TILELANG_MHC_PRE:-False}"
export SGLANG_OPT_DEEPGEMM_HC_PRENORM="${SGLANG_OPT_DEEPGEMM_HC_PRENORM:-False}"
export SGLANG_OPT_USE_TILELANG_MHC_POST="${SGLANG_OPT_USE_TILELANG_MHC_POST:-False}"
export SGLANG_OPT_FP8_WO_A_GEMM="${SGLANG_OPT_FP8_WO_A_GEMM:-False}"
export SGLANG_ENABLE_SPEC_V2="${SGLANG_ENABLE_SPEC_V2:-0}"
export SGLANG_ENABLE_OVERLAP_PLAN_STREAM="${SGLANG_ENABLE_OVERLAP_PLAN_STREAM:-0}"
export SGLANG_NPU_USE_MULTI_STREAM="${SGLANG_NPU_USE_MULTI_STREAM:-0}"
export SGLANG_ZBAL_LOCAL_MEM_SIZE="${SGLANG_ZBAL_LOCAL_MEM_SIZE:-0}"
export SGLANG_ENABLE_TP_MEMORY_INBALANCE_CHECK="${SGLANG_ENABLE_TP_MEMORY_INBALANCE_CHECK:-1}"
export SGLANG_ENABLE_WAR_BARRIER="${SGLANG_ENABLE_WAR_BARRIER:-1}"
export SGLANG_FORCE_COARSE_WAR_BARRIER="${SGLANG_FORCE_COARSE_WAR_BARRIER:-1}"

export ASCEND_TOOLKIT_ROOT="${ASCEND_TOOLKIT_ROOT:-/usr/local/Ascend/ascend-toolkit/latest}"
export CANN_PYTHON_SITE_PACKAGES="${CANN_PYTHON_SITE_PACKAGES:-/usr/local/Ascend/cann-9.1.0/python/site-packages}"
export PYTHONPATH="$SGLANG_ROOT/python:$KERNEL_ROOT/python/sgl_kernel_npu:$ASCEND_TOOLKIT_ROOT/python/site-packages:$CANN_PYTHON_SITE_PACKAGES${PYTHONPATH:+:$PYTHONPATH}"
