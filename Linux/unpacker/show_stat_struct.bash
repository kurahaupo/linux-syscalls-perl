#!/bin/bash

# vim: set syntax=sh :

shopt -s extglob

declare -r true=1 false=0

declare -i stop_on_error=false

while (($#))
do
    case $1 in
        -1) stop_on_error=true ;;
        -*) printf >&2 'Bad option "%s"\n' "$1" ; exit 64 ;;
        *)  break ;;
    esac
    shift
done

argv0=$0
if [[ $argv0 != */* ]]
then
    if [[ -f $argv0 && -r $argv0 && -x $argv0 ]]
    then
        argv0=./$argv0
    else
        argv0=$( PATH+=: ; type -p "$argv0" || printf ././%s "$argv0" )
    fi
fi

dir=${argv0%%!(*[/]*)}
odir=/tmp/

(($#)) || { printf >&2 'Missing targets\n' ; exit 1 ; }

dd=(
      # -D_GNU_SOURCE
        -D_LARGEFILE64_SOURCE
      # -D_LARGEFILE_SOURCE
        -DUSE_ASM_STAT
   )
nd=${#dd[@]}

dd_description=(
      # g
        k
      # l
        a
    )

aa=( -m64   # -march unspecified
     -mx32  # for x86_64 CPU but runs as a 32-bit process
     -m32   # -march=i386  unless cross-compiler installed
)
na=${#aa[@]}

aa_description=( x64 x32 i32 )

#for ((s=ss;s&s-1; s=(s|s-1)+1)) do :;done # round up to power of 2

for ((k=0;k<na<<nd;++k)) do

    printf '\nk = %u = %u + %u * %u\n' $((k)) $((k%na)) $((k/na)) $((na))

    cc=( gcc )

    cflags=()

    # Model (64-bit or 32-bit or 32-on-64)
    if a=${aa[k%na]} ; [[ $a ]] ; then cflags+=( "$a" ) ; fi
    if as=${aa_description[k%na]} ; [[ $as ]] ; then cflags+=( -D"USE_$as" ) ; fi

    # Options
    ms=
    for ((m=k/na, j=0;j<nd;++j)) do
        if (( m & 1<<j ))
        then
            cflags+=( "${dd[j]}" )
            ms+=${dd_description[j]^}
        else
            ms+=${dd_description[j],}
        fi
    done

    printf -v comp_opts -- -Dcompilation_options=\"%s\ %s\" "CC={${cc[*]}}" "CFLAGS={${cflags[*]}}"
    cflags+=( "$comp_opts" )

    ms+=.$as

    rm -fv *".$ms"

    make clean > CLEAN.log.$ms 2>&1

    for p do
        pf=$dir$p

        printf '%s\n' "p=$p pf=$pf na=$na nd=$nd"

        l=$odir$p.log

        #exec >| "$l"  2>&1
        set +x

        ll=$l.$ms
        if (
            #printf '# Compiling target=%s options=%s\n' "$pf" "CC={${cc[*]}} CFLAGS={${cflags[*]}}"
            printf '# vim: set syntax=none :\n'

            printf 'Compile:\n'

            ( set -x ; make "CC=${cc[*]}" "CFLAGS=${cflags[*]}" "$pf" ) || exit

            file "$pf"
            ls -dlis --full-time "$pf"
            "$pf"
           ) 3>&1 4>&2 >> "$ll" 2>&1
        then
            printf 'logging %s SUCCESS\n' "$ll"
        else
            ex=$?
            printf 'logging %s ERROR %u\n' "$ll" $ex
            if ((ex != 0 && stop_on_error))
            then
                cat "$ll"
                exit $ex
            fi
        fi

    done

    for f in "$odir"*".log.$ms" ; do
        printf '\n# vim: set syntax=none nowrap :\n' >> "$f"
    done

done

# vim: set syntax=sh :
