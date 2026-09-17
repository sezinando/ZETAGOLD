# ZETAGOLD — R10 REDUCE v2 — Estudo, Objetivo e Evolução

**Status:** Estudo aprovado — sem alteração de comportamento econômico  
**Branch de referência:** `refactor/v0.116-engine12-parity`  
**Data:** 2026-09-17  
**Escopo:** ENGINE 2 / R10 — Exposure Reduction

---

## 1. Objetivo do registro

Registrar de forma persistente a evolução conceitual do R10 REDUCE para continuidade futura do projeto ZETAGOLD.

Este documento consolida as ideias discutidas, as decisões arquiteturais já tomadas, as hipóteses a testar e o estado atual do estudo.

**Regra principal:** nenhuma mudança econômica deve ser implementada apenas com base nesta etapa de estudo. Primeiro devemos modelar, instrumentar, testar e comparar.

---

## 2. Contexto

O R10 atual do ZETAGOLD já possui mecanismos de:

- Profit-Funded Partial Reduction;
- Profit-Funded Average Adjustment;
- Balanced Exposure Reduction;
- verificação de que a redução não aumenta a exposição;
- Action Contract;
- integração com Execution Core;
- compatibilidade com R10 Reconciliation;
- telemetria/markers.

O estudo atual não pretende reconstruir o R10 do zero.

A direção aprovada é evoluir o R10 de um mecanismo predominantemente de execução de redução para uma **camada de decisão econômica de reconfiguração da posição**.

---

## 3. Ideia central aprovada

O R10 não deve pensar apenas:

> “Consigo encerrar a cesta?”

Deve também perguntar:

> “Existe uma oportunidade econômica de reduzir a carga estrutural da operação, mesmo sem condições para encerrá-la?”

A operação pode conter uma posição principal muito perdedora e posições menores em sentido oposto que geram lucro durante o movimento.

Exemplo conceitual:

```
BUY principal = 0.80
SELLs menores = posições de alívio/lucro
Mercado continua caindo
```

Mesmo que o lucro das SELLs não seja suficiente para encerrar a cesta BUY inteira, ele pode permitir uma **redução parcial das posições extremamente adversas**.

Objetivo:

- diminuir a carga da operação;
- reduzir exposição;
- reduzir necessidade futura de recuperação;
- melhorar a composição dos tickets remanescentes;
- aproveitar consolidações/retrações para ajustar a estrutura;
- evitar esperar necessariamente pelo fechamento integral da cesta.

---

## 4. Duas capacidades econômicas principais

### 4.1 Balanced Reduce

Reduz simultaneamente posições dos dois lados.

Exemplo:

```
ANTES
BUY  = 10
SELL = 8

NET   = +2 BUY
GROSS = 18

REDUCE 1 lote de cada lado

DEPOIS
BUY  = 9
SELL = 7

NET   = +2 BUY
GROSS = 16
```

Objetivo:

**reduzir GROSS EXPOSURE preservando, quando desejável, NET EXPOSURE.**

Este mecanismo evita que o sistema encerre uma cesta inteira e fique desnecessariamente carregado somente com a outra.

---

### 4.2 Position Adjustment

Seleciona e reduz parcialmente posições específicas, especialmente as mais adversas.

Exemplo:

```
BUY
0.10 @ 4500
0.10 @ 4400
0.10 @ 4300
0.50 @ 4100
```

Se houver capital/oportunidade para uma redução parcial, o R10 pode remover parte de um ticket extremamente adverso em vez de esperar capital suficiente para encerrar a cesta inteira.

O objetivo não é simplesmente realizar prejuízo.

O objetivo é:

- reduzir volume;
- reduzir Recovery Load;
- reduzir exposição;
- melhorar a composição da cesta;
- potencialmente melhorar o preço médio ponderado dos tickets remanescentes quando a seleção ocorrer entre tickets distintos.

**Observação importante:** reduzir parcialmente um único ticket não altera seu preço de entrada. A melhoria do preço médio da cesta ocorre quando a redução remove tickets de diferentes preços de entrada e altera a composição remanescente.

---

## 5. Subtipos de Position Adjustment

### PA-1 — Partial Ticket Reduction

Reduz parte de um ticket:

