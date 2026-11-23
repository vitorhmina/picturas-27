#import "../template.typ": *

= Utilização de IA

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 7, e Exercício 7, secção 6. Documentar ferramentas, modelos e _skills_, tarefas
  apoiadas e validação feita pela equipa. A equipa é responsável por todo o conteúdo entregue.
]

== Ferramentas, modelos e configuração

#tabela(
  colunas: (3.5cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização (_skills_, instruções de projeto, MCP, …)],
  [Claude Code (extensão de VS Code), modelo Claude Opus 5.5], [Agente com acesso ao repositório e à linha de comandos (Git Bash e PowerShell), em modo de planeamento antes de cada alteração e com permissões por ação. Instruções de projeto: `AGENTS.md` do repositório (arquitetura, convenções, armadilhas conhecidas). Sem servidores MCP nem _skills_ específicas do projeto.],
  [#preencher[outras ferramentas usadas pela equipa]], [#preencher[…]],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por IA e validação],
  tabela(
    colunas: (2.4cm, 2.6cm, 3cm, 3.2cm, 1fr),
    tamanho: 8pt,
    [Ferramenta / modelo / _skill_], [Tarefa apoiada (capítulo)], [O que foi aceite], [O que foi rejeitado e porquê], [Como foi validado pela equipa],
    [Claude Code / Opus 5.5], [Análise das ideias de RNF das diretrizes e escolha dos candidatos (cap. 5–6)], [Comparação por pertinência, complexidade e mensurabilidade; escolha de elasticidade e recuperabilidade, com modularidade e métricas como pré-requisitos], [Observabilidade como RNF principal: _baseline_ pouco mensurável. Usabilidade do trabalho em segundo plano: menor exigência técnica (reavaliado na v1.3, ver abaixo)], [#preencher[discussão em equipa; confirmação com o docente]],
    [Claude Code / Opus 5.5], [Recolha de evidências no código (cap. 2–5)], [Referências `ficheiro:linhas` das evidências EV-01 a EV-18], [Contagens não verificadas: uma afirmação de «29 serviços» com `restart: on-failure` foi corrigida para 28 depois de contada com `grep`], [#preencher[revisão de cada referência no _commit_ `0523102`]],
    [Claude Code / Opus 5.5], [Instrumentos de medição `bench/` (cap. 6, 10, anexo A)], [Cliente da API pública, cenários E1–E3 e R1–R3, resumo CSV], [Um erro de interpretação da resposta de `POST /process` (a resposta é a cadeia JSON `"Created"`, não um objeto) foi detetado na revisão do código do _gateway_ antes da primeira execução], [Teste de fumo contra a pilha em execução (um vídeo e duas imagens); #preencher[revisão dos _scripts_ pela equipa]],
    [Claude Code / Opus 5.5], [Preparação do ambiente de medição (cap. 2)], [Deteção de contentores e de uma imagem do RabbitMQ de uma experiência anterior que contaminariam a _baseline_; verificação das imagens ficheiro a ficheiro contra o _commit_ de partida], [Uma sugestão de contornar a verificação de permissões do `buildx bake` foi bloqueada pelo sistema de permissões do agente; foi substituída pela reutilização das imagens verificadas. Uma afirmação de que `COMPOSE_BAKE=false` resolvia o problema revelou-se falsa ao ser testada e foi retirada da documentação], [#preencher[…]],
    [Claude Code / Opus 5.5], [Rascunho do relatório (cap. 1–8, 10, 12, anexos)], [Estrutura, tabelas e texto a partir das evidências], [#preencher[…]], [#preencher[revisão integral pela equipa]],
    [Claude Code / Opus 5.5], [Implementação da DA-2 (cap. 8, 10)], [Confirmação após resposta confirmada nas ferramentas e no orquestrador, correção das respostas de erro, registo `Process` com a mensagem do passo e vigilante de recuperação, testes e cenário de falha do _broker_], [Republicar passos expirados a partir do registo: rejeitado depois de verificar que os passos de imagem escrevem por cima do próprio ficheiro, pelo que a repetição não é idempotente. A primeira versão da rota de processamento esperava as confirmações do _broker_ e bloqueava o pedido com o _broker_ em baixo; detetado ao preparar o cenário `outage_crash.py` e corrigido para publicar em segundo plano], [Testes unitários, cenários de falha R1–R3 antes e depois, teste ponta a ponta; #preencher[revisão do código pela equipa]],
    [Claude Code / Opus 5.5], [Reavaliação do primeiro candidato antes do autoescalador (cap. 6)], [Comparação da elasticidade com a operabilidade do trabalho em segundo plano por pertinência, complexidade, solidez da medição e custo; recomendação de operabilidade], [A primeira recomendação (manter a elasticidade) pesava o trabalho já feito; a equipa pediu uma comparação sem esse viés, que a inverteu. A sugestão de migrar para Kubernetes com KEDA foi rejeitada por custo e por mudar a plataforma entre medições], [Decisão da equipa],
    [Claude Code / Opus 5.5], [Implementação da DA-1 e instrumento U1–U3 (cap. 8, 10)], [Ponto de consulta do estado, eventos com o projeto, indicador não bloqueante, retoma, fim pelo estado do servidor, notificação global; _script_ Playwright com controlos], [A primeira sondagem (U1) declarava a página bloqueada antes de Apply, enquanto a página ainda estava a carregar: detetado pelo controlo e corrigido. Com um vídeo de 10 s, U2 e U3 davam falsos negativos numa máquina carregada (a execução terminava antes de o separador carregar): passaram a usar o vídeo de 60 s e a registar se a execução ainda decorria], [Testes unitários, controlos do instrumento, verificação funcional na pilha; #preencher[revisão do código pela equipa]],
  ),
)

== Análise crítica

#preencher[O que correu bem, onde a IA introduziu erros ou soluções inadequadas, como foram detetados, e que práticas a equipa adotou para validar o resultado.]

Até esta versão, os erros introduzidos pela IA foram afirmações não verificadas (uma contagem e o efeito de uma
variável de ambiente) e um erro de interpretação de uma resposta da API. Todos foram detetados por verificação direta:
contagem no código, execução do comando e leitura do código do _gateway_. A prática adotada é não aceitar nenhuma
evidência, contagem ou comando sem uma verificação executada no _commit_ de partida.
