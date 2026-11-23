#import "../template.typ": *

= Alternativas e Matriz de Comparação

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secção 3 do _template_. Entre duas e três alternativas para o processamento de vídeo,
  indicando se cada uma mantém ou altera o padrão global, com custo e risco de migração.
]

== Alternativas consideradas

#tab([Alternativas consideradas],
  tabela(
    colunas: (1.6cm, 3.4cm, 1fr, 3cm, 2.4cm),
    tamanho: 8.5pt,
    [ID], [Nome / padrão], [Descrição breve], [Mantém ou altera o padrão global?], [Fonte],
    [ALT-1], [Serviço de vídeo único replicado (_competing consumers_)], [Manter o `video_tool` como está e executar várias réplicas a consumir `video_queue`, eventualmente com número de réplicas ajustado à carga.], [Mantém (e mantém o desvio do vídeo)], [Diretrizes da Fase 2 (elasticidade); padrão _competing consumers_],
    [ALT-2], [Um microserviço por estágio de vídeo, orquestrado pelo `projects`, com escalamento por fila], [Separar o `video_tool` em serviços de efeitos de fotograma, legendagem e extração, cada um com a sua fila e código partilhado numa biblioteca comum; o orquestrador encadeia os estágios como nas imagens, mantendo efeitos contíguos num só passo de codificação; o número de réplicas de cada serviço segue a profundidade da sua fila.], [Mantém (o vídeo passa a seguir o padrão global)], [Diretrizes da Fase 2 (modularidade e elasticidade); relatório da Fase 1 do PL5-G6, DA-01],
    [ALT-3], [Coreografia por eventos entre estágios], [Cada estágio publica diretamente o trabalho para o estágio seguinte; o orquestrador só recebe o resultado final.], [Altera (remove a orquestração central do vídeo)], [Slides da aula 11 (_event-driven_, coreografia vs. orquestração)],
  ),
)

== Análise de cada alternativa

*ALT-1 — Serviço de vídeo único replicado*

#tabela-campos(
  [Coerência com o padrão global], [Usa o mecanismo já previsto pelo padrão (várias réplicas a consumir uma fila, ficheiros no volume partilhado, EV-15), mas conserva o desvio do vídeo: todos os efeitos no mesmo serviço (EV-08).],
  [Efeito nos atributos de qualidade], [Melhora a capacidade (vários trabalhos em paralelo). Não melhora a modularidade. Piora a utilização de recursos: cada réplica traz o ffmpeg e o modelo Whisper, mesmo que só processe efeitos leves (H-02: memória por réplica dominada pelo modelo Whisper, a confirmar com `docker stats`).],
  [Vantagens potenciais], [Alteração mínima (configuração do Compose); risco de regressão funcional quase nulo.],
  [Desvantagens ou riscos], [Não separa trabalhos leves de pesados: com N réplicas, N legendagens simultâneas voltam a bloquear todos os trabalhos curtos. Escala tudo ou nada.],
  [Custo e risco de migração (a funcionalidade existente tem de ser preservada)], [Baixo custo; baixo risco (o código do serviço não muda).],
)

*ALT-2 — Um microserviço por estágio de vídeo, orquestrado, com escalamento por fila*

#tabela-campos(
  [Coerência com o padrão global], [Alta: o vídeo passa a ter uma fila e um serviço por tipo de trabalho e o orquestrador encadeia os passos, como nas imagens (EV-09, EV-03).],
  [Efeito nos atributos de qualidade], [Melhora a capacidade e a utilização de recursos (só a legendagem carrega o Whisper e só ela escala para legendagens), a modularidade e a testabilidade de cada estágio. Pode piorar o comportamento temporal de um trabalho isolado, por haver mais saltos entre serviços e uma codificação intermédia por estágio.],
  [Vantagens potenciais], [Trabalhos curtos deixam de esperar por legendagens; cada estágio é alterado, reconstruído e escalado isoladamente; o orquestrador passa a ver o progresso por estágio.],
  [Desvantagens ou riscos], [Mais serviços e filas para operar; o encadeamento por estágio tem de preservar a semântica atual (efeitos contíguos num só passo, legendagem e extração pela ordem definida, extração sempre no fim); mais pontos de falha, o que torna a recuperação de falhas (CAND-2) ainda mais necessária.],
  [Custo e risco de migração], [Médio a alto: altera o orquestrador e o serviço de vídeo; mitigado pelos testes existentes de `Tools/video/tests` (43 testes) e `projects/tests`, e por testes de regressão ponta-a-ponta.],
)

*ALT-3 — Coreografia por eventos entre estágios*

#tabela-campos(
  [Coerência com o padrão global], [Baixa: o padrão global é orquestrado (EV-03, EV-05); a coreografia criaria um segundo estilo só para o vídeo.],
  [Efeito nos atributos de qualidade], [Melhora a capacidade como a ALT-2, mas piora a analisabilidade e a recuperabilidade: o estado da execução fica distribuído pelos estágios, e o cancelamento e a contagem de operações, hoje no orquestrador, teriam de ser reimplementados.],
  [Vantagens potenciais], [Menos tráfego para o orquestrador.],
  [Desvantagens ou riscos], [O _commit_ atómico da execução e o cancelamento por `activeToken` dependem do orquestrador; reproduzi-los na coreografia é praticamente nova funcionalidade.],
  [Custo e risco de migração], [Alto custo e alto risco de regressão.],
)

