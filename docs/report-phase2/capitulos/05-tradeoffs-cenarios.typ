#import "../template.typ": *

#paisagem[
= Trade-offs, Cenários de Qualidade e Prioridades

== Cenários de qualidade para a extensão de vídeo

#tab([Cenários de qualidade],
  tabela(
    colunas: (1.1cm, 3.6cm, 2.6cm, 2cm, 2.6cm, 2.2cm, 2.2cm, 2.8cm, 1fr),
    tamanho: 7.5pt,
    [ID], [Fragilidade na base (EV-nn)], [Característica (ISO/IEC 25010)], [Fonte do estímulo], [Estímulo], [Artefacto], [Ambiente], [Resposta], [Medida da resposta],
    [QS-01], [Um único consumidor de vídeo, um trabalho de cada vez; a legendagem corre no mesmo serviço e ocupa-o durante minutos (EV-06, EV-07, EV-08). *EV-17*: `bench/` (ramo `test/nfr-baseline-benchmarks`) — sem carga concorrente, um vídeo de 10 s com brilho espera 7,7 s pelo primeiro progresso e demora 34 s], [Eficiência de desempenho › capacidade; utilização de recursos (elasticidade)], [Utilizadores premium em simultâneo], [Um trabalho de vídeo curto é submetido enquanto uma legendagem automática de outro utilizador está em curso; ou chega uma rajada de trabalhos de vídeo mistos], [Processamento de vídeo (`video_queue`, `video_tool`)], [Carga normal com um trabalho pesado em curso; pico de 10 trabalhos simultâneos; período inativo após o pico], [O trabalho curto começa sem esperar que a legendagem termine; a rajada é processada em paralelo; após o pico, os recursos de vídeo regressam ao mínimo], [(a) Tempo de espera do trabalho curto até ao primeiro progresso, em s (p50 e p95); (b) _makespan_ da rajada, em s; (c) memória total e número de contentores de vídeo em repouso, 60 s após o pico, em MiB e contentores],
    [QS-02], [Ferramentas de imagem confirmam à receção e publicam sem persistência; o orquestrador confirma antes de tratar a resposta; nenhum _timeout_ nem reentrega; erros das ferramentas não chegam ao utilizador (EV-10, EV-11, EV-12, EV-13)], [Fiabilidade › recuperabilidade; tolerância a falhas], [Falha de infraestrutura], [Uma ferramenta, o serviço de vídeo ou o orquestrador termina abruptamente (SIGKILL) durante um lote e é reiniciado], [Troca de mensagens entre `projects` e ferramentas; registos `Process`], [Lote em curso com 3 projetos de imagens e 2 de vídeo; serviço reiniciado 5 s depois], [Cada trabalho termina com resultado ou com erro comunicado ao utilizador; nenhum estado órfão], [(a) % de trabalhos que atingem um estado terminal correto em ≤ 180 s; (b) tempo desde o reinício até ao último estado terminal, em s; (c) número de registos `Process` órfãos após o lote],
    [QS-03], [Efeitos de fotograma, legendagem e extração no mesmo serviço e imagem Docker (EV-06, EV-08)], [Manutenibilidade › modularidade; modificabilidade], [Programador], [Altera a etapa de legendagem (e.g., outro modelo)], [Código e imagem do serviço de vídeo], [Desenvolvimento e _deployment_], [Só o serviço de legendagem é reconstruído, testado e reinstalado], [Número de serviços reconstruídos e reinstalados por alteração de uma etapa; número de módulos com dependências cruzadas entre etapas],
    [QS-04], [Vídeos até 1 GB mantidos inteiros em memória no _gateway_ e no `projects` (EV-01)], [Eficiência de desempenho › utilização de recursos], [Utilizador premium], [Carrega um vídeo de 1 GB], [`api_gateway`, `projects`], [Carga normal], [O carregamento conclui sem que a memória dos serviços cresça com o tamanho do ficheiro], [Pico de memória de `api_gateway` e `projects` durante o carregamento, em MiB, em função do tamanho do ficheiro],
    [QS-05], [Sem métricas nem registos centralizados; erros de ferramentas descartados em silêncio (EV-11, EV-14)], [Manutenibilidade › analisabilidade], [Operador], [Um trabalho fica pendente], [Toda a cadeia de processamento], [Produção, falha silenciosa], [O operador identifica o serviço e a fila responsáveis], [Tempo até identificar a causa, em min, para falhas injetadas conhecidas; número de serviços com métricas de filas e de trabalhos],
    [QS-06], [Bases de dados e serviços internos acessíveis a partir do anfitrião; segredos no ficheiro versionado; TLS interno sem validação (`AGENTS.md`). *EV-18*: `docker-compose.yaml:118-119, 135-136, 157-158, 173-174, 178, 222`], [Segurança › confidencialidade; autenticidade], [Atacante na rede], [Acede diretamente a `projects` (porta 9002) ou ao MongoDB (porta 27018)], [Configuração de rede e segredos], [_Deployment_ local por omissão], [O acesso é recusado; só `nginx` está exposto], [Número de portas internas expostas; número de segredos no repositório],
    [QS-07], [Durante o processamento, uma camada sobreposta bloqueia toda a página do projeto (*EV-19*: `frontend/app/dashboard/[pid]/page.tsx:894-927`); o progresso existe só no _browser_ e perde-se ao recarregar ou noutro separador, deixando de ser possível acompanhar ou cancelar a execução (*EV-20*: `page.tsx:89-93, 303, 431`); os eventos de fim não indicam o projeto (*EV-21*: `wsGateway/index.js:95, 100`)], [Usabilidade › operabilidade], [Utilizador (qualquer perfil)], [Aplica o _pipeline_ e, durante o processamento, quer continuar a usar a aplicação, recarrega a página ou abre o projeto noutro separador], [Página do projeto (`frontend`), eventos (`wsGateway`), estado das execuções (`projects`)], [Utilização normal; vídeo de 10–60 s ou lote de imagens], [A página continua utilizável; depois de recarregar, ou noutro separador, o progresso e o cancelamento continuam disponíveis e os resultados aparecem quando a execução termina], [(a) tempo em que a interface fica bloqueada durante uma execução, em s e em % das sondagens; (b) % de recarregamentos com progresso e cancelamento; (c) % de execuções retomadas cujos resultados aparecem sem recarregar; (d) % de segundos separadores com progresso e cancelamento],
  ),
)
]

