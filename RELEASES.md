## v0.2.0   2021-10-29

Bugfixes
* add package version declaration
* rename futimesat→utimensat (to match syscall); add futimens
  (futimens() and utimensat() are specified in POSIX.1-2008)
* for utimensat, when checking for "" (empty string), also check that it is not a ref (Time::Nanosecond::ts)
* import floor

Improvements:
* change defaults when flags are undef or omitted:
    * act on symlinks for link & unlink
    * follow symlinks for faccessat

## v0.1.0   2021-09-04

Core functionality with timers and filedescriptors
Support Linux x86_64 and i386
