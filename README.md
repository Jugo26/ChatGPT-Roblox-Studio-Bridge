# ChatGPT Roblox Studio Bridge

Bridge local de código aberto para ler e editar projetos abertos no **Roblox Studio** via ChatGPT, usando um plugin Roblox Studio, servidor Python em `127.0.0.1:48765` e um conector para executar comandos no computador.

> **Importante:** o projeto é uma ponte local, não um plugin nativo do ChatGPT. Para solicitar mudanças em linguagem natural, conecte o **Desktop Commander** ao ChatGPT, abra o Studio e mantenha o painel do plugin conectado.

## Instalação para Windows

1. Baixe o ZIP do projeto em **Code > Download ZIP** e extraia em uma pasta fixa.
2. Instale Python 3.10 ou superior e marque **Add Python to PATH**.
3. Execute `INSTALAR_E_INICIAR.bat` (duplo clique). Na primeira execução, o instalador gera um **token exclusivo** em `token.txt`, constrói `ChatGPT_Studio_Bridge.rbxmx` e instala em `%LOCALAPPDATA%\Roblox\Plugins`.
4. Abra/reinicie o Roblox Studio, abra o seu projeto, clique em **Plugins > ChatGPT Bridge > CONECTAR**.
5. Caso apareça a permissão, permita chamadas HTTP do plugin para `http://127.0.0.1:48765`. Mantenha o servidor Python aberto.

Não instale um .rbxmx compartilhado por outra pessoa: cada instalação gera o próprio token, e as versões geradas localmente não são publicadas.

## Testar pelo terminal

Em PowerShell, dentro da pasta extraída:

```powershell
python studio_agent.py status
python studio_agent.py inspect --root Workspace --depth 2
python studio_agent.py run --file examples/ping.json --timeout 15
```

Exemplo de comando JSON de criação de objeto:

```json
{"op":"create","parent":["Workspace"],"class":"Part","name":"BlocoTeste","properties":{"Anchored":true,"Size":{"type":"Vector3","x":8,"y":2,"z":8},"Position":{"type":"Vector3","x":0,"y":10,"z":0}}}
```

Salve como `command.json` e execute `python studio_agent.py run --file command.json --timeout 30`.

## Usar pelo ChatGPT

Instale o app **Desktop Commander** no ChatGPT e conecte sua máquina. Use a skill em `skills/roblox-studio-operator/SKILL.md` como guia para o assistente. Em seguida, peça: **"No Roblox Studio aberto, crie uma casa com 4 paredes e 1 porta e confirme no Explorer."**

O assistente usa o Desktop Commander para executar `studio_agent.py status`, consultar o Explorer, enviar JSON e verificar as mudanças. Os comandos não funcionam sem a conexão ao Desktop Commander, servidor Python ativo e painel do Studio conectado.

## Operações da ponte

`ping`, `tree`, `get`, `selection`, `select`, `create`, `set`, `script`, `rename`, `clone`, `move`, `delete` e `batch`. Exemplos e formatos: `docs/COMMANDS.md`.

`studio_agent.py` verifica a conexão recente, pode restringir o nome do projeto com `--expected-place`, aguarda a resposta e cancela jobs não entregues quando expiram. Quando o job já foi entregue, um timeout retorna seu ID para investigar em `inflight/` / `results/`; não reenvie automaticamente.

## Arquivos

- `plugin.template.lua`: plugin Studio (com marcador de token, não é instalado diretamente)
- `install.py`: gera o token e o plugin `.rbxmx`
- `bridge.py`: servidor HTTP local
- `studio_agent.py`: CLI para ChatGPT/Desktop Commander
- `send.py`: CLI simples de fila
- `INSTALAR_E_INICIAR.bat`: instala e inicia no Windows
- `skills/roblox-studio-operator/SKILL.md`: workflow para o agente

## Privacidade e segurança

O servidor escuta só no loopback (`127.0.0.1`) e solicita `X-Bridge-Token`. O token é único por instalação e nunca deve entrar no Git. Desconecte no painel do Studio para interromper comandos. O bridge modifica apenas o projeto do Studio conectado, mas a versão 1.x não suporta selecionar com segurança uma dentre várias sessões Studio conectadas à mesma porta.

## Desenvolvimento

Requisitos: Python padrão (sem dependências PyPI).

```powershell
python -m py_compile bridge.py send.py studio_agent.py install.py
python install.py --no-install
python studio_agent.py status
```

## Licença

MIT. Veja [LICENSE](LICENSE).
