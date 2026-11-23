#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Candidatos a Requisitos Não Funcionais

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 5 do _template_. Dois RNF distintos, a partir dos cenários mais prioritários do
  capítulo 5.
]

#tab([Candidatos a requisitos não funcionais da Fase 2],
  tabela(
    colunas: (1.4cm, 2.6cm, 3cm, 2.2cm, 3cm, 3cm, 1.6cm, 3.4cm, 1fr),
    tamanho: 7.5pt,
    [\#], [Característica / subcaracterística (ISO/IEC 25010)], [Fragilidade na base (evidência)], [Origem (padrão global / vídeo / interação)], [Impacto nos stakeholders (pertinência)], [Exigência técnica (complexidade)], [Cenário (`QS-nn`, cap. 5)], [Escala e método de medição (esboço)], [Pré-requisitos / efeitos colaterais],
    [CAND-1], [Usabilidade › operabilidade: o utilizador mantém o controlo da aplicação e da execução enquanto um projeto é processado (trabalho em segundo plano)], [Camada sobreposta que bloqueia a página durante toda a execução; estado da execução só no _browser_, perdido ao recarregar; eventos sem identificação do projeto (EV-19, EV-20, EV-21)], [Interação entre o _frontend_ e o padrão global (estado das execuções no orquestrador)], [Utilizadores: não podem fazer nada durante minutos (vídeo) e, se recarregarem a página, perdem o progresso e o cancelamento, embora a execução continue e consuma a quota], [Estado da execução derivado do servidor sem alterar o processamento; página que retoma uma execução em curso e tolera eventos perdidos; medição automática na interface real (Playwright)], [QS-07], [Cenários U1–U3 (`bench/background_ui.py`): tempo de bloqueio da interface; progresso e cancelamento depois de recarregar; progresso num segundo separador], [Pré-requisitos: nenhum. Sinergia com CAND-2 (estado dos passos nos registos `Process`). Efeitos: pedidos de consulta adicionais; edição do projeto bloqueada durante a execução],
    [CAND-2], [Fiabilidade › recuperabilidade e tolerância a falhas], [_Auto-ack_ e publicação não persistente nas ferramentas; `ack` antes do tratamento no orquestrador; sem _timeout_ nem reentrega; erros descartados (EV-10, EV-11, EV-12, EV-13)], [Global (herdado pelo vídeo)], [Utilizadores: trabalhos pendentes para sempre, sem erro, com quota consumida. Operadores: estado órfão que só se limpa manualmente], [Semântica de entrega em Node e Python; idempotência; reconciliação de estado; injeção de falhas reprodutível], [QS-02], [Cenários R1–R3 (`bench/chaos.py`): % de trabalhos com estado terminal correto, tempo de recuperação e `Process` órfãos, com SIGKILL de uma ferramenta, do serviço de vídeo e do orquestrador a meio de um lote], [Condição para a escala para baixo do CAND-1. Efeitos: possível duplicação de processamento (mitigada por idempotência); ligeiro custo de desempenho das confirmações],
    [CAND-3 (não escolhido)], [Eficiência de desempenho › capacidade e utilização de recursos (elasticidade)], [Um consumidor de vídeo com `prefetch_count=1`; legendagem no mesmo serviço; recursos fixos (EV-06, EV-07, EV-08, EV-16, EV-17)], [Vídeo e global], [Trabalhos de segundos esperam minutos atrás de uma legendagem, quando há trabalhos simultâneos], [Separar o vídeo por estágio; métricas de filas; autoescalador com escala para baixo segura], [QS-01], [E1–E3 (`bench/elasticity.py`), medidos na base], [Ver a secção «Candidato considerado e não escolhido»],
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
    [Ambiente], [Máquina e versões da tabela 2.1; pilha completa em Docker Desktop (12 vCPU, 7,4 GiB); Chromium sem interface (Playwright); mesmos contentores alheios ao projeto nas duas medições (registados em cada ficheiro de resultados)], [Igual ao CAND-1, sem o _browser_],
    [Instrumento], [`bench/background_ui.py` (interface real em Chromium com Playwright; projetos preparados pela API pública); resultados em `bench/results/<label>/background-ui.json`], [`bench/chaos.py` (API pública, Socket.IO, `docker compose kill/start`, consulta ao MongoDB); resultados em `bench/results/<label>/chaos-<alvo>.json`],
    [Valor medido na base], [#preencher[após a medição inicial (U1 bloqueio p50 e %, U2 e U3 em %)]], [R1 mínimo: 40 % com a ferramenta de imagem ou o orquestrador como alvo (média 52 % e 68 %), 100 % com o serviço de vídeo e no controlo. R2 p95: não mensurável com a ferramenta de imagem (nenhuma repetição recuperou); 10,3 s com o orquestrador (só 2 de 5 repetições recuperaram); 28,7 s com o serviço de vídeo. R3 máximo: 8 `Process` órfãos (ferramenta de imagem) e 7 (orquestrador) (`bench/results/baseline/`)],
    [Valor-alvo (e origem)], [U1: 0 s de bloqueio (0 % das sondagens) — heurística «controlo e liberdade do utilizador» (Nielsen, 1994) e limite de 10 s de atenção para tempos de resposta (Nielsen, 1993): uma operação de minutos não deve impedir o resto da interação. U2 e U3: 100 % — o estado está no servidor, logo deve estar sempre disponível; resultados mostrados sem recarregar em 100 % das execuções retomadas], [R1 = 100 % e R3 = 0: nenhum trabalho pode ficar pendente nem deixar estado por limpar, porque o utilizador não tem forma de o recuperar. R2 p95 ≤ 30 s: o tempo de recuperação do serviço de vídeo na base (28,7 s), que já confirmava após o processamento, mostra que é alcançável com reentrega],
    [Valor mínimo aceitável (e origem)], [U1: ≤ 1 s por execução (transições da interface). U2 e U3: 100 % para o progresso e o cancelamento; ≥ 80 % das execuções retomadas com os resultados mostrados sem recarregar (no restante, recarregar resolve, sem perda de controlo)], [R1 ≥ 95 % (no máximo um trabalho em 25 com erro comunicado em vez de resultado); R2 p95 ≤ 60 s (o dobro do alvo, para absorver o reprocessamento do passo interrompido); R3 = 0],
  ),
)

== Relação entre os dois candidatos

Os dois candidatos são especificados, implementados e medidos separadamente, mas o CAND-1 apoia-se no CAND-2: o estado
da execução que a página passa a consultar é derivado dos registos `Process`, que a DA-2 mantém até os efeitos de cada
passo estarem guardados e cujos passos perdidos o vigilante de recuperação termina com erro. Sem o CAND-2, um passo
perdido deixaria a execução «em curso» para sempre, também na página. Inversamente, os eventos identificados por projeto
do CAND-1 fazem chegar à página certa os erros e as recuperações do CAND-2. Outros RNF afetados: o desempenho (pedidos
de consulta adicionais, só de leitura) e a integridade dos resultados (a edição do projeto em processamento fica
bloqueada).

== Candidato considerado e não escolhido (CAND-3)

Até à v1.2, o primeiro candidato era a elasticidade do processamento de vídeo (CAND-3, cenário QS-01). A _baseline_
foi medida (`bench/results/baseline/`: espera do trabalho curto p95 112,8 s; _makespan_ de 10 trabalhos p50 331,2 s;
3 059 MiB em repouso) e o primeiro passo, a separação do serviço de vídeo por estágio, foi implementado e integrado
(cap. 8). Antes de implementar o autoescalador, a equipa reavaliou a escolha pelos critérios das diretrizes e trocou-a
pelo CAND-1, por três razões:

+ *Pertinência.* A elasticidade só beneficia o utilizador quando há trabalhos de vídeo simultâneos; o CAND-1 afeta
  todos os utilizadores em todas as execuções, de imagens e de vídeo.
+ *Solidez da avaliação.* Toda a solução corre numa só máquina (12 vCPU). Réplicas adicionais competem pelos mesmos
  CPU, pelo que o autoescalamento reduziria sobretudo a espera dos trabalhos curtos (reordenação) e pouco o _makespan_
  de uma rajada. A medição com o vídeo de 177 s depois da separação confirmou que a separação, por si só, não elimina
  a espera (`bench/results/split-177s/`: 134,7 s, p50).
+ *Abrangência.* Com o CAND-2, os dois RNF seriam de infraestrutura do processamento; o CAND-1 cobre outra
  característica (usabilidade) e assenta no trabalho do CAND-2.

A separação do serviço de vídeo mantém-se como _refactoring_ de modularidade (QS-03) e de isolamento de falhas, e a
_baseline_ de E1–E3 fica como evidência para trabalho futuro (cap. 11).

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
