#import "../template.typ": *

= Padrões Arquiteturais Atuais

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secções 2.1 a 2.3 do _template_. Factos citam uma evidência (`EV-nn`); o que não tem
  evidência é uma hipótese (`H-nn`).
]

== Padrão global da solução

#tabela-campos(
  [Nome(s) do padrão / estilo], [Microserviços; arquitetura orientada a mensagens (_message queue_ com _exchange_ direto) com orquestração central; _API Gateway_; _pipes and filters_ distribuído para o _pipeline_ de imagens.],
  [Descrição], [Cada responsabilidade de domínio (utilizadores, projetos, subscrições, armazenamento) e cada efeito de imagem é um serviço com o seu contentor. O serviço `projects` orquestra o _pipeline_: envia um passo de cada vez para a fila da ferramenta e avança quando recebe a resposta em `project_queue`. As ferramentas não comunicam entre si nem com bases de dados; partilham apenas o volume de ficheiros.],
)

#tab([Decisões globais que condicionam o vídeo],
  tabela(
    colunas: (4.5cm, 3.4cm, 1fr),
    tamanho: 8.5pt,
    [Decisão global], [Evidência], [Efeito no vídeo],
    [Uma fila por ferramenta no _exchange_ direto `picturas`; o orquestrador publica e as ferramentas consomem], [*EV-09*: `rabbitMQ/definitions.json` — 20 filas declaradas, uma por ferramenta de imagem, `video_queue`, `project_queue` e `ws_queue`], [O vídeo recebe uma única fila, `video_queue`, para todos os efeitos; não existe forma de encaminhar trabalhos de vídeo por tipo],
    [Ficheiros trocados por caminho num volume partilhado, não pela mensagem], [*EV-15*: `docker-compose.yaml` — o volume `image_data` é montado em `projects` e em todas as ferramentas, incluindo `video_tool`], [Os vídeos (até 1 GB) não passam pela fila; qualquer réplica de uma ferramenta acede ao mesmo ficheiro, o que permite várias réplicas sem mover dados],
    [Recursos fixos, definidos estaticamente no Compose, com reinício automático só em caso de falha do processo], [*EV-16*: `docker-compose.yaml` — 28 serviços com `restart: on-failure`, nenhum com `deploy.replicas` ou limites de recursos], [O vídeo tem sempre exatamente um consumidor; a capacidade não acompanha a carga],
    [Mensagens confirmadas de forma diferente consoante o lado: as ferramentas de imagem confirmam à receção; o orquestrador confirma após lançar o tratamento, sem esperar por ele], [*EV-10*: `Tools/utils/rabbit_mq.py:37-41` (`auto_ack=True`) e `:25-28` (publicação sem `delivery_mode` persistente); *EV-12*: `projects/utils/rabbit_mq.js:46-53` (`channel.ack` logo após invocar a _callback_ assíncrona, sem a aguardar) e `:11-29` (uma ligação por mensagem, `throw` em caso de erro)], [O vídeo é a exceção do lado das ferramentas: `video_tool` confirma manualmente no fim (*EV-07*). As respostas que regressam ao orquestrador têm a mesma fragilidade das imagens],
    [Estado das execuções guardado no orquestrador (`Process` em MongoDB), apagado quando chega a resposta], [*EV-13*: `projects/models/process.js:3-15` — o esquema tem `timestamps` mas nenhum índice TTL; não existe varrimento periódico em `projects/`], [Um vídeo cuja resposta se perde deixa a execução em aberto para sempre],
  ),
)

#tab([Benefícios e desafios do padrão global],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Cada ferramenta de imagem evolui, é reconstruída e é substituída sem tocar nas outras], [Manutenibilidade › modularidade, modificabilidade], [EV-09, EV-15],
    [Benefício], [A fila desacopla o pedido HTTP do processamento: o _Apply_ responde imediatamente e o trabalho continua], [Eficiência de desempenho › comportamento temporal], [EV-03],
    [Benefício], [Como os ficheiros estão num volume partilhado, uma ferramenta pode ter várias réplicas a consumir a mesma fila sem alterar o código], [Eficiência de desempenho › capacidade], [EV-15; H-01 (a confirmar ao escalar uma ferramenta)],
    [Desafio], [A confirmação imediata e a publicação não persistente fazem perder mensagens quando uma ferramenta, o orquestrador ou o _broker_ reinicia; a execução fica pendente sem erro], [Fiabilidade › tolerância a falhas, recuperabilidade], [EV-10, EV-12, EV-13],
    [Desafio], [Os erros das ferramentas de imagem não chegam ao utilizador, porque a resposta de erro troca `messageId` e `correlationId`], [Fiabilidade › maturidade; Usabilidade › proteção contra erros], [*EV-11*: `Tools/utils/tool_msg.py:64-68` e `projects/routes/projects.js:182-184`],
    [Desafio], [Não há métricas nem registos centralizados: a pilha ELK está comentada], [Manutenibilidade › analisabilidade], [*EV-14*: `docker-compose.yaml:6-30` e `nginx/nginx.conf:135-170`],
  ),
)

== Padrão do processamento de vídeo

