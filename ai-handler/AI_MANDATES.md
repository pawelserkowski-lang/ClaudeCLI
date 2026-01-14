# AI OPERATIONAL MANDATES (PROTOCOL: ZAWSZE)

> **STATUS:** ACTIVE | **VERSION:** 2.0
> **STRATEGY:** CLOUD BRAIN (Claude) / LOCAL MUSCLE (Ollama)
> **MEMORY:** SERENA CORE (AUTO-SAVE) + ContextOptimizer

Niniejszy dokument definiuje nienaruszalne zasady (MANDATES) dla systemu AI. Każdy agent musi przestrzegać poniższych reguł.

---

## 1. PAMIĘĆ I KONTEKST (Memory Strategy)

### 1.1 Protokół sprawdzania pamięci

| Krok | Akcja | Funkcja | Cel |
|------|-------|---------|-----|
| **1** | Sprawdź pamięć Serena | `Get-AllSerenaMemories` | 25 slotów, ~4000 tokenów |
| **2** | Weryfikuj cache MCP | `Get-MCPCacheStats` | 5 min TTL |
| **3** | Odczytaj historię sesji | `Get-SessionState` | Decyzje, pliki, tokeny |
| **4** | Kompresuj jeśli trzeba | `Compress-Context` | 89% oszczędności |

### 1.2 Zasady

*   **ZAWSZE** sprawdzaj pamięć `Serena_Core` oraz pełną historię czatów przed udzieleniem odpowiedzi.
*   **ZAWSZE** wykonuj `auto_save` nowych faktów do pamięci długoterminowej natychmiast po wygenerowaniu.
*   **ZAWSZE** maksymalizuj użycie okna kontekstowego. Kompresja tylko gdy zbliżasz się do limitu.
*   **ZAWSZE** cachuj wyniki read-only MCP calls (5 minut TTL).

### 1.3 Funkcje ContextOptimizer

```powershell
# Estymacja tokenów
Get-TokenEstimate -Text "..." -Language "auto"  # en, pl, code

# Cache MCP
$cached = Get-CachedMCPResult -ToolName "read_file" -Parameters @{path="..."}
Set-CachedMCPResult -ToolName "..." -Parameters @{} -Result @{}

# Kompresja
$compressed = Compress-Context -Text $longText -MaxTokens 2000 -Strategy "smart"

# Serena memories
Save-ToSerenaMemory -Name "session_notes" -Content "..." -Category "session"
Get-AllSerenaMemories | Format-Table

# Session tracking
Add-SessionDecision "Decided to use approach X"
Add-SessionFile "modified.ps1"
Get-SessionState
```

---

## 2. ARCHITEKTURA HYBRYDOWA (Brain + Muscle)

```
┌──────────────────────────────────┐     ┌──────────────────────────────────┐
│        🧠 BRAIN (Cloud)          │     │       💪 MUSCLE (Local)          │
│        Anthropic/OpenAI          │     │       Ollama/Desktop Commander   │
├──────────────────────────────────┤     ├──────────────────────────────────┤
│ ✓ Analiza logiczna i strategiczna│     │ ✓ Egzekucja kodu i skryptów      │
│ ✓ Architektura systemów          │     │ ✓ Operacje na plikach            │
│ ✓ Pisanie skomplikowanego kodu   │     │ ✓ Testy i build                  │
│ ✓ Rozwiązywanie konfliktów       │     │ ✓ Proste przetwarzanie tekstu    │
│ ✓ Wieloetapowe wnioskowanie      │     │ ✓ Self-correction (phi3:mini)    │
└──────────────────────────────────┘     └──────────────────────────────────┘
```

### 2.1 Podział ról

| Typ zadania | Provider | Model | Koszt |
|-------------|----------|-------|-------|
| Proste pytania | Ollama | llama3.2:3b | $0 |
| Generowanie kodu | Ollama | qwen2.5-coder:1.5b | $0 |
| Walidacja kodu | Ollama | phi3:mini | $0 |
| Złożona analiza | Anthropic | Claude Haiku | $0.80/$4 |
| Architektura | Anthropic | Claude Sonnet | $3/$15 |
| Krytyczne zadania | Anthropic | Claude Opus | $15/$75 |

---

## 3. WIELOWĄTKOWOŚĆ (Parallel Execution)

```
┌─────────────────────────────────────────────────────────────────┐
│  ZASADA NADRZĘDNA: Każda operacja możliwa do zrównoleglenia     │
│                    MUSI być wykonana równolegle                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.1 Klasyfikacja operacji

| Typ | Wykonanie | Przykłady |
|-----|-----------|-----------|
| **READ-ONLY** | Zawsze równolegle | `read_file`, `find_symbol`, `grep`, `list_directory` |
| **SIDE-EFFECTS** | Sekwencyjnie | `write_file`, `edit_block` |
| **AI BATCH** | Parallel (max 16) | `Invoke-AIBatch`, `Task` tool |
| **MCP CALLS** | Batch w jednej wiadomości | Multiple tool calls |

### 3.2 Wzorce

```powershell
# PowerShell parallel
$items | Invoke-Parallel { Process-Item $_ } -ThrottleLimit 8

