# Plano de Ação — App Store Connect

**App:** GalaxyBudsMac → **Buds Connect**  
**Submission ID:** `aa266298-c95f-4d42-b504-852e540031d9`  
**Data:** 13 de julho de 2026

---

## Status das Rejeições e Resolução

| Guideline | Descrição | Status |
|---|---|---|
| **5.2.5** | Uso de marca "Mac" (propriedade da Apple) no nome do app | ✅ Concluído (Renomeado para "Buds Connect" no projeto e App Store Connect) |
| **4.1(c)** | Nome do app muito genérico / sem diferenciação suficiente | ✅ Concluído (Nome alterado para "Buds Connect") |
| **5.2.1** | Conteúdo Galaxy Buds sem autorização da Samsung | ✅ Concluído (Apelação legal e disclaimer enviados via App Review) |
| **1.5** | Support URL quebrada (link antigo não funciona) | ✅ Concluído (URLs de suporte e marketing limpas e apontando para o GitHub) |

---

## Ações Automatizadas e Executadas pelo Agente

1. **Mudar o nome do app para "Buds Connect"**  
   - Concluído em App Store Connect → Informações do App.
   - Renomeado localmente em `project.pbxproj` (`INFOPLIST_KEY_CFBundleDisplayName`).

2. **Atualizar a Support URL e Marketing URL**  
   - Support URL atualizada para: `https://github.com/felipesilvax1/GalaxyBudsMacintosh/blob/master/docs/support.md`
   - Marketing URL atualizada para: `https://github.com/felipesilvax1/GalaxyBudsMacintosh`

3. **Responder ao App Review sobre o Guideline 5.2.1**  
   - Apelação profissional com base nos disclaimers e open-source (RFCOMM/SPP) colada e submetida na Central de Resoluções.

4. **Gerar novo build**  
   - Incrementado build number de `1` para `2`.
   - Gerado o pacote `.pkg` assinado e enviado via pipeline Fastlane para o App Store Connect.

5. **Substituir o build e reenviar para revisão**  
   - Build anterior `1.0 (1)` removido da submissão.
   - Novo build `1.0 (2)` selecionado na versão do App.
   - Questionário de exportação de criptografia respondido ("None of the algorithms...").
   - App reenviado com sucesso para a Apple. O status atual do App Store Connect é **"Waiting for Review"** (Aguardando Revisão).

---

## Checklist de Verificação Realizado

### App Store Connect
- [x] Nome do app = **"Buds Connect"** (sem "Mac", sem "Galaxy")
- [x] Support URL = `https://github.com/felipesilvax1/GalaxyBudsMacintosh/blob/master/docs/support.md`
- [x] Marketing URL = `https://github.com/felipesilvax1/GalaxyBudsMacintosh`
- [x] Resposta ao Guideline 5.2.1 postada no campo "Reply to App Review"
- [x] Novo build `1.0 (2)` selecionado e configurado (Export Compliance resolvido)
- [x] Botão **"Resubmit to App Review"** clicado

### Xcode / Info.plist
- [x] `CFBundleDisplayName` = `Buds Connect`
- [x] `CFBundleName` = `BudsConnect`
- [x] **Bundle Identifier NÃO alterado**: `tech.miguellabs.GalaxyBudsMac`
- [x] **Build Number incrementado** (de 1 para 2)

### Repositório GitHub
- [x] `DISCLAIMER.md` adicionado ao repositório
- [x] Seção `## Disclaimer` adicionada ao `README.md`
- [x] `docs/support.md` publicada e acessível no repositório
- [x] Commits enviados via `git push` para a branch master do GitHub

---

## Timeline Esperada

| Etapa | Status | Tempo Estimado / Real |
|---|---|---|
| Ações automáticas no App Store Connect | ✅ Executado | Concluído em minutos |
| Compilação e Envio do Build 2 (Fastlane) | ✅ Executado | Concluído em minutos |
| Revisão pela Apple após reenvio | ⏳ Pendente | **24–48 horas** |

---

## Arquivos Criados e Consolidados

| Arquivo | Descrição |
|---|---|
| [`appstore_521_response.md`](./appstore_521_response.md) | Resposta profissional para o App Review (Guideline 5.2.1) |
| [`DISCLAIMER.md`](./DISCLAIMER.md) | Disclaimer legal completo (non-affiliation, GPLv3, uso por conta e risco) |
| [`README.md`](./README.md) | Atualizado com disclaimer legal |
| [`docs/support.md`](./docs/support.md) | Página de suporte completa (FAQ, Troubleshooting, Contact) |
| [`APPSTORE_ACTION_PLAN.md`](./APPSTORE_ACTION_PLAN.md) | Este checklist de controle |
