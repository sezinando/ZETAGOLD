# ZETAGOLD — ETAPA 12.1 — Baseline Runtime Validation

**Branch:** `refactor/v0.116-engine12-parity`  
**Data:** 2026-09-17  
**Status:** Checklist definida; execução depende de MetaEditor/Strategy Tester

## Objetivo

Antes de medir o R10 v2, provar que o caminho atual do ZETAGOLD constitui um baseline reproduzível e que a modularização v0.116 não alterou sua arquitetura econômica.

## Escopo do baseline

Validar, no mínimo: inicialização/ownership; R1 atomic admission; seeds; ciclo BUY/SELL; recovery/grid; R9; R10 atual; R10.2; R11; R13; BRX; trailing; R10 reconciliation; Action Contract; persistence; telemetry.

## Gate A — Compilação

Não há PASS de MetaEditor registrado após as últimas restaurações. O teste da versão atual da branch deve registrar erros, warnings, build e timestamp. Nenhum resultado de runtime deve ser considerado válido enquanto o compile gate não for PASS.

## Gate B — Startup

Verificar: `OnInit()` = `INIT_SUCCEEDED`; ownership passa; não há ciclo duplicado; persistence carrega; R12/Excursion/Counterfactual inicializam; R13 não contamina ownership Master.

## Gate C — Seed

Validar: `R1 atomic = BOTH pendings OR NONE`. Não aceitar somente BUY, somente SELL ou recriação no mesmo tick após suspensão de pending.

## Gate D — Lifecycle

Reconstruir: `R1 → activation → grid/recovery → hedge/reduction → realization → flat → R1 re-arm`.

## Gate E — R10 atual

Executar os cenários de `Tests/R10/R10_REGRESSION_SCENARIOS.md` e confirmar: não cria ordens; só reduz; exposição não aumenta; balanced reduction preserva a matemática quando ambas as pernas executam; falha parcial gera reconciliação; cooldown funciona; ownership é respeitado.

## Gate F — R13

Verificar Magic próprio, capital rastreável, ownership Master preservado, R13 → R10 adjustment com redução real de exposição e débito de capital após redução efetiva.

## Gate G — BRX / Realization

Confirmar floor/buffer, weighted BE quando configurado, fechamento transacional, cascata de realização e ausência de nova exposição indevida.

## Gate H — Telemetria

Os artefatos devem reconstruir `STATE BEFORE → DECISION → ACTION → STATE AFTER`. Counterfactual Path Telemetry permanece observer-only.

## Critério de Baseline PASS

Baseline somente será PASS quando compilação, startup, lifecycle, regressões R10, ownership/capital R13, realization, reconciliação e telemetria estiverem validados sem comportamento econômico inesperado.

## Decisão

A ETAPA 12.1 não altera o EA. Ela estabelece o controle experimental para comparar posteriormente R10 atual e Shadow R10 v2.

**Nenhum resultado numérico é declarado até que o Strategy Tester seja executado e seus artefatos estejam disponíveis.**
