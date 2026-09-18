# ZETAGOLD — R10 REDUCE v2 — Estudo, Objetivo e Evolução

**Status:** Estudo aprovado — ETAPAS 5 a 11 concluídas; sem alteração de comportamento econômico  
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

### ETAPA 9 — Structural Impact & Average Adjustment — CONCLUÍDA

Esta etapa definiu como medir o efeito estrutural de uma redução antes de transformar o conceito em regra operacional.

#### 9.1 Weighted Average por direção

Para uma direção com tickets (i=1..n):

```
WeightedAverage = Σ(Lots_i × OpenPrice_i) / Σ(Lots_i)
```

Para uma redução de `q` lotes do ticket `k`:

```
NewAverage =
    (Σ(Lots_i × OpenPrice_i) - q × OpenPrice_k)
    / (TotalLots - q)
```

A variação pode ser expressa como:

```
AverageDelta =
    q × (AverageBefore - OpenPrice_k)
    / (TotalLots - q)
```

Consequência importante:

- reduzir parcialmente um único ticket **não altera o OpenPrice daquele ticket**;
- o Weighted Average da direção somente muda quando a composição ponderada dos tickets muda;
- retirar volume de um ticket acima da média desloca a média remanescente para baixo;
- retirar volume de um ticket abaixo da média desloca a média remanescente para cima.

Portanto, "Position Adjustment" deve distinguir **redução de volume** de **melhoria da composição média**.

#### 9.2 Structural Impact

O impacto estrutural de uma ação R10 será observado em dimensões independentes:

```
Volume Relief
Gross Exposure Relief
Net Exposure Change
Weighted Average Delta
Average Distance To Market
Recovery Load Relief
Concentration Change
Recovery Capacity Change
```

Não será criado, nesta etapa, um score único.

#### 9.3 Average Distance to Market

Para uma direção:

```
AverageDistance =
    Σ(Lots_i × |OpenPrice_i - MarketReference|)
    / Σ(Lots_i)
```

A referência de mercado deverá ser definida de forma consistente com a direção e o instrumento; para estudo inicial, será usado o preço executável/relevante do lado da posição, evitando misturar referências entre cenários.

#### 9.4 Recovery Load — refinamento

A hipótese anterior:

```
Recovery Load ≈ Lots × Distance
```

foi refinada para uma forma agregada por ticket:

```
RecoveryLoad =
    Σ(Lots_i × Distance_i)
```

E, quando convertido para unidade monetária:

```
RecoveryLoadMoney =
    Σ(Lots_i × Distance_i × ValuePerPoint_i)
```

A fórmula continua sendo uma **métrica de estudo**, não uma regra econômica definitiva.

O ganho estrutural de uma redução poderá ser medido por:

```
RecoveryLoadRelief =
    RecoveryLoadBefore - RecoveryLoadAfter
```

#### 9.5 Basket Break-Even

Não devemos confundir:

- Weighted Average de BUY;
- Weighted Average de SELL;
- Break-Even da cesta completa.

O Break-Even da cesta depende simultaneamente de:

- volumes BUY e SELL;
- preços de entrada;
- preço atual;
- valor por ponto;
- spread;
- swap;
- comissão;
- custos de execução.

Logo, o R10 v2 deverá registrar separadamente:

```
BUY Weighted Average
SELL Weighted Average
Basket Net Exposure
Basket Break-Even
```

O Basket Break-Even será tratado como resultado econômico derivado, e não como substituto do Weighted Average.

#### 9.6 Position Adjustment — efeito desejável

Uma redução seletiva somente deverá ser considerada estruturalmente favorável quando houver evidência mensurável em uma ou mais dimensões, por exemplo:

```
- menor Gross Exposure;
- menor Recovery Load;
- menor concentração em ticket adverso;
- melhora da composição ponderada;
- preservação controlada do Net Exposure;
- aumento da Recovery Capacity.
```

Uma redução que apenas realiza prejuízo, sem produzir benefício estrutural observável, não deverá ser classificada automaticamente como oportunidade R10.

#### 9.7 Balanced Reduce — efeito estrutural

Para:

```
BUY = B
SELL = S
q = redução comum
```

temos:

```
BUY'  = B - q
SELL' = S - q
GROSS' = GROSS - 2q
NET'   = NET
```

desde que `q` seja executado integralmente nos dois lados.

