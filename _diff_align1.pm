

    # Take two lists, and expand them with undefs so that equal elements line up.
    # Work by picking the longest common subsequence, then recursively operating
    # on the parts either side of that.
    # If there are no equal elements, just pad the two lists to the same length.
    sub _diff_align(\@\@) ;
    sub _diff_align(\@\@) {
        my ($l1,$l2) = @_;
        if (!@$l1) {
            @$l1 = ((undef) x @$l2);
            return;
        }
        if (!@$l2) {
            @$l2 = ((undef) x @$l1);
            return;
        }
        my @l1 = @$l1;
        my @l2 = @$l2;
        # find maximal common stretch, with minimal offset from the centres
        my $m1 = $#l1/2;
        my $m2 = $#l2/2;
        my $mo = $m1 - $m2;
        my $pos;
        my $off;
        my $len = 0;
        for my $o ( $mo, map { $mo+$_, $mo-$_ } 1 .. $#l1+$#l2+1 ) {
            for (my $i = ::max(0, -$o), my $e = ::min($#l1, $#l2-$o) ; $i <= $e ;++$i) {
                if ( $l1[$i] ne '' && $l1[$i] eq $l2[$i+$o] ) {
                    my ($z) = grep { $l1[$_] ne $l2[$_+$o] } $i .. $e;
                    $z //= $e+1;
                    if ($len < $z-$i) {
                        # found a new longest subset
                        $len = $z-$i;
                        $pos = $i;
                        $off = $o;
                    }
                    $i = $z;
                }
            }
        }
        if (defined $pos) {
            # found a common subset
            my @e1 = splice @l1, $pos+$len;
            my @e2 = splice @l2, $pos+$len+$off;
            _diff_align @e1,@e2;
            my @s1 = splice @l1, 0, $pos;
            my @s2 = splice @l2, 0, $pos+$off;
            _diff_align @s1,@s2;
            @l1 = (@s1, @l1, @e1);
            @l2 = (@s2, @l2, @e2);
        } else {
            push @l1, (undef) x ($#l1 - $#l2) if $#l1 > $#l2;
            push @l2, (undef) x ($#l2 - $#l1) if $#l2 > $#l1;
        }
        @$l1 = @l1;
        @$l2 = @l2;
    }
