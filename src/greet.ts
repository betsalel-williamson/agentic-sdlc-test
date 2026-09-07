/** Raised when the caller's arguments are wrong, as opposed to a bug. */
export class UsageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UsageError';
  }
}

/**
 * Build the greeting for `name`.
 *
 * The name is reproduced verbatim — internal spacing, casing and non-ASCII
 * characters are preserved. Only whitespace-only and empty names are rejected,
 * since `Hello, !` is not a greeting.
 */
export function greet(name: string): string {
  if (name.trim() === '') {
    throw new UsageError('a name is required, but the name given was empty');
  }
  return `Hello, ${name}!`;
}
