// Vistas arquiteturais antes e depois (cap. 9): mesma disposição, mesma notação.
// Coordenadas em cm; as caixas e as setas são desenhadas com primitivas do Typst.

#let azul = rgb("#1f5fbf")      // DA-1 (QS-07)
#let laranja = rgb("#c8650a")   // DA-2 (QS-02)
#let cinza = rgb("#6f6f6f")     // refactoring preparatório (QS-03)

// Posição e tamanho de cada caixa (x, y, largura, altura), comuns às duas vistas
#let G = (
  browser: (0, 0.6, 4.8, 4.4),
  api: (5.7, 0.6, 3.4, 1.7),
  ws: (5.7, 3.3, 3.4, 1.7),
  projects: (10.0, 0.6, 5.0, 4.4),
  mongo: (10.0, 6.2, 5.0, 2.4),
  rabbit: (15.9, 0.6, 3.2, 8.0),
  tools: (20.0, 0.6, 4.6, 3.6),
  video: (20.0, 5.0, 4.6, 3.6),
)

// Uma linha do corpo de uma caixa, com marcador: texto, (texto, cor) para um destaque,
// (rotulo: …) para um rótulo sem marcador, ou "" para um espaço
#let _linha(l) = {
  if l == "" { return v(0.15em) }
  if type(l) == dictionary {
    return block(spacing: 0.5em, text(size: 7.3pt, fill: gray.darken(30%), style: "italic", l.rotulo))
  }
  let (t, c) = if type(l) == array { (l.at(0), l.at(1)) } else { (l, black) }
  block(spacing: 0.5em, grid(
    columns: (0.25cm, 1fr),
    text(size: 7.6pt, fill: c, "•"),
    text(size: 7.6pt, fill: c, weight: if c == black { "regular" } else { "medium" }, t),
  ))
}

#let caixa(x, y, w, h, titulo, corpo: (), cor: black, tracejado: false, estereotipo: none) = place(
  dx: x * 1cm,
  dy: y * 1cm,
  rect(
    width: w * 1cm,
    height: h * 1cm,
    radius: 2pt,
    inset: 5pt,
    fill: if cor == black { white } else { cor.lighten(90%) },
    stroke: (paint: cor, thickness: if cor == black { 0.7pt } else { 1.1pt }, dash: if tracejado { "dashed" } else { none }),
  )[
    #set par(leading: 0.35em, justify: false, spacing: 0.35em)
    #set align(left)
    #if estereotipo != none [#text(size: 6.6pt, fill: cor, style: "italic", estereotipo) \ ]
    #block(spacing: 0.45em, text(size: 8.6pt, weight: "bold", fill: if cor == black { black } else { cor.darken(20%) }, titulo))
    #block(spacing: 0.45em, line(length: 100%, stroke: 0.4pt + if cor == black { gray } else { cor.lighten(40%) }))
    #for l in corpo { _linha(l) }
  ],
)

#let _ponta(a, b, cor) = {
  let (x1, y1) = a
  let (x2, y2) = b
  let dx = x2 - x1
  let dy = y2 - y1
  let n = calc.sqrt(dx * dx + dy * dy)
  let ux = dx / n
  let uy = dy / n
  let L = 0.22
  let W = 0.085
  place(polygon(
    fill: cor,
    stroke: none,
    (x2 * 1cm, y2 * 1cm),
    ((x2 - L * ux - W * uy) * 1cm, (y2 - L * uy + W * ux) * 1cm),
    ((x2 - L * ux + W * uy) * 1cm, (y2 - L * uy - W * ux) * 1cm),
  ))
}

