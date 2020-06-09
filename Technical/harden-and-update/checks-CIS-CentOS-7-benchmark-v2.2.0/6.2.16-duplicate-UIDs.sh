#!/usr/bin/env bash
echo "6.2.16 Ensure no duplicate UIDs exist"
echo "____CHECK____"
while read -r unique_count uid; do
  [[ -z "${unique_count}" ]] && break
  if (( unique_count > 1 )); then
    echo "Check FAILED, correct this!"
    echo "Duplicate UID $uid for these users:"
    gawk -F: '($3 == n) { print $1 }' "n=$uid" /etc/passwd | xargs
    exit 1
  fi
done < <(cut -f3 -d":" /etc/passwd | sort -n | uniq -c)
echo "Check PASSED"
printf "\n\n"