export function normalizeName(value) {
  const name = String(value ?? '').trim().replace(/\s+/g, ' ');
  if (!name || [...name].length > 80) throw new Error('Enter a preferred name between 1 and 80 characters.');
  return name;
}
export function authMessage(error) {
  if (error.status === 429 || /rate_limit|over_email_send_rate_limit/.test(error.code || '')) return 'Please wait a minute before requesting another code.';
  if (/otp_expired|otp_disabled/.test(error.code || '')) return 'That code has expired or is invalid. Please request a new code.';
  if (/email_address_not_authorized|email_provider_disabled/.test(error.code || '')) return 'Email sign-in is not available yet. You can keep browsing.';
  return 'We could not complete sign-in. Check your details and try again.';
}
