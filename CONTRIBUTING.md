# Contribuindo

## Pré-requisitos

- Docker
- VS Code com a extensão [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Começando

Clone o repositório com os submódulos (os três serviços vivem em repositórios separados):

```
git clone --recurse-submodules <repo-url>
# ou, se já tiver clonado:
git submodule update --init --recursive
```

Abra a pasta no VS Code e rode **Dev Containers: Reopen in Container** (`Ctrl/Cmd+Shift+P`). O primeiro build leva alguns minutos; as próximas aberturas são rápidas.

## O que o devcontainer configura automaticamente

- **`.devcontainer/Dockerfile`**: base Ubuntu, zsh (oh-my-zsh, definido como shell padrão) e [mise](https://mise.jdx.dev/) para gerenciar as linguagens.
- **`.devcontainer/entrypoint.sh`** (roda uma vez na criação do container, como `postCreateCommand`):
  - sobe o container do Postgres/pgvector (`akpedia-db`) via `docker compose`
  - conecta o devcontainer à rede Docker do `akpedia-db` para que o server consiga acessá-lo pelo nome (são containers irmãos, não aninhados — `localhost` não resolve entre eles)
  - dá trust e instala todos os `.mise.toml` (raiz do repo, `akpedia-server`, `akpedia-ml`) — é isso que efetivamente instala Java 17, Python 3.12, Node 22 e `uv`
  - configura `pnpm`/`yarn` via corepack
  - instala a CLI `akpedia` e seu autocomplete no zsh
- Dois volumes Docker nomeados persistem estado entre **rebuilds** do container (não só restarts): `akpedia-mise-data` (linguagens instaladas pelo mise) e `akpedia-m2` (repositório local do Maven). Sem eles, cada rebuild baixaria tudo de novo.
- As extensões recomendadas do VS Code (Vue, ESLint/Prettier, pacote Java, Spring Boot, Python, Ruff, Docker, YAML, TOML) são instaladas automaticamente.

## Rodando os serviços

```
akpedia run              # server (:8080) + ml (:8000) + client (:5173)
akpedia run server ml    # só os que você quiser
```

A saída é colorida e prefixada por serviço (`[server]`, `[ml]`, `[client]`); `Ctrl+C` encerra tudo. Autocomplete funciona: `akpedia <TAB>`, `akpedia run <TAB>`.

As dependências do client não são instaladas automaticamente — rode isso uma vez (ou depois de mudanças no `package.json`):

```
cd akpedia-client && npm install
```

`akpedia-server` (Maven wrapper) e `akpedia-ml` (`uv run`) resolvem suas próprias dependências na primeira execução.

### Rodando um módulo individualmente

```
cd akpedia-server && ./mvnw spring-boot:run
cd akpedia-ml && uv run uvicorn app.main:app --reload
cd akpedia-client && npm run dev
```

## Branches e commits

### Nome da branch

Deve seguir o padrão `AKP-<número>`:

```
AKP-12
```

### Mensagens de commit

Conventional Commits com o escopo do ticket — `type(AKP-<número>): descrição`:

```
feat(AKP-12): adiciona endpoint de login
fix(AKP-15): corrige validação de e-mail
```

### CLI `akpedia`

```
akpedia branch <número>   # cria (se não existir) e faz checkout de AKP-<número>
akpedia commit <type> <mensagem>
```

`akpedia commit` valida `<type>` contra a lista do Conventional Commits (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`, `revert`), usa a branch atual como escopo e recusa o commit se ela não seguir o padrão `AKP-<número>`. Autocomplete também funciona aqui: `akpedia commit <TAB>` lista os types.

Ambos os comandos operam no repositório git do diretório em que você está — como cada submódulo (`akpedia-server`, `akpedia-ml`, `akpedia-client`) é seu próprio repositório, rodar `akpedia branch`/`akpedia commit` de dentro de um deles afeta só aquele submódulo, não o repositório pai.

## Variáveis de ambiente

Cada módulo tem um `.env.example` — copie para `.env` e ajuste conforme necessário. Dentro do devcontainer, `DB_URL` já aponta para o container `akpedia-db` via `containerEnv` no `devcontainer.json`, então normalmente não é preciso configurá-la lá.

## Resolução de problemas

- **Mudou o `Dockerfile` ou o `devcontainer.json`?** Rode **Dev Containers: Rebuild Container**.
- **Alguma ferramenta instalada pelo mise dá "command not found" mesmo a instalação tendo "funcionado"?** Já aconteceu com o `uv` após um download falho; force a reinstalação:
  ```
  cd akpedia-ml && mise install --force uv@latest
  ```
- **Git reclamando de "dubious ownership"?** O container já configura `git config --global --add safe.directory '*'` no build; rode esse comando de novo caso isso seja resetado por algum motivo.
- **Quer começar do zero?** Remova os volumes persistidos e reconstrua: `docker volume rm akpedia-mise-data akpedia-m2`.