Portanto, Balanced Reduce possui uma propriedade estrutural clara:

> reduz GROSS Exposure sem alterar NET Exposure.

Essa propriedade deverá ser preservada como hipótese principal do modo Balanced, mas sempre condicionada à execução efetiva das duas pernas e à política de risco.

#### 9.8 Recovery Capacity

A redução de volume pode aumentar a capacidade operacional de recuperação, mas isso não deve ser presumido.

Para fins de estudo, serão registrados:

```
Recovery Capacity Before
Recovery Capacity After
Capacity Delta
```

A definição monetária/operacional dessa capacidade será refinada nas etapas seguintes.

#### 9.9 Structural Impact Record

Cada ação candidata do R10 v2 deverá poder gerar, em telemetria, um registro conceitual:

```
Action
Objective
Tickets
RequestedLots
AuthorizedLots

GrossBefore
GrossAfter
GrossRelief

NetBefore
NetAfter
NetDelta

WeightedAverageBefore
WeightedAverageAfter
AverageDelta

RecoveryLoadBefore
RecoveryLoadAfter
RecoveryLoadRelief

BasketBreakEvenBefore
BasketBreakEvenAfter

RealizedP/L
ExecutionCost
CapitalConsumed
```

Esse registro será fundamental para o futuro Shadow/Counterfactual Instrumentation.

#### 9.10 Conclusão da ETAPA 9

A conclusão desta etapa é:

> **R10 v2 não deve considerar uma redução "boa" apenas porque ela diminui lotes. Deve medir como a ação altera a estrutura remanescente da operação.**

Assim, o fluxo conceitual passa a ser:

```
Opportunity
    ↓
Target Selection
    ↓
Structural Impact Projection
    ↓
Capital / R11 Authorization
    ↓
Reduction Plan
    ↓
Execution
    ↓
Reconciliation
    ↓
Structural Impact Actual
```

**Nenhuma mudança econômica foi implementada nesta etapa.**

---

### ETAPA 10 — R11 Governor — CONCLUÍDA

Esta etapa separou formalmente duas responsabilidades que não devem ser confundidas:

- **R10 decide se uma redução faz sentido economicamente e qual redução deseja executar**;
- **R11 governa a capacidade máxima dessa redução quando ela puder interferir na arquitetura de recuperação**.

A implementação atual do R11 já possui um governador operacional para **adições de recuperação** por meio de `R11RecoveryLotFactor()` e `R11RecoveryAdditionAllowed()`. A conclusão desta etapa não altera esse comportamento. O estudo define a extensão conceitual do R11 para o caminho de REDUCE.

#### 10.1 Princípio de autoridade

Fluxo aprovado:

```
R10 Opportunity
      ↓
R10 Desired Reduction
      ↓
R11 Reduction Governor
      ↓
R10 Authorized Reduction
      ↓
Execution Core
      ↓
Reconciliation
```

O R11 **não escolhe o alvo**, não define a oportunidade e não executa ordens.

Ele responde apenas:

> **"Dada a redução desejada pelo R10, qual é a capacidade máxima que a política de recuperação permite neste momento?"**

#### 10.2 Assimetria importante: adicionar ≠ reduzir

Uma conclusão central desta etapa é que o R11 não deve ser tratado como um simples "limitador de lote" simétrico.

Adicionar recuperação aumenta GROSS Exposure.

Reduzir exposição normalmente diminui GROSS Exposure.

Portanto:

```
Recovery Addition → Governor restritivo
Reduction         → Governor normalmente permissivo
```

Porém, uma redução excessiva pode remover volume/estrutura necessária para determinadas políticas de recuperação. Por isso, o R11 pode impor **preservação mínima de estrutura**, mas somente quando existir uma regra de recuperação que justifique essa preservação.

Não devemos bloquear uma redução apenas porque ela reduz capacidade potencial de recuperação futura.

#### 10.3 R11 Reduction Capacity

A capacidade de redução será conceitualmente definida como:

```
R11ReductionCapacity =
    MIN(
        PerActionCapacity,
        DirectionCapacity,
        StructureCapacity,
        RecoveryPolicyCapacity
    )
```

Cada componente deve ser explicável.

**PerActionCapacity**

Limite máximo de lotes que uma única ação R10 pode remover.

**DirectionCapacity**

Limite associado à direção alvo e à exposição atual.

**StructureCapacity**

