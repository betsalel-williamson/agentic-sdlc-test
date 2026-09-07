import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { greet, UsageError } from '../src/greet.js';

describe('greet', () => {
  // Requirement: Greet a named person
  it('greets a single name', () => {
    assert.equal(greet('World'), 'Hello, World!');
  });

  it('preserves internal spaces in a name', () => {
    assert.equal(greet('Ada Lovelace'), 'Hello, Ada Lovelace!');
  });

  it('preserves non-ASCII characters', () => {
    assert.equal(greet('世界'), 'Hello, 世界!');
  });

  it('preserves surrounding spaces once the name is non-empty', () => {
    // The spec rejects whitespace-ONLY names; it does not trim a real one.
    assert.equal(greet(' Ada '), 'Hello,  Ada !');
  });

  // Requirement: Reject an empty name
  it('rejects the empty string', () => {
    assert.throws(() => greet(''), UsageError);
  });

  it('rejects a whitespace-only name', () => {
    assert.throws(() => greet('   '), UsageError);
  });

  it('rejects a name of only tabs and newlines', () => {
    assert.throws(() => greet('\t\n'), UsageError);
  });
});
