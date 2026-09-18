# ZETAGOLD — R10 v2 — ETAPA 12 Backtest Comparativo

**Branch:** `refactor/v0.116-engine12-parity`  
**Data:** 2026-09-17  
**Status:** Protocolo definido; execução bloqueada pelo Compile Gate  
**Escopo:** comparar comportamento real, Shadow R10 v2 e futura implementação R10 v2

## 1. Objetivo

Medir, em uma mesma linha temporal e com os mesmos dados de mercado, a diferença entre:

1. **BASELINE** — R10 atual do ZETAGOLD;
2. **SHADOW** — decisão hipotética do R10 v2 sobre o estado real;
3. **FUTURE ACTIVE** — R10 v2 executável, somente após validação do Shadow.

A ETAPA 12 não autoriza alteração econômica no EA.

## 2. Pré-condição obrigatória

O backtest comparativo fica **BLOCKED** enquanto o Compile Gate não estiver PASS.

O estado atual do repositório registra falha de compilação por dependências/símbolos v0.116 ainda não reconciliados. Portanto, não será fabricado resultado de Strategy Tester.

Sequência obrigatória:

```
Dependency/Compile Gate PASS
        ↓
Baseline Runtime PASS
        ↓
Shadow Instrumentation PASS
        ↓
Comparative Backtest
        ↓
Statistical/Scenario Analysis
        ↓
Decision to Implement
```

## 3. Controle experimental

Cada cenário deve usar:

- mesmo símbolo;
- mesmo período;
- mesmo timeframe;
- mesma modelagem de ticks;
- mesmo spread/configuração quando reproduzível;
- mesmo depósito e condições de conta;
- mesmas configurações do restante do EA;
- mesma janela temporal;
- nenhuma informação futura.

A única variável econômica futura deve ser o comportamento do R10.

## 4. Três caminhos de comparação

### A — Baseline

Executar o ZETAGOLD atual sem R10 v2 ativo.

Registrar:

- ciclo;
- ordens;
- BUY/SELL lots;
- GROSS/NET;
- floating P/L;
- realized P/L;
- DD;
- recovery additions;
- R10 actions;
- recovery time;
- cycle outcome.

### B — Shadow

Executar o mesmo caminho operacional, mas o R10 v2 permanece observer-only.

Para cada oportunidade hipotética registrar:

- DecisionId;
- timestamp;
- cycle;
- objective;
- selection policy;
- target ticket(s);
- desired lots;
- capital capacity;
- exposure capacity;
- R11 capacity;
- broker capacity;
- authorized lots;
- projected realized P/L;
- projected execution cost;
- gross before/after;
- net before/after;
- recovery load before/after;
- projected break-even;
- decision state/reason.

**ExecutedLots do Shadow = 0.**

### C — Future Active

Somente depois de critérios objetivos de validação do Shadow.

O R10 v2 será ativado inicialmente em modo controlado, mantendo:

- Action Contract;
- Execution Core;
- Reconciliation;
- R11 como governor;
- R13 como autoridade de capital.

## 5. Dataset de cenários

A validação deve cobrir, no mínimo:

| Cenário | Objetivo |
|---|---|
| Tendência favorável | verificar se R10 evita redução desnecessária |
| Tendência adversa | medir redução estrutural |
| Consolidação/retração | testar oportunidades de Position Adjustment |
| BUY-heavy | testar redução direcional |
| SELL-heavy | testar redução direcional simétrica |
| BUY/SELL próximos | testar Balanced Reduce |
| Basket profundamente adversa | testar capital insuficiente |
| Recovery ativo | testar interação R10/R11/R13 |
| Alta volatilidade | testar custo e capacidade |
| Baixa volatilidade | testar frequência/oportunidade |
| Break rápido | testar risco de timing |
| Execução parcial/falha | validar reconciliação |

## 6. Hipóteses

### H1 — Exposure Relief

R10 v2 deve identificar oportunidades que reduzem GROSS Exposure sem necessariamente encerrar a cesta.

### H2 — Recovery Load

Position Adjustment deve produzir redução mensurável de Recovery Load em parte dos cenários elegíveis.

### H3 — Balanced Reduce

Quando BUY e SELL possuem volume elegível, a redução comum deve preservar NET e reduzir GROSS, se esse objetivo estiver autorizado.

### H4 — Capital Discipline

Capital insuficiente deve bloquear ou limitar a redução, sem uso implícito de Free Margin.

### H5 — Structural Selection

Selecionar tickets pela estrutura pode produzir resultado diferente de simplesmente selecionar a maior perda absoluta.

### H6 — R11 Separation

R11 deve limitar capacidade quando necessário sem assumir a decisão econômica do R10.

## 7. Métricas primárias

```
Max Drawdown
Recovery Time
Gross Exposure
Net Exposure
Recovery Load
Number of Recovery Orders
Average Recovery Lot
R10 Reduction Frequency
Reduced Lots
Realized Loss from R10
Profit Used by R10
Net Reduction Result
Exposure Relief
Cycles Recovered
Cycles Broken
Reconciliation Events
```

## 8. Métricas de timing

Registrar a distância temporal entre a decisão Shadow e:

- próximo recovery addition;
- próximo aumento relevante de GROSS;
- próximo pico de floating DD;
- próximo mínimo/máximo local disponível apenas retrospectivamente para análise posterior;
- fechamento do ciclo.

A informação retrospectiva só pode ser usada **depois** do evento para análise, nunca para decidir o Shadow.

## 9. Métricas de qualidade da decisão

Não será utilizado score único.

Classificar cada decisão por resultado observável:

```
Opportunity Identified
Opportunity Blocked
Candidate
Authorized
Actual R10 Action
Projected R10 v2 Action
```

E comparar:

```
Projected Gross Relief
Actual Gross Relief
Projected Recovery Load Relief
Actual Recovery Load Relief
Projected Realized Cost
Actual Realized Cost
```

## 10. Critérios de segurança

O R10 v2 não poderá avançar para Active apenas por produzir mais reduções.

Deve demonstrar simultaneamente:

- respeito aos invariantes;
- ausência de aumento de exposição causado pela redução;
- capital corretamente atribuído;
- ausência de double counting;
- reconciliação correta;
- ausência de lookahead;
- comportamento determinístico;
- explicabilidade das decisões.

## 11. Critério de promoção

A promoção para implementação controlada exige evidência de que as decisões Shadow são economicamente plausíveis e operacionalmente seguras.

Não existe um limiar universal de melhoria de P/L definido nesta etapa.

A decisão deve considerar o conjunto de métricas e cenários, preservando também os ciclos em que **não reduzir** foi a decisão correta.

## 12. Saída esperada

O backtest deverá produzir pelo menos:

```
R10_BASELINE.csv
R10_SHADOW.csv
R10_COMPARISON.csv
R10_SCENARIO_SUMMARY.csv
```

E um relatório contendo:

- metodologia;
- dataset;
- configuração;
- divergências;
- oportunidades;
- bloqueios;
- impacto estrutural;
- custos;
- ciclos recuperados/quebrados;
- eventos de reconciliação;
- conclusão por hipótese.

## 13. Decisão da ETAPA 12

**A ETAPA 12 foi iniciada conceitualmente e o protocolo experimental está definido. A execução está bloqueada até o Compile Gate atingir PASS.**

Nenhuma mudança econômica será implementada para contornar o bloqueio.
