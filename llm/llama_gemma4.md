# Optimizing Gemma 4 for AMD RX 9060 XT + ROCm 7.2

## Hardware Profile

- GPU: AMD Radeon RX 9060 XT (RDNA 4, gfx1200, 32 CU, 16 GB VRAM, 170 W TDP)
- CPU: AMD Ryzen 5 9600X (Zen 5, 6C/12T, 5486 MHz boost)
- RAM: 32 GB DDR5
- ROCm: 7.2 (HIP 7.2.53211, AMD clang 22.0.0)
- OS: CachyOS (Arch-based), kernel 7.1.1-2-cachyos
- iGPU: gfx1036 (Ryzen integrated, 512 MB - not used for inference)

## Variant Selection

With 16 GB VRAM, the E2B, E4B, and 12B fit. The larger models require 24+ GB.

Available GGUF quants for 12B: Q4_K_M (7.38 GB), Q8_0 (12.7 GB), bf16 (23.8 GB).

| Variant          | Weights (Q8_0) | Weights (Q4_K_M) | VRAM Left (Q4_K_M) | Verdict              |
|------------------|----------------|-------------------|---------------------|----------------------|
| E2B (5.1B total) | ~5.4 GB        | ~3.1 GB           | ~12.9 GB            | Fits, but weaker     |
| E4B (8B total)   | ~8.5 GB        | ~4.8 GB           | ~11.2 GB            | Good, long ctx       |
| 12B Dense        | 12.7 GB        | 7.38 GB           | ~8.6 GB             | Best balance         |
| 26B A4B MoE      | ~26.8 GB       | ~15.1 GB          | <1 GB               | Too large            |
| 31B Dense        | ~32.6 GB       | ~18.4 GB          | None                | Won't fit            |

**Primary: Gemma 4 12B-it at Q4_K_M** (7.38 GB weights). Strongest model that fits comfortably, with ~8.6 GB left for KV cache (32K+ context). Unified encoder-free multimodal architecture with native text, image, and audio support.

**Quality option: Gemma 4 12B-it at Q8_0** (12.7 GB weights). Higher quality but only ~3.3 GB left for KV cache -- use with shorter context (-c 8192).

**Long context option: Gemma 4 E4B-it at Q8_0** (~8.5 GB weights). Use when you need 65K+ context.

## Build Configuration (Verified)

The current llama.cpp build at `build/` is already correctly configured:

```
CMAKE_BUILD_TYPE  = Release
GGML_HIP          = ON
GPU_TARGETS       = gfx1200       # exact match for RX 9060 XT RDNA 4
GGML_NATIVE       = ON            # auto-tunes CPU code for Zen 5
GGML_HIP_GRAPHS   = ON            # HIP graph capture for reduced launch overhead
GGML_HIP_MMQ_MFMA = ON            # matrix fused multiply-add kernels
GGML_HIP_NO_VMM   = ON            # required for RDNA GPUs
GGML_CPU           = ON
GGML_CPU_REPACK    = ON
```

No rebuild is needed. If rebuilding from scratch:

```bash
cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_HIP=ON \
    -DGPU_TARGETS="gfx1200" \
    -DGGML_NATIVE=ON \
    -DGGML_HIP_GRAPHS=ON \
    -DGGML_HIP_MMQ_MFMA=ON \
    -DGGML_HIP_NO_VMM=ON

cmake --build build --config Release -j$(nproc)
```

## Environment Variables

```bash
# Use only the discrete RX 9060 XT (device 0), skip the Ryzen iGPU (device 1)
export HIP_VISIBLE_DEVICES=0

# Optional: force the GPU architecture if ROCm misdetects it
# export HSA_OVERRIDE_GFX_VERSION=12.0.0

# Optional: tune HIP memory allocation behavior
# export GPU_MAX_ALLOC_PERCENT=100
```

## Running Gemma 4

### Interactive Chat (llama-cli)

```bash
# 12B Q4_K_M (primary - best balance of quality and VRAM headroom)
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli \
    -hf ggml-org/gemma-4-12B-it-GGUF:Q4_K_M \
    -ngl 99 \
    -fa \
    -c 32768 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    -cnv

# E4B (alternative - more VRAM headroom for long context)
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli \
    -hf ggml-org/gemma-4-E4B-it-GGUF:Q8_0 \
    -ngl 99 \
    -fa \
    -c 65536 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    -cnv
```

### OpenAI-Compatible API Server (llama-server)

```bash
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-server \
    -hf ggml-org/gemma-4-12B-it-GGUF:Q4_K_M \
    -ngl 99 \
    -fa \
    -c 32768 \
    --host 0.0.0.0 \
    --port 8080
```

### With a Local GGUF File

