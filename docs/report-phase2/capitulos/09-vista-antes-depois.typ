#import "../template.typ": *
#import "vistas.typ": vista-antes, vista-depois, legenda-vistas

// Capítulo inteiro na horizontal (as vistas ocupam a largura da página).
#paisagem[
= Vista Arquitetural Antes e Depois

Vista de componentes e ligações do processamento de um projeto. As caixas são serviços (contentores Docker) ou
armazenamento; as setas são pedidos HTTP, mensagens RabbitMQ ou eventos Socket.IO, numeradas e descritas nas notas.
As duas vistas usam a mesma disposição e a mesma notação; só mudam as cores, os estereótipos e o texto dos elementos
alterados.

== Antes

#figure(kind: image,
  [#vista-antes() #v(0.2cm) #legenda-vistas()],
  caption: [Vista arquitetural antes das decisões DA-1 e DA-2 (_commit_ `0523102`)],
)

== Depois

#figure(kind: image,
  [#vista-depois() #v(0.2cm) #legenda-vistas()],
  caption: [Vista arquitetural depois das decisões DA-1 e DA-2 e da separação do vídeo],
)

#pagebreak(weak: true)
== Legenda e notas

*Legenda.* Preto: inalterado. Azul: DA-1, trabalho em segundo plano (QS-07). Laranja: DA-2, recuperabilidade
(QS-02). Cinzento tracejado: _refactoring_ preparatório de separação do vídeo (QS-03), mantido mas não avaliado como RNF
(cap. 8). Cada elemento alterado indica as táticas que o realizam no estereótipo `«tática: …»` (cap. 7). Uma caixa é
colorida pela decisão que mais a altera; as linhas do seu texto usam a cor da decisão a que pertencem.

#tab([Interações das vistas e o que mudou],
  tabela(
    colunas: (0.8cm, 5.2cm, 6.4cm, 1fr),
    tamanho: 8pt,
    [N.º], [Interação], [Antes], [Depois],
    [1], [_Browser_ → `api_gateway`: pedidos REST (aplicar, cancelar, resultados)], [—], [Inalterado],
    [2], [`api_gateway` → `projects`], [—], [Inalterado],
    [3], [`projects` → RabbitMQ: pedido de cada passo], [Publicação sem persistência nem confirmação, numa ligação nova por mensagem], [Publicada por `dispatch()`, persistente e confirmada pelo _broker_; o `Process` guarda a mensagem (DA-2)],
    [4], [RabbitMQ → `projects`: respostas das ferramentas (`project_queue`)], [Confirmadas antes de serem tratadas: uma falha a meio perde a resposta], [Confirmadas só depois de tratadas; uma resposta repetida é tolerada (DA-2)],
    [5], [`projects` → RabbitMQ: eventos para o utilizador (`ws_queue`)], [`process-update` e `process-error` sem projeto], [Com `projectId` (DA-1); publicação confirmada (DA-2)],
    [6], [RabbitMQ → ferramentas de imagem], [_Auto-ack_ à receção: uma ferramenta que morre perde o passo], [Confirmação só depois de a resposta ser confirmada; reentrega pelo _broker_ (DA-2); o `watermark` (imagem pré-construída) mantém-se],
    [7], [Ferramentas de imagem → RabbitMQ: respostas], [Não persistentes; respostas de erro com identificadores trocados], [Persistentes e confirmadas; os erros chegam ao utilizador (DA-2)],
    [8], [RabbitMQ → vídeo], [Uma fila e um serviço para todas as etapas], [Uma fila por etapa; uma etapa de cada vez (preparatório)],
    [9], [Vídeo → RabbitMQ: respostas e progresso], [Publicação sem persistência nem confirmação], [Publicação confirmada e persistente (DA-2)],
    [10], [`projects` ↔ MongoDB (`Process`)], [Registo apagado antes de os efeitos do passo estarem guardados], [Guarda a mensagem e o estado do passo; o vigilante (DA-2) e o estado da execução (DA-1) leem-no],
    [11], [RabbitMQ → `ws_gateway` (`ws_queue`)], [—], [Transporte inalterado; os eventos levam o projeto (DA-1)],
    [12], [`ws_gateway` → _browser_ (Socket.IO)], [A página conta os eventos de qualquer projeto e ignora-os se não tiver uma execução local], [A página filtra os eventos pelo projeto; um componente global notifica a conclusão noutras páginas (DA-1)],
    [13], [_Browser_ → `api_gateway`: `GET …/process/status`], [Não existe], [Novo: ao abrir a página, a cada 5 s durante uma execução e, noutras páginas, um por evento recebido pelo notificador (DA-1)],
    [14], [`api_gateway` → `projects`: `GET …/process/status`], [Não existe], [Novo: estado derivado dos _tokens_ da execução e dos registos `Process`, sem escritas (DA-1)],
  ),
)
]
