

# Take two lists, and pad them with undefs so that equal elements line up.
# Work by picking the longest common subsequence, then recursively operating
# on the parts either side of that.
# If there are no equal elements, just pad the two lists to the same length.

# Version 1: after finding the longest common subsequence, make copies of
# the lists on either side, and work on them recursively.
#
# This minimizes the work that has to be done by "splice".

# Take two lists, and pad them with undefs so that equal elements line up.
# Work by picking the longest common subsequence, then recursively operating
# on the parts either side of that.
# If there are no equal elements, just pad the two lists to the same length.
#
# If two elements are "the same", this can be given a "weight", so that a single
# important element may be prefered over a run of less important elements,
# by returning a larger value from the &$eq comparison function.
sub __list_align(&$$$$$$) {
    my ($eq,
        $a1,$s1,$e1,
        $a2,$s2,$e2) = @_;

    my @stack = [$s1,$e1,$s2,$e2];

    STACK: while (my $zz = pop @stack) {
        ($s1,$e1, $s2,$e2) = @$zz;

        if ($e1 >= $s1 && $e2 >= $s2) {

            # Find maximal common stretch.
            #
            # When comparing $a1->[$i] and $s2->[$i+$o], the possible offsets
            # $o range from $s2-$e1 to $e2-$s1 (for the cases where only the
            # first and last elements are compared).
            #

            my $max_weight = -1;

            # Record where max_weight was found:
            my $i1;
            my $z1;
            my $oo;

            my $min_offset = $s2-$e1;
            my $max_offset = $e2-$s1;

            # Since the longest stretch is most likely to be found with the
            # offset $o mid way between (at ($s2+$e2)-($s1+$e1))/2), start
            # there and work outwards.

            my $mid_offset = $min_offset + $max_offset >> 1;    # halve and round down

            for my $q ( 0 .. $max_offset - $min_offset ) {
                # This generates:
                #   0, 1, -1, 2, -2, 3, -3, 4, -4 ...
                my $o = do { use integer; -($q >> 1 ^ -($q&1)) };

                # add mid_offset to get either:
                #   mid, mid+1, mid-1, ... min, max
                # when max-min is odd, or
                #   mid, mid+1, mid-1, ... max, min
                # when max-min is even.
                $o += $mid_offset;

                # choose range start and end to ensure that
                #   s1 ≤ i ≤ e1 & s2 ≤ i+o ≤ e2
                # for the entire range.
                my $i = $s1-$o;         $i = $s1 if $i < $s1;   # my $i = max($s1, $s1-$o)
                my $e = $e2-$s2+$s1-$o; $e = $e1 if $e > $e1;   # my $e = min($e1, $e2-$s2+$s1-$o)
                for (; $i <= $e ;++$i) {
                    my $w = $eq->($l1[$i], $l2[$i+$o]) or next;
                    my $z = $i+1;
                    for (;$z <= $e ;++$z) {
                        my $w2 = $eq->($l1[$z], $l2[$z+$o]) or last;
                        $w += $w2;
                    }
                    if ($max_weight < $w) {
                        # found a new longest subset
                        $max_weight = $w;
                        $z1 = $z;
                        $i1 = $i;
                        $oo = $o;
                    }
                    $i = $z;
                }
            }
            if (defined $i1) {
                # found a common subsequence
                --$i1;
                my $i2 = $i1 + $oo;
                my $z2 = $z1 + $oo;
                push @stack, [$s1, $i1, $s2, $i2],
                             [$z1, $e1, $z2, $e2];
                next STACK;
              # __list_align $eq, $a1, $z1, $e1,
              #                   $a2, $z2, $e2;
              # __list_align $eq, $a1, $s1, $i1,
              #                   $a2, $s2, $i2;
              # return;
            }
        }

        my $len_diff = ($e2-$s2) - ($e1-$s1);

        splice $a1, $e1+1, 0, (undef) x  $len_diff if $len_diff > 0;
        splice $a2, $e2+1, 0, (undef) x -$len_diff if $len_diff < 0;
    }
}

sub list_align(&\@\@) {
    my ($eq,$a1,$a2) = @_;
    if (!$a1 || !$a2) { return }

    __list_align $eq, $a1, 0, $#$a1, $a2, 0, $#$a2;
}


sub _list_align(&\@\@) ;
sub _list_align(&\@\@) {
    my ($eq,$l1,$l2) = @_;

    # short-circuit "empty" cases
    if (!$l1 || !$l2) { return }
    if (!@$l1) {
        @$l1 = ((undef) x @$l2);
        return;
    }
    if (!@$l2) {
        @$l2 = ((undef) x @$l1);
        return;
    }

    # temporary copies of the two arrays
    my @l1 = @$l1;
    my @l2 = @$l2;

    # find maximal common stretch, with minimal offset from the centres
    my $min_offset = $s2-$e1;
    my $max_offset = $e2-$s1;

    my $mid_offset = $min_offset + $max_offset >> 1;

    my $mo = $m1 - $m2;

    my $max_weight = -1;
    my $pos;
    my $off;
    my $len;
    for my $q ( 0 .. $max_offset - $min_offset ) {
        my $o = $mid_offset - ($q >> 1 ^ -($q&1));
        my $i = -$o; $i = 0 if $i < 0;              # my $i = ::max(0,        -$o)
        my $e = $#l2-$o; $e = $#l1 if $e > $#l1;    # my $e = ::min($#l1, $#l2-$o)
        for (; $i <= $e ;++$i) {
            my $w = $eq->($l1[$i], $l2[$i+$o]) or next;
            my $z = $i+1;
            for (;$z <= $e ;++$z) {
                my $w2 = $eq->($l1[$z], $l2[$z+$o]) or last;
                $w += $w2;
            }

            if ($max_weight < $w) {
                # found a new longest subset
                $max_weight = $w;
                $len = $z-$i;
                $pos = $i;
                $off = $o;
            }
            $i = $z;
        }
    }
    if (defined $pos) {
        # found a common subset
        my @s1 = splice @l1, 0, $pos;
        my @s2 = splice @l2, 0, $pos+$off;
        _list_align $eq, \@s1, \@s2;
        my @e1 = splice @l1, $len;
        my @e2 = splice @l2, $len;
        _list_align $eq, \@e1, \@e2;
        @l1 = (@s1, @l1, @e1);
        @l2 = (@s2, @l2, @e2);
    } else {
        push @l1, (undef) x ($#l1 - $#l2) if $#l1 > $#l2;
        push @l2, (undef) x ($#l2 - $#l1) if $#l2 > $#l1;
    }

    # copy the temporary arrays back to the originals
    @$l1 = @l1;
    @$l2 = @l2;
}
