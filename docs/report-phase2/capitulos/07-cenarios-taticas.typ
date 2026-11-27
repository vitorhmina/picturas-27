#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Cenários de Entrada e Táticas Candidatas

== Candidatos e cenários de entrada

#tab([Candidatos e cenários de entrada],
  tabela(
    colunas: (1.6cm, 1.6cm, 3cm, 2.4cm, 2.6cm, 3.4cm, 3.6cm, 1fr),
    tamanho: 8pt,
    [Candidato], [Cenário (`QS-nn`)], [Característica / subcaracterística (ISO/IEC 25010)], [Evidência], [Origem (padrão global / vídeo / interação)], [Estímulo a que a tática reage], [Resposta e medida (resumo)], [Escala e método (cap. 6)],
    [CAND-1], [QS-07], [Usabilidade › operabilidade], [EV-19, EV-20, EV-21], [Interação (_frontend_ ↔ orquestrador)], [Utilizador aplica o _pipeline_ e quer continuar a usar a aplicação, recarrega a página ou abre outro separador], [A página continua utilizável e retoma a execução — tempo de bloqueio; % com progresso e cancelamento após recarregar e num segundo separador], [U1–U3, `bench/background_ui.py`],
    [CAND-2], [QS-02], [Fiabilidade › recuperabilidade, tolerância a falhas], [EV-10, EV-11, EV-12, EV-13], [Global], [SIGKILL de uma ferramenta, do serviço de vídeo ou do orquestrador durante um lote], [Todos os trabalhos terminam com resultado ou erro; sem órfãos — % terminal, tempo de recuperação, órfãos], [R1–R3, `bench/chaos.py`],
  ),
)

== Alterações feitas ao capítulo 5 (se existirem)

#tab([Alterações aos cenários],
  tabela(
    colunas: (2cm, 1fr, 4cm),
    [Cenário], [O que mudou e porquê], [Onde foi atualizado],
    [—], [Nenhuma: os cenários do capítulo 5 foram usados sem alterações], [—],
  ),
)

== Táticas candidatas

#tab([Táticas candidatas],
  tabela(
    colunas: (1.4cm, 1.4cm, 3cm, 3.4cm, 1fr, 3.6cm, 1.6cm),
    tamanho: 7.5pt,
    [ID], [Cenário], [Atributo → categoria], [Tática], [Como produz a resposta (estímulo → tática → resposta)], [Já existe na base? (evidência)], [Classe (A/B/C)],
    [TAT-02], [QS-03], [Modificabilidade → aumentar a coesão], [Separar o serviço de vídeo por etapa, com uma fila por etapa (efeitos, legendagem, extração) e encadeamento pelo orquestrador], [Programador altera a legendagem → a alteração fica no serviço de legendagem → só esse serviço é reconstruído, testado e reinstalado], [Não: tudo em `video_queue` e num só serviço (EV-08, EV-09); o padrão já existe nas imagens], [A],
    [TAT-06], [QS-02], [Disponibilidade → recuperar de falhas (reintroduzir o pedido)], [Confirmação manual após o processamento e reentrega pelo _broker_ (_at-least-once_), em ferramentas e no orquestrador], [Ferramenta morre a meio → mensagem não confirmada → o _broker_ reentrega-a quando o serviço reinicia → trabalho conclui], [Parcial: só no serviço de vídeo (EV-07); _auto-ack_ nas imagens (EV-10); `ack` antecipado no orquestrador (EV-12)], [A],
    [TAT-07], [QS-02], [Disponibilidade → prevenir falhas (transações / mensagens persistentes)], [Publicação persistente (`delivery_mode=2`) com confirmações do publicador e ligações reutilizadas com religação automática], [_Broker_ ou ligação falha → mensagens persistidas e confirmadas não se perdem; o serviço religa-se], [Não: publicação sem persistência e uma ligação por mensagem com `throw` (EV-10, EV-12)], [A],
    [TAT-08], [QS-02], [Disponibilidade → detetar falhas (_timeout_); recuperar (ressincronização de estado)], [_Timeout_ das execuções e reconciliação de `Process` pendentes ao arrancar o orquestrador e periodicamente], [Resposta nunca chega → execução expira → trabalho reenviado ou terminado com erro comunicado ao utilizador], [Não: sem TTL nem varrimento (EV-13)], [A],
    [TAT-09], [QS-02], [Disponibilidade → recuperar de falhas (tratamento de exceções); prevenir duplicados], [Respostas idempotentes (ignorar respostas repetidas pelo `correlationId`) e fila de mensagens mortas com limite de tentativas], [Mensagem reentregue duas vezes → segunda resposta ignorada; mensagem que falha sempre → vai para a fila de mortas e o utilizador recebe erro], [Não; erros perdidos pela troca de identificadores (EV-11)], [A],
    [TAT-10], [QS-02], [Disponibilidade → remoção planeada do serviço], [Terminação graciosa: ao receber SIGTERM, o serviço deixa de consumir e termina ou devolve o trabalho em curso], [Serviço é parado para atualização ou reinício (SIGTERM) → trabalho em curso concluído ou devolvido à fila → nenhum trabalho perdido], [Não], [A],
    [TAT-11], [QS-02], [Disponibilidade → recuperar (intervenção do utilizador)], [Botão «repetir» para trabalhos falhados], [Trabalho falha → utilizador repete], [Não], [C (rejeitada: funcionalidade nova)],
    [TAT-12], [QS-07], [Usabilidade → apoiar a iniciativa do utilizador (cancelar)], [Processamento em segundo plano com indicador de progresso não bloqueante: a página continua utilizável e o cancelamento está sempre à vista], [Utilizador aplica o _pipeline_ → indicador no cabeçalho em vez de camada sobreposta → continua a navegar, ver e descarregar; só a edição deste projeto fica bloqueada], [Não: camada sobreposta a toda a página (EV-19)], [B],
    [TAT-13], [QS-07], [Usabilidade → apoiar a iniciativa do sistema (manter um modelo do sistema)], [Estado da execução mantido pelo servidor e consultável, derivado dos _tokens_ da execução e dos registos `Process`], [Página recarregada ou novo separador → consulta o estado → retoma o progresso e o cancelamento], [Parcial: o servidor já guarda os _tokens_ e os passos (EV-13), mas não os expõe; a página guarda o seu próprio estado (EV-20)], [A],
    [TAT-14], [QS-07], [Disponibilidade → recuperar (ressincronização de estado)], [Reconciliação periódica com o servidor durante uma execução: a página termina a execução pelo estado do servidor quando os eventos se perderam], [Eventos perdidos durante um recarregamento → a consulta mostra a execução confirmada → a página mostra os resultados], [Não], [A],
    [TAT-15], [QS-07], [Usabilidade → apoiar a iniciativa do sistema (manter um modelo da tarefa)], [Eventos identificados pelo projeto e notificação da conclusão ou falha em qualquer página da aplicação], [Execução termina enquanto o utilizador está noutra página → notificação com ligação para os resultados], [Não: eventos sem projeto (EV-21)], [B],
    [TAT-16], [QS-07], [Usabilidade → apoiar a iniciativa do utilizador (pausar / retomar)], [Pausar e retomar execuções], [Utilizador pausa uma execução longa e retoma-a mais tarde], [Não], [C (rejeitada: funcionalidade nova)],
  ),
)
]
