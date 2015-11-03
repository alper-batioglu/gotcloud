#!/bin/bash
set -e -u -o pipefail # Safety first!

echo 'Your ran `cd src && make test` before this, right?  I'\''ll trust that you did.'

gotcloud_root="$(dirname $(dirname $0))"
gotcloud_executable="$gotcloud_root/gotcloud"
echo using $gotcloud_executable

outdir="$(mktemp -d --tmpdir gotcloud-tests-$USER-XXX)"
echo "outputting to $outdir"

child_pids=""

# Note: These three commands are independent of each other, so we'll run them all in parallel.

cmds1="align indel bamQC recabQC"
for cmd in $cmds1; do
    bash -c "$gotcloud_executable $cmd --test $outdir/$cmd &> $outdir/$cmd.output; echo \$? > $outdir/$cmd.return_status; echo \$(date) finished $cmd;" &
    child_pids+=" $!"
done

set +e

# Note: ldrefine is beagle + thunder, and beagle4 is `umake --split4` + `umake --beagle4`
# Note: all tests are run in `umaketest`, because the name of the working directory must stay consistent through the whole process.
# TODO: run ldrefine and beagle4 in parallel

cmds2="snpcall beagle thunder split4 beagle4"
for cmd in $cmds2; do
    $gotcloud_root/bin/umake.pl --$cmd --test $outdir/umaketest &> $outdir/$cmd.output
    echo $? > $outdir/$cmd.return_status
    cp $outdir/umaketest/umaketest.log $outdir/$cmd.log
    echo $(date) finished $cmd
done

set -e

for child_pid in $child_pids; do
    wait $child_pid
done

status=0

for cmd in $cmds1 $cmds2; do
    cmd_status=$(cat $outdir/$cmd.return_status)
    printf "%-10s %4d\n" $cmd $cmd_status
done
echo

for cmd in $cmds1 $cmds2; do
    cmd_status=$(cat $outdir/$cmd.return_status)
    if [[ $cmd_status != 0 ]]; then
        status=$cmd_status
        echo output of failing command $cmd:
        cat $outdir/$cmd.output
        echo
        echo log files for failing command $cmd:
        cat $outdir/$cmd.log
        echo
    fi
done

echo "When you're done, run the following command to clean up:"
echo "rm -r $outdir"

exit $status