# ZETAGOLD — Directional Edge & Adaptive Grid — Estudo e Roadmap

**Status:** Estudo estratégico — sem alteração do comportamento econômico
**Branch:** refactor/v0.116-engine12-parity
**Data:** 2026-09-17
**Escopo:** futura evolução de R1 / Lifecycle / Grid / Recovery

## 1. Objetivo

Investigar uma vantagem estatística para escolher a direção de entrada e a distância das novas entradas do Grid, mantendo a possibilidade de ajuste de preço médio sem transformar o ZETAGOLD em um grid cego.

Hipótese central:

> Atingir o Grid Step não deve ser motivo suficiente para adicionar exposição. A nova entrada deve ser justificada pelo estado do mercado, pela expectativa condicional da direção, pelo risco incremental, pelos custos e pela capacidade de exposição disponível.

Princípios fundamentais:

- Não comprar simplesmente porque caiu.
- Não vender simplesmente porque subiu.
- Não comprar um topo, a menos que ele tenha sido superado e a continuação tenha evidência suficiente.
- Não vender um fundo, a menos que ele tenha sido superado para baixo e a continuação tenha evidência suficiente.
- WAIT é uma decisão válida.

## 2. Directional Edge Engine

Criar futuramente uma camada observacional que estime:

- P(UP | estado atual);
- P(DOWN | estado atual);
- expectativa de movimento;
- movimento adverso esperado;
- custo de execução;
- expectativa líquida.

Métrica inicial de estudo:

Directional Edge = P(UP | State) - P(DOWN | State)

O Edge não será tratado como previsão determinística. A pergunta será: estados historicamente semelhantes apresentaram assimetria de resultado para qual direção?

## 3. Quatro decisões possíveis

A camada deverá permitir:

- BUY;
- SELL;
- WAIT;
- REDUCE.

Não devemos forçar uma direção quando a evidência for insuficiente.

## 4. Adaptive Grid Direction

Fluxo futuro de estudo:

Market State → Directional Edge → Expected Value → Incremental Risk → Exposure Governance → BUY / SELL / WAIT.

O Grid continuará existindo. A mudança é que a direção da nova posição deixará de depender apenas da distância do preço.

## 5. Adaptive Grid Distance

O Step deverá ser estudado como função do regime e não necessariamente como constante.

Hipótese:

Adaptive Step = Base Step × Volatility Factor × Regime Factor × Edge Factor × Exposure Factor

Esta fórmula é apenas uma hipótese de pesquisa. Nenhum fator será implementado antes de validação.

Possíveis comportamentos:

- mercado favorável e Edge forte → Step potencialmente menor;
- tendência adversa forte → Step maior ou WAIT;
- mercado indefinido → WAIT;
- limite de risco crítico → zero novas entradas.

## 6. Averaging com vantagem direcional

Podemos manter averaging e, ao mesmo tempo, exigir que a tese direcional continue válida.

Exemplo:

BUY inicial → mercado recua → recalcular Market State → verificar se o Edge de BUY permanece positivo → verificar risco incremental → consultar R11 → somente então considerar novo BUY.

Assim, melhorar o preço médio deixa de ser a justificativa isolada.

## 7. Expected Value da nova entrada

Será estudado:

EV(q) = P(recovery) × ganho esperado − P(continuação adversa) × perda esperada − custos.

Também será investigada a quantidade ótima:

q* = quantidade que maximiza expectativa ajustada ao risco.

O maior lote permitido não será assumido como o melhor lote.

## 8. Market State

O estado de mercado poderá combinar:

- regime;
- direção da tendência;
- força da tendência;
- ATR e volatilidade;
- ADX;
- estrutura de EMAs;
- momentum;
- posição dentro das Bollinger Bands;
- distância da média;
- máximas e mínimas recentes;
- estado de breakout;
- estado de pullback;
- exposição existente.

R12 continuará como observador. O Directional Edge será a camada de interpretação estatística. Lifecycle/Grid continuará responsável pela decisão de expansão e R11 pela capacidade.

## 9. Topos, fundos e rompimentos

Estudar separadamente:

1. extremo não superado;
2. rompimento;
3. confirmação;
4. reteste;
5. continuação;
6. falso rompimento.

A hipótese não é que todo breakout deve gerar entrada. O objetivo é medir se determinadas condições de breakout produzem assimetria estatística suficiente.

## 10. Regimes

O estudo deverá separar pelo menos:

- TREND_UP;
- TREND_DOWN;
- RANGE;
- TRANSITION.

Em TRANSITION, WAIT poderá ser preferível até que uma nova direção apresente evidência suficiente.

## 11. Directional Edge Shadow

Antes de qualquer alteração econômica, criar uma camada observer-only que registre:

Timestamp, regime, preço, direção candidata, PUp, PDown, Edge, Expected Gain, Expected Loss, Cost, EV, Base Step, Adaptive Step, exposição e decisão.

Horizontes a estudar: +5, +10, +20 e +50 candles, além de horizontes em pontos normalizados por ATR.

Registrar também MFE, MAE, retorno futuro, tempo até recuperação e falha/êxito de breakout.

## 12. Exposure-aware Entry

O mesmo Edge não deve produzir o mesmo lote em qualquer estado.

Edge forte + exposição baixa pode permitir maior capacidade.

Edge forte + exposição alta deve continuar sujeito à capacidade do R11 e aos limites globais de risco.

Arquitetura proposta:

Market State → Directional Edge → Entry Decision → Adaptive Grid Distance → Lifecycle/Grid → R11 → Execution Core.

