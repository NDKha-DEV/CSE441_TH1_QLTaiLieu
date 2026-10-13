import test from 'node:test';
import assert from 'node:assert/strict';

import {
  EXPECTED_PROJECT_ID,
  ClaimUpdateError,
  applyRoleClaim,
  mergeRoleClaim,
  parseArgs,
} from './set-supabase-role.mjs';

const validArgs = [
  '--project',
  EXPECTED_PROJECT_ID,
  '--uid',
  'demo-user-one',
  '--uid',
  'demo-user-two',
  '--uid',
  'demo-user-three',
];

test('accepts exactly three distinct UIDs for the expected project', () => {
  const options = parseArgs(validArgs);

  assert.equal(options.projectId, EXPECTED_PROJECT_ID);
  assert.equal(options.mode, 'dry-run');
  assert.equal(options.uids.length, 3);
});

test('accepts exactly one UID for the expected project', () => {
  const options = parseArgs([
    '--project',
    EXPECTED_PROJECT_ID,
    '--uid',
    'current-demo-user',
  ]);

  assert.equal(options.projectId, EXPECTED_PROJECT_ID);
  assert.equal(options.mode, 'dry-run');
  assert.deepEqual(options.uids, ['current-demo-user']);
});

test('accepts explicit non-interactive confirmation for one UID only', () => {
  const options = parseArgs([
    '--project',
    EXPECTED_PROJECT_ID,
    '--uid',
    'current-demo-user',
    '--apply',
    '--yes',
  ]);

  assert.equal(options.mode, 'apply');
  assert.equal(options.nonInteractiveConfirmation, true);
  assert.deepEqual(options.uids, ['current-demo-user']);
});

test('requires one UID and --apply for non-interactive confirmation', () => {
  assert.throws(
    () =>
      parseArgs([
        '--project',
        EXPECTED_PROJECT_ID,
        '--apply',
        '--yes',
      ]),
    /exactly 1 UID or exactly 3 UIDs/,
  );
  assert.throws(
    () =>
      parseArgs([
        ...validArgs,
        '--apply',
        '--yes',
      ]),
    /--yes requires exactly one --uid/,
  );
  assert.throws(
    () =>
      parseArgs([
        '--project',
        EXPECTED_PROJECT_ID,
        '--uid',
        'current-demo-user',
        '--yes',
      ]),
    /--yes can only be used together with --apply/,
  );
});

test('rejects zero, two, or more than three UIDs', () => {
  for (const args of [
    ['--project', EXPECTED_PROJECT_ID],
    [
      '--project',
      EXPECTED_PROJECT_ID,
      '--uid',
      'demo-user-one',
      '--uid',
      'demo-user-two',
    ],
    [...validArgs.slice(0, -2), '--uid', 'demo-user-three', '--uid', 'extra'],
  ]) {
    assert.throws(() => parseArgs(args), /exactly 1 UID or exactly 3 UIDs/);
  }
});

test('rejects duplicate, empty, and padded UIDs', () => {
  assert.throws(
    () =>
      parseArgs([
        '--project',
        EXPECTED_PROJECT_ID,
        '--uid',
        'same',
        '--uid',
        'same',
        '--uid',
        'third',
      ]),
    /Duplicate UIDs/,
  );
  assert.throws(
    () => parseArgs([...validArgs.slice(0, 4), '--uid', '', ...validArgs.slice(6)]),
    /UID/,
  );
  assert.throws(
    () =>
      parseArgs([
        '--project',
        EXPECTED_PROJECT_ID,
        '--uid',
        ' one ',
        '--uid',
        'two',
        '--uid',
        'three',
      ]),
    /UIDs must/,
  );
});

test('rejects a missing or different project and conflicting modes', () => {
  assert.throws(() => parseArgs(validArgs.slice(2)), /--project is required/);
  assert.throws(
    () => parseArgs(['--project', 'another-project', ...validArgs.slice(2)]),
    /Refusing project/,
  );
  assert.throws(
    () => parseArgs([...validArgs, '--apply', '--dry-run']),
    /Choose exactly one/,
  );
});

test('merges the role claim without discarding existing claims', () => {
  const original = { featureFlag: true, nested: { tier: 2 }, role: 'old-role' };
  const merged = mergeRoleClaim(original);

  assert.deepEqual(merged, {
    featureFlag: true,
    nested: { tier: 2 },
    role: 'authenticated',
  });
  assert.equal(original.role, 'old-role');
});

