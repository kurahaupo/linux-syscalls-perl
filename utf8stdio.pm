package utf8stdio v0.0.0 {
BEGIN {
  binmode $_, ":utf8" for *STDIN, *STDOUT, *STDERR
}
};
1;
