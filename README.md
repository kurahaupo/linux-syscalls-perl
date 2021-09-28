# linux-syscalls-perl

The `Linux::Syscalls` module attempts to provide non-native (but still fast)
access to all Linux system calls that aren't in the core POSIX module. That
includes both actual POSIX calls that lack support in `POSIX.pm` such as
`fstatat`, specialized services provided through multiplexer interfaces such as
`ioctl`, common BSD & SysV calls that didn't make the cut into POSIX (such as
`chroot`), Linux extensions to syscalls (`waitid` taking an extra parameter),
and truly Linux-specific syscalls such as `getcpu`.

Only a small subset of these are implemented so far.

As a design goal, all inputs are passed as parameters, and all outputs are
returned; no placing outputs into global variables or into references that are
passed in.

(The implementation of any system call that takes a buffer to be filled instead
allocates a buffer and returns that to the caller. That especially applies to
"small" buffers such as the `int status` passed to `wait()`. For calls that can
accept an arbitrary buffer size and return an arbitrary list of values, such as
`getdents`, a buffer size hint is accepted as a parameter.)

## Contributing to this project

Immediately after cloning into a local repository, please go:

    ln -fs ../../.git.precommit.d/pre-commit .git/hooks/pre-commit

This will prevent the subsequent introduction of syntax errors and whitespace
anomalies. Please ensure you have `/bin/bash` installed.

## Process management

All of the various `*wait*` system calls are provided; all information is
returned as tuples in line with the overall design goal as above. In particular
`$?` is untouched.

`waitid5` is added as an interface to obtaining the additional information
returned from the Linux `waitid` system call.

The exit status of a program is conventionally truncated to 8 bits, but where
more bits are available, these functions attempt to make that information
available.

(Hopefully a new `exit2` call can be implemented that will post a wide exit
code; see Future work below.)

## Filedescriptors and Filenames

The initial focus was on "things that can be done with filedescriptors and
filenames", in particular the `*at` family of syscalls. The related constants
are provided, but use `undef` rather than `AT_CWD`.

In most cases a numeric filedescriptor or a Perl file-handle can be used
interchangeably; `$fd = $io->fileno()` and `open $io, "<&=$fd"` provide
automatic translations under the hood.

The same cannot be said for `opendir`: there's no equivalent of either of those
operations.

But it gets even worse: `opendir` doesn't work with `DirHandle` objects;
rather, it populates a hidden part of an `IO::Handle`, which actually holds
*two filedescriptors*:
 * one for ordinary file operations, and
 * another for `readdir`, `telldir`, `seekdir`, and `closedir`.

There was no way to retrieve that second filedescriptor until a recent version
of Perl added a `dirfd` method, and `opendir` does not understand `<&=$fd` so
the reverse is still impossible.

Without these, it's impracticable to scan a directory using `readdir` and then
securely process the resulting entries using `fstatat` or `openat`, and as for
processing subdirectories using `openat`, forget about it. (The only workable
approaches require holding two open filedesciptors.)

Therefore the `getdents` system call is provided as an alternative to
`readdir`.

Moreover, the `getdents` system call can return additional information: on many
systems it can return a filetype, so that it's not necessary to perform a
`fstatat` operation to identify subdirectories.

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

## Timestamps

There are various ways to manage sub-second timestamp precision; the simplest
approach is to use a "floating point `time_t`".

Internally Perl uses a C `double` to hold a floating-point value, which is
typically an IEEE 64-bit float that provides 53-bit precision. This gives a
resolution of about ±0.14µs for timestamps between 2004 and 2037; ±0.29µs from
2038, ±0.57µs from 2106, and so on. This ensures lossless representation of
`struct timeval` values with microsecond resolution for the next 80+ years.

Many syscalls use `struct timespec` for timestamps, and clearly Perl's floating
is inadequate to represent these nanosecond-resolution values, so a helper
package `Time::Nanosecond` is provided for dealing with such timestamps
losslessly and (hopefully) painlessly.

`Time::Nanosecond` provides two reference implementations, so that
speed/space trade-offs can be assessed in different situations:
  * `Time::Nanosecond::ns` holds integer nanoseconds (only if 64-bit integers
    are available); and
  * `Time::Nanosecond::ts` holds a pair holding seconds and nanoseconds,
    equivalent to `struct timespec`.

Both implementations provide the same functionality:

* Constructors:
  * `from_timespec`
  * `from_timeval`
  * `from_nanoseconds`
  * `from_microseconds`
  * `from_milliseconds`
  * `from_centiseconds`
  * `from_deciseconds`
  * `from_seconds` (floating point)
* Conversions:
  * `timespec` (as pair)
  * `timeval` (as pair)
  * `nanoseconds` (as integer)
  * `microseconds` (as integer)
  * `milliseconds` (as floating point)
  * `centiseconds` (as floating point)
  * `deciseconds` (as floating point)
  * `seconds` (as floating point)

Basic arithmetic operations are provided, along with drop-in replacements for
`localtime`, `gmtime` and `strftime` that can handle fractional seconds.

The `strftime` replacement adds a new format specifier `%N` and modifies the
`%S`, `%T` and `%s` specifiers, allowing a precision to be specified.

Since the `from_seconds` and `seconds` deal with floating point, it's trivial to
convert to & from most other formats.

(The `Time::Nanosecond` package is not really Linux-specific, and may be moved
to its own git repository later.)

## Future work

Currently only `x86_64` and `i386` are supported and only a subset of available
system calls are implemented.

Both will be expanded on as as-needed basis. Please let me know if you have any
particular calls you need to use.

`exit2` may be needed to return a wide exit code, but it won't be useful until
I've figured out how to force the Perl interpreter to unwind and invoke all the
`END` blocks, and then still invoke the extended status version of `exit`.
Moreover it's dependent on patches that have yet to hit the mainline kernel.

Create `IO::Dir` as a drop-in replacement for the `DirHandle` module that uses
the "normal" filedescriptor inside IO::Handle rather than the hidden one. Provide
methods:
  * `readdir` (returns one name or `undef` in scalar context, or the entire
    directory in list context up to a specified limit)
  * `getdent` (returns one entry and its associated filetype)
  * `getdents` (returns a ref to one name+type pair in scalar context, or
    refs to pairs for the entirely directory up to a specified limit)
(`IO::Handle`  methods such as `seek` and `tell` should work without needing to
be overridden.)
