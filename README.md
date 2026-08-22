<p align="center">
  <img src="logo.png" alt="vollama mascot" width="180" />
</p>

<h1 align="center">vollama</h1>

<p align="center">
  An Ollama-style CLI and OpenAI-compatible API that wraps multiple inference engines behind a single interface.
</p>

vollama provides a familiar, Ollama-style workflow (`run`, `list`, `ps`, `stop`) on top of a pluggable set of LLM inference engines. Each model is defined by a declarative recipe that specifies which engine serves it — vLLM, llama.cpp, SGLang, TensorRT-LLM, OpenVINO GenAI, Unsloth Studio, or ACE-Step — so a single interface can manage heterogeneous inference workloads without locking you into any one backend.

## Features

- **Ollama-compatible CLI** — `run`, `list`, `ps`, `stop`, `show`, `pull`, `add`, `cp`, `rm`
- **Multiple inference engines** — vLLM, llama.cpp, SGLang, TensorRT-LLM, OpenVINO GenAI, Unsloth Studio, and ACE-Step, selectable per model
- **OpenAI-compatible API** — drop-in `/v1/chat/completions` endpoint with SSE streaming
- **Recipe system** — model configurations are declarative TOML files, easy to version and share
- **GPU-aware** — auto-detects NVIDIA GPUs, estimates VRAM requirements, shows compatibility
- **Keep-alive** — auto-unloads idle models after a configurable timeout
- **Auto-load** — loads the requested model on first API request
- **HuggingFace integration** — pull models directly from the Hub
- **systemd-ready** — ships with a hardened service unit
- **Flutter GUI** — optional cross-platform graphical interface

## Quick Start

### Prerequisites

- Rust 2024 edition (1.85+)
- At least one supported inference engine installed (for example [vLLM](https://docs.vllm.ai/) or [llama.cpp](https://github.com/ggml-org/llama.cpp))

### Platform Support

| Platform | vLLM | llama.cpp | GPU detection |
|---|---|---|---|
| Linux (NVIDIA) | Yes | Yes | nvidia-smi |
| macOS (Apple Silicon) | No | Yes (Metal) | — |

On macOS, use llama.cpp recipes with Metal acceleration. vLLM requires CUDA and is Linux-only. Other engines have their own platform requirements, which `vollama doctor` reports per engine.

## Usage

### Start the daemon

```bash
vollama serve
```

### Chat with a model

```bash
vollama run qwen3-coder
```

Loads the model (if not already running) and starts an interactive chat session with streaming responses.

### Manage models

```bash
vollama models                # list available recipes + GPU compatibility
vollama show qwen3-coder      # recipe details + VRAM estimate
vollama ps                    # currently running model
vollama stop                  # stop the running model
vollama pull org/model-id     # download from HuggingFace
vollama add my-recipe         # create a new recipe (interactive)
vollama rm old-recipe         # delete a recipe
```

### API

The daemon exposes an OpenAI-compatible proxy at `http://localhost:11435/v1/`:

```bash
curl http://localhost:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-coder",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

## Recipes

Recipes are declarative TOML files that define which engine serves a model and how it is launched. No shell involved — vollama spawns engine binaries directly.

```toml
backend = "vllm"
model = "QuantTrio/Qwen3-Coder-30B-A3B-Instruct-AWQ"

[args]
gpu-memory-utilization = 0.85
max-model-len = 65536
trust-remote-code = true
```

The `backend` field selects the inference engine for the model. Each engine exposes its own set of arguments, which `vollama show` and the interactive `vollama add` command document.

Recipe lookup order (last wins):

1. `./recipes/` — local dev convenience
2. `/usr/share/vollama/recipes/` — system-wide
3. `~/.config/vollama/recipes/` — per-user overrides

## License

Proprietary — see [LICENSE](LICENSE).
