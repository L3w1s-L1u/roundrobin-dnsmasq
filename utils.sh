#! /usr/bin/env bash
#

# Check if given ip address is valid
# Courtesy of ghoti@https://stackoverflow.com/questions/13777387/check-for-ip-validity
# param-1: ip address to check
# return: 0 if ip is valid and 1 if ip is invalid
ip_invalid() {
	# Set up local variables
	local ip=${1:-NO_IP_PROVIDED}
	local IFS=.; local -a a=($ip)
	# Start with a regex format test
	[[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
	# Test values of quads
	local quad
	for quad in {0..3}; do
		[[ "${a[$quad]}" -gt 255 ]] && return 1
	done
	return 0
}
