# Protokół Wyścigu AI (AI Race Protocol)

## Cel
Uruchomienie N agentów AI wykonujących **TO SAMO zadanie** równolegle w osobnych sandboxach, a następnie porównanie wyników.

## Prawidłowa procedura

### 1. Przygotowanie
```powershell
# Zapisz aktualny stan
git stash push -m "pre-race-backup"
# LUB utwórz branch
git checkout -b race-test
```

### 2. Uruchomienie wyścigu
Każdy agent otrzymuje **IDENTYCZNY prompt**:

```
Task(
  description="Race Agent #N",
  prompt="[IDENTYCZNE ZADANIE DLA WSZYSTKICH]",
  subagent_type="general-purpose",
  run_in_background=true
)
```

### 3. Metryki do zbierania
| Metryka | Jak mierzyć |
|---------|-------------|
| **Czas** | Timestamp start → finish |
| **Tokeny** | Z powiadomień agenta |
| **Narzędzia** | Ilość tool calls |
| **Jakość** | Manualna ocena wyniku |
| **Błędy** | Ilość errorów w output |

### 4. Porównanie wyników
```
╔═══════════════════════════════════════════════╗
║  Agent  │  Czas  │ Tokeny │ Tools │ Jakość   ║
╠═══════════════════════════════════════════════╣
║  #1     │  2m    │ 45K    │ 12    │ 95%      ║
║  #2     │  3m    │ 62K    │ 18    │ 88%      ║
║  ...    │  ...   │ ...    │ ...   │ ...      ║
╚═══════════════════════════════════════════════╝
```

### 5. Ogłoszenie zwycięzcy
Kryteria:
- **Najszybszy**: Najmniejszy czas
- **Najtańszy**: Najmniej tokenów
- **Najdokładniejszy**: Najwyższa jakość

## Czego NIE robić
- ❌ Dawać każdemu agentowi INNE zadanie (to podział pracy, nie wyścig)
- ❌ Uruchamiać agentów na tym samym pliku równolegle (konflikty)
- ❌ Zapominać o backupie stanu przed wyścigiem

## Przykład prawidłowego wyścigu
```powershell
# 3 agenty z tym samym zadaniem
1..3 | ForEach-Object {
    Task -description "Race Agent #$_" `
         -prompt "Zrefaktoryzuj plik X.ps1 zgodnie z wzorcem Y" `
         -subagent_type "general-purpose" `
         -run_in_background $true
}
```
