// Vista da arquitetura global e sequência de um pedido (cap. 2), no commit de partida 0523102.
// Mesmas primitivas das vistas do capítulo 9 (caixa, seta); coordenadas em cm.
#import "vistas.typ": caixa, seta

#let roxo = rgb("#7b3fa0")      // caminho do vídeo
#let verde = rgb("#1d7a5c")     // fila RabbitMQ
#let cinza-a = rgb("#6f6f6f")   // armazenamento

#let _amostra(cor, tracejado, texto, linha: false) = box(baseline: 20%)[
  #if linha {
    box(width: 0.6cm, height: 0.28cm, align(horizon, line(length: 0.6cm, stroke: 1.2pt + cor)))
  } else {
    box(width: 0.5cm, height: 0.28cm, fill: if cor == black { white } else { cor.lighten(90%) },
      stroke: (paint: cor, thickness: 1pt, dash: if tracejado { "dashed" } else { none }))
  }
  #h(0.15cm) #texto
]

#let legenda-arquitetura() = {
  set text(size: 7pt)
  grid(
    columns: 5,
    column-gutter: 0.45cm,
    _amostra(black, false, [Serviço]),
    _amostra(verde, false, [Fila RabbitMQ]),
    _amostra(cinza-a, true, [Armazenamento]),
    _amostra(black, false, [Imagens e comum], linha: true),
    _amostra(roxo, false, [Caminho do vídeo], linha: true),
  )
}

#let vista-global() = box(width: 16cm, height: 10.2cm, {
  // entrada
  caixa(0, 3.6, 2.4, 1.4, "Browser", corpo: ("Next.js (página do projeto)",))
  caixa(3.2, 3.6, 2.0, 1.4, "nginx", corpo: (":8080, TLS",))
  // camada de entrada atrás do nginx
  caixa(6.2, 0.0, 3.0, 0.9, "frontend (Next.js)")
  caixa(6.2, 1.6, 3.0, 1.2, "api_gateway", corpo: ("Valida o JWT; vídeo em memória (EV-01)",))
  caixa(6.2, 3.6, 3.0, 1.2, "ws_gateway", corpo: ("Socket.IO; consome ws_queue",))
  caixa(6.2, 5.6, 3.0, 1.0, "SeaweedFS (S3)", cor: cinza-a, tracejado: true, corpo: ("src, out, preview",))
  // domínio
  caixa(10.4, 0.0, 2.6, 0.9, "users, subscriptions")
  caixa(10.4, 1.6, 2.6, 2.0, "projects", corpo: ("Orquestrador: projetos, media, pipeline, execuções (Process)",))
  caixa(10.4, 5.6, 2.6, 1.0, "img_storage", corpo: ("Fachada S3",))
  caixa(13.8, 0.0, 2.2, 3.6, "MongoDB", cor: cinza-a, tracejado: true, corpo: ("Uma base por serviço",))
  caixa(13.8, 4.2, 2.2, 2.4, "RabbitMQ", cor: verde, corpo: ("exchange picturas", "<tool>_queue", ("video_queue", roxo), "project_queue", "ws_queue"))
  // processamento
  caixa(6.2, 7.6, 3.0, 1.2, "image_data", cor: cinza-a, tracejado: true, corpo: ("Volume partilhado",))
  caixa(10.4, 7.6, 2.6, 1.6, "Ferramentas de imagem", corpo: ("Um serviço por efeito (PIL e IA)",))
  caixa(13.8, 7.6, 2.2, 1.6, "video_tool", cor: roxo, corpo: (("Pipeline inteiro numa mensagem", roxo),))

  // entrada
  seta(((2.4, 4.3), (3.2, 4.3)))
  place(line(start: (5.2cm, 4.3cm), end: (5.7cm, 4.3cm), stroke: 0.7pt))
  place(line(start: (5.7cm, 0.45cm), end: (5.7cm, 6.1cm), stroke: 0.7pt))
  seta(((5.7, 0.45), (6.2, 0.45)))
  seta(((5.7, 2.2), (6.2, 2.2)))
  seta(((5.7, 4.2), (6.2, 4.2)))
  seta(((5.7, 6.1), (6.2, 6.1)))
  // api_gateway para os serviços de domínio
  seta(((9.2, 1.9), (9.8, 1.9), (9.8, 0.45), (10.4, 0.45)))
  seta(((9.2, 2.4), (10.4, 2.4)))
  // persistência
  seta(((13.0, 0.45), (13.8, 0.45)))
  seta(((13.0, 2.4), (13.8, 2.4)), dupla: true)
  seta(((11.7, 3.6), (11.7, 5.6)))
  seta(((10.4, 6.1), (9.2, 6.1)))
  // projects copia as fontes para o volume
  seta(((10.4, 3.3), (9.9, 3.3), (9.9, 8.0), (9.2, 8.0)))
  // filas
  seta(((13.0, 3.2), (13.4, 3.2), (13.4, 5.0), (13.8, 5.0)), dupla: true)
  seta(((13.8, 4.4), (9.2, 4.4)))
  seta(((14.3, 6.6), (14.3, 7.1), (11.7, 7.1), (11.7, 7.6)), dupla: true)
  seta(((15.3, 6.6), (15.3, 7.6)), cor: roxo, dupla: true)
  // ficheiros em processamento
  seta(((10.4, 8.4), (9.2, 8.4)), dupla: true)
  seta(((14.9, 9.2), (14.9, 9.8), (7.7, 9.8), (7.7, 8.8)), cor: roxo, dupla: true)
})

