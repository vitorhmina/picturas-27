#import "../template.typ": *
#import "arquitetura.typ": vista-global, legenda-arquitetura, sequencia-pedido, legenda-sequencia

= Âmbito e Vista da Arquitetura
== Preparação e ambiente

#tab([Preparação e ambiente],
  tabela-campos(
    [Commit de partida], [`052310226c51fa57a17101c7bd1ad795674aac95` (`0523102`)],
    [Comando(s) de arranque], [`docker compose down -v --remove-orphans` (uma vez, para remover volumes e contentores de outras versões) e `docker compose up -d --build`; depois `docker compose restart nginx`. Aplicação em `https://localhost:8080`.],
    [Ambiente (SO, CPU, RAM, versões de Docker e Compose)], [Windows 11 Pro 10.0.26200; AMD Ryzen 5 5500U (6 núcleos, 12 _threads_); 15,3 GB de RAM; Docker Desktop com Docker Engine 29.8.2 e Docker Compose 5.5.1; VM do Docker com 12 vCPU e 7,4 GiB de memória.],
    [Ajustes necessários], [(1) Com o Docker Compose 5.5, `docker compose build` falha em todas as imagens com «_additional privileges requested: pass --allow=fs.read=…_», porque o _builder_ passou a exigir permissão explícita para ler os `Dockerfile`; as imagens usadas foram construídas a partir do _commit_ de partida e comparadas com o repositório. (2) No primeiro arranque com volumes vazios, o RabbitMQ demora mais do que o _healthcheck_ permite e três serviços ficam no estado `Created`; um segundo `docker compose up -d` resolve.],
  ),
)

Quando o utilizador carrega em _Apply_, o _frontend_ envia um pedido ao serviço `projects` através do _API Gateway_; o `projects` valida o _pipeline_ e a quota antes de criar a execução (`activeToken`).
Os ficheiros são copiados do S3 para o volume partilhado `image_data`.
As imagens são processadas passo a passo, através das filas das ferramentas.
Os vídeos seguem um percurso diferente, através de uma única mensagem enviada para `video_queue`.
O serviço `video_tool` descodifica o vídeo, aplica efeitos e legendas, extrai fotogramas e volta a codificá-lo.
O progresso dos vídeos chega ao _browser_ através de `ws_queue` e Socket.IO.
Todos os registos `Process` são criados antes do processamento e, quando o último desaparece, é feito o _commit_ e os resultados ficam disponíveis.
O campo `media_type`, definido no carregamento, distingue imagens de vídeos.

== Fontes consultadas

#tab([Fontes consultadas],
  tabela(
    colunas: (5.5cm, 3cm, 1fr),
    [Fonte], [Versão / data], [Usada para],
    [`README.md`, `AGENTS.md`], [_commit_ `0523102`], [Arquitetura, fluxo de imagens e vídeos, limites, armadilhas conhecidas (e.g., _auto-ack_ das ferramentas de imagem, troca de identificadores nas respostas de erro)],
    [Código e configuração (`projects/`, `Tools/`, `apiGateway/`, `wsGateway/`, `docker-compose.yaml`, `rabbitMQ/`, `nginx/`)], [_commit_ `0523102`], [Todas as evidências `EV-nn` deste relatório],
    [`doc-ext-requisitos-2627.pdf`], [Versão 1], [Requisitos de vídeo da base (PL1-G4) e limites por perfil],
    [`doc-sol-arquitetural.pdf`], [Fase 2 - 2025/2026], [Arquitetura de base anterior ao vídeo (padrão global)],
    [Relatório da Fase 1 do grupo PL5-G6], [v2.0, 2026-10-23], [Alternativa de um serviço por ferramenta de vídeo (DA-01 da Fase 1), termo de comparação no capítulo 4],
    [Diretrizes da Fase 2], [Versão 1, 2026-11-04], [Regras do trabalho e ideias indicativas de RNF],
    [Slides da aula 11 (_Architectural Styles_, J. M. Fernandes) e documento de apoio de padrões arquiteturais], [Slides: outubro de 2021], [Classificação dos padrões e das alternativas],
    [Bass, Clements e Kazman, _Software Architecture in Practice_, 4.ª ed., cap. 3, 4, 8, 9 e 13], [2021], [Cenários de qualidade e catálogo de táticas (capítulo 7)],
    [ISO/IEC 25010:2011], [2011], [Classificação dos atributos de qualidade],
  ),
)

== Vista da arquitetura global