#tab([Priorização dos cenários],
  tabela(
    colunas: (1.4cm, 5cm, 5cm, 2cm),
    tamanho: 8.5pt,
    [ID], [Importância para os stakeholders], [Dificuldade / risco técnico], [Prioridade],
    [QS-07], [Alta — afeta todos os utilizadores em todas as execuções: a aplicação fica inutilizável durante o processamento (minutos, num vídeo) e um recarregamento faz perder o controlo da execução, que continua a consumir a quota], [Média — o estado da execução passa a vir do servidor sem alterar o processamento; exige um ponto de consulta, eventos identificados por projeto e uma página que retoma a execução e tolera eventos perdidos], [1],
    [QS-01], [Alta quando há trabalhos de vídeo simultâneos; nula para um utilizador sozinho. Numa única máquina, réplicas adicionais competem pelos mesmos CPU], [Alta — exige separar o serviço de vídeo, recolher métricas e ajustar réplicas à carga sem alterar resultados], [3],
    [QS-02], [Alta — um trabalho perdido fica pendente para sempre, consome a quota diária e o utilizador não recebe erro], [Alta — semântica de entrega em sistemas distribuídos (confirmações, idempotência, reconciliação) em Node e Python], [2],
    [QS-03], [Média — afeta a equipa de desenvolvimento, não o utilizador final], [Média — separar o serviço de vídeo sem alterar resultados], [4 (realizado como _refactoring_ preparatório, cap. 8)],
    [QS-06], [Alta em produção; baixa no contexto académico e local da solução], [Média — transversal a todos os serviços; difícil de medir além de uma lista de verificação], [5],
    [QS-05], [Média — operadores e equipa], [Média — infraestrutura adicional; a métrica principal depende de quem diagnostica], [6],
    [QS-04], [Média — só afeta carregamentos grandes], [Média — o padrão de carregamento por partes já existe noutros contextos], [7],
  ),
)

== Atributos de qualidade por ordem de prioridade

+ *Usabilidade (operabilidade)* — QS-07: afeta todos os utilizadores em cada execução e é a fragilidade mais visível
  da solução; mede-se na interface real, de forma automática.
+ *Fiabilidade (recuperabilidade, tolerância a falhas)* — QS-02: trabalhos pendentes sem erro são a falha mais grave
  observada.
+ *Eficiência de desempenho (capacidade, utilização de recursos)* — QS-01: relevante sob carga concorrente, mas numa
  só máquina o ganho do autoescalamento é sobretudo de reordenação.
