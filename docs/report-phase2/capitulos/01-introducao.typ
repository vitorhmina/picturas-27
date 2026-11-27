#import "../template.typ": *

= Introdução

== Propósito e âmbito

Na Fase 1, o PictuRAS passou a aceitar vídeo com o objetivo de validar a funcionalidade (MVP). A solução de base
desta fase (grupo PL1-G4, integrada no repositório oficial) cumpre os requisitos funcionais, mas tem duas fraquezas no
processamento de projetos: enquanto uma execução decorre, a página fica bloqueada e o progresso perde-se ao
recarregar; e a troca de mensagens entre o orquestrador e as ferramentas não sobrevive à falha de um serviço, pelo
que um trabalho pode ficar pendente para sempre.

Este relatório especifica, mede e melhora, por _refactoring_ e sem acrescentar funcionalidades, os dois requisitos
não funcionais que respondem a essas fraquezas, no padrão global de microserviços orientados a mensagens e para
imagens e vídeos:

- *CAND-1 — Usabilidade › operabilidade (trabalho em segundo plano):* enquanto um projeto é processado, o utilizador
  continua a usar a aplicação e mantém o controlo da execução (acompanhá-la e cancelá-la), mesmo depois de recarregar
  a página ou noutro separador.
- *CAND-2 — Fiabilidade › recuperabilidade e tolerância a falhas:* um trabalho em curso sobrevive à falha de uma
  ferramenta ou do orquestrador, terminando com resultado ou com um erro visível ao utilizador, em vez de ficar
  pendente indefinidamente.

A escolha destes dois candidatos decorre da priorização dos cenários (capítulo 5). O âmbito inclui ainda a separação
do serviço de vídeo por etapa, um _refactoring_ preparatório de modularidade (QS-03, capítulo 8).

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

== Exercícios e versões usadas

#tab([Exercícios que alimentam este relatório],
  tabela(
    colunas: (3.6cm, 2.2cm, 2cm, 2cm, 1fr),
    [Exercício], [Capítulos], [Enunciado], [Template], [Versão do documento da equipa],
    [Exercício 6, Bloco 1: padrões arquiteturais], [2, 3 e 4], [1.0], [1.0], [v1.0],
    [Exercício 6, Bloco 2: trade-offs, cenários e candidatos a RNF], [5 e 6], [1.0], [1.0], [v1.0],
    [Exercício 7: táticas arquiteturais], [7 a 10], [1.0], [1.0], [v1.0],
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
