# Five Sols in Mars — versão do L0cas

Uma versão independente do jogo, feita em Godot 4.7 (renderer GL Compatibility).
É um projeto Godot próprio, separado do projeto da raiz do repositório.

## Como abrir

1. Abra o Godot 4.7.
2. Em **Importar**, escolha o arquivo `solucao-l0cas/project.godot`.
3. Aperte **F5** para rodar.

## Estrutura

- `scenes/main.tscn`: cena inicial.
- `scripts/`: lógica do jogo (`game.gd` é o autoload `Game`).
- `art/gen/`: imagens geradas por `tests/gen_art.gd`.
- `tests/`: scripts de teste (`smoke.gd`), capturas de tela (`shots.gd`) e geração de arte.

Feito com ajuda de IA (Claude).
