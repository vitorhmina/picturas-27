#import "../template.typ": *

// Primeira parte na horizontal (a matriz de efeitos é larga); o resto do capítulo na vertical.
#paisagem[
= Trade-offs, Medição e Preservação Funcional

== Matriz de efeitos

#tab([Matriz de efeitos das decisões],
  tabela(
    colunas: (1.3cm, 1fr, 1fr, 1fr, 1fr, 1fr, 1.3fr),
    tamanho: 8pt,
    [Decisão], [Desempenho], [Disponibilidade / Fiabilidade], [Segurança], [Usabilidade], [Manutenibilidade / Testabilidade], [Justificação],
    [DA-1], [↓ ligeira: leituras de estado adicionais (cap. 8)], [\= processamento inalterado; ↑ a página termina a execução mesmo com eventos perdidos], [\= mesma autenticação e permissões de partilha], [↑ operabilidade (objetivo); ↓ edição do projeto bloqueada durante a execução], [↑ uma só fonte do estado da execução (servidor), com testes; ↓ mais um ponto de consulta e um componente global], [O custo limita-se a leituras; o bloqueio só afeta o projeto em processamento],
    [DA-2], [↓ ligeira (confirmações e persistência); reprocessamento após falha], [↑ recuperabilidade e tolerância a falhas (objetivo)], [\= (sem efeito)], [↑ os erros das ferramentas chegam ao utilizador; os trabalhos deixam de ficar pendentes], [↑ falhas visíveis e estado consistente; ↓ lógica de entrega mais complexa no orquestrador], [Na pilha final, a espera mediana desce, mas o _makespan_ de uma rajada sobe, sobretudo pela separação do vídeo (E1–E2, abaixo). O reprocessamento pode reaplicar um efeito de imagem (cap. 8)],
  ),
)

== Interação entre DA-1 e DA-2

#tab([Interação entre as decisões],
  tabela(
    colunas: (2cm, 2cm, 3.6cm, 1fr),
    [Decisão A], [Decisão B], [Efeito], [Razão / evidência],
    [DA-2], [DA-1], [Pré-requisito], [O estado da execução é derivado dos registos `Process` que a DA-2 mantém fiáveis; sem ela, um passo perdido deixaria a execução «em curso» para sempre, também na página.],
    [DA-1], [DA-2], [Sinergia], [Os eventos com `projectId` e a consulta do estado levam os erros da DA-2 à página do projeto afetado.],
  ),
)
]

== Plano de medição

#tab([Plano de medição],
  tabela(
    colunas: (1.3cm, 1fr, 2.5cm, 3cm, 2.4cm, 2.6cm),
    tamanho: 8pt,
    [Cenário], [Cenário de teste e carga (cap. 6)], [Ambiente], [O que se regista], [Repetições e agregação], [_Scripts_],
    [QS-07], [*U1:* vídeo de 10 s e 3 imagens; sondagem da interface a cada 0,25 s. \ *U2:* vídeo de 60 s, recarregado 3 s após Apply. \ *U3:* o mesmo projeto aberto num segundo separador 3 s após Apply.], [Cap. 2; Chromium sem interface (Playwright)], [Bloqueio da interface; progresso, cancelar e resultados após recarregar e no segundo separador], [5 por cenário; p50 e p95 (U1); % de repetições (U2, U3)], [`bench/background_ui.py`],
    [QS-02], [5 projetos (12 imagens, 2 vídeos) lançados em simultâneo; o alvo é terminado (SIGKILL) com trabalho em curso e reiniciado 5 s depois. \ *Alvos:* nenhum (controlo), `contrast_tool`, serviços de vídeo, `projects`.], [Igual, sem _browser_], [Estado final de cada trabalho; tempo até ao último estado terminal; `Process` órfãos], [5 por alvo; mínimo de R1, p95 de R2, máximo de R3], [`bench/chaos.py`, `bench/summarize.py`],
  ),
)

== Resultados das medições

