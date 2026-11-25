#import "../template.typ": *

= Trade-offs, Medição e Preservação Funcional

#orientacao[
  *Origem:* Exercício 7, secção 5 do _template_ (e os riscos de preservação funcional do Bloco 2, secção 6). A mesma
  medição é feita antes e depois do _refactoring_, no mesmo ambiente.
]

== Matriz de efeitos

#paisagem[
#tab([Matriz de efeitos das decisões],
  tabela(
    colunas: (1.6cm, 2.8cm, 3.4cm, 2.6cm, 2.4cm, 3.4cm, 1fr),
    tamanho: 8pt,
    [Decisão], [Desempenho], [Disponibilidade / Fiabilidade], [Segurança], [Usabilidade], [Manutenibilidade / Testabilidade], [Justificação],
    [DA-1], [↓ ligeira: um pedido de estado ao abrir a página e um a cada 5 s durante uma execução (leituras)], [\= processamento inalterado; ↑ a página termina a execução mesmo com eventos perdidos], [\= a consulta usa a mesma autenticação e as permissões de partilha (`checkSharePermission`)], [↑ operabilidade (objetivo): página utilizável, progresso e cancelamento persistentes; ↓ edição do projeto em processamento bloqueada], [↑ estado da execução com uma só fonte (servidor), com testes (`run-status.test.js`); ↓ mais um ponto de consulta e um componente global], [O custo de desempenho limita-se a leituras; o bloqueio da edição só afeta o projeto em processamento],
    [DA-2], [↓ ligeira (confirmações e persistência das mensagens); possível reprocessamento após falha], [↑ recuperabilidade e tolerância a falhas (objetivo)], [\= (sem efeito)], [↑ erros das ferramentas passam a chegar ao utilizador; trabalhos deixam de ficar pendentes], [↑ falhas visíveis e estado consistente; ↓ lógica de entrega mais complexa no orquestrador], [O custo de desempenho é verificado repetindo E1–E2 depois da DA-2; o reprocessamento não altera resultados graças à idempotência],
  ),
)
]

== Interação entre DA-1 e DA-2

#tab([Interação entre as decisões],
  tabela(
    colunas: (2.2cm, 2.2cm, 4.4cm, 1fr),
    [Decisão A], [Decisão B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [DA-2], [DA-1], [Pré-requisito], [O estado da execução da DA-1 é derivado dos registos `Process` que a DA-2 mantém até os efeitos de cada passo estarem guardados. Sem isso, um passo perdido deixaria a execução «em curso» para sempre, também na página; com a DA-2, o vigilante termina-o com erro, que a DA-1 mostra.],
    [DA-1], [DA-2], [Sinergia], [Os eventos com `projectId` e a consulta do estado fazem chegar à página certa os erros e as recuperações da DA-2.],
  ),
)

== Plano de medição

#tab([Plano de medição],
  tabela(
    colunas: (1.4cm, 4.2cm, 3cm, 3cm, 2.6cm, 2.6cm),
    tamanho: 8pt,
    [Cenário], [Cenário de teste e carga], [Ambiente (máquina, recursos, versões)], [O que se regista], [Repetições e agregação], [Onde ficam os _scripts_ e os dados],
    [QS-07], [U1: brilho num vídeo de 10 s e brilho → contraste → saturação em 3 imagens; sondagem da interface a cada 0,25 s desde Apply até ao fim. U2: brilho num vídeo de 60 s, com recarregamento 3 s após Apply. U3: o mesmo projeto aberto num segundo separador 3 s após Apply], [Tabela 2.1; Chromium sem interface (Playwright); mesma pilha nas duas medições], [Por repetição: tempo e % de sondagens bloqueadas e duração da execução; progresso e cancelar após recarregar e no segundo separador; resultados mostrados sem recarregar e atraso; controlos do instrumento], [5 repetições por cenário; p50 e p95 _nearest-rank_ para U1; % de repetições para U2 e U3], [`bench/background_ui.py`, `bench/results/<label>/background-ui.json`],
    [QS-02], [5 projetos (3 × 4 imagens, 2 vídeos) com brilho → contraste → saturação, lançados em simultâneo; o alvo é congelado ao despacho (`pause`) e terminado 10 s depois (SIGKILL), para que haja trabalho em curso no momento da falha; reinício 5 s depois; espera até 180 s. Alvos: nenhum (controlo), `contrast_tool`, serviço(s) de vídeo, `projects`.], [Igual ao QS-01], [Estado final de cada trabalho (concluído, erro, pendente), instantes de falha e reinício, registos `Process` órfãos no MongoDB], [5 repetições por alvo; mínimo e média de R1, p95 de R2, máximo de R3], [`bench/chaos.py`, `bench/results/<label>/chaos-<alvo>.json`; resumo com `bench/summarize.py`],
  ),
)

