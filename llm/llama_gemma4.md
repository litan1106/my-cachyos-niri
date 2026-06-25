# Gemma 4 E4B + llama-server for VS Code on AMD RX 9060 XT

## Hardware Profile

- GPU: AMD Radeon RX 9060 XT (RDNA 4, gfx1200, 32 CU, 16 GB VRAM, 170 W TDP)
- CPU: AMD Ryzen 5 9600X (Zen 5, 6C/12T, 5486 MHz boost)
- RAM: 32 GB DDR5
- ROCm: 7.2 (HIP 7.2.53211, AMD clang 22.0.0)
- OS: CachyOS (Arch-based), kernel 7.1.1-2-cachyos
- iGPU: gfx1036 (Ryzen integrated, 512 MB - not used for inference)

## Benchmark Results (RX 9060 XT)

Measured with `llama-bench -ngl 99 -fa on`:

| Model                   | Size     | Prompt (pp512) | Generation (tg128) |
|-------------------------|----------|----------------|---------------------|
| **Gemma 4 E4B Q8_0**   | 7.46 GiB | 3306.04 t/s    | 47.40 t/s           |
| Qwen3.5 9B Q8_0        | 9.10 GiB | 2121.80 t/s    | 32.00 t/s           |
| Gemma 4 12B Q4_K_M     | 6.86 GiB | 1264.41 t/s    | 34.06 t/s           |

**Gemma 4 E4B Q8_0 is the best model for this GPU:** 39% faster generation than the 12B, 2.6x faster prompt processing, and near-lossless Q8_0 quality.

## Build Configuration (Verified)

```
CMAKE_BUILD_TYPE  = Release
GGML_HIP          = ON
GPU_TARGETS       = gfx1200
GGML_NATIVE       = ON
GGML_HIP_GRAPHS   = ON
GGML_HIP_MMQ_MFMA = ON
GGML_HIP_NO_VMM   = ON
```

If rebuilding from scratch:

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

## 1. Start llama-server

```bash
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-server \
    -hf ggml-org/gemma-4-E4B-it-GGUF:Q8_0 \
    -ngl 99 \
    -fa on \
    -c 32768 \
    --host 127.0.0.1 \
    --port 8012
```

Verify it is running:

```bash
curl http://127.0.0.1:8012/health
```

The server exposes:
- Chat completions: `http://127.0.0.1:8012/v1/chat/completions`
- Completions: `http://127.0.0.1:8012/v1/completions`
- Infill (FIM): `http://127.0.0.1:8012/infill`
- Models list: `http://127.0.0.1:8012/v1/models`

## 2. Install llama-vscode Extension

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for `llama-vscode`
4. Install the extension by ggml-org

## 3. Configure llama-vscode

Open VS Code settings (Ctrl+,) and search for `llama`, or edit `settings.json` directly:

```json
{
    "llama.endpoint": "http://127.0.0.1:8012",
    "llama.api_key": "",
    "llama.fim.enabled": true,
    "llama.chat.enabled": true
}
```

Or configure via the llama-vscode status bar menu:
1. Click "llama-vscode" in the bottom status bar
2. Select the endpoint (http://127.0.0.1:8012)
3. Enable completion and chat features

## 4. Usage

### Code Completion (FIM)
Just start typing in any file. llama-vscode sends fill-in-the-middle requests to the server. Accept suggestions with Tab.

### Chat
Use the llama-vscode chat panel (Ctrl+Shift+M or click status bar) to ask questions about your code, get explanations, or request changes.

## 5. Run as a systemd User Service (Optional)

Create a service so llama-server starts automatically:

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/llama-server.service << 'EOF'
[Unit]
Description=llama.cpp server (Gemma 4 E4B Q8_0)
After=default.target

[Service]
Type=simple
Environment=HIP_VISIBLE_DEVICES=0
ExecStart=%h/Projects/llama_cpp/build/bin/llama-server \
    -hf ggml-org/gemma-4-E4B-it-GGUF:Q8_0 \
    -ngl 99 \
    -fa on \
    -c 32768 \
    --host 127.0.0.1 \
    --port 8012
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable llama-server
systemctl --user start llama-server

# Check status
systemctl --user status llama-server

# View logs
journalctl --user -u llama-server -f
```

## 6. Thinking Mode

For reasoning tasks, use thinking mode by starting the system prompt with `<|think|>`:

```bash
curl http://127.0.0.1:8012/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "<|think|>\nYou are a helpful coding assistant."},
      {"role": "user", "content": "Write a binary search in Rust."}
    ],
    "temperature": 1.0,
    "top_p": 0.95,
    "top_k": 64
  }'
```

## Context Length vs VRAM Budget

With E4B Q8_0 (~8.5 GB weights) and flash attention enabled:

| Context Length | Estimated Total VRAM | Status      |
|----------------|----------------------|-------------|
| 8K tokens      | ~9.0 GB              | Comfortable |
| 16K tokens     | ~9.5 GB              | Comfortable |
| 32K tokens     | ~10.5 GB             | Good        |
| 65K tokens     | ~12.5 GB             | OK          |
| 128K tokens    | ~16+ GB              | At limit    |

## Runtime Flag Reference

| Flag               | Value       | Purpose                                                |
|--------------------|-------------|--------------------------------------------------------|
| `-ngl 99`          | 99          | Offload all layers to GPU                              |
| `-fa on`           | on          | Flash attention: less VRAM for KV cache, faster        |
| `-c 32768`         | 32768       | 32K context window                                     |
| `--host 127.0.0.1` | 127.0.0.1   | Listen on localhost only                               |
| `--port 8012`      | 8012        | Default port for llama-vscode                          |
| `--temp 1.0`       | 1.0         | Google recommended sampling temperature                |
| `--top-p 0.95`     | 0.95        | Google recommended nucleus sampling                    |
| `--top-k 64`       | 64          | Google recommended top-k sampling                      |
| `-hf`              | repo:quant  | Auto-download from HuggingFace                         |