#tab([Resultados das medições],
  tabela(
    colunas: (1.3cm, 1fr, 2.4cm, 2.4cm, 1.5cm, 1.6cm, 1.5cm),
    tamanho: 8.5pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (_baseline_)], [Depois], [Alvo], [Mínimo aceitável], [Atingido?],
    table.cell(rowspan: 5)[QS-07],
    [U1: tempo de bloqueio por execução, p50 (s): vídeo / imagens], [22,8 / 2,8], [0 / 0 (máx. 0,6 s numa repetição)], [0], [≤ 1], [Sim],
    [U1: sondagens com a interface bloqueada (%): vídeo / imagens], [96,8 / 78,6], [0 / 0 (máx. 1,3 %)], [0], [—], [Sim],
    [U2: recarregamentos com progresso e cancelar (%)], [0], [100], [100], [100], [Sim],
    [U2: execuções retomadas com os resultados mostrados sem recarregar (%)], [0], [100], [100], [80], [Sim],
    [U3: segundos separadores com progresso e cancelar (%)], [0], [100], [100], [100], [Sim],
    table.cell(rowspan: 6)[QS-02],
    [R1: trabalhos com estado terminal correto, mínimo por alvo (%): ferramenta de imagem / orquestrador], [40 / 40], [100 / 100], [100], [95], [Sim],
    [R1: trabalhos pendentes no total das 5 repetições: ferramenta de imagem / orquestrador], [12 / 8], [0 / 0], [0], [0], [Sim],
    [R2: tempo de recuperação, p95 (s): ferramenta de imagem / orquestrador], [n.d. / 10,3 (2 de 5)], [29,6 / 32,7], [≤ 30], [≤ 60], [Alvo / mínimo],
    [R2: tempo de recuperação, p95 (s): serviços de vídeo (R1 = 100 % e R3 = 0 antes e depois)], [28,7], [48,9], [≤ 30], [≤ 60], [Mínimo],
    [R3: `Process` órfãos, máximo: ferramenta de imagem / orquestrador], [8 / 7], [0 / 0], [0], [0], [Sim],
    [Falha do _broker_ seguida de SIGKILL do orquestrador (`bench/outage_crash.py`)], [Nunca termina (só com mensagens fiáveis)], [Concluído (3/3 _media_)], [Concluído], [Concluído ou erro comunicado], [Sim],
  ),
)

*Análise dos resultados* (por requisito não funcional):

*Fiabilidade (QS-02, DA-2).* Os valores «depois» são os da medição final (`bench/results/after-da2/`).

- *R1 e R3 atingem o alvo.* Na base, terminar uma ferramenta de imagem ou o orquestrador deixava até 60 % dos
  trabalhos pendentes e 8 registos `Process` órfãos, porque as mensagens eram confirmadas antes do processamento
  (EV-10, EV-12). Depois da DA-2, todos os trabalhos terminam, sem órfãos.