Limite destinado a preservar uma estrutura mínima quando essa preservação for explicitamente exigida.

**RecoveryPolicyCapacity**

Limite derivado de uma política de recuperação ativa, quando aplicável.

Se nenhuma política exigir preservação adicional:

```
RecoveryPolicyCapacity = INFINITE
```

e o R11 não deve inventar uma restrição.

#### 10.4 Hard Block

O R11 pode produzir:

```
R11ReductionCapacity = 0
```

somente quando houver condição objetiva de bloqueio, por exemplo:

- ação incompatível com uma política de recuperação ativa;
- violação de estrutura mínima explicitamente configurada;
- limite operacional por ação atingido;
- estado de reconciliação/inconsistência que impeça nova mutação.

O último caso pertence primordialmente ao Execution/Reconciliation layer e não deve ser duplicado como lógica econômica do R11.

#### 10.5 Taper

Assim como o R11 atual reduz progressivamente a capacidade de **adicionar** recuperação quando o GROSS Exposure se aproxima do bloqueio, uma política futura poderá limitar progressivamente a **redução** quando a operação estiver próxima de uma estrutura mínima necessária.

Entretanto:

> **Taper de redução não é default.**

Somente deve existir se backtests demonstrarem que remover exposição além de determinado ponto prejudica sistematicamente a recuperação.

#### 10.6 Preservação de NET Exposure

O R11 não deve assumir que NET Exposure precisa ser preservado.

Essa é uma decisão do R10.

Exemplo:

```
BUY 10
SELL 8

Balanced Reduce:
BUY 9
SELL 7

NET = +2  → preservado
```

O R11 pode limitar `q`, mas não deve transformar uma redução Balanced em Directional Reduction por conta própria.

Portanto:

```
R10 = decide Objective
R11 = limits Capacity
```

#### 10.7 Relação com R11 atual

O R11 existente calcula:

```
Gross Exposure
Net Exposure
Net/Gross Ratio
Recovery Lot Factor
Gross Exposure Block
Gross Exposure Taper
Minimum Net/Gross Ratio
Minimum Recovery Lot Factor
```

Esses mecanismos continuam ligados ao **Recovery Addition Path**.

Para o R10 v2, a futura instrumentação deverá registrar separadamente:

```
R11 Addition Capacity
R11 Reduction Capacity
```

Não devemos reutilizar automaticamente `R11RecoveryLotFactor()` para REDUCE, porque a semântica econômica é diferente.

#### 10.8 Authorized Reduction

A fórmula conceitual consolidada passa a ser:

```
CandidateReduce
        ↓
Capital Capacity
        ↓
Exposure Capacity
        ↓
R11 Reduction Capacity
        ↓
Broker Capacity
        ↓
AuthorizedReduce
```

Ou:

```
AuthorizedReduce =
MIN(
    CandidateReduce,
    CapitalCapacity,
    ExposureCapacity,
    R11ReductionCapacity,
    BrokerCapacity
)
```

seguida da normalização para `LotStep/MinLot`.

#### 10.9 R11 deve preservar a recuperação, não impedir o alívio

Foi registrada uma regra arquitetural importante:

> **O R11 existe para governar a capacidade de recuperação; não para impedir sistematicamente a redução de risco.**

Se uma redução:

- diminui GROSS Exposure;
- diminui Recovery Load;
- mantém ou melhora a capacidade de recuperação;
- não viola uma política explícita;

o R11 não deve bloquear essa ação apenas por conservadorismo genérico.

#### 10.10 Telemetria necessária

Toda decisão R10 v2 deverá poder registrar:

```
R10 Desired Lots
R11 Capacity Lots
R11 Block Reason
R11 Policy
Authorized Lots
R11 Reduction Factor
```

Quando houver redução parcial por R11:

```
Desired = 0.20
R11 Capacity = 0.10
Authorized = 0.10
```

A telemetria deve deixar claro que:

- R10 desejou 0.20;
- R11 permitiu no máximo 0.10;
- Execution Core executou 0.10, se possível.

#### 10.11 Conclusão da ETAPA 10

O R11 não será transformado em uma segunda inteligência econômica do R10.

A separação aprovada é:

```
R10 → WHY / WHAT / WHICH
R11 → HOW MUCH IS ALLOWED
Execution → EXECUTE
Reconciliation → WHAT ACTUALLY HAPPENED
```

