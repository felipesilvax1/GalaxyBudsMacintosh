# App Store Connect — Instruções de Renomeação para "Buds Connect"

> **Contexto:** Estas mudanças resolvem as rejeições da Apple:
> - **Guideline 5.2.5** — "Mac" no nome viola trademark da Apple
> - **Guideline 4.1(c)** — "Galaxy Buds" caracteriza copycat da Samsung

---

## ⚠️ ATENÇÃO ANTES DE COMEÇAR

- **NÃO mude o Bundle ID** (`tech.miguellabs.GalaxyBudsMac`). Mudar o Bundle ID desvincula updates de usuários existentes — isso quebraria a continuidade da app na App Store.
- Estas alterações no App Store Connect são **independentes** do código. Você pode fazer as mudanças no portal antes ou depois de submeter o novo build.
- O App Store Connect leva até **24h** para propagar o novo nome após aprovação.

---

## Passo 1 — Acessar o App Store Connect

1. Acesse [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Faça login com seu Apple ID de desenvolvedor
3. Clique em **"My Apps"**
4. Selecione o app **GalaxyBudsMac**

---

## Passo 2 — Mudar o Nome do App (App Name)

> Localização: **App Store → Informações do App Store → Nome**

1. No menu lateral esquerdo, selecione **"App Store"**
2. Escolha a versão correta (ex: 1.1 ou a que estiver em draft/preparação)
3. No campo **"Nome"** (App Name), substitua pelo novo nome:

   ```
   Buds Connect
   ```

4. ⚠️ O nome do app na App Store tem limite de **30 caracteres**.
5. Este nome é único por país — se quiser variações por localização, faça por idioma.

---

## Passo 3 — Atualizar o Subtitle (Subtítulo)

> Localização: **App Store → Informações do App Store → Subtítulo**

O subtítulo aparece abaixo do nome na App Store (limite: 30 caracteres).

**Sugestão de subtítulo:**
```
Galaxy Buds Manager for Mac
```

> **Nota:** O uso de "Galaxy Buds" no *subtítulo* é aceitável desde que não implique afiliação com a Samsung. Adicione no campo de "Notas de Revisão" da submissão: *"'Galaxy Buds' no subtítulo descreve a funcionalidade do app, não implica relação com a Samsung."*

---

## Passo 4 — Atualizar Keywords (Palavras-chave)

> Localização: **App Store → Informações do App Store → Palavras-chave**

Remova qualquer keyword que contenha somente "GalaxyBudsMac" ou "Galaxy Buds Mac". Adicione:

```
galaxy buds, bluetooth earbuds, buds battery, noise control, samsung buds, earbuds manager, bluetooth manager
```

> **Limite:** 100 caracteres por idioma (incluindo vírgulas).

---

## Passo 5 — Atualizar a Descrição

> Localização: **App Store → Informações do App Store → Descrição**

Na descrição, substitua qualquer referência ao nome antigo "GalaxyBudsMac" por **"Buds Connect"**.

**Exemplo de ajuste no início da descrição:**
- ❌ `GalaxyBudsMac é o companheiro perfeito...`
- ✅ `Buds Connect é o companheiro perfeito para seus Galaxy Buds no Mac.`

---

## Passo 6 — Atualizar o Promotional Text (opcional)

> Localização: **App Store → Informações do App Store → Promotional Text**

O Promotional Text pode ser alterado **a qualquer momento sem nova submissão de build**.

**Sugestão:**
```
Controle seus Galaxy Buds direto da barra de menus do Mac. Bateria, ANC e muito mais.
```

---

## Passo 7 — Submeter um Novo Build

Após as mudanças de metadata no App Store Connect:

1. Faça o build do app no Xcode com as alterações de código já feitas (o CFBundleDisplayName agora é "Buds Connect")
2. Archive o app: **Product → Archive**
3. Faça o upload via **Xcode Organizer** ou **Transporter**
4. No App Store Connect, associe o novo build à versão
5. Adicione **Notas de Revisão** para o time da Apple:

```
Notes for App Review:

We have renamed the app from "GalaxyBudsMac" to "Buds Connect" to comply with:
- Guideline 5.2.5: Removed "Mac" from the display name. The bundle ID (tech.miguellabs.GalaxyBudsMac) must remain unchanged to preserve update continuity for existing users, as per Apple's guidelines.
- Guideline 4.1(c): The new name "Buds Connect" does not reference Samsung's "Galaxy Buds" trademark. References to "Galaxy Buds" in the subtitle and description are functional descriptors of the device compatibility, not claims of affiliation with Samsung.

The app is a third-party companion app for Samsung Galaxy Buds and uses only publicly documented Bluetooth protocols.
```

---

## Checklist Final

- [ ] Nome do app alterado para **"Buds Connect"** no App Store Connect
- [ ] Subtítulo atualizado
- [ ] Keywords atualizadas (sem "GalaxyBudsMac")
- [ ] Descrição atualizada (sem "GalaxyBudsMac")
- [ ] Novo build feito com CFBundleDisplayName = "Buds Connect" no Xcode
- [ ] Build submetido e associado à versão
- [ ] Notas de revisão adicionadas explicando as mudanças

---

## O que NÃO mudar

| Item | Valor | Motivo |
|------|-------|--------|
| Bundle ID | tech.miguellabs.GalaxyBudsMac | Mudar desvincula updates existentes |
| Nome do target Xcode | GalaxyBudsMac | Pode causar erros de build |
| Nomes de classe Swift | GalaxyBudsApp, etc. | Apenas código interno, invisível ao usuário |
| Widget Bundle ID | tech.miguellabs.GalaxyBudsMac.BudsOnMacWidget | Derivado do Bundle ID principal |
