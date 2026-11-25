#import "../template.typ": *

= Decisões Arquiteturais

#orientacao[
  *Origem:* Exercício 7, secção 3 do _template_. Uma decisão por cenário, ao estilo ADR. Depois de implementada,
  completem cada decisão com as referências da implementação e com os desvios face ao que foi decidido.
]

== DA-1 — Estado da execução no servidor e progresso sem bloquear a página (cenário QS-07)

#tab([Decisão arquitetural DA-1],
  tabela-campos(
    [Contexto], [Durante uma execução, a página do projeto fica coberta por uma camada sobreposta até ao fim (EV-19). O estado da execução existe só na memória da página, pelo que um recarregamento ou outro separador perde o progresso e o cancelamento, embora a execução continue no servidor (EV-20). Os eventos não identificam o projeto (EV-21). Restrições: não alterar o processamento, os resultados nem a semântica do cancelamento. O servidor já guarda o estado de cada passo nos registos `Process` (DA-2).],
    [Tática(s) escolhida(s)], [TAT-12 (indicador não bloqueante), TAT-13 (estado da execução no servidor), TAT-14 (reconciliação periódica) e TAT-15 (eventos por projeto e notificação global).],
    [Estrutura / padrão que a realiza], [O servidor passa a ser a fonte do estado da execução. `projects/utils/runStatus.js` deriva-o dos _tokens_ do projeto e dos registos `Process` pendentes, sem novos campos nem escritas, e expõe-no em `GET /:user/:project/process/status`, encaminhado pelo `apiGateway`. Os eventos `process-update` e `process-error` passam a levar o `projectId` (de forma compatível: um segundo argumento e um campo extra). No _frontend_, a camada sobreposta dá lugar a um indicador no cabeçalho, com barra de progresso, percentagem e cancelar. A página consulta o estado ao abrir e retoma uma execução em curso; durante uma execução, consulta-o a cada 5 s e termina-a pelo estado do servidor se os eventos se perderam. Um componente no _layout_ do _dashboard_ notifica a conclusão ou a falha quando o utilizador está noutra página. A edição do _pipeline_ e a remoção de _media_ desse projeto ficam bloqueadas durante a execução.],
    [Alternativas consideradas e razão de rejeição], [Guardar o progresso no `localStorage`: sobrevive a um recarregamento, mas não chega a outro dispositivo e diverge do servidor (cancelamentos, falhas, recuperações). Guardar contadores de progresso no documento do projeto: uma escrita por passo e risco de divergência com os registos `Process`, que já são a fonte de verdade. Enviar o estado pelo `wsGateway` ao ligar: exigiria estado num _gateway_ hoje sem estado. Manter a camada sobreposta e só persistir o progresso: não resolve o bloqueio (U1). Pausar e retomar (TAT-16): funcionalidade nova (classe C).],
    [Consequências positivas], [A aplicação continua utilizável durante o processamento; recarregar ou abrir outro separador deixa de fazer perder o controlo da execução; os resultados aparecem mesmo com eventos perdidos; os eventos deixam de se misturar entre projetos do mesmo utilizador; o estado mostrado é o do servidor, também depois de uma recuperação da DA-2.],
    [Consequências negativas / riscos], [Pedidos de consulta adicionais (um ao abrir a página e um a cada 5 s durante uma execução, só de leitura). A edição do projeto em processamento fica explicitamente bloqueada (antes, a camada bloqueava tudo). O progresso de um vídeo retomado só reaparece no evento seguinte do vídeo. A notificação global não resolve projetos partilhados de outro proprietário.],
    [Elementos arquiteturais afetados], [`projects/utils/runStatus.js` (novo), `projects/routes/projects.js`, `projects/utils/project_msg.js`, `projects/utils/recovery.js`, `apiGateway/routes/projects.js`, `wsGateway/index.js`; no _frontend_: `app/dashboard/[pid]/page.tsx`, `app/dashboard/layout.tsx`, `components/processing-notifier.tsx` (novo), `providers/project-provider.tsx`, `components/toolbar/toolbar-button.tsx`, `components/project-page/project-image.tsx`, `lib/projects.ts`, `lib/queries/projects.ts`.],
    [Origem e âmbito do _refactoring_], [Interação entre o _frontend_ e o padrão global (estado das execuções no orquestrador). Risco de regressão baixo no processamento (só leituras novas) e médio na página do projeto.],
    [Classe (A/B/C)], [B: a apresentação do progresso muda e é o objeto da melhoria. O processamento, os resultados e o cancelamento mantêm-se (A).],
    [Implementação (_commits_ / _pull requests_)], [Ramo `feature/background-processing`, um _commit_ por funcionalidade: `2845e1c` (estado da execução), `499321a` (eventos com o projeto), `4a4e3fa` (indicador não bloqueante), `1ccec2c` (retoma após recarregar ou noutro separador), `e336cf9` (fim pelo estado do servidor), `4a49ce6` (notificação global). PR \#6. Instrumento: `8cfd60c` e `a9e812e` no ramo `test/background-work-baseline`, PR \#5, integrado antes da implementação para medir a _baseline_ com o mesmo _script_. Correção posterior: `b4326b4` (a barra de progresso deixa de recuar numa execução; ver desvios).],
    [Desvios face à decisão], [Nenhum na estrutura. Os testes na pilha revelaram um defeito já existente no cálculo do progresso, herdado da camada sobreposta: em projetos com imagens e vídeos, um vídeo a 100 % era descontado dos passos contados antes de chegar o seu evento de conclusão, e a barra recuava de 100 % para 75 % antes de voltar a 100 % (2 de 3 execuções). Com o indicador permanente no cabeçalho, o recuo passou a ser visível durante toda a execução. A barra mostra agora o valor mais alto atingido na execução (`b4326b4`; 0 de 5 execuções com recuo).],
  ),
)

