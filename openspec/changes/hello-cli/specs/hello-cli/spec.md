## Purpose

Defines the observable contract of the `hello` command: how it reads a name from
the command line, what it writes to stdout and stderr, and which exit status it
returns in each case.

## ADDED Requirements

### Requirement: Greet a named person

The command SHALL accept exactly one positional argument, the name, and SHALL
write `Hello, <name>!` followed by a newline to stdout, then exit with status 0.
The name SHALL be reproduced verbatim, including any internal spaces, casing,
and non-ASCII characters.

#### Scenario: A single name is supplied

- **WHEN** the command is run as `hello World`
- **THEN** stdout is `Hello, World!` followed by a newline
- **AND** stderr is empty
- **AND** the exit status is 0

#### Scenario: The name is a quoted string containing spaces

- **WHEN** the command is run as `hello "Ada Lovelace"`
- **THEN** stdout is `Hello, Ada Lovelace!` followed by a newline
- **AND** the exit status is 0

#### Scenario: The name contains non-ASCII characters

- **WHEN** the command is run as `hello 世界`
- **THEN** stdout is `Hello, 世界!` followed by a newline
- **AND** the exit status is 0

### Requirement: Reject a missing name

When no positional argument is supplied, the command SHALL write a usage message
to stderr and exit with status 1. It SHALL NOT write to stdout, and SHALL NOT
substitute a default name.

#### Scenario: No arguments at all

- **WHEN** the command is run as `hello`
- **THEN** stderr names the problem and shows the expected usage
- **AND** stdout is empty
- **AND** the exit status is 1

### Requirement: Reject an empty name

A name consisting only of whitespace, or of nothing at all, SHALL be treated as
missing: the command SHALL write a usage message to stderr and exit with
status 1. This prevents the meaningless output `Hello, !`.

#### Scenario: The name is an empty string

- **WHEN** the command is run as `hello ""`
- **THEN** stderr names the problem
- **AND** stdout is empty
- **AND** the exit status is 1

#### Scenario: The name is only whitespace

- **WHEN** the command is run as `hello "   "`
- **THEN** stderr names the problem
- **AND** stdout is empty
- **AND** the exit status is 1

### Requirement: Reject more than one name

The command greets exactly one person. When two or more positional arguments are
supplied, it SHALL write a usage message to stderr naming the count received, and
exit with status 1, rather than silently greeting only the first.

#### Scenario: Two positional arguments

- **WHEN** the command is run as `hello Ada Grace`
- **THEN** stderr reports that exactly one name is expected and two were given
- **AND** stdout is empty
- **AND** the exit status is 1

### Requirement: Reject unknown options

An argument that looks like an option but is not one the command defines SHALL
be rejected with a usage message on stderr and exit status 1, rather than being
greeted as a name.

#### Scenario: An undefined option is supplied

- **WHEN** the command is run as `hello --shout Ada`
- **THEN** stderr reports the unknown option
- **AND** stdout is empty
- **AND** the exit status is 1

### Requirement: Report usage on request

The command SHALL support a `--help` option that writes its usage — the synopsis,
the positional argument, and every option it accepts — to stdout and exits with
status 0. Help SHALL take precedence over any other argument, including an
otherwise-invalid one, so that help is always reachable.

#### Scenario: Help is requested

- **WHEN** the command is run as `hello --help`
- **THEN** stdout contains the usage synopsis and the list of options
- **AND** the exit status is 0

#### Scenario: Help is requested alongside invalid arguments

- **WHEN** the command is run as `hello --help Ada Grace`
- **THEN** stdout contains the usage synopsis
- **AND** the exit status is 0

### Requirement: Report its version

The command SHALL support a `--version` option that writes its version to stdout
and exits with status 0. The reported version SHALL match the version declared in
the package manifest, so the two cannot drift apart.

#### Scenario: Version is requested

- **WHEN** the command is run as `hello --version`
- **THEN** stdout is the package version followed by a newline
- **AND** the exit status is 0

### Requirement: Keep diagnostics off stdout

Every message that is not the greeting itself, the help text, or the version
SHALL be written to stderr. This keeps `hello <name>` safe to pipe: on success
stdout carries only the greeting, and on failure it carries nothing.

#### Scenario: Output is piped and the invocation fails

- **WHEN** the command is run with invalid arguments and stdout is redirected to a file
- **THEN** the file is empty
- **AND** the diagnostic appears on stderr
