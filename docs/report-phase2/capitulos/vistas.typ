// Vistas arquiteturais antes e depois (cap. 9): mesma disposição, mesma notação.
// Coordenadas em cm; as caixas e as setas são desenhadas com primitivas do Typst.

#let azul = rgb("#1f5fbf")      // DA-1 (QS-07)
#let laranja = rgb("#c8650a")   // DA-2 (QS-02)
#let cinza = rgb("#6f6f6f")     // refactoring preparatório (QS-03)

// Uma linha do corpo de uma caixa: texto simples, ou (texto, cor) para um destaque
#let _linha(l) = if type(l) == array {
  text(size: 6.5pt, fill: l.at(1), weight: "medium", l.at(0))
} else {
  text(size: 6.5pt, l)
}

#let caixa(x, y, w, h, titulo, corpo: (), cor: black, tracejado: false, estereotipo: none) = place(
  dx: x * 1cm,
  dy: y * 1cm,
  rect(
    width: w * 1cm,
    height: h * 1cm,
    radius: 2pt,
    inset: 4pt,
    fill: if cor == black { white } else { cor.lighten(90%) },
    stroke: (paint: cor, thickness: if cor == black { 0.7pt } else { 1.1pt }, dash: if tracejado { "dashed" } else { none }),
  )[
    #set par(leading: 0.3em, justify: false, spacing: 0.3em)
    #set align(left)
    #if estereotipo != none [#text(size: 5.8pt, fill: cor, style: "italic", estereotipo) \ ]
    #text(size: 7.3pt, weight: "bold", fill: if cor == black { black } else { cor.darken(20%) }, titulo)
    #for l in corpo [ \ #_linha(l) ]
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
#let _setas-base(cor-msg: black, cor-ws: black) = {
  seta(((4.6, 1.3), (5.6, 1.3)), num: 1)
  seta(((8.8, 1.3), (9.8, 1.3)), num: 2)
  seta(((14.6, 1.4), (15.6, 1.4)), cor: cor-msg, num: 3)
  seta(((15.6, 2.6), (14.6, 2.6)), cor: cor-msg, num: 4)
  seta(((14.6, 4.2), (15.6, 4.2)), cor: cor-msg, num: 5)
  seta(((18.6, 1.5), (19.6, 1.5)), cor: cor-msg, num: 6)
  seta(((19.6, 3.4), (18.6, 3.4)), cor: cor-msg, num: 7)
  seta(((18.6, 6.0), (19.6, 6.0)), cor: cor-msg, num: 8)
  seta(((19.6, 7.8), (18.6, 7.8)), cor: cor-msg, num: 9)
  seta(((12.2, 5.0), (12.2, 6.2)), num: 10, dupla: true)
  seta(((17.1, 8.6), (17.1, 9.4), (7.2, 9.4), (7.2, 5.0)), cor: cor-ws, num: 11, pos: (12.2, 9.4))
  seta(((5.6, 4.2), (4.6, 4.2)), cor: cor-ws, num: 12)
}

#let vista-antes() = box(width: 24cm, height: 9.8cm, {
  caixa(0, 0.8, 4.6, 4.2, "Browser — página do projeto (Next.js)", corpo: (
    "Estado da execução só na memória da página (processing, progresso, vídeos) (EV-20)",
    "Camada sobreposta bloqueia toda a página até ao fim; cancelar só dentro dela (EV-19)",
    "Conta todos os process-update como do projeto aberto (EV-21)",
    "Recarregar ou outro separador: sem progresso nem cancelar",
  ))
  caixa(5.6, 0.8, 3.2, 1.6, "api_gateway (Express)", corpo: ("Valida o JWT e encaminha para projects",))
  caixa(5.6, 3.4, 3.2, 1.6, "ws_gateway (Socket.IO)", corpo: ("Consome ws_queue; eventos sem identificação do projeto",))
  caixa(9.8, 0.8, 4.8, 4.2, "projects (orquestrador)", corpo: (
    "Regista um Process por media e publica cada passo",
    "Confirma a resposta antes de a tratar (EV-12)",
    "Nova ligação ao broker por mensagem; sem confirmações",
    "Sem prazo nem reconciliação dos passos (EV-13)",
  ))
  caixa(9.8, 6.2, 4.8, 2.4, "MongoDB — Process", corpo: (
    "Um registo por passo em curso",
    "Apagado antes de os efeitos do passo estarem guardados",
  ))
  caixa(15.6, 0.8, 3.0, 7.8, "RabbitMQ (exchange picturas)", corpo: (
    "Filas:",
    "· uma por ferramenta",
    "· video_queue",
    "· project_queue (respostas)",
    "· ws_queue (eventos)",
    "",
    "Mensagens publicadas sem persistência (EV-10)",
  ))
  caixa(19.6, 0.8, 4.4, 3.4, "Ferramentas de imagem (PIL e IA)", corpo: (
    "Confirmam a mensagem à receção (auto-ack) (EV-10)",
    "Respostas de erro com identificadores trocados: o erro não chega ao utilizador (EV-11)",
  ))
  caixa(19.6, 5.2, 4.4, 3.4, "video_tool", corpo: (
    "Efeitos, legendagem e extração de fotogramas num só serviço e numa só fila (EV-06, EV-08)",
    "Um consumidor, prefetch 1 (EV-07)",
  ))
  _setas-base()
})

