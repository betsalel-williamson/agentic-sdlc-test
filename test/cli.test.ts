import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import pkg from '../package.json' with { type: 'json' };

const CLI = fileURLToPath(new URL('../src/cli.js', import.meta.url));

interface Result {
  status: number | null;
  stdout: string;
  stderr: string;
}

/** Drive the real binary; exit codes and stream routing only exist here. */
function run(...args: string[]): Result {
  const r = spawnSync(process.execPath, [CLI, ...args], { encoding: 'utf8' });
  return { status: r.status, stdout: r.stdout, stderr: r.stderr };
}

describe('hello CLI', () => {
  // Requirement: Greet a named person
  it('greets a single name on stdout and exits 0', () => {
    const r = run('World');
    assert.equal(r.status, 0);
    assert.equal(r.stdout, 'Hello, World!\n');
    assert.equal(r.stderr, '');
  });

  it('greets a quoted name containing spaces', () => {
    const r = run('Ada Lovelace');
    assert.equal(r.status, 0);
    assert.equal(r.stdout, 'Hello, Ada Lovelace!\n');
  });

  it('greets a non-ASCII name', () => {
    const r = run('世界');
    assert.equal(r.status, 0);
    assert.equal(r.stdout, 'Hello, 世界!\n');
  });

  // Requirement: Reject a missing name
  it('exits 1 with usage on stderr when no name is given', () => {
    const r = run();
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /a name is required/);
    assert.match(r.stderr, /Usage: hello <name>/);
  });

  // Requirement: Reject an empty name
  it('exits 1 when the name is an empty string', () => {
    const r = run('');
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /empty/);
  });

  it('exits 1 when the name is only whitespace', () => {
    const r = run('   ');
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /empty/);
  });

  // Requirement: Reject more than one name
  it('exits 1 naming the count when two names are given', () => {
    const r = run('Ada', 'Grace');
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /expected exactly one name, but received 2/);
  });

  // Requirement: Reject unknown options
  it('exits 1 on an undefined option rather than greeting it', () => {
    const r = run('--shout', 'Ada');
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /shout/);
    assert.doesNotMatch(r.stderr, /at Object\./); // no raw stack trace
  });

  // Requirement: Report usage on request
  it('prints usage to stdout and exits 0 for --help', () => {
    const r = run('--help');
    assert.equal(r.status, 0);
    assert.equal(r.stderr, '');
    assert.match(r.stdout, /Usage: hello <name>/);
    assert.match(r.stdout, /--version/);
  });

  it('lets --help win over otherwise-invalid arguments', () => {
    const r = run('--help', 'Ada', 'Grace');
    assert.equal(r.status, 0);
    assert.match(r.stdout, /Usage: hello <name>/);
  });

  // Requirement: Report its version
  it('prints the manifest version for --version and exits 0', () => {
    const r = run('--version');
    assert.equal(r.status, 0);
    assert.equal(r.stderr, '');
    assert.equal(r.stdout, `${pkg.version}\n`);
  });

  // Requirement: Keep diagnostics off stdout
  it('writes nothing to stdout when the invocation fails', () => {
    for (const args of [[], [''], ['Ada', 'Grace'], ['--shout']]) {
      const r = run(...args);
      assert.equal(r.status, 1);
      assert.equal(
        r.stdout,
        '',
        `stdout should be empty for ${args.join(' ')}`
      );
      assert.notEqual(r.stderr, '');
    }
  });

  it('accepts the short flags -h and -v', () => {
    assert.equal(run('-h').status, 0);
    assert.equal(run('-v').stdout, `${pkg.version}\n`);
  });
});