- *As duas partes da DA-2 cobrem falhas diferentes.* As mensagens fiáveis (PR \#3) bastam para R1–R3: o _broker_
  reentrega o passo interrompido. A recuperação de execuções (PR \#4) cobre o caso do _broker_ em baixo com o
  orquestrador terminado antes de publicar: o trabalho, que nunca terminava, passa a concluir.
- *Os erros chegam ao utilizador.* Antes eram descartados e o trabalho ficava pendente (EV-11).
- *R2 atinge o alvo com a ferramenta de imagem (29,6 s) e fica no mínimo aceitável com o orquestrador (32,7 s) e com
  os serviços de vídeo (48,9 s).* O R2 da base não é comparável: só recuperaram 2 das 10 repetições, as que não
  apanharam trabalho em curso. Depois da DA-2, os trabalhos de imagem terminam até 17 s após o reinício; o R2 é o
  tempo que falta ao vídeo mais longo do lote, que continua a ser processado.
- *No vídeo, o R2 sobe de 28,7 s para 48,9 s.* Mesmo sem falhas, o vídeo mais lento do lote demora mais na pilha
  final (cerca de 47 s, contra 29–40 s), pela mesma causa provável do custo de E2. A etapa interrompida recomeça do
  início, como o serviço único já fazia na base: a falha atrasa o vídeo cerca de 20 s, contra cerca de 16 s na base.

*Custo de desempenho (E1–E2).* E1 e E2 são as medições do QS-01 (cap. 5), repetidas na pilha final: em E1, um
trabalho curto de vídeo é submetido durante uma legendagem; em E2, chegam 10 trabalhos de vídeo em simultâneo. O
trabalho curto espera menos de metade, porque deixou de ficar atrás da legendagem. Numa rajada, a espera mediana cai,
mas o _makespan_ sobe 60 %. A medição só com a separação já tinha este _makespan_, o que a aponta como origem
principal; a cauda da espera é maior na pilha final, pelo que não se exclui um contributo da DA-2. A causa provável é
a ordem das filas entre etapas (uma réplica por etapa, e os trabalhos com legendas voltam à fila de efeitos), mas não
foi confirmada (cap. 11). A comparação é indicativa (ameaça 1).

#tab([Custo de desempenho na pilha final (E1–E2)],
  tabela(
    colunas: (1fr, 2.4cm, 2.4cm, 3.2cm),
    tamanho: 8.5pt,
    [Medição (s)], [Base], [Final], [Só separação (E1 com vídeo de 177 s)],
    [E1: espera do trabalho curto, p50 / p95], [97,0 / 112,8], [41,5 / 54,9], [134,7 / 137,3],
    [E1: legendagem, total p50], [102,4], [81,1], [228,8],
    [E2: _makespan_ de 10 trabalhos, p50 / p95], [331,2 / 350,0], [531,6 / 546,7], [523,7 / 552,6],
    [E2: espera por trabalho, p50 / p95], [41,7 / 191,6], [9,1 / 455,6], [13,4 / 218,0],
  ),
)

*Operabilidade (QS-07, DA-1).* As duas medições usam a mesma pilha; só mudam o _frontend_ (original ou final) e a
correção de `/dirty` no orquestrador (`bench/results/baseline/` e `bench/results/after-dirty-fix/`).

- *U1 atinge o alvo.* Na base, a página ficava bloqueada durante toda a execução. Depois, o bloqueio é 0 s em 9 das
  10 repetições; na restante, uma sondagem apanhou a página bloqueada no arranque (0,6 s, abaixo do mínimo de 1 s).
  As execuções não ficam mais lentas.
- *U2 e U3 atingem o alvo.* Na base, recarregar ou abrir outro separador perdia o progresso e o cancelar, e os
  resultados só apareciam ao recarregar de novo. Depois, ambos se mantêm em todas as repetições e os resultados
  aparecem sozinhos até 2 s após o fim.
- *A primeira medição «depois»* (`after-bg`) teve U2 = 80 % por um defeito pré-existente, corrigido antes da medição
  final (secção «Defeitos pré-existentes encontrados»).

*Ameaças à validade já identificadas.*

+ A máquina de medição é um portátil (Ryzen 5 5500U) partilhado. A _baseline_ de E1–E2 e R1–R3 e a medição só com a
  separação decorreram com um _cluster_ Kubernetes local alheio ao projeto, ausente na medição final, pelo que as
  comparações de tempos com elas (E1–E2, R2) são indicativas. As medições intermédias da DA-2, com a máquina ainda
  mais carregada, só servem para resultados que não dependem do tempo (R1, R3 e a falha do _broker_).
+ A espera é medida até ao primeiro evento de progresso e a conclusão por _polling_ de 1 s: os dois valores são
  limites superiores, com um erro de cerca de 1 s.
+ Com 5 repetições, o p95 coincide com o máximo e é sensível a valores extremos.

== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (2.2cm, 3cm, 2.8cm, 1fr, 3cm),
    tamanho: 8.5pt,
    [Zona alterada], [Testes existentes], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-1: estado da execução e página do projeto], [`projects/tests`; `bench/e2e_smoke.py` (5 cenários com imagens e vídeo)], [Nenhum teste da página nem do estado da execução], [`run-status.test.js` (7 testes); `bench/background_ui.py`], [U1–U3 no alvo; regressão sem falhas novas (abaixo)],
    [DA-2: entrega de mensagens e recuperação], [Nenhum], [Confirmação, reentrega, idempotência e reconciliação], [`recovery.test.js` (7 testes); `dead-letters.test.js` (1 teste); `bench/chaos.py`, com controlo sem falhas; `bench/outage_crash.py`], [R1–R3 no alvo; controlo: 100 %; regressão sem falhas novas (abaixo)],
  ),
)