## 13. Relação com R10

A futura entrada direcional e a redução de exposição devem ser complementares:

Entrada: Market State → Directional Edge → Lifecycle/Grid → R11 → Execution.

Redução: Exposure State → R10 → R11 Reduction Capacity → Execution.

Assim teremos uma inteligência para decidir quando aumentar exposição e outra para decidir quando reduzi-la.

## 14. Pesquisa do desenvolvedor / AW

A pesquisa no material público do desenvolvedor mostrou quatro ideias particularmente relevantes para esta iniciativa:

1. AW Recovery permite que averaging seja condicionado por filtros de tendência, em vez de abrir somente pelo Step.
2. O desenvolvedor recomenda considerar ATR para determinar o espaçamento e descreve Step dinâmico por multiplicador.
3. AW Gold Trend Trading combina trend filter com averaging quando o preço se move na direção oposta.
4. AW Trend Predictor combina tendência e níveis de breakout e registra estatísticas históricas dos sinais.

Essas ideias são referências de pesquisa, não regras a copiar.

## 15. Novas sugestões para o ZETAGOLD

### Breakout Quality

Medir distância do rompimento normalizada por ATR, posição do fechamento, follow-through e sucesso do reteste.

### Pullback Quality

Durante uma tendência válida, estudar se um recuo preserva características suficientes do regime para justificar averaging na direção principal.

### Adverse Continuation Probability

Antes de adicionar, estimar a probabilidade de continuação adversa. Se elevada, WAIT.

### Edge Decay

O Edge terá validade temporal. Um sinal antigo não deve permanecer válido indefinidamente.

### Regime Transition Guard

Mudança de regime poderá invalidar a direção anterior e forçar WAIT.

### Exposure-aware Edge

O Edge deve ser combinado com exposição atual, Recovery Load e capacidade R11.

## 16. Invariantes propostos

DG-1 — No Blind Averaging: atingir o Step não é suficiente.

DG-2 — Directional Evidence: nova entrada deve possuir evidência direcional ou política de averaging explicitamente autorizada.

DG-3 — No Top Buying: não adicionar BUY em extremo superior sem condição de continuação validada.

DG-4 — No Bottom Selling: não adicionar SELL em extremo inferior sem condição de continuação validada.

DG-5 — WAIT: ausência de Edge suficiente produz WAIT.

DG-6 — Adaptive Distance: Step não é necessariamente constante.

DG-7 — Exposure Governance: Edge forte não autoriza exposição ilimitada.

DG-8 — No Lookahead: somente dados disponíveis no instante da decisão.

DG-9 — Shadow First: nenhuma mudança econômica antes da validação.

## 17. Etapas planejadas

DG-1 — Auditoria do Lifecycle/Grid: identificar exatamente quem cria BUY/SELL, em quais condições, com quais Steps e se existe filtro direcional atual.

DG-2 — Market State Dataset: criar o registro histórico dos estados.

DG-3 — Directional Edge Shadow: observar BUY/SELL/WAIT sem executar.

DG-4 — Extreme / Breakout Study: estudar topo, fundo, rompimento, reteste, continuação e falha.

DG-5 — Conditional Probability: medir P(UP | State) e P(DOWN | State).

DG-6 — Expected Value: incorporar payoff, perda esperada e custos.

DG-7 — Adaptive Grid Direction: comparar Grid atual contra direção condicionada.

DG-8 — Adaptive Grid Distance: comparar Step fixo, ATR, regime e combinação Edge + Regime + Exposure.

DG-9 — Averaging with Directional Edge: testar quando uma posição perdedora ainda possui Edge suficiente para novo ajuste.

DG-10 — Exposure-aware Entry: integrar Edge e capacidade R11.

DG-11 — Walk-Forward: validação fora da amostra.

DG-12 — Monte Carlo / Stress: robustez a sequências, custos e eventos extremos.

DG-13 — Controlled Activation: ativação somente após evidência suficiente.

## 18. Critério de sucesso

Não será suficiente aumentar P/L ou quantidade de trades.

A hipótese será considerada interessante somente se demonstrar fora da amostra:

- Edge direcional persistente;
- EV positivo após custos;
- redução de entradas estruturalmente ruins;
- controle de exposição;
- comportamento melhor em tendências adversas;
- robustez em diferentes regimes;
- ausência de dependência excessiva de um período específico.

## 19. Relação com o R10 v2

A prioridade imediata continua sendo o TESTE3 do R10 v2 Shadow.

Depois dele, a investigação estrutural desta iniciativa começará pela auditoria do Lifecycle/Grid.

Sequência:

TESTE3 → Lifecycle/Grid Audit → Directional Edge → Adaptive Grid Direction → Adaptive Grid Distance.

## 20. Decisão registrada

Esta iniciativa fica registrada como uma linha futura do projeto ZETAGOLD, sem alteração econômica no EA atual.

Hipótese central:

> O ZETAGOLD deve adicionar exposição somente quando a combinação entre direção, estado do mercado, expectativa condicional, estrutura da posição, custo e capacidade de exposição justificar matematicamente a nova exposição.

Referências externas pesquisadas:

- AW Recovery: https://www.mql5.com/en/blogs/post/749585
- AW Recovery inputs: https://www.mql5.com/en/blogs/post/749512
- AW Gold Trend Trading: https://www.mql5.com/en/market/product/56647
- AW Trend Predictor manual: https://www.mql5.com/en/blogs/post/738049
