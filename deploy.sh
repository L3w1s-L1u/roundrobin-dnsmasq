#! /bin/bash
# Docker compose file and dnsmasq config generator
# 
if [[ "$USER" != "root" ]];then
    echo "Please run this script with sudo."
    exit -1
fi
if ! [[ -x "/sbin/iptables-save" ]];then
    echo "Please install \"iptables-persistent\", your original iptables rules need to be saved first."
    exit -1
fi

source "${PWD}/utils.sh"
iptables_rules_dir="/etc/iptables"
compose_tmpl="${PWD}/template/docker-compose.yml.tmpl"
compose_file="${PWD}/docker-compose.yml"
dnsmasq_config_tmpl="${PWD}/template/dnsmasq.conf.tmpl"
dnsmasq_config_file="dnsmasq.conf"

prompt_dns_name="Please enter a public DNS name, enter \"NO\" to finish adding: "
prompt_dns_ip="Please enter IPv4 address of "
prompt_local_ip="Please enter local DNS server IPv4 address: "
prompt_local_interface="Please enter local interface to listen (e.g. eth0): "

upstream_dirs=""
dns_count=0
dns_port=5300
web_port=5380
dns_max=10

# generate docker-compose and dnsmasq config files
# param-1: upstream dns list [dns_name1 dns_ip1 ... dns_namen dns_ipn]
# param-2: dnsmasq server listen interface
generate_config_files()
{
	echo "generating compose and config files ..."
	sed -n "1,3p" "${compose_tmpl}" > "${compose_file}"
	for i in ${1}
	do
		if ! [[ "${i}" =~ [0-9]+(\.[0-9]+){3} ]];then
			echo "generate service entry for upstream: ${i}"
			dns_port=$((dns_port+1))
			web_port=$((web_port+1))
			sed -f - "${compose_tmpl}" > tmp <<-EOF
				s/\[ISP_NAME\]/${i}/g
				s/\[DNS_PORT\]/${dns_port}/g
				s/\[WEB_PORT\]/${web_port}/g
			EOF
			sed -n "4,18p" tmp >> "${compose_file}"
			upstream_path="${PWD}/${i}"
		elif ! [[  "$(ip_invalid ${i})" ]] ;then 
			echo "generate config file for upstream: ${i}"
			if ! [[  -d "${upstream_path}" ]];then
				mkdir -p "${upstream_path}"
				echo "created upstream dir: ${upstream_path}"
			fi
   			sed -f - "${dnsmasq_config_tmpl}" > "${upstream_path}/${dnsmasq_config_file}" <<-EOF
				s/#server=$/server=${i}/g
				s/#no-dhcp-interface=$/no-dhcp-interface=${2}/g
			EOF
		fi
	done
	rm -f tmp
}

# Main
echo "Please provide upstream public DNS names and IPs ..."

while [[ "${dns_count}" -lt "${dns_max}" ]];do
	echo && read -e -p "${prompt_dns_name}" dns_name
	if [[ "${dns_name}" == "NO" ]];then
		break
	fi
	echo && read -e -p "${prompt_dns_ip}${dns_name}: " dns_ip
	if ! $(ip_invalid "${dns_ip}");then
		echo "Invalid ip given. Try again."
		exit 1
	fi
	upstream_dns_list="${upstream_dns_list} ${dns_name} ${dns_ip}"
	((dns_count++))
done

if [[ ${dns_count} -eq ${dns_max} ]];then
	echo "Maximum upstream dns server number: ${dns_max} reached."
fi

echo "Upstream DNS count: ${dns_count}"
echo "Upstream DNS list: ${upstream_dns_list}"

echo && read -e -p "${prompt_local_ip}" local_ip

if ! $(ip_invalid "${local_ip}") ;then
	echo "Invalid ip given. Try again."
	exit 1
fi
echo && read -e -p "${prompt_local_interface}" local_if

echo "Local IP: ${local_ip}"
echo "Local interface: ${local_if}"

echo && read -e -p "Above upstream and local DNS config correct? [Y/N]" confirm
case "${confirm}" in
	[Nn])
		echo "Please run this guidance again to generate new configs."
		exit 0
		;;
	[Yy])
		;;
	*)
		echo "Only y(Y) or n(N) accept, default to No."
		exit 0
		;;
esac

generate_config_files "${upstream_dns_list}" "${local_ip}" "${local_if}"
echo "Generated ${compose_file}, ${dnsmasq_config_file}"

echo "Save current iptable rules ..."
if ! [[ -d "${iptables_rules_dir}" ]];then
	mkdir "${iptables_rules_dir}"
fi
iptables-save > "${iptables_rules_dir}/rules.v4.default"
echo "Current iptable rules saved as ${iptables_rules_dir}/rules.v4.default"

echo "Adding iptables rules ..."
dns_port=5300
while [ ${dns_count} -gt  0 ]
do
	mapped_port=$((dns_port+dns_count))
	iptables -t nat -A PREROUTING -p udp -d "${local_ip}/32" -m udp	--dport 53 -m state --state NEW \
	-m statistic --mode nth --every "${dns_count}" --packet 0 -j DNAT --to-destination="${local_ip}:${mapped_port}"
	iptables -t nat -A OUTPUT -p udp -o lo -m udp --dport 53 -m state --state NEW \
	-m statistic --mode nth --every "${dns_count}" --packet 0 -j DNAT --to-destination="${local_ip}:${mapped_port}"
	dns_count=$((dns_count-1))
done
iptables-save > "${iptables_rules_dir}/rules.v4.roundrobin-dnsmasq"
echo "Modified iptables saved as ${iptables_rules_dir}/rules.v4.roundrobin-dnsmasq."

echo "All rules added. Please run \"docker-compose up\" to bring up your dns caching servers."