== Matriz de comparação de padrões

#paisagem[
#tab([Matriz de comparação de padrões (escala: Alto / Médio / Baixo)],
  tabela(
    colunas: (3.8cm, 1fr, 1fr, 1fr, 1fr, 1fr),
    tamanho: 8pt,
    [Atributo de qualidade (ISO/IEC 25010)], [Padrão global atual (referência)], [Padrão atual do vídeo], [ALT-1], [ALT-2], [ALT-3],
    [Relação com o padrão global], [—], [Afasta-se (um serviço para tudo)], [Mantém (e mantém o desvio)], [Mantém (o vídeo passa a segui-lo)], [Altera],
    [Eficiência de desempenho: comportamento temporal], [Médio — um passo por mensagem; sem paralelismo dentro de uma ferramenta (EV-09)], [Médio — um trabalho isolado é rápido (uma codificação), mas espera por todos os anteriores (EV-07)], [Médio — sem espera enquanto houver réplicas livres], [Médio — sem espera por trabalhos de outro tipo; um salto extra por estágio (H-03)], [Médio — como ALT-2],
    [Eficiência de desempenho: capacidade / elasticidade], [Baixo — recursos fixos, uma réplica (EV-16)], [Baixo — um trabalho de cada vez (EV-06, EV-07)], [Médio — escala, mas tudo ou nada], [Alto — escala por tipo de trabalho (EV-15)], [Alto — escala por estágio],
    [Fiabilidade: tolerância a falhas / recuperabilidade], [Baixo — _auto-ack_ e respostas sem garantia (EV-10, EV-12, EV-13)], [Médio — _ack_ no fim no serviço; respostas herdam a fragilidade (EV-07, EV-12)], [Médio — igual ao atual], [Médio — mais saltos, cada um precisa de _ack_ manual (CAND-2)], [Baixo — estado distribuído sem coordenador],
    [Manutenibilidade: modularidade / modificabilidade], [Alto — um serviço por efeito (EV-09)], [Baixo — todos os estágios no mesmo serviço (EV-08)], [Baixo — igual ao atual], [Alto — um serviço por estágio, biblioteca comum], [Médio — modular, mas com lógica de encadeamento espalhada],
    [Segurança], [Baixo — serviços confiam uns nos outros, TLS interno sem validação (`AGENTS.md`)], [Baixo — igual], [Baixo — igual], [Baixo — igual; um autoescalador com acesso ao Docker aumenta a superfície (H-04)], [Baixo — igual],
    [Usabilidade: operabilidade], [Médio — o utilizador não vê erros das ferramentas de imagem (EV-11)], [Médio — progresso por percentagem (EV-04)], [Médio — igual], [Médio — igual (o progresso por estágio não é exposto ao utilizador nesta fase)], [Médio — igual],
  ),
)
]

== Adequação do padrão atual

O padrão global é adequado ao PictuRAS: filas por ferramenta, volume partilhado e orquestração central dão
modularidade e já preveem réplicas. O padrão atual do vídeo é *menos adequado* do que a ALT-2 para os requisitos
identificados. Ao concentrar efeitos, legendagem e extração num serviço com um único consumidor, transforma uma
legendagem de minutos em espera para todos os trabalhos de vídeo e impede escalar apenas o trabalho pesado. A ALT-1
resolve parte da espera com custo mínimo, mas escala tudo ou nada e multiplica o modelo Whisper em memória. A ALT-3
resolve a capacidade à custa da coerência com o padrão global e da recuperabilidade. A ALT-2 é a que torna o vídeo
coerente com o padrão global e permite elasticidade por tipo de trabalho. O seu custo (mais saltos e mais pontos de
falha) torna a recuperação de falhas na troca de mensagens um requisito, e não uma opção. Por isso os dois candidatos
do capítulo 6 são tratados em conjunto.

#tab([Hipóteses usadas nos capítulos 3 e 4],
  tabela(
    colunas: (1.4cm, 1fr, 1fr),
    tamanho: 8.5pt,
    [ID], [Hipótese], [Como confirmar ou refutar],
    [H-01], [Uma ferramenta pode ter várias réplicas a consumir a mesma fila sem alterar o código, porque os ficheiros estão no volume partilhado], [Escalar um serviço (`docker compose up -d --scale <serviço>=2`) e verificar que um lote termina com os mesmos resultados],
    [H-02], [A memória de uma réplica do serviço de vídeo é dominada pelo modelo Whisper carregado], [Comparar `docker stats` do serviço antes e depois de uma legendagem (cenário E3, capítulo 10)],
    [H-03], [Separar estágios acrescenta, por trabalho, uma latência pequena face à duração do processamento], [Comparar o tempo total do trabalho leve sem concorrência antes e depois da separação (cenário E1)],
    [H-04], [Um autoescalador com acesso à API do Docker aumenta a superfície de ataque], [Análise da configuração do autoescalador (capítulo 8, DA-1) e da exposição do _socket_ do Docker],
  ),
)