#tabela-campos(
  [Nome do padrão], [Serviço monolítico de processamento (_worker_ único) com _pipeline_ interno (_pipes and filters_ dentro do processo).],
  [Descrição], [Uma mensagem por vídeo leva o _pipeline_ completo. O `video_tool` sonda o vídeo, descodifica-o uma vez, aplica os efeitos de fotograma, a legendagem automática (Faster-Whisper em CPU) e a extração de fotogramas como estágios internos, e codifica uma vez. Consome um trabalho de cada vez e confirma a mensagem só no fim.],
  [Contraste com o caminho de imagens], [Nas imagens, o _pipeline_ é distribuído: cada passo é uma mensagem, numa fila diferente, para um serviço diferente, e o orquestrador encadeia os passos. No vídeo, o encadeamento é interno ao serviço e o orquestrador só vê o início e o fim. A escolha evita descodificar e codificar o vídeo a cada efeito (*EV-03*, *EV-08*).],
)

#tab([Benefícios e desafios do padrão do vídeo],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Uma só descodificação e codificação por vídeo, qualquer que seja o número de efeitos; o áudio é preservado num único passo], [Eficiência de desempenho › comportamento temporal, utilização de recursos], [EV-03, EV-08],
    [Benefício], [Confirmação manual no fim e escrita sem saída parcial: se o serviço morrer a meio, a mensagem volta à fila], [Fiabilidade › recuperabilidade], [*EV-07*: `Tools/video/video.py:54, 170-174`],
    [Desafio], [Um único consumidor com `prefetch_count=1`: os trabalhos de vídeo de todos os utilizadores são processados em série; uma legendagem (minutos de CPU) atrasa todos os outros], [Eficiência de desempenho › capacidade, comportamento temporal], [*EV-06*: `docker-compose.yaml:256-273`; EV-07; medição exploratória EV-17 (descrita no capítulo 5)],
    [Desafio], [Efeitos de fotograma, legendagem e extração no mesmo serviço e na mesma imagem: alterar ou escalar um obriga a reconstruir e escalar todos; cada réplica carrega o modelo Whisper], [Manutenibilidade › modularidade; Eficiência › utilização de recursos], [*EV-08*: `Tools/video/video_processor.py:316-330` e `Tools/video/subtitles.py`; EV-06],
    [Desafio], [Efeitos PIL duplicados entre as ferramentas de imagem e `Tools/video/effects.py`], [Manutenibilidade › reutilização], [`AGENTS.md`, «_Known pitfalls_»; `Tools/video/effects.py:1-79`],
  ),
)

== Relação entre o padrão global e o padrão do vídeo

#tab([Relação entre o padrão global e o padrão do vídeo],
  tabela(
    colunas: (2.4cm, 3cm, 3cm, 1.9cm, 2.6cm, 1.8cm),
    tamanho: 8pt,
    [Aspeto], [O que o padrão global prescreve], [O que o vídeo faz], [Segue / afasta-se], [Consequência], [Evidência],
    [Comunicação], [Mensagens assíncronas por fila; resposta em `project_queue`], [Igual: `video_queue` e resposta em `project_queue`], [Segue], [O orquestrador trata vídeos e imagens no mesmo _handler_], [EV-03, EV-05],
    [Granularidade dos serviços], [Um serviço por efeito], [Um serviço para todos os efeitos de vídeo, legendagem e extração], [Afasta-se], [Contenção: trabalhos curtos esperam por legendagens longas; impossível escalar só a legendagem], [EV-06, EV-08, EV-09],
    [Encadeamento do _pipeline_], [Orquestrador avança passo a passo], [Encadeamento interno ao serviço], [Afasta-se], [Menos codificações (benefício), mas o orquestrador não vê o progresso por estágio], [EV-03, EV-08],
    [Confirmação de mensagens], [_Auto-ack_ nas ferramentas de imagem], [_Ack_ manual no fim do trabalho], [Afasta-se (para melhor)], [O vídeo recupera da falha do seu serviço; as imagens não], [EV-07, EV-10],
    [Tratamento de falhas no orquestrador], [Sem _timeout_, sem reentrega, `ack` antes de o tratamento terminar], [Herda o mesmo comportamento], [Segue], [Uma resposta perdida deixa a execução pendente, para imagens e vídeos], [EV-12, EV-13],
    [Capacidade], [Um contentor por serviço, recursos fixos], [Um contentor, sem réplicas], [Segue], [A capacidade de vídeo é fixa num trabalho de cada vez], [EV-06, EV-16],
    [Armazenamento], [Volume partilhado `image_data`], [Igual, mais o volume `whisper_models`], [Segue], [Réplicas e serviços separados podem partilhar os mesmos ficheiros], [EV-15],
    [Observabilidade], [Sem métricas; registos em `stdout` por contentor], [Progresso por `ws_queue` só para o _browser_], [Segue], [Não há forma de saber quantos trabalhos esperam nem quanto tempo], [EV-04, EV-14],
  ),
)

O vídeo herda do padrão global a comunicação por filas, o volume partilhado e a orquestração central, o que significa
que herda também as suas restrições: recursos fixos por serviço, mensagens que se perdem quando um serviço falha e
nenhuma observabilidade. Afasta-se do padrão ao concentrar todos os efeitos num só serviço. Este desvio poupa
codificações, mas transforma o `video_tool` num ponto de contenção: com um único consumidor e `prefetch_count=1`, a
duração de uma legendagem automática soma-se ao tempo de espera de todos os outros trabalhos de vídeo. As duas
fragilidades que motivam este relatório resultam, assim, uma do desvio (contenção e capacidade fixa do vídeo) e outra
do padrão global herdado (falta de recuperação de falhas na troca de mensagens).
