#!/bin/bash

TC_MODULES_URL=http://distro.ibiblio.org/tinycorelinux/4.x/x86_64/tcz

download_command="curl -L -\# -o"
deps_file=tmp_deps.lst
pkgs_file=pkgs.lst

function download {
    eval $download_command $@
}

function process_deps_for {
    local pkg=$1
    local dep="$pkg.dep"
    echo "processing $pkg"
    download $dep $TC_MODULES_URL/$dep -f 2>/dev/null
    if [ -f "$dep" ]; then
        for d in `cat $dep`
        do
            echo $d >> $deps_file
            echo "processing dependencies $dep of $pkg"
            process_deps_for $d
        done
    fi
    rm -f $dep 
}

for pkg in `cat $pkgs_file`
do
    process_deps_for $pkg
done

cat $deps_file $pkgs_file | sort | uniq | grep -v KERNEL > t_deps.lst

cmp t_deps.lst opt/tce/onboot.lst

if [ $? != 0 ]; then
    echo "updating depencencies"
    cat t_deps.lst > opt/tce/onboot.lst
fi

rm t_deps.lst
rm $deps_file
