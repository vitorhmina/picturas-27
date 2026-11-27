#import "../template.typ": *

= Conclusões e Recomendações

== Adequação do padrão atual (global e do vídeo)

O padrão global (microserviços com um orquestrador e comunicação assíncrona por filas) mostrou-se adequado: nenhuma
das melhorias exigiu substituí-lo, e as duas decisões cabem dentro dele. As fraquezas encontradas estavam na forma
como o padrão era realizado, não na sua escolha. A entrega de mensagens não sobrevivia à falha de um serviço
(confirmação à receção, publicação sem persistência, respostas de erro descartadas). O estado de uma execução, que o
orquestrador já guardava, não era exposto, e a página do projeto mantinha uma cópia própria que se perdia ao
recarregar.

O vídeo era o ponto em que a solução se afastava do padrão global: todas as ferramentas de vídeo eram executadas por
um único serviço, a partir de uma única fila. Esse serviço foi dividido em três, cada um com a sua fila: um para os
efeitos comuns, o corte temporal e a velocidade (aplicados numa só passagem), outro para a legendagem e outro para a
extração de fotogramas. O orquestrador passou a encaminhar o trabalho para cada um, como já fazia com as ferramentas
de imagem, sem alterar os resultados.

== Sugestões de otimização

As otimizações sugeridas dão continuidade às duas decisões:

+ *Fila de mensagens mortas com limite de tentativas (DA-2).* Hoje uma mensagem que faz falhar a ferramenta é repetida
  uma vez e descartada, e o utilizador só recebe o erro quando o passo expira (desvio 1 da DA-2). Uma fila própria
  daria o erro de imediato e guardaria a mensagem para análise.
+ *Progresso intermédio dos passos longos (DA-2).* Um passo ou etapa interrompido é processado de novo desde o início,
  o que domina o tempo de recuperação com o orquestrador (32,7 s) e com os serviços de vídeo (48,9 s). Guardar
  progresso intermédio, por exemplo por segmentos de vídeo, reduziria esse tempo.
+ *Operabilidade para além da página do projeto (DA-1).* O estado da execução no servidor permite mostrar uma lista das
  execuções em curso de todos os projetos, enviar notificações do sistema operativo quando o separador não está
  visível e retomar o acompanhamento depois de uma falha do _browser_.

== Considerações para evolução futura

A elasticidade (QS-01) ficou mais próxima do que estava no início desta fase. A separação do vídeo deu a cada etapa
uma fila e um serviço que podem ser escalados à parte, e a entrega _at-least-once_ da DA-2 torna seguro remover uma
réplica a meio de um trabalho, porque o passo interrompido é entregue de novo. Falta a medida que decide o número de
réplicas (a profundidade e a idade de cada fila) e o mecanismo que o aplica. Um orquestrador de contentores com
escalamento por eventos (e.g., Kubernetes com KEDA) fá-lo sem código próprio, mas muda a plataforma de execução e foi
deixado fora desta fase por isso.

== Trabalho futuro

Os valores-alvo de U1–U3, R1 e R3 foram atingidos. O R2 só atingiu o alvo com a ferramenta de imagem (29,6 s): com
o orquestrador (32,7 s) e com os serviços de vídeo (48,9 s) fica no mínimo aceitável. Em ambos os casos, o tempo é
dominado por reprocessar o passo ou a etapa interrompida desde o início; reduzi-lo exigiria guardar progresso
intermédio, o que não foi feito. A causa da diferença no vídeo (28,7 s na base) não foi isolada.

A medição final revelou ainda um custo de desempenho: com uma rajada de 10 trabalhos de vídeo (E2), a espera mediana
diminui, mas o _makespan_ sobe 60 %, sobretudo por causa da separação do vídeo. A causa provável (a ordem das filas
entre etapas, com uma réplica por etapa) não foi confirmada e é o primeiro ponto a investigar.

Ficaram por confirmar duas hipóteses: o custo de desempenho próprio das confirmações, que a medição final não separa
do da separação do vídeo, e o comportamento com vários utilizadores a processar ao mesmo tempo, que os cenários U1–U3 não exercitam.

*Ligação à Fase 3.* O _refactoring_ facilita a integração de novas funcionalidades em três pontos: um novo efeito de
vídeo é acrescentado a uma etapa sem tocar nas outras (`Tools/video_common/`); uma nova ferramenta herda a entrega
fiável da biblioteca comum (`Tools/utils/`); e qualquer funcionalidade que precise do estado de uma execução usa o
ponto de consulta da DA-1 em vez de criar outro. Em contrapartida, qualquer serviço novo tem de tolerar mensagens
repetidas, uma regra que fica documentada em `AGENTS.md`.