A solução segue um padrão de *microserviços* com comunicação *assíncrona por filas* (RabbitMQ, _exchange_ direto
`picturas`) e um *volume partilhado* (`image_data`) para os ficheiros em processamento. Todo o tráfego entra por
`nginx`; o _API Gateway_ valida o JWT e encaminha para os serviços de domínio. O serviço `projects` é o orquestrador:
detém projetos, _media_, _pipelines_ e execuções. Cada efeito de imagem é um microserviço que consome a sua fila. O
vídeo afasta-se deste padrão: um único serviço, `video_tool`, consome `video_queue` e executa o _pipeline_ inteiro.

#figure(kind: image,
  block(breakable: false)[#vista-global() #v(0.15cm) #legenda-arquitetura()],
  caption: [Vista da arquitetura global com o caminho do vídeo destacado],
)

*Ferramenta / notação:* diagrama de contentores ao estilo C4 (nível 2), desenhado em Typst com as mesmas primitivas
das vistas do capítulo 9. Estado no _commit_ de partida `0523102`. As setas indicam o sentido do pedido ou da
mensagem; uma seta com duas pontas indica pedidos e respostas.

#tab([Legenda da vista da arquitetura],
  tabela(
    colunas: (5cm, 1fr),
    [Elemento (cor, forma ou estilo)], [Significado],
    [Caixa e setas roxas], [Caminho do vídeo],
    [Setas pretas], [Caminho das imagens (uma mensagem por passo) e comunicação comum],
    [Caixa verde], [Fila RabbitMQ],
    [Caixa cinzenta tracejada], [Armazenamento (MongoDB, S3, volume partilhado)],
  ),
)

== Sequência de um pedido completo

#figure(kind: image,
  block(breakable: false)[#sequencia-pedido() #v(0.15cm) #legenda-sequencia()],
  caption: [Sequência do processamento em lote de um projeto com vídeos],
)

#tab([Passos do pedido completo],
  tabela(
    colunas: (2.6cm, 3.4cm, 1fr, 4.2cm),
    tamanho: 8.5pt,
    [Passo], [Origem → Destino], [Mensagem / _endpoint_ / fila], [Evidência],
    [Carregamento do vídeo], [_Browser_ → `nginx` → `api_gateway` → `projects` → `img_storage` (S3)], [`POST /:user/:project/video` (_multipart_); o ficheiro é guardado inteiro em memória no _gateway_ e no `projects` (`multer.memoryStorage`), validado com `ffprobe` e enviado para a área `src`], [*EV-01*: `apiGateway/routes/projects.js:23-24, 458-500` e `projects/routes/projects.js:72-73, 1391-1394` — carregamento em memória e rota específica de vídeo],
    [Definição do _pipeline_], [_Browser_ → `api_gateway` → `projects` (MongoDB)], [`POST /:user/:project/tool` com `{procedure, params}` e cabeçalho `X-Project-Version`; a extração de fotogramas é forçada para o fim], [*EV-02*: `projects/routes/projects.js:1397-1467` — inserção da ferramenta, validação e controlo de versão otimista],
    [_Apply_], [_Browser_ → `api_gateway` → `projects` → RabbitMQ `video_queue` → `video_tool`], [`POST /:user/:project/process`; ficheiros de origem copiados para `image_data`; uma mensagem por vídeo com o _pipeline_ completo (`procedure: "video"`); todos os `Process` registados antes do envio], [*EV-03*: `projects/routes/projects.js:1600-1675` e `projects/utils/processBatch.js:3-12` — uma mensagem por vídeo e registo prévio do lote],
    [Progresso], [`video_tool` → `ws_queue` → `ws_gateway` → _browser_], [Mensagens `update-client-video-progress` com percentagem, emitidas como `video-progress` por Socket.IO para a sala do utilizador; não ficam guardadas no servidor], [*EV-04*: `Tools/video/video.py:112-124` e `wsGateway/index.js:64-72`],
    [Resultado], [`video_tool` → `project_queue` → `projects` → `img_storage`; `projects` → `ws_queue` → _browser_], [Resposta com `correlationId` igual ao `messageId` do pedido; o orquestrador procura o `Process`, envia o MP4 para a área `out`, cria o `Result`, dá _commit_ à execução quando já não restam `Process` e notifica o cliente (`process-update`)], [*EV-05*: `Tools/video/video.py:76-92, 155` e `projects/routes/projects.js:170-210, 430-480`],
  ),
)