== Resultados das medições

#tab([Resultados das medições],
  tabela(
    colunas: (1.4cm, 1fr, 2cm, 2cm, 2cm, 2cm, 2cm),
    tamanho: 8.5pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (_baseline_)], [Depois], [Valor-alvo], [Mínimo aceitável], [Atingido?],
    [QS-07], [U1: tempo de bloqueio por execução, p50 (s): vídeo / imagens], [#preencher[…]], [#preencher[…]], [0], [≤ 1], [#preencher[…]],
    [QS-07], [U1: sondagens com a interface bloqueada (%): vídeo / imagens], [#preencher[…]], [#preencher[…]], [0], [—], [#preencher[…]],
    [QS-07], [U2: recarregamentos com progresso e cancelar (%)], [#preencher[…]], [#preencher[…]], [100], [100], [#preencher[…]],
    [QS-07], [U2: execuções retomadas com os resultados mostrados sem recarregar (%)], [#preencher[…]], [#preencher[…]], [100], [80], [#preencher[…]],
    [QS-07], [U3: segundos separadores com progresso e cancelar (%)], [#preencher[…]], [#preencher[…]], [100], [100], [#preencher[…]],
    [QS-02], [R1: trabalhos com estado terminal correto, mínimo por alvo (%): ferramenta de imagem / orquestrador], [40 / 40 (média 52 / 68)], [100 / 100 (média 100 / 100)], [100], [95], [Sim],
    [QS-02], [R1: trabalhos pendentes no total das 5 repetições: ferramenta de imagem / orquestrador], [12 / 8], [0 / 0], [0], [0], [Sim],
    [QS-02], [R2: tempo de recuperação, p95 (s): ferramenta de imagem / orquestrador], [n.d. (nenhuma repetição recuperou) / 10,3 (2 de 5)], [48,4 / 50,7 (provisório)], [≤ 30], [≤ 60], [Mínimo, provisório],
    [QS-02], [R3: `Process` órfãos, máximo: ferramenta de imagem / orquestrador], [8 / 7], [0 / 0], [0], [0], [Sim],
    [QS-02], [Falha do _broker_ (pausa) seguida de SIGKILL do orquestrador (`bench/outage_crash.py`)], [Só com DA-2 parcial (mensagens fiáveis): o trabalho nunca termina], [Concluído (3/3 _media_) em 40,5 s], [Concluído], [Concluído ou erro comunicado], [Sim],
  ),
)

*Análise dos resultados* (por requisito não funcional):

*Fiabilidade (QS-02, DA-2).* Os valores «depois» são os de `bench/results/process-recovery/` (PR \#4, sobre o PR \#3);
os resultados intermédios, só com as mensagens fiáveis, estão em `bench/results/reliable-messaging/`.

- *R1 e R3 atingem o alvo.* Na base, terminar uma ferramenta de imagem ou o orquestrador a meio de um lote deixava, no
  pior caso, 60 % dos trabalhos pendentes para sempre e até 8 registos `Process` órfãos, porque as mensagens eram
  confirmadas antes do processamento (EV-10, EV-12). Depois da DA-2, os 25 trabalhos de cada alvo terminam em todas as
  repetições, sem pendentes nem órfãos. As mensagens fiáveis (PR \#3) bastam para este cenário: o _broker_ reentrega o
  passo interrompido. A recuperação de execuções (PR \#4) cobre as falhas que a reentrega não resolve: com o _broker_
  em baixo e o orquestrador terminado antes de publicar, o trabalho nunca terminava; agora o vigilante publica o passo
  registado e o trabalho conclui em 40,5 s.
- *Os erros chegam ao utilizador.* Com os identificadores e a ordem dos argumentos corrigidos, um erro de uma ferramenta
  chega ao utilizador como `process-error` em 0,1 s; antes era descartado e o trabalho ficava pendente (EV-11).
- *R2 fica dentro do mínimo aceitável, mas não do alvo, e o valor é provisório.* O R2 da base não é comparável: com a
  ferramenta de imagem nenhuma repetição recuperou, e com o orquestrador só recuperaram as 2 repetições em que a falha
  não apanhou trabalho em curso, o que favorece a base. Depois da DA-2, o R2 inclui reprocessar o passo interrompido
  com a máquina em sobrecarga (ameaça 5), pelo que é repetido na medição final.
- *Efeitos noutros atributos.* No controlo (sem falhas) todos os trabalhos continuam a terminar e os testes ponta a
  ponta passam (5/5), pelo que as confirmações não alteram os resultados. O custo de desempenho das confirmações e da
  persistência é medido na medição final, repetindo E1–E2.

#preencher[Operabilidade (QS-07, DA-1): após a medição de `bench/background_ui.py` antes e depois.]

*Ameaças à validade já identificadas.* (1) A máquina de medição é um portátil (Ryzen 5 5500U) partilhado com outros
contentores, cuja lista fica registada em cada ficheiro de resultados para garantir as mesmas condições antes e
depois. (2) O primeiro evento de progresso surge após cerca de 1–2 % dos fotogramas, pelo que a «espera» é um limite
superior do tempo em fila (erro inferior a 1 s nos vídeos curtos). (3) O instante de conclusão é obtido por
_polling_ de 1 s. (4) Com 5 repetições, o p95 coincide com o máximo e é sensível a valores extremos. (5) As medições
intermédias da DA-2 decorreram com a máquina limitada (bateria a carregar a partir de 44 %, navegador com carga e um
_cluster_ Kubernetes local alheio ao projeto a usar 25–40 % de CPU): processar diretamente o vídeo de 10 s demorou
41,6 s em vez de cerca de 13 s. As taxas de conclusão (R1) e os órfãos (R3) não dependem do tempo e são válidos; os
tempos (R2) não são comparáveis e são repetidos na medição final, com a máquina em repouso e ligada à corrente
(`bench/results/*/NOTE.txt`).

== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (2.4cm, 4cm, 3cm, 3.2cm, 1fr),
    tamanho: 8.5pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-1: estado da execução e página do projeto], [`projects/tests` (`node --test`); `bench/e2e_smoke.py` (5 cenários com imagens e vídeo, incluindo o número de eventos `process-update`)], [Nenhum teste da página do projeto nem do estado da execução], [`projects/tests/run-status.test.js` (6 testes: passos por imagem e por vídeo, itens terminados, execução confirmada, registos de outras execuções e pré-visualizações, falha, projeto nunca processado); `bench/background_ui.py` com controlos; o cliente de medição passou a aceitar o segundo argumento de `process-update`], [`projects/tests`: 35/36 (a falha é o teste de ligações simbólicas, que não corre em Windows); #preencher[ponta a ponta e U1–U3 após a medição]],
    [DA-2: entrega de mensagens e recuperação], [Nenhum], [Confirmação, reentrega, idempotência e reconciliação não têm testes], [`projects/tests/recovery.test.js` (7 testes: publicação com registo da confirmação, republicação de passos nunca publicados, falha de passos expirados só com a fila vazia, prazo maior para vídeo, barreira de _commit_ da extração, erro de pré-visualização); cenário de controlo `chaos.py --target none`; `bench/outage_crash.py` (falha do _broker_ e do orquestrador); verificação do caminho de erro], [`projects/tests`: 29/30 (a falha é um teste de ligações simbólicas já existente, que não corre em Windows); `Tools/video_common/tests`: 90/90; ponta a ponta (`bench/e2e_smoke.py`): 5/5, com imagens e vídeo; controlo: 100 % em 5/5 repetições],
  ),
)

#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (3.4cm, 3.2cm, 4cm, 1fr),
    tamanho: 8.5pt,
    [Risco], [Funcionalidade afetada (imagem / vídeo)], [Mitigação], [Teste de regressão],
    [Separação do vídeo (preparatória): a divisão em estágios altera a ordem ou o número de codificações e muda o resultado], [Vídeo: efeitos, legendagem, extração], [Agrupar efeitos contíguos num só estágio, como antes; manter a extração no fim], [`bench/video_equivalence.py`: 9/9 saídas idênticas; `bench/e2e_smoke.py`: 5/5],
    [Reentrega processa duas vezes o mesmo passo e duplica resultados], [Imagem e vídeo], [Respostas idempotentes pelo estado do `Process` (`output_stored`, `successor_msg_id`; desvio 2 da DA-2)], [Cenários de falha R1–R3, em que o _broker_ reentrega o passo interrompido: R3 = 0. Sem teste unitário dedicado (lacuna)],
    [O _commit_ da execução passa a acontecer cedo demais ou nunca], [Imagem e vídeo, incluindo extração de fotogramas], [Manter o registo prévio do lote (`processBatch.js`) e a regra de _commit_ quando não restam `Process`], [`projects/tests/process-batch.test.js`, `frame-extraction.test.js`; cenário de controlo],
    [Com a página utilizável, o utilizador altera o _pipeline_ ou remove _media_ a meio de uma execução], [Imagem e vídeo], [Edição do _pipeline_, assistente, predefinições e adição e remoção de _media_ bloqueados para o projeto em processamento], [Verificação manual; U1 sonda só uma ação de leitura (descarregar)],
    [Um estado antigo do servidor termina a execução na página antes de tempo], [Imagem e vídeo], [Só conta um estado obtido depois de o servidor registar a execução; terminar pelo estado exige uma execução confirmada (`committed`)], [U2 (resultados mostrados depois do fim, nunca antes); `run-status.test.js`],
  ),
)

== Defeitos pré-existentes encontrados

Os testes na pilha em execução revelaram defeitos que já existiam no _commit_ de partida e que não pertencem a nenhum
dos RNF escolhidos. Foram corrigidos à parte, sem alterar o comportamento pretendido nem acrescentar funcionalidade
(não são classe C), e ficam registados aqui para não serem confundidos com efeitos das decisões.

#tab([Defeitos pré-existentes encontrados e corrigidos],
  tabela(
    colunas: (3cm, 4.2cm, 1fr, 2.8cm),
    tamanho: 8.5pt,
    [Defeito], [Sintoma], [Causa e correção], [Verificação],
    [Respostas de erro das ferramentas com identificadores trocados (EV-11)], [Um erro de uma ferramenta nunca chegava ao utilizador e o trabalho ficava pendente], [O `messageId` e o `correlationId` estavam trocados, bem como a ordem dos argumentos. Por ser objeto da recuperabilidade, a correção faz parte da DA-2 (`a69a0e8`, classe B)], [Erro comunicado em 0,1 s (secção anterior)],
    [Apply rejeitado com «Project version conflict» depois de adicionar uma ferramenta], [O pedido de processamento falhava com 409 até a página ser recarregada], [Adicionar uma ferramenta volta a pedir o projeto e, logo a seguir, marcar o projeto com alterações por guardar (`/dirty`) incrementa outra vez a versão. Se o servidor lia o projeto antes dessa escrita e respondia depois dela, a resposta substituía a versão em _cache_ pela anterior, e todas as edições seguintes enviavam uma versão desatualizada. A página volta a pedir o projeto quando uma resposta traz uma versão inferior à que já tem (`7f75a8c`, PR \#7, `frontend/lib/queries/projects.ts`)], [Adicionar uma borda e aplicar logo: 409 em 2 de 5 tentativas antes, 0 de 15 depois],
    [A barra de progresso recuava de 100 % para 75 %], [Em projetos com imagens e vídeos, a percentagem voltava atrás perto do fim], [Descrito na DA-1 (desvios), por afetar o indicador que é objeto do QS-07 (`b4326b4`)], [Recuo em 2 de 3 execuções antes, 0 de 5 depois],
  ),
)
