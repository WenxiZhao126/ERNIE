#!/usr/bin/env bash
echo "3.2.4 Ensure suspicious packets are logged"
ensure_kernel_net_param ipv4 conf..log_martians 1
