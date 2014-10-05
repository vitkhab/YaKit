#!/bin/bash

# Make config for yandex tank
echo "[phantom]
address = 10.0.2.101
port = 80
rps_schedule = step(1,60,1,30)
header_http = 1.1
headers = [Host: yakit-z03]
  [User-Agent: Yandex-tank]
  [Connection: close]
  [Accept-Encoding:gzip,deflate]
uris = /" > ./load.ini

# Launch yandex tank
yandex-tank