== _Refactoring_ preparatório — separação do serviço de vídeo por estágio (QS-03)

Implementado como primeiro passo do CAND-3 (elasticidade), antes da reavaliação descrita no capítulo 6, e mantido
(PR \#2, `feature/split-video-workers`). O `video_tool` deu lugar a três serviços, `video_effects_tool`,
`video_subtitles_tool` e `video_frames_tool`, com filas próprias e uma biblioteca comum, `Tools/video_common/`. O
orquestrador divide o _pipeline_ de cada vídeo em estágios exatamente onde o serviço único já recodificava
(`projects/utils/videoStages.js`, espelhado por `video_common/pipeline.py` e verificado contra o mesmo ficheiro de
casos). Os resultados não mudaram: 9/9 saídas idênticas byte a byte entre o serviço único e os estágios
(`bench/video_equivalence.py`), 90 testes unitários e 5/5 cenários ponta a ponta. A imagem de efeitos e a de extração
têm 857 MB cada, contra 1,69 GB do serviço único; só a de legendagem leva o Whisper (1,74 GB). Ficam como ganhos a
modularidade (cada estágio é alterado, testado e reconstruído isoladamente) e o isolamento de falhas (uma falha da
legendagem já não para os efeitos), bem como o pré-requisito de uma futura elasticidade. Não é avaliado como RNF desta
fase.

== DA-2 — Entrega pelo menos uma vez com idempotência e reconciliação (cenário QS-02)

#tab([Decisão arquitetural DA-2],
  tabela-campos(
    [Contexto], [As ferramentas de imagem confirmam as mensagens à receção e publicam sem persistência; o orquestrador confirma as respostas antes de as tratar; as execuções não expiram; as respostas de erro trocam identificadores e são ignoradas (EV-10, EV-11, EV-12, EV-13). Uma falha de um serviço a meio de um lote deixa trabalhos pendentes para sempre (QS-02). A separação do serviço de vídeo (secção anterior) aumentou o número de serviços e de mensagens.],
    [Tática(s) escolhida(s)], [TAT-06 (confirmação manual e reentrega), TAT-07 (publicação persistente e confirmações do publicador), TAT-08 (_timeout_ e reconciliação), TAT-09 (idempotência e fila de mensagens mortas) e TAT-10 (terminação graciosa).],
    [Estrutura / padrão que a realiza], [Entrega _at-least-once_ com consumidor idempotente: `Tools/utils/rabbit_mq.py` passa a confirmar depois do processamento, com `prefetch` e religação; `projects/utils/rabbit_mq.js` passa a usar uma ligação persistente, publicação persistente com confirmações e `ack` só depois de a _callback_ terminar. Respostas repetidas são ignoradas pelo `correlationId`. Filas com `x-dead-letter-exchange` e limite de tentativas. `Process` com _heartbeat_ e prazo; um varrimento ao arrancar e periódico reenvia ou termina com erro as execuções expiradas. Os serviços tratam SIGTERM.],
    [Alternativas consideradas e razão de rejeição], [TAT-11 (repetir manualmente): classe C. Entrega _exactly-once_ com transações distribuídas: complexidade desproporcionada e não suportada pelo RabbitMQ entre serviços. Só reiniciar automaticamente os serviços (já existe, `restart: on-failure`, EV-16): reinicia o processo mas não recupera as mensagens perdidas.],
    [Consequências positivas], [Trabalhos sobrevivem à falha de qualquer serviço; os erros chegam ao utilizador; deixa de haver estado órfão; torna segura uma futura remoção de réplicas (escala para baixo).],
    [Consequências negativas / riscos], [Possível processamento duplicado após uma falha (custo de CPU, sem efeito no resultado graças à idempotência); ligeiro custo das confirmações; risco de regressão na lógica de _commit_ da execução.],
    [Elementos arquiteturais afetados], [`Tools/utils/rabbit_mq.py`, `Tools/utils/tool_msg.py`, `Tools/video*/`, `projects/utils/rabbit_mq.js`, `projects/routes/projects.js`, `projects/models/process.js`, `rabbitMQ/definitions.json`, `wsGateway/utils/rabbit_mq.js`.],
    [Origem e âmbito do _refactoring_], [Padrão global (herdado pelo vídeo). Risco de regressão médio, concentrado no tratamento de respostas do orquestrador.],
    [Classe (A/B/C)], [A, exceto a correção da troca de identificadores: B, porque passa a mostrar ao utilizador erros que antes eram descartados, e é esse o objeto da melhoria.],
    [Implementação (_commits_ / _pull requests_)], [PR \#3 (`feature/reliable-messaging`): _commits_ `c273f59` (confirmação após resposta confirmada nas ferramentas), `a69a0e8` (correção das respostas de erro), `ac316df` (ligação única com confirmações no orquestrador), `95b3aae` (documentação) e `766dbca` (resultados). PR \#4 (`feature/process-recovery`): `0f1ab00` (recuperação de execuções, `projects/utils/recovery.js`, 7 testes), `6c9cb26` (documentação) e `369d95e` (teste de falha do _broker_ e resultados).],
    [Desvios face à decisão], [(1) *Sem fila de mensagens mortas*: uma mensagem que faz falhar a ferramenta é repetida uma vez (`requeue` só se não for uma reentrega) e depois descartada; o utilizador recebe o erro pelo vigilante de recuperação quando o passo expira. Evita alterar as filas e os consumidores para um caso que a medição não exercita. (2) *Idempotência pelo estado do `Process`, não pelo `correlationId`*: o registo só é apagado depois de guardados os efeitos do passo, e as marcas `output_stored` e `successor_msg_id` permitem que uma resposta repetida retome sem guardar resultados duas vezes nem criar dois sucessores; respostas sem registo são ignoradas. (3) *Sem _heartbeat_*: o prazo conta desde a confirmação da publicação pelo _broker_ (`dispatched_at`; 5 min para imagens, 60 min para vídeo) e o passo só é terminado com erro quando a fila da ferramenta está vazia. (4) *Passos já publicados nunca são republicados*, apenas terminados com erro: os passos de imagem depois do primeiro escrevem por cima do próprio ficheiro, pelo que repeti-los a partir do registo não é idempotente; só os passos registados e nunca publicados (e.g., com o _broker_ em baixo) são publicados de novo, como num padrão _outbox_. (5) `wsGateway` e `rabbitMQ/definitions.json` não foram alterados.],
  ),
)
