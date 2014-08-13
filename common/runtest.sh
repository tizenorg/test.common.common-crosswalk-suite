#!/bin/bash

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Authors: Nicolas Zingilé <nicolas.zingile@open.eurogiciel.org>

set -e
source /etc/tizen-platform.conf
widgetsdb=/home/guest/.applications/dbspace/.app_info.db
widgetinstdir=/opt/usr/media/tct
testdir=/usr/share/tests/common-crosswalk-suite/TESTDIR
resdir=/tmp
tmpoutfile=$resdir/output.xml
resfile=$resdir/testkit.result.xml


function get_widgetid () {
    sqlite3 $widgetsdb "select x_slp_appid from app_info where name=\"$1\""
}

function launch_testkit_stub () {
    if [[ -z $(ps -ef | grep testkit-stub | grep -v bash | grep -v grep) ]]; then
        echo 'testkit-stub is not launched... will be launched'
        testkit-stub --port:8000
    fi
}

function install_widget () {
    local widgetzip=$(find $testdir -name $1*.xpk.zip)
    local widgetxpk=$widgetinstdir/opt/$1/$1.xpk
    [[ ! -d $widgetinstdir ]] && mkdir -p $widgetinstdir && echo "$widgetinstdir directory created"
    if [[ -z $2 ]]; then
        echo 'test widget will be uncompressed and installed...'
        unzip -u $widgetzip -d $widgetinstdir
        su - guest -c "export DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/9999/dbus/user_bus_socket\"; export XDG_RUNTIME_DIR=\"/run/user/9999\"; xwalkctl -i $widgetxpk"
        widgetid=$(get_widgetid $1)
    fi
}

function launch_test () {
   testfile=$1
   testtype=$2

echo "## execution script: running testkit on $testfile"
case $testtype in
		web)
		    widgetname=$(basename $testfile .xml)
		    widgetid=$(get_widgetid $widgetname)
		    install_widget $widgetname $widgetid
		    testkit-lite -e 'su - guest -c "export DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/9999/dbus/user_bus_socket\"; export XDG_RUNTIME_DIR=\"/run/user/9999\"; systemctl --user restart xwalk.service; xwalk-launcher '$widgetid'"' -f /usr/share/tests/common-crosswalk-suite/$widgetname.xml --comm localhost -o $resdir/$widgetname.result.xml
		;;
		standard)
	    timeout 10800 testkit-lite -f /usr/share/tests/common-crosswalk-suite/$testfile --comm localhost -o $resdir/$(basename $testfile .xml).result.xml
		;;
		*)
		    echo 'Unknown test type'
		    exit 1
	        ;;
   esac
}

launch_testkit_stub

echo '## execution script: preparing environment'
rm -rf $resdir/*.result.xml
rm -rf $resdir/*.result.txt
rm -rf $tmpoutfile

testlist_web='tct-2dtransforms-css3-tests.xml tct-3dtransforms-css3-tests.xml tct-animations-css3-tests.xml tct-animationtiming-w3c-tests.xml tct-appcache-html5-tests.xml tct-audio-html5-tests.xml tct-capability-tests.xml tct-colors-css3-tests.xml tct-dnd-html5-tests.xml tct-extra-html5-tests.xml tct-fileapi-w3c-tests.xml tct-flexiblebox-css3-tests.xml tct-fonts-css3-tests.xml tct-forms-html5-tests.xml tct-fullscreen-nonw3c-tests.xml tct-geoallow-w3c-tests.xml tct-gumallow-w3c-tests.xml tct-indexeddb-w3c-tests.xml tct-jsenhance-html5-tests.xml tct-mediacapture-w3c-tests.xml tct-mediaqueries-css3-tests.xml tct-multicolumn-css3-tests.xml tct-notification-w3c-tests.xml tct-pagevisibility-w3c-tests.xml tct-svg-html5-tests.xml tct-text-css3-tests.xml tct-touchevent-w3c-tests.xml tct-transitions-css3-tests.xml tct-typedarrays-nonw3c-tests.xml tct-ui-css3-tests.xml tct-vibration-w3c-tests.xml tct-video-html5-tests.xml tct-webdatabase-w3c-tests.xml tct-webstorage-w3c-tests.xml tct-workers-w3c-tests.xml tct-appcontrol-tizen-tests.xml tct-bookmark-tizen-tests.xml tct-callhistory-tizen-tests.xml tct-content-tizen-tests.xml tct-filesystem-tizen-tests.xml tct-messageport-tizen-tests.xml tct-networkbearerselection-tizen-tests.xml tct-notification-tizen-tests.xml tct-power-tizen-tests.xml tct-systeminfo-tizen-tests.xml tct-systemsetting-tizen-tests.xml tct-time-tizen-tests.xml tct-tizen-tizen-tests.xml'

for tst in $testlist_web; do
   launch_test $tst web
done

testlist_standard='testkit.xml'

for tst in $testlist_standard; do
   launch_test $tst standard
done

echo "## execution script: merging results in $resfile"

for file in $resdir/*-tests.result.xml
do
    echo "merging $file in $resfile"
    if grep -sr suite $resfile >/dev/null;
    then
        xml sel -R -t -c / -c "document('$file')" $resfile | \
        xml ed -m /xsl-select/test_definition[2]/suite/* /xsl-select/test_definition[1]/suite | \
        xml ed -d /xsl-select/test_definition[2] | \
        xml sel -t -c /xsl-select/* > $tmpoutfile
    else
        xml sel -R -t -c / -c "document('$file')" $resfile | \
        xml ed -m /xsl-select/test_definition[2]/suite /xsl-select/test_definition[1] | \
        xml ed -d /xsl-select/test_definition[2] | \
        xml sel -t -c /xsl-select/* > $tmpoutfile
    fi

    cp $tmpoutfile $resfile
done

echo '## execution script: finished'