*Regressão na versão final.* Todos os testes foram repetidos sobre a versão entregue: `projects/tests` 37/38,
`Tools/video_common/tests` 90/90 e `bench/e2e_smoke.py` 5/5, com imagens e vídeo. A única falha é um teste de
ligações simbólicas já existente, que não corre em Windows. As duas alterações posteriores à medição final
(cap. 8) foram ainda verificadas com `bench/chaos.py`, com o orquestrador como alvo (2 repetições: R1 = 100 %,
R3 = 0); os valores de U1–U3 e R1–R3 da secção «Resultados das medições» são anteriores a elas. A equipa testou ainda a aplicação manualmente, com imagens
e vídeos; foi assim que se encontrou o 409 depois de adicionar uma ferramenta («Defeitos pré-existentes encontrados»).

#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (3.4cm, 2.4cm, 1fr, 4cm),
    tamanho: 8.5pt,
    [Risco], [Funcionalidade afetada], [Mitigação], [Teste de regressão],
    [A divisão do vídeo em etapas muda o resultado], [Vídeo: efeitos, legendagem, extração], [Etapas só onde o serviço único já recodificava; extração no fim], [`bench/video_equivalence.py`: 9/9 saídas idênticas; `bench/e2e_smoke.py`: 5/5],
    [A reentrega duplica resultados], [Imagem e vídeo], [Respostas idempotentes pelo estado do `Process` (desvio 2 da DA-2); risco residual de reaplicar um efeito de imagem (cap. 8)], [R1–R3 (R3 = 0); sem verificação do conteúdo dos resultados (lacuna)],
    [O _commit_ da execução acontece cedo demais ou nunca], [Imagem e vídeo, incluindo extração], [Registo prévio do lote e _commit_ só quando não restam `Process`], [`process-batch.test.js`, `frame-extraction.test.js`; controlo],
    [O utilizador altera o projeto a meio de uma execução], [Imagem e vídeo], [Edição do projeto bloqueada durante a execução (cap. 8)], [Utilização manual pela equipa],
    [Um estado antigo do servidor termina a execução na página antes de tempo], [Imagem e vídeo], [Só conta um estado posterior ao registo da execução, e os resultados exigem uma execução confirmada; o último `Process` só é removido depois do _commit_ (cap. 8)], [U2; `run-status.test.js`],
  ),
)

== Defeitos pré-existentes encontrados

Os defeitos seguintes já existiam no _commit_ de partida. Os dois que afetavam o objeto da melhoria foram corrigidos
dentro das decisões; os outros dois foram corrigidos à parte. Nenhuma correção acrescenta funcionalidade (não são
classe C); ficam registados para não serem confundidos com efeitos das decisões.

#tab([Defeitos pré-existentes encontrados e corrigidos],
  tabela(
    colunas: (3cm, 3.4cm, 1fr, 3cm),
    tamanho: 8.5pt,
    [Defeito], [Sintoma], [Causa e correção], [Verificação],
    [Respostas de erro das ferramentas com identificadores trocados (EV-11)], [Um erro de uma ferramenta nunca chegava ao utilizador e o trabalho ficava pendente], [O `messageId` e o `correlationId` estavam trocados, bem como a ordem dos argumentos. Corrigido na DA-2 (`a69a0e8`, classe B)], [`process-error` recebido pelo utilizador],
    [Apply rejeitado com 409 depois de adicionar uma ferramenta], [O processamento falhava até a página ser recarregada], [Uma resposta lida antes da escrita de `/dirty` e recebida depois dela repunha em _cache_ uma versão desatualizada do projeto. A página volta a pedir o projeto quando uma resposta traz uma versão inferior à que já tem (`7f75a8c`, PR \#7)], [409 em 2 de 5 tentativas antes, 0 de 15 depois],
    [A barra de progresso recuava de 100 % para 75 %], [Em projetos com imagens e vídeos, perto do fim], [Um vídeo a 100 % era descontado antes do seu evento de conclusão; a barra mostra agora o valor mais alto atingido (`b4326b4`, DA-1)], [Recuo em 2 de 3 execuções antes, 0 de 5 depois],
    [Apply rejeitado com 409 logo depois de abrir o projeto], [O processamento nunca começava, sem erro na página], [Ao abrir, a página grava `/dirty` sem alterar o valor, e a escrita incrementava a versão. O orquestrador deixa de escrever quando o valor não muda (`38058ce`)], [U2: 1 de 5 repetições sem início antes, 0 de 5 depois; testes da API],
  ),
)
