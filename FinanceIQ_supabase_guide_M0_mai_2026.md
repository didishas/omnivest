# FinanceIQ — Intégration Supabase

## 1. Pourquoi Supabase ?
Oui, Supabase est adapté pour synchroniser cette app entre téléphone et PC :
- Authentification email/mot de passe.
- Base PostgreSQL.
- Row Level Security pour que chaque utilisateur ne voie que ses propres finances.
- Realtime pour rafraîchir téléphone et PC quand une donnée change.

## 2. Fichiers
- `FinanceIQ_corrige_date_2026.html` : version corrigée côté date.
- `FinanceIQ_supabase_schema.sql` : tables + sécurité RLS.

## 3. Étapes Supabase
1. Créer un projet Supabase.
2. Aller dans SQL Editor.
3. Coller le contenu de `FinanceIQ_supabase_schema.sql`.
4. Activer Auth > Email provider.
5. Récupérer :
   - Project URL
   - Publishable key / anon key
6. Ne jamais mettre la `service_role key` dans le navigateur.

## 4. Exemple client JavaScript pour une app HTML simple

À placer avant ton `</body>` si tu veux convertir l'app localStorage vers Supabase :

```html
<script type="module">
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'

const SUPABASE_URL = 'https://TON-PROJET.supabase.co'
const SUPABASE_KEY = 'TA_PUBLISHABLE_KEY'
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  return data.user
}

async function loadCloudState() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return null

  const { data, error } = await supabase
    .from('finance_state')
    .select('*')
    .eq('user_id', user.id)
    .single()

  if (error && error.code !== 'PGRST116') throw error
  return data
}

async function saveCloudState() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  const payload = {
    user_id: user.id,
    revenues,
    ibkr_total: ibkrBalance.total,
    ibkr_pnl: ibkrBalance.pnl,
    invested_this_month: investedThisMonth,
    debt_huissier: debtHuissier,
    debt_onem: debtOnem,
    real_capital: realCapital,
    current_month: currentMonth,
    manual_plan_month: manualPlanMonth,
    plan_start_date: PLAN_START_DATE
  }

  const { error } = await supabase
    .from('finance_state')
    .upsert(payload, { onConflict: 'user_id' })

  if (error) throw error
}

async function addCloudExpense(expense) {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  const { error } = await supabase.from('finance_expenses').insert({
    user_id: user.id,
    name: expense.name,
    amt: expense.amt,
    cat: expense.cat,
    expense_date: expense.date
  })

  if (error) throw error
}

async function loadCloudExpenses() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return []

  const { data, error } = await supabase
    .from('finance_expenses')
    .select('*')
    .eq('user_id', user.id)
    .order('expense_date', { ascending: false })

  if (error) throw error

  return data.map(e => ({
    name: e.name,
    amt: Number(e.amt),
    cat: e.cat,
    date: e.expense_date,
    cloudId: e.id
  }))
}

// Sync temps réel : quand PC modifie, téléphone reçoit, et inversement.
async function startRealtimeSync() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  supabase
    .channel('financeiq-sync-' + user.id)
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'finance_state',
      filter: 'user_id=eq.' + user.id
    }, async () => {
      const cloud = await loadCloudState()
      if (cloud) {
        revenues = cloud.revenues
        ibkrBalance = { total: Number(cloud.ibkr_total), pnl: Number(cloud.ibkr_pnl) }
        investedThisMonth = Number(cloud.invested_this_month)
        debtHuissier = Number(cloud.debt_huissier)
        debtOnem = Number(cloud.debt_onem)
        realCapital = Number(cloud.real_capital)
        currentMonth = Number(cloud.current_month)
        manualPlanMonth = cloud.manual_plan_month
        renderDashboard()
        renderBilan()
        renderProjection()
      }
    })
    .on('postgres_changes', {
      event: '*',
      schema: 'public',
      table: 'finance_expenses',
      filter: 'user_id=eq.' + user.id
    }, async () => {
      expenses = await loadCloudExpenses()
      renderExpenses()
      renderBilan()
      renderDashboard()
    })
    .subscribe()
}
</script>
```

## 5. Important
Pour une app exposée publiquement, garde seulement la publishable/anon key dans le front. La service_role key doit rester côté serveur uniquement.


## Correction spécifique M0 = mai 2026

Dans cette version, le plan financier commence en mai 2026 :

- M0 = mai 2026
- M1 = juin 2026
- M2 = juillet 2026
- M3 = août 2026

La constante utilisée dans l'app est :

```js
const PLAN_START_DATE = '2026-05-01';
```

Si le navigateur avait déjà sauvegardé une ancienne projection dans `localStorage`, l'app ignore automatiquement l'ancien mois si `planStartDate` ne correspond plus au nouveau départ.
