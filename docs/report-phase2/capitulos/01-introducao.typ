#import "../template.typ": *

= Introdução

#orientacao[
  Uma a duas páginas, no máximo. O leitor deve perceber, sem ler o resto, o que é este documento e em que se baseia.
]

== Propósito e âmbito

Na Fase 1, o PictuRAS passou a suportar vídeo com o objetivo de validar a funcionalidade (MVP). A solução de base
desta fase (grupo PL1-G4, integrada no repositório oficial) processa todos os efeitos de vídeo, incluindo a legendagem
automática e a extração de fotogramas, num único serviço (`video_tool`), e a troca de mensagens entre o orquestrador e
as ferramentas não sobrevive à falha de um serviço. Este relatório especifica, mede e melhora, por _refactoring_ e sem
acrescentar funcionalidades, dois requisitos não funcionais do processamento de projetos (imagens e vídeos), enquadrado no padrão global
de microserviços orientados a mensagens:

- *CAND-1 — Usabilidade › operabilidade (trabalho em segundo plano):* enquanto um projeto é processado, o utilizador
  continua a usar a aplicação e mantém o controlo da execução (acompanhá-la e cancelá-la), mesmo depois de recarregar
  a página ou noutro separador. Na base, uma camada sobreposta bloqueia a página durante toda a execução e o progresso
  existe só no _browser_. Este candidato substituiu, na v1.3, a elasticidade do processamento de vídeo, que foi
  analisada e medida mas não escolhida (cap. 6).
- *CAND-2 — Fiabilidade › recuperabilidade e tolerância a falhas:* um trabalho em curso sobrevive à falha de uma
  ferramenta ou do orquestrador, terminando com resultado ou com um erro visível ao utilizador, em vez de ficar
  pendente indefinidamente.

A restrição da fase é a preservação do comportamento funcional: os mesmos pedidos produzem os mesmos resultados, para
imagens e para vídeos, o que é verificado por testes de regressão (capítulo 10).

== _Baseline_ e repositório
#tab([Artefactos de partida],
  tabela(
    colunas: (5cm, 1fr),
    [Artefacto], [Versão / referência],
    [Documento de requisitos de base], [doc-ext-requisitos-2627.pdf],
    [Documento de solução arquitetural de base], [doc-sol-arquitetural.pdf],
    [Repositório de partida], [`https://github.com/picturas-um/picturas-27`, _commit_ `052310226c51fa57a17101c7bd1ad795674aac95` (`0523102`, «Tell students replacing Phase 1 to wipe old Docker volumes (\#37)»)],
    [Repositório entregue], [`https://github.com/vitorhmina/picturas-27`, _commit_ #preencher[hash da entrega]],
    [Diretrizes da Fase 2], [Versão 1 (4 de novembro de 2026)],
  ),
)

O mesmo _commit_ de partida é usado em todos os capítulos e em todas as medições da _baseline_. Cada alteração é feita
num ramo próprio (`test/nfr-baseline-benchmarks`, `feature/split-video-workers`, `feature/reliable-messaging`,
`feature/process-recovery`, `test/background-work-baseline`, `feature/background-processing`) e integrada por _pull
request_, para que cada passo do _refactoring_ seja rastreável.

== Exercícios e versões usadas

#orientacao[
  Indiquem, para cada exercício, a versão do enunciado e do _template_ que usaram, e a versão do vosso documento que
  serviu de entrada ao exercício seguinte (Bloco 1 → Bloco 2 → Exercício 7).
]

#tab([Exercícios que alimentam este relatório],
  tabela(
    colunas: (3.6cm, 2.2cm, 2cm, 2cm, 1fr),
    [Exercício], [Capítulos], [Enunciado], [Template], [Versão do documento da equipa],
    [Exercício 6, Bloco 1: padrões arquiteturais], [2, 3 e 4], [#preencher[1.1]], [#preencher[1.1]], [#preencher[v1.0]],
    [Exercício 6, Bloco 2: trade-offs, cenários e candidatos a RNF], [5 e 6], [#preencher[1.2]], [#preencher[1.2]], [#preencher[v1.0]],
    [Exercício 7: táticas arquiteturais], [7 a 10], [#preencher[3.0]], [#preencher[3.0]], [#preencher[v1.0]],
  ),
)

== Organização do documento

A Parte II (capítulos 2 a 4) descreve como a solução de base foi lançada, a sua arquitetura e o caminho do vídeo,
identifica os padrões arquiteturais atuais e compara-os com alternativas. Cada afirmação sobre o sistema cita uma
evidência (`EV-nn`) ou é marcada como hipótese (`H-nn`). A Parte III (capítulos 5 e 6) transforma as fragilidades
encontradas em cenários de qualidade (`QS-nn`), prioriza-os e escolhe os dois candidatos a RNF (`CAND-n`) com a
respetiva quantificação. A Parte IV (capítulos 7 a 10) identifica táticas (`TAT-nn`), regista as decisões
arquiteturais (`DA-n`), mostra a arquitetura antes e depois e apresenta o plano de medição, os resultados e a
preservação funcional. A Parte V (capítulos 11 e 12) sintetiza as conclusões e documenta a utilização de IA. Os IDs
encadeiam os capítulos: `EV`/`H` → `ALT` → `QS`/`CAND` → `TAT` → `DA`.
