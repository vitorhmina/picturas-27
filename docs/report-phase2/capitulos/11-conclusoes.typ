#import "../template.typ": *

= Conclusões e Recomendações

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 6 do _template_.

  Sintetizem os contributos do relatório, sem repetir o conteúdo dos capítulos anteriores: o que o diagnóstico concluiu
  sobre a adequação do padrão atual, que otimizações sugerem e que considerações ficam para a evolução futura.

  Terminem com o que ficou por fazer e porquê (e.g., valores-alvo não atingidos, hipóteses por confirmar) e com a
  ligação à Fase 3: de que forma o _refactoring_ facilita, ou não, a integração de novas funcionalidades. Sejam realistas e honestos quanto às limitações da
  análise e às hipóteses que ficaram por confirmar.
]

== Adequação do padrão atual (global e do vídeo)

O padrão global (microserviços com um orquestrador e comunicação assíncrona por filas) mostrou-se adequado: nenhuma
das melhorias exigiu substituí-lo, e as duas decisões cabem dentro dele. As fraquezas encontradas estavam na forma
como o padrão era realizado, não na sua escolha. A entrega de mensagens não sobrevivia à falha de um serviço
(confirmação à receção, publicação sem persistência, respostas de erro descartadas). O estado de uma execução, que o
orquestrador já guardava, não era exposto, e a página do projeto mantinha uma cópia própria que se perdia ao
recarregar.

O vídeo era o ponto em que a solução se afastava do padrão global: um único serviço e uma única fila executavam todos
os estágios. A separação por estágio aproximou-o do padrão das imagens sem alterar os resultados. A coreografia sem
orquestrador (capítulo 4) foi rejeitada, porque o _commit_ atómico e o cancelamento de uma execução dependem do
orquestrador.

== Sugestões de otimização

As sugestões implementadas são as das duas decisões e a separação do vídeo (capítulo 8). Das recomendações do
capítulo 5, ficam por implementar, por ordem de prioridade:

+ *Fila de mensagens mortas com limite de tentativas.* Hoje uma mensagem que faz falhar a ferramenta é repetida uma vez
  e descartada, e o utilizador só recebe o erro quando o passo expira (desvio 1 da DA-2). Uma fila própria daria o erro
  de imediato e guardaria a mensagem para análise.
+ *Carregamento em _streaming_.* Os ficheiros de vídeo são guardados inteiros em memória no _gateway_ e no orquestrador
  (EV-01), o que limita os carregamentos simultâneos de vídeos grandes.
+ *Retirar os segredos do ficheiro versionado* e deixar de publicar as portas internas.
+ *Métricas e elasticidade* dos serviços de vídeo (ver a secção seguinte).

== Considerações para evolução futura

A elasticidade (CAND-3) ficou mais próxima do que estava no início desta fase. A separação do vídeo deu a cada estágio
uma fila e um serviço que podem ser escalados à parte, e a entrega _at-least-once_ da DA-2 torna seguro remover uma
réplica a meio de um trabalho, porque o passo interrompido é entregue de novo. Falta a medida que decide o número de
réplicas (a profundidade e a idade de cada fila) e o mecanismo que o aplica. Um orquestrador de contentores com
escalamento por eventos (e.g., Kubernetes com KEDA) fá-lo sem código próprio, mas muda a plataforma de execução e foi
deixado fora desta fase por isso.

O estado da execução no servidor (DA-1) é a base de outras melhorias de operabilidade: uma lista das execuções em
curso de todos os projetos, notificações do sistema operativo quando o separador não está visível, ou a retoma depois
de uma falha do _browser_.

== Trabalho futuro

Os valores-alvo de U1–U3, R1 e R3 foram atingidos. O R2 só atingiu o alvo com a ferramenta de imagem (29,6 s): com
o orquestrador (32,7 s) e com os serviços de vídeo (48,9 s) fica no mínimo aceitável. Em ambos os casos, o tempo é
dominado por reprocessar o passo ou estágio interrompido desde o início; reduzi-lo exigiria guardar progresso
intermédio, o que não foi feito. A causa da diferença no vídeo (28,7 s na base) não foi isolada.

A medição final revelou ainda um custo de desempenho: com uma rajada de 10 trabalhos de vídeo (E2), a espera mediana
diminui, mas o _makespan_ sobe 60 %, sobretudo por causa da separação do vídeo. A causa provável (a ordem das filas
entre estágios, com uma réplica por estágio) não foi confirmada e é o primeiro ponto a investigar.

Ficaram por fazer a fila de mensagens mortas, a elasticidade e as restantes recomendações da secção anterior. Ficaram
também por confirmar duas hipóteses: o custo de desempenho próprio das confirmações, que a medição final não separa
do da separação do vídeo, e o comportamento com vários utilizadores a processar ao mesmo tempo, que os cenários U1–U3 não exercitam.

*Ligação à Fase 3.* O _refactoring_ facilita a integração de novas funcionalidades em três pontos: um novo efeito de
vídeo é acrescentado a um estágio sem tocar nos outros (`Tools/video_common/`); uma nova ferramenta herda a entrega
fiável da biblioteca comum (`Tools/utils/`); e qualquer funcionalidade que precise do estado de uma execução usa o
ponto de consulta da DA-1 em vez de criar outro. Em contrapartida, qualquer serviço novo tem de tolerar mensagens
repetidas, uma regra que fica documentada em `AGENTS.md`.