```
0.80 @ 4500
      ↓
0.70 @ 4500
```

Benefícios:

- menor volume;
- menor exposição;
- menor carga de recuperação;
- preço do ticket remanescente permanece igual.

### PA-2 — Ticket Selection Adjustment

Seleciona tickets específicos para alterar a composição:

```
0.10 @ 4500  ← candidato
0.10 @ 4400
0.10 @ 4300
0.50 @ 4100
```

Ao retirar o ticket de 4500, o preço médio ponderado da estrutura remanescente pode melhorar.

---

## 6. Capital interno da operação

Foi corrigido o conceito inicial de “margem para o Reduce”.

O R10 não deve tratar simplesmente `Free Margin` como dinheiro que pode ser gasto.

Devemos distinguir:

- **Margin** — margem atualmente utilizada;
- **Free Margin** — capacidade financeira livre da conta;
- **Reduction Capital** — capital econômico autorizado para financiar uma redução.

Hipótese inicial conservadora:

```
Reduction Capital
=
Authorized Realized Profit
+
Authorized R13 Recovery Capital
```

Lucro flutuante não deve ser tratado automaticamente como capital de redução.

O princípio é:

> **O R10 deve usar capital econômico gerado/disponibilizado pela própria operação, e não assumir que toda a Free Margin está disponível para consumo.**

---

## 7. Reduction Budget

Foi introduzido o conceito de:

**R10 Reduction Budget**

Componentes:

- Budget Available;
- Budget Reserved;
- Budget Consumed;
- Budget Remaining.

Exemplo:

```
Available       $150
Reserved         $80
Consumed         $80
Remaining        $70
```

O orçamento poderá ser acumulado a partir de realizações elegíveis e/ou capital de recuperação autorizado pelo R13.

A ideia é permitir que o R10 não precise agir a cada pequeno evento. Ele pode acumular capacidade e esperar uma oportunidade estruturalmente melhor.

---

## 8. Seleção de tickets

A seleção não deve ser baseada somente na maior perda absoluta.

Critérios estudados:

1. Maior perda absoluta;
2. Maior perda por lote;
3. Maior distância do preço atual;
4. Impacto sobre a estrutura;
5. Reduction/Recovery Load;
6. Custo econômico da redução.

O conceito de **Farthest/Worst Order** do AW Recovery é compatível com o ZETAGOLD e já existe parcialmente no R10 atual.

Entretanto, no ZETAGOLD ele deve ser tratado como **candidato**, não como ordem automática de fechamento.

Fluxo:

```
Farthest / Worst Candidate
        ↓
Economic Test
        ↓
Structural Test
        ↓
Capital Test
        ↓
R11 Test
        ↓
Reduction Plan
        ↓
Execution Core
        ↓
Reconciliation
```

---

## 9. Quanto reduzir — Reduce Ratio

Foi identificada como hipótese de pesquisa a utilização de uma fração da posição extrema.

Valores a estudar:

```
1/4
1/5
1/6
1/7
1/8
1/10
```

Exemplo:

```
Worst Ticket = 0.80
Reduce Ratio = 1/8

Candidate Reduce = 0.10 lot
```

A referência 1/6–1/8 veio do estudo do AW Recovery e **não deve ser assumida como ótima para o ZETAGOLD**.

Será tratada como variável experimental.

---

## 10. Exposure Relief

Métrica central proposta:

```
Exposure Relief =
Gross Exposure Before
-
Gross Exposure After
```

Exemplo:

```
18 → 16 lots

Exposure Relief = 2 lots
```

Também serão acompanhados:

- Net Exposure Before/After;
- Gross Exposure Before/After;
- Reduced Lots;
- Realized P/L;
- Capital Consumed;
- Capital Remaining.

---

## 11. Recovery Load

Foi proposta uma métrica inicial para representar a carga estrutural da recuperação:

```
Recovery Load ≈ Lots × Distance to Market
```

Uma evolução monetária poderá utilizar:

```
Recovery Load Money
≈
Lots × Distance × ValuePerPoint
```

Essa métrica ainda é **hipótese de modelagem** e deverá ser validada antes de virar regra operacional.

---

## 12. R10 Benefit