Essa separação mantém a arquitetura determinística, auditável e compatível com a estrutura atual do ZETAGOLD.

**Nenhuma mudança econômica foi implementada nesta etapa.**

---

### ETAPA 11 — Shadow / Counterfactual Instrumentation — CONCLUÍDA

Esta etapa definiu o mecanismo de observação necessário para avaliar o R10 v2 **sem alterar o comportamento econômico do EA**.

O ZETAGOLD já possui `EAGOLD_CounterfactualPathTelemetry.mqh`, que registra o estado real da operação em arquivo CSV, incluindo tickets, volumes, P/L, exposição, ciclo, excursão e regime R12. A ETAPA 11 não substitui esse mecanismo; ela define a próxima camada: **Decision Shadow do R10 v2**.

#### 11.1 Princípio

O Shadow R10 v2 deve responder:

> **"Dado o estado real observado neste momento, o que o R10 v2 teria decidido?"**

Mas não pode:

- abrir ordens;
- fechar ordens;
- alterar SL/TP;
- reservar capital real;
- alterar Recovery State;
- alterar R11;
- alterar R13;
- alterar o Action Contract operacional.

Fluxo:

```
Estado Real
   ↓
R10 v2 Shadow
   ↓
Candidate Opportunity
   ↓
Structural Projection
   ↓
Capital Projection
   ↓
R11 Capacity Projection
   ↓
Hypothetical Authorized Reduce
   ↓
LOG ONLY
```

#### 11.2 Separação entre REAL e SHADOW

O registro deverá distinguir explicitamente:

```
REAL_ACTION
SHADOW_DECISION
SHADOW_PROJECTION
```

Uma decisão Shadow nunca deve ser interpretada como execução real.

Exemplo:

```
REAL:
BUY 0.80
SELL 0.30

SHADOW:
Objective = POSITION_ADJUSTMENT
Candidate = BUY ticket #123
DesiredLots = 0.10
CapitalCapacity = 0.08
R11Capacity = 0.10
AuthorizedLots = 0.08
Decision = CANDIDATE
ExecutedLots = 0.00
```

#### 11.3 Máquina de decisão Shadow

O modelo aprovado é:

```
OBSERVE
  ↓
ELIGIBILITY
  ↓
OPPORTUNITY
  ↓
TARGET
  ↓
STRUCTURAL PROJECTION
  ↓
CAPITAL PROJECTION
  ↓
R11 PROJECTION
  ↓
AUTHORIZED SHADOW PLAN
  ↓
RECORD
```

Nenhuma etapa chama o Execution Core.

#### 11.4 Estados de decisão

Para evitar ambiguidades, o Shadow deverá utilizar estados explicáveis:

```
NO_OPPORTUNITY
BLOCKED
CANDIDATE
AUTHORIZED
```

E razões separadas:

```
NO_EXPOSURE
NO_CAPITAL
NO_STRUCTURAL_BENEFIT
TARGET_NOT_ELIGIBLE
R11_BLOCK
BROKER_CAPACITY
COOLDOWN
RECONCILIATION_REQUIRED
POLICY_BLOCK
```

Não devemos registrar apenas "score = X". A razão da decisão precisa ser recuperável.

#### 11.5 Projection Before / After

Para cada candidato, o Shadow deverá calcular, sem executar:

```
GrossBefore / GrossAfter
NetBefore / NetAfter
TargetLotsBefore / TargetLotsAfter
WeightedAverageBefore / WeightedAverageAfter
AverageDistanceBefore / AverageDistanceAfter
RecoveryLoadBefore / RecoveryLoadAfter
BasketBreakEvenBefore / BasketBreakEvenAfter
```

Além disso:

```
GrossRelief
NetDelta
AverageDelta
RecoveryLoadRelief
```

Esses valores são **projeções matemáticas**, não resultados de execução.

#### 11.6 Capital Shadow

O Shadow deve simular o orçamento sem consumir o orçamento real:

```
ShadowCapitalAvailable
ShadowCapitalReserved
ShadowCapitalConsumed
ShadowCapitalRemaining
```

A projeção deve respeitar a mesma regra de identidade de capital definida na ETAPA 6.

Importante:

> **Shadow capital não pode contaminar o capital real.**

#### 11.7 R11 Shadow

O Shadow deve reproduzir a política do R11 de forma observacional:

