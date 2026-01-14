# Project Purpose

HYDRA 10.0 is an advanced environment for Claude CLI, operating in "Maximum Autonomy Mode." It provides full access to environment variables, Windows Registry, file system, network operations, and software installation. The project emphasizes parallel execution of tasks and integrates an "Advanced AI System" with several modules:
- **Self-Correction:** Auto-validates and regenerates code on syntax errors using phi3:mini.
- **Few-Shot Learning:** Learns from successful responses to provide context-aware examples.
- **Speculative Decoding:** Uses parallel multi-model generation with model racing and consensus.
- **Load Balancing:** Performs CPU-aware provider switching for auto local/cloud selection.
- **Semantic File Mapping:** Offers deep RAG (Retrieval-Augmented Generation) with import analysis and dependency graph context.

The overarching goal is to enable highly autonomous and efficient AI-driven development workflows on Windows 11 using PowerShell 7+ and various AI models (Ollama and Anthropic Claude).