#let vista-depois() = box(width: 24cm, height: 9.8cm, {
  caixa(0, 0.8, 4.6, 4.2, "Browser — página do projeto (Next.js)", cor: azul,
    estereotipo: "«tática: TAT-12, TAT-13, TAT-14, TAT-15»", corpo: (
      ("Indicador de progresso no cabeçalho, com cancelar; a página continua utilizável", azul),
      ("Ao abrir, retoma a execução a partir do servidor (13)", azul),
      ("Durante a execução, consulta o estado a cada 5 s e termina-a por ele", azul),
      ("Ignora eventos de outros projetos; notifica a conclusão noutras páginas", azul),
      "Edição do projeto bloqueada só durante a execução",
    ))
  caixa(5.6, 0.8, 3.2, 1.6, "api_gateway (Express)", cor: azul, corpo: (
    "Valida o JWT e encaminha para projects",
    ("+ GET …/process/status", azul),
  ))
  caixa(5.6, 3.4, 3.2, 1.6, "ws_gateway (Socket.IO)", cor: azul, estereotipo: "«tática: TAT-15»", corpo: (
    "Consome ws_queue",
    ("Eventos com projectId", azul),
  ))
  caixa(9.8, 0.8, 4.8, 4.2, "projects (orquestrador)", cor: laranja,
    estereotipo: "«tática: TAT-06, TAT-07, TAT-08, TAT-09, TAT-13»", corpo: (
      ("runStatus.js: estado da execução, derivado dos tokens e dos Process", azul),
      ("Confirma a resposta só depois de a tratar; tolera duplicados", laranja),
      ("Uma ligação com religação; publicação confirmada e persistente", laranja),
      ("dispatch(): o Process guarda a mensagem do passo (outbox)", laranja),
      ("recovery.js: a cada 15 s republica o que nunca foi publicado e termina com erro os passos expirados", laranja),
    ))
  caixa(9.8, 6.2, 4.8, 2.4, "MongoDB — Process", cor: laranja, estereotipo: "«tática: TAT-08, TAT-09»", corpo: (
    ("+ tool, params, dispatched_at, output_stored, successor_msg_id, failed", laranja),
    ("Apagado só depois de os efeitos estarem guardados", laranja),
  ))
  caixa(15.6, 0.8, 3.0, 7.8, "RabbitMQ (exchange picturas)", cor: laranja, estereotipo: "«tática: TAT-07»", corpo: (
    "Filas:",
    "· uma por ferramenta",
    ("· video_effects_queue, video_subtitles_queue, video_frames_queue", cinza),
    "· project_queue (respostas)",
    "· ws_queue (eventos)",
    "",
    ("Mensagens persistentes; confirmações do publicador", laranja),
  ))
  caixa(19.6, 0.8, 4.4, 3.4, "Ferramentas de imagem (PIL e IA)", cor: laranja, estereotipo: "«tática: TAT-06, TAT-10»", corpo: (
    ("Confirmam só depois de a resposta ser confirmada; prefetch 1; religação", laranja),
    ("Terminação graciosa (SIGTERM)", laranja),
    ("Erros chegam ao utilizador (identificadores corrigidos)", laranja),
  ))
  caixa(19.6, 5.2, 4.4, 3.4, "Serviços de vídeo por estágio", cor: cinza, tracejado: true, estereotipo: "«tática: TAT-02» (preparatório)", corpo: (
    ("video_effects_tool — efeitos, corte, velocidade", cinza),
    ("video_subtitles_tool — legendagem (Whisper)", cinza),
    ("video_frames_tool — extração de fotogramas", cinza),
    ("Biblioteca comum Tools/video_common; um estágio de cada vez", cinza),
  ))
  _setas-base(cor-msg: laranja, cor-ws: azul)
  seta(((4.6, 2.0), (5.6, 2.0)), cor: azul, num: 13)
  seta(((8.8, 2.0), (9.8, 2.0)), cor: azul, num: 14)
})

#let legenda-vistas() = _legenda((
  (black, false, [Inalterado]),
  (azul, false, [DA-1 — trabalho em segundo plano (QS-07)]),
  (laranja, false, [DA-2 — recuperabilidade (QS-02)]),
  (cinza, true, [_Refactoring_ preparatório (QS-03)]),
))