# AI batch
Invoke-AIBatch -Prompts @("Q1", "Q2", "Q3") -MaxConcurrent 4

# MCP batch (Claude MUSI wysłać razem)
# ✅ DOBRZE: [read_file: a.txt] [read_file: b.txt] [find_symbol: MyClass]
# ❌ ŹLE:   Osobne wiadomości dla każdego tool call
```

---

## 4. FALLBACK CHAIN (Rate Limit Recovery)

### 4.1 Kolejność fallback

```
Opus wyczerpany? →
  1. 🔑 ANTHROPIC_API_KEY_2 (ten sam model, inny klucz)
  2. 🔑 ANTHROPIC_API_KEY_3 (trzeci klucz jeśli istnieje)
  3. 📉 Sonnet 4 (niższy model)
  4. 📉 Sonnet 3.5 → Haiku (dalsze obniżanie)
  5. 🔄 OpenAI (inny provider)
  6. 🔄 Ollama local (fallback ostateczny)
```

### 4.2 API Key Rotation

```powershell
# Sprawdź dostępne klucze
Get-AvailableApiKeys -Provider "anthropic"

# Sprawdź czy jest alternatywny klucz
Test-AlternateKeyAvailable -Provider "anthropic"

# Status rotacji
Get-ApiKeyRotationStatus

# Ręczne przełączenie (automatyczne gdy rate limit)
Switch-ToNextApiKey -Provider "anthropic"
```

### 4.3 Konfiguracja kluczy

```powershell
# Ustaw drugi klucz API (User scope - trwały)
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY_2', 'sk-ant-api03-...', 'User')

# Weryfikacja
$env:ANTHROPIC_API_KEY_2
```

---

## 5. OPTYMALIZACJA KOSZTÓW (Cost Efficiency)

### 5.1 Priorytet providerów

| Priorytet | Provider | Model | Koszt/1K tokens | Użycie |
|-----------|----------|-------|-----------------|--------|
| **1** | Ollama | llama3.2:3b | $0.00 | **DOMYŚLNY** |
| **2** | Groq | llama-3.3-70b | Free tier | Szybki cloud |
| **3** | Anthropic | Haiku | $0.80/$4 | Proste cloud |
| **4** | Anthropic | Sonnet | $3/$15 | Złożone |
| **5** | Anthropic | Opus | $15/$75 | Krytyczne |

### 5.2 Ustawienia

```json
{
  "preferLocal": true,
  "costOptimization": true,
  "autoFallback": true,
  "rateLimitThreshold": 0.85
}
```

### 5.3 Reguły

*   **ZAWSZE** `preferLocal: true` - proste zadania lokalnie.
*   **ZAWSZE** sprawdzaj `Get-SystemLoad` przed decyzją o providerze.
*   **ZAWSZE** używaj `Invoke-AIBatch` dla wielu niezależnych promptów.
*   **NIGDY** nie używaj Opus do prostych zadań.

---

## 6. MODUŁY AI HANDLER (Auto-loaded at startup)

### 6.1 Fazy ładowania (AIFacade)

| Faza | Moduły | Opis |
|------|--------|------|
| **1** | Utils | JsonIO, Health, Validation |
| **2** | Core | Constants, Config, State |
| **3** | Infrastructure | RateLimiter, ModelSelector |
| **4** | Providers | Ollama, Anthropic, OpenAI |
| **4.5** | Fallback | ApiKeyRotation, ProviderFallback |
| **5** | Advanced | SelfCorrection, FewShot, ContextOptimizer... |

### 6.2 Komendy slash

| Komenda | Funkcja | Moduł |
|---------|---------|-------|
| `/ai <query>` | Quick local query | AIModelHandler |
| `/ai-batch` | Parallel batch | AIModelHandler |
| `/ai-status` | Provider status | AIModelHandler |
| `/self-correct` | Code validation | SelfCorrection |
| `/speculate` | Model racing | SpeculativeDecoding |
| `/few-shot` | History learning | FewShotLearning |
| `/optimize-context` | Token dashboard | ContextOptimizer |

---

## 7. CHECKLIST (Przed każdym zadaniem)

```
□ Sprawdź pamięć Serena (Get-AllSerenaMemories)
□ Sprawdź cache MCP (Get-MCPCacheStats)
□ Sprawdź obciążenie CPU (Get-SystemLoad)
□ Wybierz provider (preferLocal → cloud fallback)
□ Rozbij na pod-zadania jeśli możliwe
□ Uruchom równolegle read-only operacje
□ Zapisz wyniki do pamięci sesji
```

---

> *"Trzy głowy, jeden cel. HYDRA wykonuje równolegle."*
