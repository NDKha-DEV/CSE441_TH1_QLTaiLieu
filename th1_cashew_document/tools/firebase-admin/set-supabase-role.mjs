import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';
import process from 'node:process';

export const EXPECTED_PROJECT_ID = 'mobileth1qltailieu';
export const ALLOWED_UID_COUNTS = [1, 3];
export const CONFIRMATION_TEXT =
  `APPLY role=authenticated project=${EXPECTED_PROJECT_ID}`;

export function parseArgs(args) {
  let projectId;
  let mode = 'dry-run';
  let modeWasSet = false;
  let nonInteractiveConfirmation = false;
  const uids = [];

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];

    if (argument === '--project') {
      if (projectId !== undefined) {
        throw new Error('--project must be supplied exactly once.');
      }
      projectId = args[++index];
      if (!projectId || projectId.startsWith('--')) {
        throw new Error('--project requires a project ID.');
      }
    } else if (argument === '--uid') {
      const uid = args[++index];
      if (uid === undefined || uid.startsWith('--')) {
        throw new Error('Each --uid must be followed by a Firebase UID.');
      }
      uids.push(uid);
    } else if (argument === '--dry-run' || argument === '--apply') {
      if (modeWasSet) {
        throw new Error('Choose exactly one of --dry-run or --apply.');
      }
      mode = argument === '--apply' ? 'apply' : 'dry-run';
      modeWasSet = true;
    } else if (argument === '--yes') {
      if (nonInteractiveConfirmation) {
        throw new Error('--yes must be supplied at most once.');
      }
      nonInteractiveConfirmation = true;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }

  if (projectId === undefined) {
    throw new Error('--project is required.');
  }
  if (projectId !== EXPECTED_PROJECT_ID) {
    throw new Error(
      `Refusing project "${projectId}"; expected "${EXPECTED_PROJECT_ID}".`,
    );
  }
  if (!ALLOWED_UID_COUNTS.includes(uids.length)) {
    throw new Error('Supply exactly 1 UID or exactly 3 UIDs.');
  }
  if (uids.some((uid) => uid.length === 0 || uid.trim() !== uid || uid.length > 128)) {
    throw new Error('UIDs must be non-empty, unpadded strings of at most 128 characters.');
  }
  if (new Set(uids).size !== uids.length) {
    throw new Error('Duplicate UIDs are not allowed.');
  }
  if (nonInteractiveConfirmation && mode !== 'apply') {
    throw new Error('--yes can only be used together with --apply.');
  }
  if (nonInteractiveConfirmation && uids.length !== 1) {
    throw new Error('--yes requires exactly one --uid.');
  }

  return { projectId, mode, uids, nonInteractiveConfirmation };
}

export function mergeRoleClaim(customClaims) {
  return { ...customClaims, role: 'authenticated' };
}

export class ClaimUpdateError extends Error {
  constructor({
    stage,
    failedUids = [],
    updatedUids = [],
    notAttemptedUids = [],
    outcomeUnknownUid,
    cause,
  }) {
    super(`Firebase custom-claim operation failed during ${stage}.`, { cause });
    this.name = 'ClaimUpdateError';
    this.stage = stage;
    this.failedUids = failedUids;
    this.updatedUids = updatedUids;
    this.notAttemptedUids = notAttemptedUids;
    this.outcomeUnknownUid = outcomeUnknownUid;
    this.code = typeof cause?.code === 'string' ? cause.code : undefined;
  }
}

function validateClaimsSize(claims) {
  const serializedClaims = JSON.stringify(claims);
  if (Buffer.byteLength(serializedClaims, 'utf8') > 1000) {
    throw new Error(
      'Merged custom claims exceed Firebase’s 1000-byte limit; no claims were changed.',
    );
  }
}

