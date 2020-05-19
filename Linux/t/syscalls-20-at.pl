1;
__END__

    AT_SYMLINK_NOFOLLOW
    AT_EACCESS
    AT_REMOVEDIR
    AT_SYMLINK_FOLLOW
    AT_NOAUTOMOUNT
    AT_EMPTY_PATH

faccessat($$$;$) ;
fchmodat($$$;$) ;
fchownat($$$$;$) ;
linkat($$$$;$) ;
fstatat($$;$) ;
mkdirat($$$) ;
mknodat($$$$) ;
openat($$;$$) ;
readlinkat($$) ;
renameat($$$$) ;
symlinkat($$$) ;
unlinkat($$$) ;
rmdirat($$$) ;
futimesat($$$$$) ;

adjtimex($;$$$$$$$$$$$$$$$$$$$) ;
statvfs($) ;
lchown($$$) ;
lchmod($$) ;
lstatns($) ;
lutimes($$$) ;
vhangup() ;
