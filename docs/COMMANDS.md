# Protocolo JSON

Todos os comandos possuem `op`. Caminhos são arrays iniciados por um serviço permitido, por exemplo `["Workspace","MinhaPasta","Peça"]`.

| Operação | Uso |
|---|---|
| `ping` | Nome e ID do lugar conectado |
| `tree` | `{"op":"tree","path":["Workspace"],"depth":2}` |
| `get` | `{"op":"get","path":["Workspace","Peça"],"properties":["Anchored","Size"]}` |
| `selection` | Objetos selecionados |
| `select` | `{"op":"select","paths":[["Workspace","Peça"]]}` |
| `create` | `{"op":"create","parent":["Workspace"],"class":"Part","name":"Peça"}` |
| `set` | `{"op":"set","path":["Workspace","Peça"],"properties":{"Anchored":true}}` |
| `script` | `{"op":"script","path":["ServerScriptService","Sistema"],"source":"print('ok')"}` |
| `rename` | `{"op":"rename","path":["Workspace","Peça"],"name":"NovoNome"}` |
| `clone` | `{"op":"clone","path":["Workspace","Peça"],"name":"Cópia"}` |
| `move` | `{"op":"move","path":["Workspace","Peça"],"parent":["ReplicatedStorage"]}` |
| `delete` | `{"op":"delete","path":["Workspace","Peça"]}` |
| `batch` | `{"op":"batch","commands":[ ... ]}`, até 80 operações |

`create` também aceita `source` para Script/LocalScript/ModuleScript e `properties`. `clone` aceita `parent` opcional. Não há transação atômica garantida para operações parciais do `batch`.

## Tipos de propriedades

- `Vector3`: `{"type":"Vector3","x":1,"y":2,"z":3}`
- `Vector2`: `{"type":"Vector2","x":1,"y":2}`
- `Color3`: `{"type":"Color3","r":1,"g":0.5,"b":0}`
- `CFrame`: `{"type":"CFrame","x":0,"y":5,"z":0}` ou 12 componentes
- `UDim2`: `{"type":"UDim2","xScale":1,"xOffset":0,"yScale":0,"yOffset":40}`
- `Enum`: `{"type":"Enum","enum":"Material","name":"Neon"}`
- `Instance`: `{"type":"Instance","path":["Workspace","Peça"]}`

Enums, componentes, propriedades e classes devem existir na API Roblox Studio. Os serviços e classes criáveis estão limitados no código do plugin.

## Uso pelo Python

```powershell
python studio_agent.py status
python studio_agent.py start
python studio_agent.py inspect --root Workspace --depth 2 --expected-place Place1
python studio_agent.py run --file command.json --expected-place Place1 --timeout 30
```

Somente envie edições se `connected: true`. Se `studio_not_connected`, abra o projeto e ative o painel. Se `different_project`, pare e troque o projeto alvo. Se `timeout_inflight_check_results_do_not_retry`, examine o ID em `inflight/` e `results/` antes de tentar novamente.