export async function applyRoleClaim(auth, uids) {
  const lookups = await Promise.allSettled(uids.map((uid) => auth.getUser(uid)));
  const failedLookups = lookups.flatMap((result, index) =>
    result.status === 'rejected' ? [{ uid: uids[index], cause: result.reason }] : [],
  );

  if (failedLookups.length > 0) {
    throw new ClaimUpdateError({
      stage: 'user lookup',
      failedUids: failedLookups.map(({ uid }) => uid),
      notAttemptedUids: uids,
      cause: failedLookups[0].cause,
    });
  }

  const updates = lookups.map((result, index) => ({
    uid: uids[index],
    user: result.value,
  })).map(({ uid, user }) => ({
    uid,
    claims: mergeRoleClaim(user.customClaims ?? {}),
  }));

  try {
    for (const update of updates) {
      validateClaimsSize(update.claims);
    }
  } catch (cause) {
    throw new ClaimUpdateError({
      stage: 'claim validation',
      notAttemptedUids: uids,
      cause,
    });
  }

  const updatedUids = [];
  for (const [index, update] of updates.entries()) {
    try {
      await auth.setCustomUserClaims(update.uid, update.claims);
      updatedUids.push(update.uid);
    } catch (cause) {
      throw new ClaimUpdateError({
        stage: 'claim update',
        failedUids: [update.uid],
        updatedUids,
        notAttemptedUids: updates.slice(index + 1).map(({ uid }) => uid),
        outcomeUnknownUid: update.uid,
        cause,
      });
    }
  }

  return updatedUids;
}

function printSelection({ projectId, uids, mode }) {
  console.log(`Firebase project: ${projectId}`);
  console.log('Selected Firebase UIDs:');
  for (const uid of uids) {
    console.log(`  - ${uid}`);
  }

  if (mode === 'dry-run') {
    console.log('Dry run only: no Firebase account was read or changed.');
    return;
  }

  console.log(`Target custom claim: role=authenticated`);
}

async function confirmApply() {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    throw new Error('--apply requires an interactive terminal for confirmation.');
  }

  const readline = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  try {
    const answer = await readline.question(
      `Type "${CONFIRMATION_TEXT}" to continue: `,
    );
    return answer === CONFIRMATION_TEXT;
  } finally {
    readline.close();
  }
}

async function main(args) {
  const options = parseArgs(args);
  printSelection(options);

  if (options.mode === 'dry-run') {
    return;
  }
  if (!options.nonInteractiveConfirmation && !(await confirmApply())) {
    throw new Error('Confirmation did not match; no claims were changed.');
  }

  const { applicationDefault, initializeApp } = await import(
    'firebase-admin/app'
  );
  const { getAuth } = await import('firebase-admin/auth');
  const app = initializeApp({
    credential: applicationDefault(),
    projectId: options.projectId,
  });

  try {
    const updatedUids = await applyRoleClaim(getAuth(app), options.uids);
    console.log(`Updated role claim for ${updatedUids.length} Firebase users.`);
    for (const uid of updatedUids) {
      console.log(`  Updated: ${uid}`);
    }
  } catch (error) {
    const code = typeof error?.code === 'string' ? ` (code: ${error.code})` : '';
    if (error instanceof ClaimUpdateError) {
      console.error(`Firebase operation failed during ${error.stage}${code}.`);
      if (error.updatedUids.length > 0) {
        console.error(`Confirmed updated: ${error.updatedUids.join(', ')}`);
      }
      if (error.outcomeUnknownUid) {
        console.error(
          `Update outcome unknown for ${error.outcomeUnknownUid}; check Firebase before retrying.`,
        );
      }
      if (error.failedUids.length > 0) {
        console.error(`Failed to process: ${error.failedUids.join(', ')}`);
      }
      if (error.notAttemptedUids.length > 0) {
        console.error(`Not attempted: ${error.notAttemptedUids.join(', ')}`);
      }
      if (error.updatedUids.length === 0 && !error.outcomeUnknownUid) {
        console.error('No claims were written.');
      }
    } else {
      console.error(
        `Firebase Admin setup failed${code}. No credentials or tokens were logged.`,
      );
    }
    process.exitCode = 1;
  } finally {
    await app.delete();
  }
}

export function usage() {
  return [
    'Usage:',
    '  node set-supabase-role.mjs --project mobileth1qltailieu --uid <uid> [--dry-run|--apply [--yes]]',
    '  node set-supabase-role.mjs --project mobileth1qltailieu --uid <uid-1> --uid <uid-2> --uid <uid-3> [--dry-run|--apply]',
    '',
    'Dry-run is the default. --apply requires interactive confirmation unless --yes is used for exactly one UID.',
  ].join('\n');
}

const invokedPath = process.argv[1]
  ? pathToFileURL(resolve(process.argv[1])).href
  : null;
if (invokedPath === import.meta.url) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    console.error(usage());
    process.exitCode = 1;
  });
}
