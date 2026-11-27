#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Candidatos a Requisitos Não Funcionais

#tab([Candidatos a requisitos não funcionais da Fase 2],
  tabela(
    colunas: (1.4cm, 2.6cm, 3cm, 2.2cm, 3cm, 3cm, 1.6cm, 3.4cm, 1fr),
    tamanho: 7.5pt,
    [\#], [Característica / subcaracterística (ISO/IEC 25010)], [Fragilidade na base (evidência)], [Origem (padrão global / vídeo / interação)], [Impacto nos stakeholders (pertinência)], [Exigência técnica (complexidade)], [Cenário (`QS-nn`, cap. 5)], [Escala e método de medição (esboço)], [Pré-requisitos / efeitos colaterais],
    [CAND-1], [Usabilidade › operabilidade], [Camada sobreposta que bloqueia a página durante toda a execução; estado da execução só no _browser_, perdido ao recarregar; eventos sem identificação do projeto (EV-19, EV-20, EV-21)], [Interação entre o _frontend_ e o padrão global (estado das execuções no orquestrador)], [Utilizadores: não podem fazer nada durante minutos (vídeo) e, se recarregarem a página, perdem o progresso e o cancelamento, embora a execução continue e consuma a quota], [Estado da execução derivado do servidor sem alterar o processamento; página que retoma uma execução em curso e tolera eventos perdidos; medição automática na interface real (Playwright)], [QS-07], [Cenários U1–U3 (`bench/background_ui.py`): tempo de bloqueio da interface; progresso e cancelamento depois de recarregar; progresso num segundo separador], [Pré-requisitos: nenhum. Efeitos colaterais: pedidos de consulta adicionais; edição do projeto bloqueada durante a execução],
    [CAND-2], [Fiabilidade › recuperabilidade e tolerância a falhas], [_Auto-ack_ e publicação não persistente nas ferramentas; `ack` antes do tratamento no orquestrador; sem _timeout_ nem reentrega; erros descartados (EV-10, EV-11, EV-12, EV-13)], [Global (herdado pelo vídeo)], [Utilizadores: trabalhos pendentes para sempre, sem erro, com quota consumida. Operadores: estado órfão que só se limpa manualmente], [Semântica de entrega em Node e Python; idempotência; reconciliação de estado; injeção de falhas reprodutível], [QS-02], [Cenários R1–R3 (`bench/chaos.py`): % de trabalhos com estado terminal correto, tempo de recuperação e `Process` órfãos, com SIGKILL de uma ferramenta, do serviço de vídeo e do orquestrador a meio de um lote], [Pré-requisitos: nenhum. Efeitos colaterais: possível duplicação de processamento (mitigada por idempotência); ligeiro custo de desempenho das confirmações],
  ),
)

== Quantificação