// Diagrama de sequência: linhas de vida e mensagens numeradas como na tabela dos passos
#let _vidas = (
  ("Browser", 0.8),
  ("api_gateway", 3.1),
  ("projects", 5.6),
  ("img_storage", 8.0),
  ("RabbitMQ", 10.3),
  ("video_tool", 12.6),
  ("ws_gateway", 14.9),
)

#let _x(nome) = _vidas.find(v => v.at(0) == nome).at(1)

#let _msg(de, para, y, rotulo, cor: black, tracejado: false) = {
  let (x1, x2) = (_x(de), _x(para))
  seta(((x1, y), (x2, y)), cor: cor, tracejado: tracejado)
  let esq = calc.min(x1, x2)
  place(dx: (esq + 0.08) * 1cm, dy: (y - 0.36) * 1cm,
    text(size: 6.2pt, fill: if cor == black { black } else { cor }, rotulo))
}

#let _nota(x, y, w, texto, cor: black) = place(dx: x * 1cm, dy: y * 1cm,
  rect(width: w * 1cm, inset: 2.5pt, fill: white, stroke: 0.5pt + cor.lighten(40%),
    text(size: 6pt, fill: cor, texto)))

#let _bloco(y1, y2, rotulo) = {
  place(dx: 0.1cm, dy: y1 * 1cm, rect(width: 15.8cm, height: (y2 - y1) * 1cm,
    stroke: (paint: luma(150), thickness: 0.5pt, dash: "dotted")))
  place(dx: 0.1cm, dy: (y1 + 0.05) * 1cm, box(width: 15.7cm, align(right, text(size: 6pt, style: "italic", fill: luma(90), rotulo))))
}

#let sequencia-pedido() = box(width: 16cm, height: 11.8cm, {
  for (nome, x) in _vidas {
    place(dx: (x - 1.0) * 1cm, dy: 0cm, rect(width: 2cm, height: 0.6cm, radius: 2pt, inset: 0pt,
      stroke: 0.7pt + if nome == "video_tool" { roxo } else { black },
      align(center + horizon, text(size: 6.8pt, weight: "bold", nome))))
    place(line(start: (x * 1cm, 0.6cm), end: (x * 1cm, 11.7cm), stroke: (paint: luma(160), thickness: 0.5pt, dash: "dashed")))
  }
  _bloco(0.8, 2.3, [1\. Carregamento do vídeo])
  _msg("Browser", "api_gateway", 1.4, [POST /:user/:project/video (multipart)])
  _msg("api_gateway", "projects", 1.75, [reencaminha (ficheiro em memória)])
  _msg("projects", "img_storage", 2.1, [ffprobe; guarda em src])

  _bloco(2.5, 3.3, [2\. Definição do pipeline])
  _msg("Browser", "projects", 3.05, [POST …/tool, X-Project-Version (via api_gateway)])

  _bloco(3.5, 6.0, [3\. Apply])
  _msg("Browser", "projects", 4.1, [POST …/process (via api_gateway)])
  _nota(5.75, 4.3, 3.9, [copia as fontes para image_data; regista um Process por media; activeToken + 1])
  _msg("projects", "RabbitMQ", 5.45, [uma mensagem por vídeo: pipeline completo], cor: roxo)
  _msg("RabbitMQ", "video_tool", 5.8, [video_queue], cor: roxo)

  _bloco(6.2, 7.9, [4\. Progresso (repetido)])
  _msg("video_tool", "ws_gateway", 7.0, [ws_queue: percentagem], cor: roxo, tracejado: true)
  _msg("ws_gateway", "Browser", 7.7, [video-progress (Socket.IO, sala do utilizador)], cor: roxo, tracejado: true)

  _bloco(8.1, 11.6, [5\. Resultado])
  _msg("video_tool", "RabbitMQ", 8.7, [project_queue: correlationId = messageId], cor: roxo)
  _msg("RabbitMQ", "projects", 9.1, [resposta])
  _msg("projects", "img_storage", 9.5, [MP4 em out; cria o Result])
  _nota(5.75, 9.7, 3.9, [commit da execução quando não restam Process])
  _msg("projects", "ws_gateway", 10.85, [ws_queue: process-update], tracejado: true)
  _msg("ws_gateway", "Browser", 11.3, [process-update (Socket.IO)], tracejado: true)
})

#let legenda-sequencia() = {
  set text(size: 7pt)
  grid(
    columns: 4,
    column-gutter: 0.45cm,
    _amostra(black, false, [Pedido ou mensagem], linha: true),
    box(baseline: 20%)[#box(width: 0.6cm, height: 0.28cm, align(horizon, line(length: 0.6cm, stroke: (paint: black, thickness: 1pt, dash: "dashed")))) #h(0.15cm) Evento para o _browser_],
    _amostra(roxo, false, [Caminho do vídeo], linha: true),
    box(baseline: 20%)[#box(width: 0.5cm, height: 0.28cm, stroke: (paint: luma(150), thickness: 0.6pt, dash: "dotted")) #h(0.15cm) Passo da tabela],
  )
}
