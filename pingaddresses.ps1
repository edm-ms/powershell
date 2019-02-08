$prefix = "172.16.0." 
$i = 1
do {ping $prefix$i -n 1 -w 2; $i ++} while ($i -le 255)