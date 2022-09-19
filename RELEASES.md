## v0.3.0

Bugfixes
* C<faccessat> follows symlinks unless C<AT_SYMLINK_NOFOLLOW> is specified
* C<rmdirat> does not take any flags
* C<unlinkat> flags are optional

Improvements
* support C<dirfd> after C<opendir> on systems new enough to have it
* add C<\*ns> versions of syscalls to force Time::nanosecond timestamps, in
  particular:
  * C<utimens>
  * C<lutimens>
  * C<statns>
  * C<fstatns>
* refactor all the C<\*utime\*> functions to call C<utimensat>
* add C<lutime>
* allow C<adjtimex> to accept C<Time::Nanosecond> values
* copious updates to internal comments, especially getdents & strftime

## v0.2.0   2021-10-29

Bugfixes
* add package version declaration
* rename C<futimesat>→C<utimensat> (to match syscall); add C<futimens>
  (C<futimens>() and C<utimensat>() are specified in POSIX.1-2008)
* for C<utimensat>, when checking for "" (empty string), also check that it is
  not a ref (C<Time::Nanosecond::ts>)
* import C<POSIX::floor>

Improvements:
* change defaults when flags are undef or omitted:
    * act on symlinks for C<link> & C<unlink>
    * follow symlinks for C<faccessat>

## v0.1.0   2021-09-04

Core functionality with timers and filedescriptors
Support Linux x86_64 and i386
