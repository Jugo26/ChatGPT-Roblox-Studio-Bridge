---
name: roblox-studio-operator
description: Use quando o usuário pedir para o ChatGPT ler, criar, modificar, depurar ou testar diretamente um projeto aberto no Roblox Studio via Desktop Commander e ChatGPT Studio Bridge.
---

# Roblox Studio Operator

Trabalhe no Roblox Studio aberto via plugin local **ChatGPT Studio Bridge**, servidor Python e conector **Desktop Commander**. Não afirme que uma alteração foi aplicada sem resposta `ok: true` do editor.

## Preflight

1. Localize o computador online pelo Desktop Commander (`list_devices`). Não presuma uma máquina ou usuário específico.
2. Localize a pasta extraída do ChatGPT-Roblox-Studio-Bridge; normalmente está em `%USERPROFILE%\Desktop\RobloxStudioBridge` ou outro local escolhido pelo usuário.
3. Na pasta do projeto, execute `python studio_agent.py status`; se o servidor estiver parado, execute `python studio_agent.py start` e cheque novamente.
4. Continue somente com `connected: true` e heartbeat recente. Verifique `studio.place` e `studio.placeId`; se o usuário nomear um jogo, confira o projeto conectado.
5. Antes de escrever, consulte com `python studio_agent.py inspect --root Workspace --depth 2` e outros serviços relevantes: `StarterGui`, `ServerScriptService`, `ReplicatedStorage`, `Lighting` etc.

## Executar

Construa um comando JSON conforme `docs/COMMANDS.md`. Grave o comando em arquivo temporário local usando Desktop Commander e execute:

```powershell
python studio_agent.py run --file agent_job.json --expected-place "NOME_DO_PROJETO" --timeout 30
```

- Para ler, use `tree`, `get`, `selection`, `ping`.
- Para editar, use `create`, `set`, `script`, `rename`, `clone`, `move`, `delete`, `batch`.
- Faça leituras antes de sobrescrever scripts; preserve o código e os objetos existentes.
- `batch` permite agrupar até 80 comandos em um histórico de undo, mas pode deixar alterações parciais se falhar.
- Após executar, leia novamente as instâncias alteradas para validar.
- Não repita automaticamente um comando em `inflight` caso a resposta expire.
- Se houver múltiplos projetos do Studio conectados na mesma ponte, não altere até identificar a sessão correta.
- Não envie `token.txt` nem o `.rbxmx` gerado para repositórios, relatórios ou chat.

## Entrega

Responda o nome do projeto modificado, as mudanças aplicadas e a validação executada. Se faltarem conexões, reporte o bloqueio real e como reativar o painel do Studio.
