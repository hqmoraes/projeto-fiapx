# Como Me Retroalimentar - Instruções para o Usuário

## 📋 Para Iniciar Qualquer Sessão

**Cole este texto no chat:**

```
CONTEXTO ATUAL: Projeto FIAP-X - Sistema de processamento de vídeo em microsserviços Go + Frontend, rodando em Kubernetes ARM64 na AWS.

CREDENCIAIS:
- SSH: ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click
- Docker Hub: hmoraes / Ch@plinh45

ESTADO ATUAL: [copie do current-state.md]

PROBLEMA ATUAL: [descreva o problema específico]
```

## 📁 Arquivos de Contexto

Você deve ler estes arquivos antes de me dar qualquer tarefa:

1. **`.project-context/environment.md`** - Credenciais e configurações
2. **`.project-context/current-state.md`** - Estado atual do projeto  
3. **`.project-context/deploy-workflow.md`** - Como fazer deploys
4. **`.project-context/instructions.md`** - Este arquivo

## 🔄 Atualizando Estado

Quando eu resolver um problema ou fizer um deploy:

1. **Eu atualizarei** o `current-state.md` automaticamente
2. **Você deve copiar** o conteúdo atualizado no próximo chat
3. **Atualize a versão** se eu fizer deploy de algo novo

## ⚡ Atalhos para Tarefas Comuns

### Para Deploy de Frontend:
```
TAREFA: Deploy frontend vX.X
ARQUIVOS ALTERADOS: [liste os arquivos .js alterados]
MUDANÇAS: [descreva brevemente as mudanças]
```

### Para Troubleshooting:
```
PROBLEMA: [erro específico]
LOGS: [cole logs relevantes se tiver]
CONTEXTO: [o que estava tentando fazer]
```

### Para Nova Feature:
```
FEATURE: [descrição da funcionalidade]
ARQUIVOS ENVOLVIDOS: [liste arquivos que precisam mudança]
REQUISITOS: [requisitos específicos]
```

## 🚨 Regras Importantes

1. **SEMPRE** me forneça as credenciais se for uma nova sessão
2. **SEMPRE** cole o estado atual antes de pedir algo
3. **NUNCA** assuma que eu lembro de sessões anteriores
4. **SEMPRE** seja específico sobre qual serviço/versão está com problema

## 💡 Exemplo de Retroalimentação Ideal

```
CONTEXTO: Projeto FIAP-X v2.4, todos os serviços rodando, testando upload de arquivos .mkv

CREDENCIAIS: SSH ubuntu@worker.wecando.click (keyPrincipal.pem), Docker hmoraes/Ch@plinh45

PROBLEMA: Upload ainda rejeitando arquivos .mkv com erro "formato não suportado"

ESTADO: Frontend v2.4 deployado com tipos MIME expandidos, preciso verificar qual tipo específico está sendo detectado pelo navegador

PRÓXIMO PASSO: Analisar logs do console do navegador para identificar tipo MIME exato
```

---
**Mantenha este arquivo sempre atualizado quando o projeto evoluir!**
