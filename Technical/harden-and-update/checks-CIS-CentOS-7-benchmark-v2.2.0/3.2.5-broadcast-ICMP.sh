#!/usr/bin/env bash
echo "3.2.5 Ensure broadcast ICMP requests are ignored"
ensure_kernel_net_param ipv4 icmp_echo_ignore_broadcasts 1