Cada oportunidade deverá ser avaliada pelo benefício estrutural e econômico, não apenas pelo P/L imediato.

Conceito preliminar:

```
R10 Benefit
=
Exposure Relief
+
Structural Improvement
+
Recovery Capacity Improvement
-
Realized Loss
-
Execution Cost
```

Os componentes e eventuais pesos ainda NÃO estão definidos.

Não devemos criar um “score mágico”. As grandezas devem permanecer explicáveis e auditáveis.

---

## 13. R11 e R13

### R11

R11 deve continuar sendo **governador de capacidade**, não executor da redução.

Fluxo:

```
R10 Desired Reduction
        ↓
R11 Governor
        ↓
R10 Authorized Reduction
        ↓
Execution Core
```

### R13

R13 continua responsável pela política de capital de recuperação.

Fluxo:

```
R13 Recovery Capital
        ↓
R10 Capital Authorization
        ↓
Reduction Budget
```

O R10 não deve acessar arbitrariamente capital da conta.

---

## 14. Arquitetura aprovada

```
ENGINE 2 — EXPOSURE MANAGEMENT
│
└── R10 — REDUCE v2
     │
     ├── Exposure Assessment
     ├── Position Census
     ├── Capital Assessment
     ├── Reduction Budget
     ├── R11 Capacity
     ├── R13 Capital
     ├── Opportunity Filter
     │
     ├── Strategy Selection
     │    ├── Balanced Reduce
     │    └── Position Adjustment
     │         ├── PA-1 Partial Ticket
     │         └── PA-2 Ticket Selection
     │
     ├── Reduce Capacity
     ├── Target Selection
     ├── Reduction Plan
     ├── Execution Core
     ├── R10 Reconciliation
     └── Telemetry
```

**Não criar uma nova Engine.**

---

## 15. Invariantes aprovados

### Invariante 1 — Exposure

> R10 nunca pode aumentar a exposição como consequência da redução.

### Invariante 2 — Economic Justification

> A existência de capital disponível, isoladamente, não é motivo suficiente para executar uma redução.

Deve existir benefício estrutural mensurável.

### Invariante 3 — Capital Authorization

> R10 somente utiliza capital explicitamente autorizado pela política de capital.

### Invariante 4 — Execution Separation

> R10 decide; Execution Core executa; Reconciliation confirma o estado real do broker.

### Invariante 5 — Basket Preservation

> R10 não deve assumir que a cesta precisa ser encerrada integralmente para produzir recuperação estrutural.

---

## 16. Relação com o AW Recovery

As ideias pesquisadas no AW Recovery servem como **referência econômica**, não como implementação a ser copiada.

Conceitos compatíveis identificados:

- tratamento parcial de posições perdedoras;
- utilização de lucros de recuperação;
- foco em posições mais adversas;
- conceito de parte da posição;
- relação entre lote de recuperação e parte a fechar;
- ajuste/redução de volume;
- importância da volatilidade para a estrutura de recuperação.

O ZETAGOLD manterá sua própria arquitetura:

```
R9
R10
R11
R12
R13
Action Contract
Execution Core
Reconciliation
Telemetry
```

---

## 17. Estado do estudo

### ETAPA 5 — Reduce Ratio e Reduce Capacity — CONCLUÍDA

Foi estabelecida a separação entre:

- **CandidateReduce** — quantidade sugerida pelo Reduce Ratio;
- **CapacityReduce** — quantidade máxima permitida pelas restrições;
- **AuthorizedReduce** — quantidade final, após capital, exposição, R11 e normalização do broker.

Ratios experimentais estudados:

```
1/4
1/5
1/6
1/7
1/8
1/10
```

Nenhum ratio foi escolhido como regra definitiva.

---

### ETAPA 6 — Recovery Capital / Reduction Budget — CONCLUÍDA

Foi formalizado o **Reduction Capital Ledger** para evitar double counting e preservar a identidade econômica do capital.

Estados conceituais:

```
GENERATED → ELIGIBLE → RESERVED → CONSUMED
                         ↓
                      RELEASED
```

Cada evento deve permitir distinguir:

- RealizedProfitGenerated;
- CapitalEligible;
- CapitalReserved;
- CapitalConsumed;
- CapitalReleased;
- CapitalRemaining.