// Seta por uma lista de pontos; `num` marca a interação descrita nas notas
#let seta(pts, cor: black, num: none, dupla: false, tracejado: false, pos: none) = {
  let st = (paint: cor, thickness: if cor == black { 0.7pt } else { 1.1pt }, dash: if tracejado { "dashed" } else { none })
  for i in range(pts.len() - 1) {
    let (x1, y1) = pts.at(i)
    let (x2, y2) = pts.at(i + 1)
    place(line(start: (x1 * 1cm, y1 * 1cm), end: (x2 * 1cm, y2 * 1cm), stroke: st))
  }
  _ponta(pts.at(-2), pts.at(-1), cor)
  if dupla { _ponta(pts.at(1), pts.at(0), cor) }
  if num != none {
    let (mx, my) = if pos != none { pos } else {
      let (x1, y1) = pts.at(0)
      let (x2, y2) = pts.at(1)
      ((x1 + x2) / 2, (y1 + y2) / 2)
    }
    place(dx: (mx - 0.17) * 1cm, dy: (my - 0.17) * 1cm, circle(
      radius: 0.17cm,
      fill: white,
      stroke: 0.6pt + cor,
      align(center + horizon, text(size: 5.8pt, weight: "bold", fill: cor, str(num))),
    ))
  }
}

#let _legenda(itens) = {
  set text(size: 7pt)
  grid(
    columns: itens.len(),
    column-gutter: 0.6cm,
    ..itens.map(((cor, tracejado, texto)) => box(baseline: 20%)[
      #box(width: 0.5cm, height: 0.28cm, fill: if cor == black { white } else { cor.lighten(90%) },
        stroke: (paint: cor, thickness: 1pt, dash: if tracejado { "dashed" } else { none }))
      #h(0.15cm) #texto
    ]),
  )
}

// Setas comuns às duas vistas (mesma disposição)
#let _setas-base(cor-msg: black, cor-ws: black, cor-video: black) = {
  seta(((4.8, 1.3), (5.7, 1.3)), num: 1)
  seta(((9.1, 1.3), (10.0, 1.3)), num: 2)
  seta(((15.0, 1.4), (15.9, 1.4)), cor: cor-msg, num: 3)
  seta(((15.9, 2.6), (15.0, 2.6)), cor: cor-msg, num: 4)
  seta(((15.0, 4.2), (15.9, 4.2)), cor: cor-msg, num: 5)
  seta(((19.1, 1.5), (20.0, 1.5)), cor: cor-msg, num: 6)
  seta(((20.0, 3.4), (19.1, 3.4)), cor: cor-msg, num: 7)
  seta(((19.1, 6.0), (20.0, 6.0)), cor: cor-video, num: 8)
  seta(((20.0, 7.8), (19.1, 7.8)), cor: cor-msg, num: 9)
  seta(((12.5, 5.0), (12.5, 6.2)), num: 10, dupla: true)
  seta(((17.5, 8.6), (17.5, 9.4), (7.4, 9.4), (7.4, 5.0)), cor: cor-ws, num: 11, pos: (12.5, 9.4))
  seta(((5.7, 4.2), (4.8, 4.2)), cor: cor-ws, num: 12)
}

#let vista-antes() = box(width: 24.6cm, height: 9.8cm, {
  caixa(..G.browser, "Browser — página do projeto", corpo: (
    "Estado da execução só na memória da página (EV-20)",
    "Camada sobreposta bloqueia a página; cancelar só dentro dela (EV-19)",
    "Conta eventos de qualquer projeto (EV-21)",
    "Ao recarregar ou noutro separador: sem progresso nem cancelar",
  ))
  caixa(..G.api, "api_gateway", corpo: ("Valida o JWT e encaminha",))
  caixa(..G.ws, "ws_gateway", corpo: ("Consome ws_queue", "Eventos sem projeto (EV-21)"))
  caixa(..G.projects, "projects (orquestrador)", corpo: (
    "Um Process por media; publica cada passo",
    "Confirma a resposta antes de a tratar (EV-12)",
    "Uma ligação por mensagem, sem confirmações",
    "Sem prazo nem reconciliação (EV-13)",
  ))
  caixa(..G.mongo, "MongoDB — Process", corpo: (
    "Um registo por passo em curso",
    "Apagado antes de os efeitos ficarem guardados",
  ))
  caixa(..G.rabbit, "RabbitMQ", corpo: (
    (rotulo: "Filas (exchange picturas)"),
    "Uma por ferramenta",
    "video_queue",
    "project_queue (respostas)",
    "ws_queue (eventos)",
    "",
    "Mensagens não persistentes (EV-10)",
  ))
  caixa(..G.tools, "Ferramentas de imagem", corpo: (
    "Auto-ack à receção (EV-10)",
    "Erros com identificadores trocados: não chegam ao utilizador (EV-11)",
  ))
  caixa(..G.video, "video_tool", corpo: (
    "Efeitos, legendas e fotogramas num só serviço e fila (EV-06, EV-08)",
    "Um consumidor, prefetch 1 (EV-07)",
    "Respostas sem persistência nem confirmação",
  ))
  _setas-base()
})