```
DesiredLots
R11Capacity
AuthorizedLots
BlockReason
```

Sem alterar:

- `R11RecoveryLotFactor()`;
- Recovery Addition Path;
- estado real do governador.

Para o futuro R10 v2, uma função específica de cálculo de capacidade deverá ser preferida a reutilizar diretamente o executor do R11.

#### 11.8 Counterfactual Plan

O registro mínimo de uma decisão Shadow deverá conter:

```
Timestamp
CycleId
Direction
Objective
SelectionPolicy
TargetTicket(s)

DesiredLots
CapitalCapacity
ExposureCapacity
R11Capacity
BrokerCapacity
AuthorizedLots

GrossBefore
GrossAfter
NetBefore
NetAfter
RecoveryLoadBefore
RecoveryLoadAfter

ProjectedRealizedPL
ProjectedExecutionCost
ProjectedCapitalConsumed

DecisionState
DecisionReason
```

Quando houver múltiplos candidatos, o sistema deverá registrar o Candidate Set ou pelo menos o identificador do conjunto analisado e o alvo selecionado pela política sequencial.

#### 11.9 Comparação futura

O objetivo não é somente saber "quantas reduções teriam ocorrido".

Precisamos responder:

```
Quantas oportunidades?
Quantas bloqueadas?
Quanto volume seria reduzido?
Quanto GROSS seria aliviado?
Quanto Recovery Load seria removido?
Qual seria o custo realizado projetado?
Quantos eventos ocorreriam perto de breaks?
Quantos ocorreriam antes/depois de recovery additions?
```

A comparação deverá preservar a linha temporal para evitar viés retrospectivo.

#### 11.10 Anti-leakage / Anti-lookahead

O Shadow só pode utilizar informações disponíveis no instante da decisão.

É proibido utilizar:

- preço futuro;
- resultado futuro;
- fechamento futuro da cesta;
- informação posterior ao tick;
- resultado de execução que ainda não ocorreu.

A projeção deve ser calculada com o estado observado no momento do evento.

Essa regra é essencial para que o backtest não produza um falso resultado de qualidade.

#### 11.11 Frequência e deduplicação

O Shadow não precisa gerar uma decisão idêntica em todos os ticks.

Deveremos registrar:

- mudança de estado;
- nova oportunidade;
- mudança de alvo;
- mudança de capacidade;
- mudança de regime;
- mudança de capital;
- mudança de exposição;
- periodicidade de amostragem.

Decisões idênticas podem ser agregadas, mas o mecanismo deve preservar um identificador de decisão/evento para reconstrução temporal.

#### 11.12 REAL vs SHADOW

A telemetria futura deverá permitir reconstruir esta linha:

```
SHADOW_DECISION
      ↓
REAL_ACTION (se o R10 atual executou algo)
      ↓
REAL_STATE_AFTER
      ↓
COUNTERFACTUAL_STATE_AFTER
```

Assim poderemos responder posteriormente:

> "O que o R10 atual fez e o que o R10 v2 teria feito no mesmo contexto?"

#### 11.13 Conclusão da ETAPA 11

A decisão registrada é:

> **Antes de implementar o R10 v2, devemos instrumentá-lo em Shadow Mode e medir suas decisões contra o caminho real do ZETAGOLD.**

Isso preserva o EA atual enquanto cria evidência para decidir quais componentes do R10 v2 merecem implementação.

**Nenhuma mudança econômica foi implementada nesta etapa.**

---

## 18. Próximas etapas

### ETAPA 9
**Structural Impact & Average Adjustment**

Concluída. Esta etapa definiu as métricas de impacto estrutural antes/depois da redução.

- weighted average;
- composição da cesta;
- distribuição de volume;
- distância média;
- Recovery Load;
- capacidade de recuperação;
- Break-Even estrutural.

### ETAPA 10
**R11 Governor**

Concluída. O R11 foi definido como governador de capacidade, sem assumir a decisão econômica do R10.

### ETAPA 11
**Shadow / Counterfactual Instrumentation**

Concluída. Definido o Decision Shadow do R10 v2, com projeção before/after, capital e R11 simulados, razões de decisão e proteção contra lookahead.

### ETAPA 12
**Backtest Comparativo**

Próximo ponto oficial do estudo.

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

**Próximo ponto oficial do estudo:** ETAPA 12 — Backtest Comparativo.