Fontes candidatas: lucro realizado elegível, resultado líquido de operações R10 e capital de recuperação explicitamente autorizado pelo R13.

**Regra:** o mesmo resultado realizado não pode ser contabilizado duas vezes em RealizationCascade e R10 Budget.

---

### ETAPA 7 — Opportunity Filter — CONCLUÍDA

Foi definida uma decisão em camadas:

```
Eligibility
→ Capital
→ Structural Benefit
→ Economic Cost
→ Governance
→ Execution
```

Tipos de oportunidade:

- **OPP-1 Balanced Reduction** — reduzir GROSS preservando NET quando desejável;
- **OPP-2 Position Adjustment** — reduzir carga estrutural de posições adversas;
- **OPP-3 Directional Reduction** — reduzir excesso de exposição direcional quando permitido.

Dimensões observáveis:

- Exposure Relief;
- Net Exposure Preservation;
- Recovery Load Relief;
- Structural Improvement;
- Recovery Capacity Improvement;
- Execution Cost.

Foi rejeitada a utilização prematura de um score único.

---

### ETAPA 8 — Target Selection Engine — CONCLUÍDA

O R10 primeiro identifica o **objetivo da redução**, depois constrói o **Candidate Set** e somente então seleciona o alvo.

Critérios estudados:

- Farthest;
- Worst Loss;
- Loss Per Lot;
- Recovery Load;
- Concentration;
- Structural Impact;
- Easy / Hard.

Para Balanced Reduce, o alvo passa a ser um par BUY/SELL compatível, e a redução comum fica limitada pela menor capacidade elegível dos dois lados, capital, R11 e restrições do broker.

A seleção deve produzir um plano explicável contendo, conceitualmente:

- Objective;
- Target Ticket(s);
- Requested Lots;
- Authorized Lots;
- Selection Policy;
- Capital Source;
- Expected Exposure Relief;
- Expected Recovery Load Relief.

---

### Ainda não definido

- fórmula definitiva de Recovery Load;
- fórmula definitiva de R10 Benefit;
- política final de capital;
- Reduce Ratio ótimo;
- prioridade entre Balanced Reduce e Position Adjustment;
- critérios objetivos de consolidação;
- limites por ciclo/tick;
- parâmetros finais;
- impacto estatístico em backtests.

---

## 18. Próximas etapas

### ETAPA 9
**Structural Impact & Average Adjustment**

Estudar matematicamente como redução parcial e seleção de tickets alteram:

- weighted average;
- composição da cesta;
- distribuição de volume;
- distância média;
- Recovery Load;
- capacidade de recuperação;
- Break-Even estrutural.

**Próximo ponto oficial do estudo.**

### ETAPA 10
**R11 Governor**

Determinar como o governador limita a redução autorizável sem assumir a decisão econômica do R10.

### ETAPA 11
**Shadow / Counterfactual Instrumentation**

Registrar o que o R10 v2 teria decidido sem alterar o comportamento real do EA.

### ETAPA 12
**Backtest Comparativo**

Comparar:

```
R10 atual
vs
R10 instrumentado
vs
R10 v2
```

### ETAPA 13
**Implementação Controlada**

Somente após a validação dos resultados.

## 19. Critérios de validação futura

O R10 v2 deverá ser comparado por:

- Max Drawdown;
- Recovery Time;
- Gross Exposure;
- Net Exposure;
- Recovery Load;
- Number of Recovery Orders;
- Average Recovery Lot;
- R10 Reduction Frequency;
- Realized Loss from R10;
- Profit Used by R10;
- Net Reduction Result;
- R13 Contribution;
- Exposure Relief;
- Cycles Recovered;
- Cycles Broken;
- Reconciliation Events.

---

## 20. Decisão registrada

**Decisão atual:** prosseguir com o estudo do R10 REDUCE v2 mantendo duas capacidades complementares:

1. **Balanced Reduce** — redução estrutural simultânea dos lados;
2. **Position Adjustment** — redução seletiva das posições mais problemáticas.

A implementação deverá preservar a arquitetura existente e ocorrer somente depois da modelagem e validação.

**Próximo ponto oficial do estudo:** ETAPA 5 — Reduce Ratio e capacidade de redução.