#let vista-depois() = box(width: 24.6cm, height: 9.8cm, {
  caixa(..G.browser, "Browser — página do projeto", cor: azul,
    estereotipo: "«tática: TAT-12, TAT-13, TAT-14, TAT-15»", corpo: (
      ("Estado lido do servidor (13)", azul),
      ("Indicador no cabeçalho, com cancelar; só a edição do projeto fica bloqueada", azul),
      ("Ignora eventos de outros projetos", azul),
      ("Ao recarregar ou noutro separador: retoma progresso e cancelar", azul),
      ("Consulta o estado a cada 5 s; notifica noutras páginas", azul),
    ))
  caixa(..G.api, "api_gateway", cor: azul, corpo: (
    "Valida o JWT e encaminha",
    ("+ GET …/process/status", azul),
  ))
  caixa(..G.ws, "ws_gateway", cor: azul, estereotipo: "«tática: TAT-15»", corpo: (
    "Consome ws_queue",
    ("Eventos com projectId", azul),
  ))
  caixa(..G.projects, "projects (orquestrador)", cor: laranja,
    estereotipo: "«tática: TAT-06, TAT-07, TAT-08, TAT-09, TAT-13»", corpo: (
      ("runStatus.js: estado da execução", azul),
      ("dispatch(): o Process guarda a mensagem do passo", laranja),
      ("Confirma a resposta depois de a tratar; tolera repetidas", laranja),
      ("Uma ligação; mensagens persistentes e confirmadas", laranja),
      ("recovery.js: republica ou termina com erro os passos perdidos", laranja),
    ))
  caixa(..G.mongo, "MongoDB — Process", cor: laranja, estereotipo: "«tática: TAT-08, TAT-09»", corpo: (
    ("Guarda a mensagem e o estado do passo (dispatched_at, output_stored, …)", laranja),
    ("Apagado só depois de os efeitos ficarem guardados", laranja),
  ))
  caixa(..G.rabbit, "RabbitMQ", cor: laranja, estereotipo: "«tática: TAT-07»", corpo: (
    (rotulo: "Filas (exchange picturas)"),
    "Uma por ferramenta",
    ("Uma por etapa de vídeo (3)", cinza),
    "project_queue (respostas)",
    "ws_queue (eventos)",
    "",
    ("Mensagens persistentes e confirmadas", laranja),
  ))
  caixa(..G.tools, "Ferramentas de imagem", cor: laranja, estereotipo: "«tática: TAT-06, TAT-10»", corpo: (
    ("Confirmam depois da resposta; prefetch 1, religação", laranja),
    ("Terminação graciosa (SIGTERM)", laranja),
    ("Erros chegam ao utilizador", laranja),
    "watermark: inalterado",
  ))
  caixa(..G.video, "Serviços de vídeo por etapa", cor: cinza, tracejado: true,
    estereotipo: "«tática: TAT-02» (preparatório)", corpo: (
      ("Efeitos, legendas e fotogramas em três serviços e filas", cinza),
      ("Uma etapa de cada vez; biblioteca comum", cinza),
      ("Respostas persistentes e confirmadas", laranja),
    ))
  _setas-base(cor-msg: laranja, cor-ws: azul, cor-video: cinza)
  seta(((4.8, 2.0), (5.7, 2.0)), cor: azul, num: 13)
  seta(((9.1, 2.0), (10.0, 2.0)), cor: azul, num: 14)
})

#let legenda-vistas() = _legenda((
  (black, false, [Inalterado]),
  (azul, false, [DA-1 — trabalho em segundo plano (QS-07)]),
  (laranja, false, [DA-2 — recuperabilidade (QS-02)]),
  (cinza, true, [_Refactoring_ preparatório (QS-03)]),
))
