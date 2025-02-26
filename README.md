# linux-syscalls-perl

The `Linux::Syscalls` module provides access to Linux system calls that aren't
in the core POSIX module.

This includes both actual POSIX calls that lack support in `POSIX.pm` such as
`fstatat`, specialized services provided through multiplexer interfaces such as
`ioctl`, common BSD & SysV calls that didn't make the cut into POSIX (such as
`chroot`), Linux extensions to syscalls (`waitid` taking an extra parameter),
and truly Linux-specific syscalls such as `getcpu`.

Only a small subset of these are implemented so far, based on need in other
projects; if you need a syscall that isn't implemented please submit a [feature
request on github](https://github.com/kurahaupo/linux-syscalls-perl/issues).

## Design goals

1. It should be possible to drop this module into any environment and have it
   _just work_; this means everything must be implemented as pure Perl before
   adding XS code to improve performance.
2. Everything is passed or returned by value. No tweaking global values (other
   than `$!`) and no passing references to be filled in.
3. Everything is properly encoded and decoded; no need for the user to use
   `pack` or `unpack`.
4. Keep parameters in the order specified in the Linux man pages for the
   syscall; this may differ from the order used in `POSIX` or `CORE`.

## Contributing to this project

Immediately after cloning into a local repository, please go:

    ln -fs ../../.git.precommit.d/pre-commit .git/hooks/pre-commit

This will prevent the subsequent introduction of syntax errors and whitespace
anomalies. Please ensure you have `/bin/bash` installed.

## Process management

All of the various *wait*-like system calls are covered, including `wait`,
`wait3`, `wait4`, `waitpid`, and `waitid`. An additional `waitid5` function
returns the additional information provided by the Linux `waitid` system call.

All information is returned as tuples in line with the overall design goal as
above. In particular `$?` is untouched.

The exit status of a program is conventionally truncated to 8 bits, but where
more bits are available, these functions attempt to make the whole of that
value available. (Linux does not currently provide a way for a process to exit
with a value wider than 8 bits; see Future work below.)

(This module does not provide `killpg` because the built-in `kill` function
already provides that functionality by negating the signal number.)

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

Moreover, the `getdents` system call can return filetype information on systems
that can return it, so that `fstatat` isn't necessary to identify
subdirectories.

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

* Constructors:
  * `new_seconds` (integer)
  * `new_fseconds` (floating point)
  * `new_deciseconds`
  * `new_centiseconds`
  * `new_milliseconds`
  * `new_microseconds`
  * `new_nanoseconds`
  * `new_timespec`
  * `new_timeval`
* Conversions:
  * `seconds` (as integer or floating point)
  * `deciseconds`
  * `centiseconds`
  * `milliseconds`
  * `microseconds`
  * `nanoseconds`
  * `timespec`
  * `timeval`
* Operators:
  * `gmtime`
  * `localtime`
  * `withprecision` (returns a new object rather than mutating in-place)

All the constructors except `new_fseconds` accept integers and set the
precision accordingly; the `new_fseconds` constructor accepts a floating-point
value, and assumes microsecond precision.

The `seconds` through `nanoseconds` conversions return integers when that would
match the nominal precision and is within the range representable by a Perl IV,
or otherwise return a Perl FV (floating point, which may lose some precision).
The `timespec` conversion is based on C's `struct timespec` and returns seconds
and nanoseconds in list context. The `timeval` conversion is based on C's
`struct timeval` and returns seconds and microseconds in list context.

The `gmtime` and `localtime` methods return a blessed scalar that is a subclass
of `Time::tm` with the addition of a `strftime` method.

`Time::Nanosecond` provides two implementations that can be selected by
either `use Time::Nanosecond ':ts';` or `use Time::Nanosecond ':ns';`,
allowing you to make a speed/space trade-off:

  * `Time::Nanosecond::ts` holds a pair holding seconds and nanoseconds,
    equivalent to `struct timespec`; and
  * `Time::Nanosecond::ns` holds integer nanoseconds (only available if Perl is
    compiled with 64-bit integer support).

These provide indentical functionality, and can interoperate with each other.

Both provide the same interface for converting to/from the equivalents of
`struct timespec`, `struct timeval`, floating-point `time_t`, and integer
seconds, deciseconds, centiseconds, milliseconds, microseconds, and
nanoseconds. Implied precision is inferred from the constructor, and carried
over in any arithmetic.

Basic arithmetic operations are provided, along with drop-in replacements for
`localtime`, `gmtime`, and `strftime` that can handle fractional seconds.

The `strftime` replacement adds a new format specifier `%N` and modifies the
`%S`, `%T` and `%s` specifiers, allowing a precision to be specified.

Since the `from_seconds` and `seconds` deal with floating point, it's trivial
to convert to & from most other formats.

The `Time::Nanosecond` module is not really Linux-specific, but is included
here because the `Linux::Syscalls` module is so heavily dependent on it.
In future it may be moved to its own git repository.

## Future work

This package is a work in progress.

* Only a subset of available system calls are currently implemented.
* Only `x86_64`, `i386` and `mipsel` are currently supported.

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