+ *Manutenibilidade (modularidade, analisabilidade)* — QS-03 e QS-05: a modularidade do vídeo foi realizada como
  _refactoring_ preparatório (QS-03, cap. 8).
+ *Segurança* — QS-06: relevante, mas fora do foco desta fase.

== Pré-requisitos e efeitos colaterais entre atributos

#tab([Pré-requisitos e efeitos colaterais entre atributos],
  tabela(
    colunas: (3cm, 3cm, 3.4cm, 1fr),
    tamanho: 8.5pt,
    [Atributo A], [Atributo B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [Modularidade (QS-03)], [Capacidade / elasticidade (QS-01)], [Pré-requisito], [Só com etapas separadas é possível escalar a legendagem sem escalar o resto (EV-08, ALT-2)],
    [Analisabilidade (QS-05)], [Capacidade / elasticidade (QS-01)], [Pré-requisito], [Ajustar réplicas à carga exige medir a profundidade e a idade das filas, hoje invisíveis (EV-14)],
    [Capacidade / elasticidade (QS-01)], [Recuperabilidade (QS-02)], [Conflito], [Reduzir réplicas termina serviços com trabalhos em curso; com _auto-ack_ e sem reentrega, esses trabalhos perdem-se (EV-10, EV-12)],
    [Recuperabilidade (QS-02)], [Capacidade / elasticidade (QS-01)], [Pré-requisito], [O ajuste de réplicas só é seguro depois de os trabalhos sobreviverem ao fim de um serviço],
    [Modularidade (QS-03)], [Comportamento temporal], [Conflito], [Cada etapa separada acrescenta um salto e pode exigir uma codificação intermédia (H-03)],
    [Capacidade / elasticidade (QS-01)], [Segurança (QS-06)], [Conflito], [Um autoescalador precisa de controlar contentores (acesso à API do Docker) (H-04)],
    [Recuperabilidade (QS-02)], [Operabilidade (QS-07)], [Sinergia], [Os registos `Process` que a DA-2 mantém até os efeitos de cada passo estarem guardados são a fonte do estado da execução que a página consulta],
    [Operabilidade (QS-07)], [Comportamento temporal], [Conflito (ligeiro)], [Consultar o estado da execução acrescenta pedidos de leitura ao orquestrador: um ao abrir a página e um a cada 5 s durante uma execução],
    [Operabilidade (QS-07)], [Integridade dos resultados], [Conflito], [Com a página utilizável, o utilizador poderia alterar o _pipeline_ ou remover _media_ a meio da execução; mitigado bloqueando só a edição desse projeto],
  ),
)

== Recomendações de melhoria à solução atual

#tab([Recomendações de melhoria],
  tabela(
    colunas: (1fr, 2.6cm, 3cm, 1.8cm, 2.2cm),
    tamanho: 8.5pt,
    [Recomendação], [Atributo(s)], [Padrão a que se refere (global / vídeo)], [Esforço], [Risco de regressão],
    [Separar o serviço de vídeo por etapa (efeitos, legendagem, extração), com biblioteca comum e encadeamento pelo orquestrador], [Modularidade; capacidade], [Vídeo (aproxima-o do global)], [Alto], [Médio],
    [Ajustar o número de réplicas de cada serviço de vídeo à profundidade da sua fila], [Capacidade; utilização de recursos], [Vídeo], [Médio], [Baixo],
    [Expor métricas de filas, contentores e trabalhos (Prometheus)], [Analisabilidade], [Global], [Médio], [Baixo],
    [Confirmação manual após processamento, publicação persistente e confirmações do publicador em todos os serviços], [Tolerância a falhas], [Global], [Médio], [Médio],
    [Tratamento idempotente das respostas, _timeout_ das execuções e reconciliação ao arrancar o orquestrador], [Recuperabilidade], [Global], [Médio], [Médio],
    [Corrigir a troca de `messageId`/`correlationId` nas respostas de erro], [Maturidade; usabilidade], [Global], [Baixo], [Baixo],
    [Retirar segredos do ficheiro versionado e deixar de publicar portas internas], [Segurança], [Global], [Baixo], [Baixo],
    [Carregamento em _streaming_ ou por partes até ao armazenamento], [Utilização de recursos], [Global], [Médio], [Médio],
    [Guardar o estado da execução no servidor e mostrar o progresso sem bloquear a página, retomando-o ao recarregar ou noutro separador], [Operabilidade], [Interação (_frontend_ ↔ orquestrador)], [Médio], [Baixo],
  ),
)
