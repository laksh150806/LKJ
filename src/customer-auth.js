import { createClient } from '@supabase/supabase-js';
import { normalizeName, authMessage } from './auth-validation.js';

export function createCustomerAuth(config) {
  const client = createClient(config.url, config.publishableKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, storageKey: 'lk-customer-auth' }
  });
  let state = { user: null, preferredName: '', admin: false, ready: false };
  let revision = 0;
  const listeners = new Set();
  const notify = () => listeners.forEach(listener => listener({ ...state }));
  let pendingRefresh = Promise.resolve();
  function refresh() {
    pendingRefresh = pendingRefresh.catch(() => {}).then(loadState);
    return pendingRefresh;
  }
  async function loadState() {
    const current = ++revision;
    const { data: { user }, error } = await client.auth.getUser();
    if (current !== revision) return;
    state = { user: null, preferredName: '', admin: false, ready: true };
    if (error || !user || !user.email_confirmed_at) { notify(); return; }
    const [profile, access] = await Promise.all([
      client.from('customer_profiles').select('preferred_name').eq('user_id', user.id).maybeSingle(),
      client.rpc('my_shop_access')
    ]);
    if (current !== revision) return;
    if (profile.error || access.error) { notify(); throw new Error('Your account could not be loaded. Please try again.'); }
    state = { user, preferredName: profile.data?.preferred_name || '', admin: access.data === true, ready: true };
    notify();
  }
  client.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') {
      revision++;
      state = { user: null, preferredName: '', admin: false, ready: true };
      notify();
    } else if (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN') {
      // Do not make awaited SDK calls inside the auth callback (it holds an auth lock).
      setTimeout(() => refresh().catch(() => {}), 0);
    }
  });
  return {
    get state() { return { ...state }; },
    subscribe(listener) { listeners.add(listener); return () => listeners.delete(listener); },
    refresh,
    async sendCode(email) {
      if (!config.emailOtpEnabled) throw new Error('Email sign-in is not available yet. You can keep browsing.');
      const { error } = await client.auth.signInWithOtp({ email: email.trim(), options: { shouldCreateUser: true } });
      if (error) throw new Error(authMessage(error));
    },
    async verifyCode(email, token) {
      const { error } = await client.auth.verifyOtp({ email: email.trim(), token: token.trim(), type: 'email' });
      if (error) throw new Error(authMessage(error));
      await refresh();
      if (!state.user) throw new Error('We could not verify your account. Please sign in again.');
    },
    async saveName(value) {
      const name = normalizeName(value);
      const expectedUser = state.user?.id;
      const { data: { user }, error: authError } = await client.auth.getUser();
      if (authError || !user || user.id !== expectedUser || !user.email_confirmed_at) throw new Error('Please sign in again before saving your name.');
      const { error } = await client.from('customer_profiles').upsert({ user_id: user.id, preferred_name: name }, { onConflict: 'user_id' });
      if (error) throw new Error('Your name could not be saved. Please try again.');
      await refresh();
    },
    async signOut() {
      const { error } = await client.auth.signOut({ scope: 'local' });
      if (error) throw new Error('Sign-out failed. Please try again.');
      revision++;
      state = { user: null, preferredName: '', admin: false, ready: true };
      notify();
    }
  };
}
