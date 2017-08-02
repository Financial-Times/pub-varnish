#!/bin/sh

HTPASSWD=`echo $HTPASSWD | tr ',' '\n'`
echo -e "$HTPASSWD" > /.htpasswd

shutdown() {
	echo "Stopping" 
	pkill varnishd 
	echo "Stopped varnishd $?"
	pkill varnishncsa
	echo "Stopped varnishncsa $?"
       	exit 0 
}

trap 'shutdown' HUP INT QUIT KILL TERM

# Convert environment variables in the conf to fixed entries
for name in VARNISH_BACKEND_PORT VARNISH_BACKEND_HOST HOST_HEADER NOTIFICATIONS_PUSH_PORT
do
    eval value=\$$name
    sed -i "s/$name/${value}/g" /etc/varnish/default.vcl
done

# Start varnish and log
echo "Starting"
varnishd -pvcc_allow_inline_c=true -f /etc/varnish/default.vcl -s malloc,1024m -t 5 -p default_grace=3600 &
sleep 4

varnishncsa -F '%h %{%d/%b/%Y:%T}t %U%q %s %D' &
echo "Started"

# wait indefinetely
while true
do
	tail -f /dev/null & wait ${!}
done