#tab([Quantificação dos requisitos não funcionais],
  tabela(
    colunas: (4cm, 1fr, 1fr),
    tamanho: 8pt,
    [], [CAND-1], [CAND-2],
    [Escala (o que se mede e em que unidade)], [*U1* tempo em que a interface está bloqueada desde Apply até ao fim da execução (s) e % das sondagens que a encontram bloqueada, com a duração da execução como referência; *U2* % de recarregamentos a meio de uma execução em que a página mostra o progresso e o botão de cancelar, e % em que mostra os resultados sozinha até 15 s após o fim; *U3* % de segundos separadores que mostram o progresso e o cancelamento], [*R1* % de trabalhos com estado terminal correto (concluído, ou erro que chega ao utilizador) em ≤ 180 s; *R2* tempo desde o reinício do serviço até ao último estado terminal (s); *R3* número de registos `Process` órfãos após o lote],
    [Cenário de medição], [U1: brilho num vídeo de 10 s (`sample_10s_720p.mp4`) e brilho → contraste → saturação em 3 imagens; a cada 0,25 s, o _script_ verifica se o botão _Download project_ do cabeçalho pode ser clicado (verificação de acionabilidade do Playwright). U2: brilho nos primeiros 60 s de `speech_mandela_177s_1080p.webm`, com recarregamento 3 s após Apply. U3: o mesmo projeto, aberto num segundo separador 3 s após Apply. Controlos: a página tem de estar utilizável antes de Apply, e o progresso e o cancelamento têm de ser detetados antes de recarregar; só contam as repetições em que a execução ainda decorria depois de a página carregar], [3 projetos de 4 imagens e 2 projetos de vídeo, todos com brilho → contraste → saturação, lançados em simultâneo; o alvo é congelado logo após o despacho (`docker compose pause`), para que o _broker_ lhe entregue trabalho, e terminado 10 s depois com SIGKILL (`docker compose kill`); reinício 5 s depois (`docker compose start`). Um SIGKILL a tempo fixo (3 s) foi testado e descartado: no teste de fumo atingiu o serviço antes de este ter recebido qualquer mensagem. Alvos: nenhum (controlo), `contrast_tool`, serviço(s) de vídeo, `projects`],
    [Carga], [1 utilizador por cenário; 5 repetições de cada cenário, cada uma com um utilizador premium novo], [5 trabalhos (14 _media_) por repetição; 5 repetições por alvo],
    [Ambiente], [Máquina e versões da tabela 3; pilha completa em Docker Desktop (12 vCPU, 7,4 GiB); Chromium sem interface (Playwright); mesmos contentores alheios ao projeto nas duas medições (registados em cada ficheiro de resultados)], [Máquina e versões da tabela 3; pilha completa em Docker Desktop (12 vCPU, 7,4 GiB); pedidos pela API pública, sem _browser_; mesmos contentores alheios ao projeto nas duas medições (registados em cada ficheiro de resultados)],
    [Instrumento], [`bench/background_ui.py` (interface real em Chromium com Playwright; projetos preparados pela API pública); resultados em `bench/results/<label>/background-ui.json`], [`bench/chaos.py` (API pública, Socket.IO, `docker compose kill/start`, consulta ao MongoDB); resultados em `bench/results/<label>/chaos-<alvo>.json`],
    [Valor medido na base], [U1 bloqueio p50: 22,8 s com um vídeo de 10 s (96,8 % das sondagens) e 2,8 s com 3 imagens (78,6 %), ou seja, toda a execução (p50 20,5 s e 0,8 s) mais a transição final. U2: progresso e cancelar após recarregar em 0 % das repetições; resultados sem recarregar em 0 %. U3: 0 % (`bench/results/baseline/background-ui.json`)], [R1 mínimo: 40 % com a ferramenta de imagem ou o orquestrador como alvo (média 52 % e 68 %), 100 % com o serviço de vídeo e no controlo. R2 p95: não mensurável com a ferramenta de imagem (nenhuma repetição recuperou); 10,3 s com o orquestrador (só 2 de 5 repetições recuperaram); 28,7 s com o serviço de vídeo. R3 máximo: 8 `Process` órfãos (ferramenta de imagem) e 7 (orquestrador) (`bench/results/baseline/`)],
    [Valor-alvo (e origem)], [U1: 0 s de bloqueio (0 % das sondagens) — heurística «controlo e liberdade do utilizador» (Nielsen, 1994) e limite de 10 s de atenção para tempos de resposta (Nielsen, 1993): uma operação de minutos não deve impedir o resto da interação. U2 e U3: 100 % — o estado está no servidor, logo deve estar sempre disponível; resultados mostrados sem recarregar em 100 % das execuções retomadas], [R1 = 100 % e R3 = 0: nenhum trabalho pode ficar pendente nem deixar estado por limpar, porque o utilizador não tem forma de o recuperar. R2 p95 ≤ 30 s: o tempo de recuperação do serviço de vídeo na base (28,7 s), que já confirmava após o processamento, mostra que é alcançável com reentrega],
    [Valor mínimo aceitável (e origem)], [U1: ≤ 1 s por execução (transições da interface). U2 e U3: 100 % para o progresso e o cancelamento; ≥ 80 % das execuções retomadas com os resultados mostrados sem recarregar (no restante, recarregar resolve, sem perda de controlo)], [R1 ≥ 95 % (no máximo um trabalho em 25 com erro comunicado em vez de resultado); R2 p95 ≤ 60 s (o dobro do alvo, para absorver o reprocessamento do passo interrompido); R3 = 0],
  ),
)

== Relação entre os dois candidatos

O CAND-1 depende da correção do estado mantido pelo CAND-2. A página passa a obter o estado da execução a partir dos
registos `Process` do orquestrador. Com a DA-2, cada registo só é removido depois de os efeitos do respetivo passo
estarem guardados; um passo cuja publicação não foi confirmada é publicado de novo, e um passo perdido depois de
publicado termina com um erro. Sem estas garantias, uma falha deixaria a execução indefinidamente «em curso», também
na página.

O CAND-2, por sua vez, depende do CAND-1 para que as falhas cheguem ao utilizador. Um erro só é útil se for
apresentado a quem lançou a execução; com os eventos identificados por projeto, os erros e as recuperações chegam à
página do projeto afetado.

== Evidência exploratória

#tab([Evidência exploratória],
  tabela(
    colunas: (5cm, 6cm, 1fr),
    tamanho: 8.5pt,
    [Descrição], [Localização (_scripts_, dados, resultados)], [Como repetir],
    [EV-17: trabalho curto de vídeo e de imagens sem carga concorrente (7,7 s de espera e 34 s no total para 10 s de vídeo; 1,2 s para duas imagens)], [`bench/client.py`; ramo `test/nfr-baseline-benchmarks`], [`bench/README.md`, secção _Setup_; teste de fumo com `BenchUser`/`BenchProject`],
    [Medição inicial completa (E1–E3, R1–R3)], [`bench/results/baseline/`], [`bench/README.md`, secção _Running_],
    [Ensaio de `bench/background_ui.py` na base (1 repetição, máquina carregada): a interface ficou bloqueada em 98 % das sondagens durante um vídeo de 10 s e em 97 % durante 3 imagens, incluindo cerca de 5 s depois de o resultado existir; depois de recarregar, nem progresso nem cancelamento; o segundo separador também não os mostrou], [`bench/background_ui.py`; ramo `test/background-work-baseline`], [`bench/README.md`, secção _Background work_],
  ),
)
]