test('reads all three users and preserves each user custom claims on update', async () => {
  const users = new Map([
    ['demo-user-one', { uid: 'demo-user-one', customClaims: { flag: true } }],
    ['demo-user-two', { uid: 'demo-user-two', customClaims: undefined }],
    ['demo-user-three', { uid: 'demo-user-three', customClaims: { level: 3 } }],
  ]);
  const reads = [];
  const writes = [];
  const auth = {
    async getUser(uid) {
      reads.push(uid);
      return users.get(uid);
    },
    async setCustomUserClaims(uid, claims) {
      writes.push({ uid, claims });
    },
  };

  const count = await applyRoleClaim(auth, [...users.keys()]);

  assert.equal(count.length, 3);
  assert.deepEqual(count, [...users.keys()]);
  assert.deepEqual(reads, [...users.keys()]);
  assert.deepEqual(writes, [
    {
      uid: 'demo-user-one',
      claims: { flag: true, role: 'authenticated' },
    },
    {
      uid: 'demo-user-two',
      claims: { role: 'authenticated' },
    },
    {
      uid: 'demo-user-three',
      claims: { level: 3, role: 'authenticated' },
    },
  ]);
});

test('single-UID update writes only the explicitly selected account', async () => {
  const reads = [];
  const writes = [];
  const auth = {
    async getUser(uid) {
      reads.push(uid);
      return { uid, customClaims: { keep: 'existing' } };
    },
    async setCustomUserClaims(uid, claims) {
      writes.push({ uid, claims });
    },
  };

  const updated = await applyRoleClaim(auth, ['selected-user']);

  assert.deepEqual(reads, ['selected-user']);
  assert.deepEqual(updated, ['selected-user']);
  assert.deepEqual(writes, [
    {
      uid: 'selected-user',
      claims: { keep: 'existing', role: 'authenticated' },
    },
  ]);
});

test('does not start writes if preflight cannot resolve all users', async () => {
  let writeCount = 0;
  const auth = {
    async getUser(uid) {
      if (uid === 'missing-user') {
        throw new Error('not found');
      }
      return { uid, customClaims: {} };
    },
    async setCustomUserClaims() {
      writeCount += 1;
    },
  };

  await assert.rejects(
    applyRoleClaim(auth, ['demo-user-one', 'missing-user', 'demo-user-three']),
    (error) => {
      assert.ok(error instanceof ClaimUpdateError);
      assert.equal(error.stage, 'user lookup');
      assert.deepEqual(error.failedUids, ['missing-user']);
      assert.deepEqual(error.updatedUids, []);
      assert.deepEqual(error.notAttemptedUids, [
        'demo-user-one',
        'missing-user',
        'demo-user-three',
      ]);
      return true;
    },
  );
  assert.equal(writeCount, 0);
});

test('does not start writes when merged claims exceed Firebase size limit', async () => {
  let writeCount = 0;
  const auth = {
    async getUser(uid) {
      return { uid, customClaims: { metadata: 'x'.repeat(1000) } };
    },
    async setCustomUserClaims() {
      writeCount += 1;
    },
  };

  await assert.rejects(
    applyRoleClaim(auth, ['demo-user-one', 'demo-user-two', 'demo-user-three']),
    (error) => {
      assert.ok(error instanceof ClaimUpdateError);
      assert.equal(error.stage, 'claim validation');
      assert.match(error.cause.message, /1000-byte limit/);
      assert.deepEqual(error.notAttemptedUids, [
        'demo-user-one',
        'demo-user-two',
        'demo-user-three',
      ]);
      return true;
    },
  );
  assert.equal(writeCount, 0);
});

for (const failedIndex of [1, 2]) {
  test(`reports partial updates accurately when UID ${failedIndex + 1} fails`, async () => {
    const uids = ['demo-user-one', 'demo-user-two', 'demo-user-three'];
    const attempted = [];
    const auth = {
      async getUser(uid) {
        return { uid, customClaims: { preserve: true } };
      },
      async setCustomUserClaims(uid) {
        attempted.push(uid);
        if (uid === uids[failedIndex]) {
          const error = new Error('simulated update failure');
          error.code = 'auth/internal-error';
          throw error;
        }
      },
    };

    await assert.rejects(applyRoleClaim(auth, uids), (error) => {
      assert.ok(error instanceof ClaimUpdateError);
      assert.equal(error.stage, 'claim update');
      assert.deepEqual(error.failedUids, [uids[failedIndex]]);
      assert.deepEqual(error.updatedUids, uids.slice(0, failedIndex));
      assert.deepEqual(error.notAttemptedUids, uids.slice(failedIndex + 1));
      assert.equal(error.outcomeUnknownUid, uids[failedIndex]);
      assert.equal(error.code, 'auth/internal-error');
      return true;
    });
    assert.deepEqual(attempted, uids.slice(0, failedIndex + 1));
  });
}
