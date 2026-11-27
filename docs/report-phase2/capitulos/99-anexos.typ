#import "../template.typ": *

#set heading(numbering: "A.1.")
#counter(heading).update(0)

= Instruções de execução

== Lançar a solução

Pré-requisitos: Docker com Compose (8 GB de RAM ou mais para a pilha completa), Git.

```bash
git clone https://github.com/vitorhmina/picturas-27 && cd picturas-27
git checkout <commit>     # 0523102 (baseline) ou o commit da entrega
docker compose down -v --remove-orphans
docker compose up -d --build        # primeira construção: 15 a 30 min
docker compose restart nginx
```

A aplicação fica em `https://localhost:8080` (aceitar o certificado autoassinado). Se o RabbitMQ exceder o
_healthcheck_ no primeiro arranque, repetir `docker compose up -d`.

== Repetir as medições

Pré-requisitos adicionais: Python 3.10 ou superior e ffmpeg.

```bash
cd bench
python -m venv .venv && .venv/Scripts/pip install -r requirements.txt
.venv/Scripts/python -m playwright install chromium
.venv/Scripts/python prepare_samples.py
# QS-07 (U1–U3)
.venv/Scripts/python background_ui.py --label baseline --runs 5
# QS-02 (R1–R3)
for t in none image-tool video projects; do
  .venv/Scripts/python chaos.py --label baseline --target $t --runs 5
done
# E1–E3 (custo de desempenho)
.venv/Scripts/python elasticity.py --label baseline --runs 5
.venv/Scripts/python summarize.py baseline
```

Em Linux e macOS, usar `.venv/bin/` em vez de `.venv/Scripts/`. Para a medição final, repetir os mesmos comandos com
`--label final`; depois da separação do vídeo, o alvo `video` indica os três serviços. Na versão final correm ainda os
testes ponta a ponta e o cenário de falha do _broker_ seguida da do orquestrador:

```bash
.venv/Scripts/python chaos.py --label final --target video --runs 5 \
  --services video_effects_tool,video_subtitles_tool,video_frames_tool
.venv/Scripts/python summarize.py baseline final
.venv/Scripts/python e2e_smoke.py --label final
.venv/Scripts/python outage_crash.py
```

O método completo está em `bench/README.md`.

= Glossário

#tabela(
  colunas: (4cm, 1fr),
  [Termo], [Definição],
  [Cenário de qualidade], [Descrição verificável de um requisito de qualidade com fonte, estímulo, artefacto, ambiente, resposta e medida da resposta.],
  [Tática arquitetural], [Decisão de desenho que influencia a resposta a um estímulo de qualidade (Bass, Clements e Kazman).],
  [Classe A / B / C], [Classificação das táticas e decisões: *A*, _refactoring_ puro; *B*, alteração visível que é o objeto da melhoria; *C*, funcionalidade nova (rejeitada nesta fase).],
  [_Baseline_], [Medição do sistema de base, antes do _refactoring_, com o mesmo método da medição final.],
  [Elasticidade], [Capacidade de ajustar os recursos à carga, aumentando-os nos picos e reduzindo-os em repouso.],
  [_Ack_ (confirmação)], [Sinal do consumidor ao RabbitMQ de que uma mensagem foi tratada e pode ser apagada; sem ele, a mensagem é reentregue.],
  [_At-least-once_], [Garantia de entrega em que cada mensagem é processada pelo menos uma vez, podendo repetir-se após uma falha.],
  [Idempotência], [Propriedade de uma operação cujo efeito é o mesmo se for executada uma ou várias vezes.],
  [Fila de mensagens mortas], [Fila para onde o _broker_ desvia mensagens que excederam o número de tentativas.],
  [_Makespan_], [Tempo desde a submissão do primeiro trabalho de um lote até à conclusão do último.],
  [p50 / p95], [Percentis 50 e 95 de uma amostra, calculados pelo método _nearest-rank_.],
  [`Process`], [Registo do orquestrador que representa um passo em curso de um trabalho; desde a DA-2, só é apagado depois de os efeitos do passo estarem guardados.],
  [Execução (`activeToken`)], [Identificador de uma aplicação do _pipeline_ a um projeto; os resultados só ficam visíveis quando a execução é _commitada_.],
)
