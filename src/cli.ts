#!/usr/bin/env node
import { parseArgs } from 'node:util';
import pkg from '../package.json' with { type: 'json' };
import { greet, UsageError } from './greet.js';

const USAGE = `Usage: hello <name>

Print a greeting for the given name.

Arguments:
  <name>         The name to greet. Exactly one is required.

Options:
  -h, --help     Show this help and exit.
  -v, --version  Show the version and exit.`;

/** A write target, so tests can capture output without touching the process. */
export type Write = (line: string) => void;

/**
 * Run the CLI over `argv` (already stripped of node and the script path) and
 * return the process exit code.
 *
 * Branch order matters: --help wins over any other argument, including an
 * invalid one, so help is always reachable.
 */
export function run(argv: readonly string[], out: Write, err: Write): number {
  let values: { help?: boolean; version?: boolean };
  let positionals: string[];

  try {
    ({ values, positionals } = parseArgs({
      args: [...argv],
      options: {
        help: { type: 'boolean', short: 'h' },
        version: { type: 'boolean', short: 'v' },
      },
      allowPositionals: true,
    }));
  } catch (cause) {
    // parseArgs throws ERR_PARSE_ARGS_UNKNOWN_OPTION for undefined options.
    // Report it as usage, not as an unhandled stack trace.
    const message = cause instanceof Error ? cause.message : String(cause);
    err(`${message}\n\n${USAGE}`);
    return 1;
  }

  if (values.help === true) {
    out(USAGE);
    return 0;
  }

  if (values.version === true) {
    out(pkg.version);
    return 0;
  }

  if (positionals.length === 0) {
    err(`a name is required\n\n${USAGE}`);
    return 1;
  }

  if (positionals.length > 1) {
    err(
      `expected exactly one name, but received ${positionals.length}\n\n${USAGE}`
    );
    return 1;
  }

  const name = positionals[0] ?? '';

  try {
    out(greet(name));
    return 0;
  } catch (cause) {
    if (cause instanceof UsageError) {
      err(`${cause.message}\n\n${USAGE}`);
      return 1;
    }
    throw cause;
  }
}

process.exitCode = run(
  process.argv.slice(2),
  (line) => process.stdout.write(`${line}\n`),
  (line) => process.stderr.write(`${line}\n`)
);
