#import "../template.typ": *

= Utilização de IA

== Ferramentas, modelos e configuração

#tabela(
  colunas: (3.5cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização (_skills_, instruções de projeto, MCP, …)],
  [Claude Code (extensão de VS Code), modelo Claude Opus 5.5], [Agente com acesso ao repositório e à linha de comandos (Git Bash e PowerShell), em modo de planeamento antes de cada alteração e com permissões por ação. Instruções de projeto: `AGENTS.md` do repositório (arquitetura, convenções, armadilhas conhecidas). Sem servidores MCP nem _skills_ específicas do projeto.],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por IA e validação],
  tabela(
    colunas: (2.4cm, 2.8cm, 3.2cm, 3.4cm, 1fr),
    tamanho: 8pt,
    [Ferramenta / modelo], [Tarefa apoiada (capítulo)], [O que foi aceite], [O que foi rejeitado e porquê], [Como foi validado pela equipa],
    [Claude Code / Opus 5.5], [Comparação dos candidatos a RNF (cap. 5–6)], [Comparação por pertinência, complexidade e mensurabilidade, usada como base da discussão], [Manter a elasticidade: pouco visível para o utilizador, e a solução proposta (um autoescalador próprio) não pareceu uma boa abordagem], [A equipa pôs os candidatos em perspetiva e escolheu os que considerou oferecerem o melhor equilíbrio entre complexidade de implementação e valor para os _stakeholders_ (impacto no utilizador)],
    [Claude Code / Opus 5.5], [_Scripts_ de medição e execução das medições (cap. 6, 10)], [Cliente da API, cenários E, R e U, agendamento e resumo dos resultados], [Medições com resultados errados: a página dada como bloqueada antes de acabar de carregar, e um vídeo demasiado curto para testar o recarregamento. Uma medição feita com a máquina sobrecarregada foi descartada e repetida], [Verificações automáticas em cada cenário; análise dos resultados pela equipa e comparação com o comportamento observado ao usar a aplicação],
    [Claude Code / Opus 5.5], [Apoio à implementação das DA-1 e DA-2 e às correções de defeitos (cap. 8, 10)], [Propostas de código e testes, depois de a equipa definir a decisão e as táticas], [Reenviar automaticamente um passo de imagem que excedeu o tempo, porque podia aplicar o efeito duas vezes à mesma imagem], [Testes unitários, cenários antes e depois e testes ponta a ponta executados pela equipa; utilização manual da aplicação pela equipa, com imagens e vídeos, à procura de erros e comportamentos inesperados],
    [Claude Code / Opus 5.5], [Apoio à redação do relatório], [Primeira versão do relatório], [Afirmações ou formulações incorretas encontradas na revisão, corrigidas pela equipa], [Revisão integral do relatório pela equipa antes da entrega, com correção dos erros encontrados e preenchimento das partes que a primeira versão não cobria],
  ),
)

== Análise crítica

A utilização de IA revelou-se mais eficaz em tarefas de verificação objetiva, nomeadamente a localização de código
relevante, o desenvolvimento dos _scripts_ de medição e o diagnóstico de falhas a partir dos registos dos serviços,
cujos resultados puderam ser confirmados por testes, medições ou leitura do código. As limitações observadas
consistiram em afirmações não verificadas e em medições inicialmente incorretas, identificadas e corrigidas durante a
validação (tabela anterior), bem como em recomendações nem sempre alinhadas com as prioridades da equipa.

Em consequência, nenhum resultado produzido com apoio de IA foi aceite sem verificação, as decisões de âmbito e de
arquitetura foram tomadas pela equipa, e o relatório foi revisto e completado pela equipa antes da entrega. A equipa
considera que a IA reduziu o tempo dedicado a tarefas repetitivas, mas que a sua utilização exige conhecimento do
sistema suficiente para validar cada resultado.
