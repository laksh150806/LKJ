import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeName, authMessage } from '../src/auth-validation.js';
test('preferred names support Tamil, spaces and length limits', () => {
 assert.equal(normalizeName('  Laksh   Kumar  '), 'Laksh Kumar');
 assert.equal(normalizeName('குமார்'), 'குமார்');
 assert.throws(() => normalizeName('   '));
 assert.throws(() => normalizeName('x'.repeat(81)));
});
test('auth failures are actionable without leaking provider internals', () => {
 assert.match(authMessage({status:429}), /wait a minute/);
 assert.match(authMessage({code:'otp_expired'}), /expired or is invalid/);
 assert.match(authMessage({message:'secret server data'}), /could not complete sign-in/);
 assert.doesNotMatch(authMessage({message:'secret server data'}), /secret/);
});