```bash
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli \
    -m /path/to/gemma-4-12B-it-Q4_K_M.gguf \
    -ngl 99 \
    -fa \
    -c 32768 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    -cnv
```

## Runtime Flag Reference

| Flag               | Value   | Purpose                                                |
|--------------------|---------|--------------------------------------------------------|
| `-ngl 99`          | 99      | Offload all layers to GPU (model fits entirely)        |
| `-fa`              | -       | Flash attention: reduces KV cache VRAM, faster long ctx|
| `-c 32768`         | 32768   | 32K context window (increase up to 131072 if VRAM OK)  |
| `--temp 1.0`       | 1.0     | Google recommended sampling temperature                |
| `--top-p 0.95`     | 0.95    | Google recommended nucleus sampling                    |
| `--top-k 64`       | 64      | Google recommended top-k sampling                      |
| `-cnv`             | -       | Conversation mode for interactive multi-turn chat      |
| `-hf`              | repo:q  | Auto-download from HuggingFace by repo ID and quant    |

## Thinking Mode

Enable Gemma 4 built-in chain-of-thought reasoning by placing the `<|think|>` token at the start of the system prompt:

```bash
# CLI with thinking enabled
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli \
    -hf ggml-org/gemma-4-12B-it-GGUF:Q4_K_M \
    -ngl 99 -fa -c 32768 \
    -sys "<|think|>\nYou are a helpful assistant." \
    -cnv
```

Via the server API:

```json
{
  "messages": [
    {"role": "system", "content": "<|think|>\nYou are a helpful assistant."},
    {"role": "user", "content": "Explain how sliding window attention works."}
  ],
  "temperature": 1.0,
  "top_p": 0.95,
  "top_k": 64
}
```

Thinking mode uses more tokens (and thus more VRAM for KV cache). If VRAM is tight, reduce context size with `-c 16384` or disable thinking by removing the `<|think|>` token.

## Context Length vs VRAM Budget

With flash attention enabled, approximate total VRAM usage:

| Context Length | 12B Q4_K_M (7.38 GB) | 12B Q8_0 (12.7 GB) | E4B Q8_0 (~8.5 GB) |
|----------------|----------------------|---------------------|---------------------|
| 8K tokens      | ~8.0 GB              | ~13.3 GB            | ~9.0 GB             |
| 16K tokens     | ~8.5 GB              | ~13.8 GB            | ~9.5 GB             |
| 32K tokens     | ~9.5 GB              | ~14.8 GB            | ~10.5 GB            |
| 65K tokens     | ~11.5 GB             | ~16+ GB (limit)     | ~12.5 GB            |
| 128K tokens    | ~15.5 GB (tight)     | Won't fit           | ~16+ GB (limit)     |

12B Q4_K_M is the sweet spot: 32K context fits easily, 65K is comfortable, even 128K is possible.
12B Q8_0 is limited to ~32K context before hitting VRAM limits.
E4B Q8_0 sits in between and is best when you need 65K+ context with higher quality.

## Benchmarking

Test prompt processing (pp) and token generation (tg) speed on the RX 9060 XT:

```bash
export HF_TOKEN="hf_your_token_here"

# Compare all viable models
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-bench \
    -hf ggml-org/gemma-4-12B-it-GGUF:Q4_K_M \
    -hf ggml-org/gemma-4-E4B-it-GGUF:Q8_0 \
    -hf unsloth/Qwen3.5-9B-MTP-GGUF:Q8_0 \
    -ngl 99 \
    -fa 1

# Single model quick test
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-bench \
    -hf ggml-org/gemma-4-12B-it-GGUF:Q4_K_M \
    -ngl 99 \
    -fa 1
```

Note: HuggingFace token is required for gated models. Create one at https://huggingface.co/settings/tokens and accept model licenses on their respective pages.

## Gemma 4 Architecture Notes for RDNA 4

Both E4B and 12B use a hybrid attention design that interleaves local sliding window attention with full global attention. Global layers use unified K/V and Proportional RoPE (p-RoPE). The 12B uses a unified encoder-free multimodal architecture, projecting raw image and audio patches directly into the LLM embedding space via lightweight linear layers.

This design is efficient for RDNA 4 because:

- Sliding window layers have bounded memory footprint regardless of context length
- Global layers with unified K/V reduce the KV cache size vs standard multi-head attention
- The 32 MB L3 infinity cache on the RX 9060 XT helps with embedding lookups (PLE on E4B, unified projections on 12B)
- HIP graph capture (GGML_HIP_GRAPHS=ON) reduces kernel launch overhead across layers
- MFMA kernels (GGML_HIP_MMQ_MFMA=ON) accelerate the matrix multiplications in attention and FFN blocks
