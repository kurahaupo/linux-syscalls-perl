# linux-syscalls-perl

The `Linux::Syscalls` module attempts to provide non-native (but still fast)
access to all Linux system calls that aren't in the core POSIX module. That
includes both actual POSIX calls that lack support in `POSIX.pm` such as
`fstatat`, specialized services provided through multiplexer interfaces such as
`ioctl`, common BSD & SysV calls that didn't make the cut into POSIX (such as
`chroot`), Linux extensions to syscalls (`waitid` taking an extra parameter),
and truly Linux-specific syscalls such as `getcpu`.

Only a small subset of these are implmented so far.

As a design goal, all outputs are by value; any system calls that take a buffer
that gets filled instead allocate a buffer within the implementation and then
returned to the caller.

## Contributing to this project

Immediately after cloning into a local repository, please go:

    ln -fs ../../.git.precommit.d/pre-commit .git/hooks/pre-commit

This will prevent the subsequent introduction of syntax errors and whitespace
anomalies. Please ensure you have `/bin/bash` installed.

## Process management

All of the various `*wait*` system calls are provided, such that they return
all available information.

`waitid5` is added as an interface to obtaining the additional information
returned from the Linux `waitid` system call.

The exit status of a program conventionally truncated to 8 bits, but where more
bits are available, these functions attempt to make that information available.

(`exit2` is planned that will post a wide exit code, but it won't be useful
until I've figured out how to force the Perl interpreter to unwind and invoke
all the `END` blocks, and then still invoke the extended status version of
`exit`.)

## Filedescriptors and Filenames

The initial focus was on "things that can be done with filedescriptors and
filenames", in particular the `*at` family of syscalls. The related constants
are provided, but use `undef` rather than `AT_CWD`.

## Timestamps

Because `stat` returns a `struct timespec` for each of the 3 timestamps, a
helper package `Time::Nanosecond` is provided for dealing with high-resolution
timestamps in a lossless way. (This is not specifically Linux-specific, and may
be moved to a separate package later.)

Perl uses C `double` interally to hold floating-point values. This means that
the naïve approach of using a "floating point `time_t`" only provides
resolution to about ±0.14µs, which makes it an adequate stand-in for `struct
timeval` with its 1µs precision, but not adequate for working with the 1ns
timestamps reported by `stat()` and related system calls.

Basic arithmetic operations are provided.

It also provides drop-in replacements for `localtime`, `gmtime` and `strftime`
that can handle fractional seconds. This adds a new format specifier `%N` and
modifies the `%S`, `%T` and `%s` specifiers, allowing a precision to be
specified.

It provides two reference implementations (three, if 64-bit integers are
available), so that speed/space trade-offs can be assessed in different
situations. All of them provide the same interface for converting to/from the
equivalents of `struct timespec`, `struct timeval` and floating-point `time_t`.
Implied precision is inferred from the constructor, and carried over in any
arithmetic.

## Future work

Currently only `x86_64` and `i386` are supported and only a subset of available
system calls are implemented.

Both will be expanded on as as-needed basis. Please let me know if you have any
particular calls you need to use.
