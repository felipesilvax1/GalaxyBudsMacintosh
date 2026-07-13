# Plano de Ação — App Store Connect

**App:** GalaxyBudsMac → **Buds Connect**  
**Submission ID:** `aa266298-c95f-4d42-b504-852e540031d9`  
**Data:** 13 de julho de 2026

---

## Status das Rejeições

| Guideline | Descrição | Status |
|---|---|---|
| **5.2.5** | Uso de marca "Mac" (propriedade da Apple) no nome do app | ✅ Corrigido automaticamente — renomear para "Buds Connect" |
| **4.1(c)** | Nome do app muito genérico / sem diferenciação suficiente | ✅ Corrigido automaticamente — novo nome resolve |
| **5.2.1** | Conteúdo Galaxy Buds sem autorização da Samsung | ⚠️ Requer resposta manual ao App Review |
| **1.5** | Support URL quebrada (link antigo não funciona) | ⚠️ Requer atualização manual da URL no App Store Connect |

---

## Ações Manuais no App Store Connect

1. **Mudar o nome do app para "Buds Connect"**  
   - Em App Store Connect → Meu App → Informações do App → Nome  
   - Remover qualquer menção a "Mac" e "Galaxy" do nome público

2. **Atualizar a Support URL**  
   - Em App Store Connect → Meu App → Informações do App → Support URL  
   - Novo valor: `https://github.com/felipesilvax1/GalaxyBudsMacintosh`  
   - (A página de suporte detalhada está em `docs/support.md` neste repositório)

3. **Responder ao App Review sobre o Guideline 5.2.1**  
   - Em App Store Connect → Meu App → Atividade → App Review Information → Reply to App Review  
   - Colar o texto completo do arquivo [`appstore_521_response.md`](./appstore_521_response.md)

4. **Fazer novo build no Xcode**  
   - Abrir o projeto no Xcode
   - Incrementar o **Build Number** em Project → Target → General → Identity (ex: de `1` para `2`)
   - Verificar que `CFBundleDisplayName` está como `Buds Connect` no `Info.plist`
   - Confirmar que o **Bundle Identifier permanece inalterado**: `tech.miguellabs.GalaxyBudsMac`
   - Ir em **Product → Archive** e aguardar a geração do archive

5. **Enviar o novo build pelo Xcode Organizer**  
   - Na janela do Organizer, selecionar o archive recém-criado
   - Clicar em **Distribute App → App Store Connect → Upload**
   - Aguardar o processamento (geralmente 10–30 minutos)

6. **Selecionar o novo build no App Store Connect e reenviar para Review**  
   - Em App Store Connect → Meu App → Versão macOS → Build  
   - Selecionar o novo build enviado
   - Clicar em **"Submit for Review"** (ou "Resubmit for Review")

---

## Checklist de Verificação Pré-Envio

### App Store Connect
- [ ] Nome do app = **"Buds Connect"** (sem "Mac", sem "Galaxy")
- [ ] Support URL = `https://github.com/felipesilvax1/GalaxyBudsMacintosh`
- [ ] Resposta ao Guideline 5.2.1 postada no campo "Reply to App Review"
- [ ] Novo build selecionado na versão de envio

### Xcode / Info.plist
- [ ] `CFBundleDisplayName` = `Buds Connect`
- [ ] `CFBundleName` = `BudsConnect` (sem espaços, usado internamente)
- [ ] **Bundle Identifier NÃO alterado**: `tech.miguellabs.GalaxyBudsMac`
- [ ] **Build Number incrementado** (ex: 1 → 2)
- [ ] **Version Number** mantido ou atualizado conforme necessário

### Repositório GitHub
- [ ] `DISCLAIMER.md` adicionado ao repositório
- [ ] Seção `## Disclaimer` adicionada ao `README.md`
- [ ] `docs/support.md` publicada e acessível no repositório
- [ ] Commits feitos com `git push` para que a Support URL esteja ativa

---

## Timeline Esperada

| Etapa | Tempo Estimado |
|---|---|
| Ações manuais no App Store Connect | 30–60 minutos |
| Processamento do novo build | 10–30 minutos |
| Revisão pela Apple após reenvio | **24–48 horas** |

> **Nota:** Se a Apple responder com novas perguntas sobre o Guideline 5.2.1, forneça links diretos para o código-fonte no GitHub e para os arquivos `DISCLAIMER.md` e `appstore_521_response.md` como evidências adicionais.

---

## Arquivos Criados Nesta Sprint

| Arquivo | Descrição |
|---|---|
| [`appstore_521_response.md`](./appstore_521_response.md) | Resposta profissional para o App Review (Guideline 5.2.1) |
| [`DISCLAIMER.md`](./DISCLAIMER.md) | Disclaimer legal completo (non-affiliation, GPLv3, uso por conta e risco) |
| [`README.md`](./README.md) | Atualizado — nova seção `## Disclaimer` adicionada |
| [`docs/support.md`](./docs/support.md) | Página de suporte completa (Getting Started, Troubleshooting, FAQ, Contact) |
| [`APPSTORE_ACTION_PLAN.md`](./APPSTORE_ACTION_PLAN.md) | Este arquivo — checklist e plano de ação |
