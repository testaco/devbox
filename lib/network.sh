#!/bin/bash
# Devbox Network Egress Control Library
# Helper functions for managing container network egress

# Include guard
if [[ -n "${_DEVBOX_NETWORK_LOADED:-}" ]]; then
	return 0
fi
_DEVBOX_NETWORK_LOADED=1

# Valid egress profiles
readonly VALID_EGRESS_PROFILES="permissive standard strict airgapped"

# Default profile
readonly DEFAULT_EGRESS_PROFILE="standard"

# Profile variables (populated by load_egress_profile)
EGRESS_PROFILE_NAME=""
EGRESS_PROFILE_DESCRIPTION=""
EGRESS_NETWORK_MODE=""
EGRESS_DEFAULT_ACTION=""
EGRESS_LOG_BLOCKED=""
EGRESS_LOG_ALL=""
EGRESS_ALLOWED_PORTS=""
EGRESS_ALLOWED_DOMAINS=""
EGRESS_BLOCKED_DOMAINS=""
EGRESS_ALLOWED_IPS=""
EGRESS_BLOCKED_IPS=""

# Validate egress profile name
# Returns 0 if valid, 1 if invalid
validate_egress_profile() {
	local profile="$1"

	for valid in $VALID_EGRESS_PROFILES; do
		if [[ "$profile" == "$valid" ]]; then
			return 0
		fi
	done

	return 1
}

# Load egress profile configuration
# Usage: load_egress_profile <profile_name> [profiles_dir]
# Sets EGRESS_* variables from profile file
load_egress_profile() {
	local profile="$1"
	local profiles_dir="${2:-$PROJECT_ROOT/profiles}"

	# Validate profile name
	if ! validate_egress_profile "$profile"; then
		return 1
	fi

	local profile_file="$profiles_dir/${profile}.conf"

	if [[ ! -f "$profile_file" ]]; then
		return 1
	fi

	# Reset variables
	EGRESS_PROFILE_NAME=""
	EGRESS_PROFILE_DESCRIPTION=""
	EGRESS_NETWORK_MODE=""
	EGRESS_DEFAULT_ACTION=""
	EGRESS_LOG_BLOCKED=""
	EGRESS_LOG_ALL=""
	EGRESS_ALLOWED_PORTS=""
	EGRESS_ALLOWED_DOMAINS=""
	EGRESS_BLOCKED_DOMAINS=""
	EGRESS_ALLOWED_IPS=""
	EGRESS_BLOCKED_IPS=""

	# Source the profile (handles multiline values)
	# shellcheck source=/dev/null
	source "$profile_file"

	# Map to standard names
	EGRESS_PROFILE_NAME="${PROFILE_NAME:-$profile}"
	EGRESS_PROFILE_DESCRIPTION="${PROFILE_DESCRIPTION:-}"
	EGRESS_NETWORK_MODE="${NETWORK_MODE:-bridge}"
	EGRESS_DEFAULT_ACTION="${DEFAULT_ACTION:-accept}"
	EGRESS_LOG_BLOCKED="${LOG_BLOCKED:-false}"
	EGRESS_LOG_ALL="${LOG_ALL:-false}"
	EGRESS_ALLOWED_PORTS="${ALLOWED_PORTS:-}"
	EGRESS_ALLOWED_DOMAINS="${ALLOWED_DOMAINS:-}"
	EGRESS_BLOCKED_DOMAINS="${BLOCKED_DOMAINS:-}"
	EGRESS_ALLOWED_IPS="${ALLOWED_IPS:-}"
	EGRESS_BLOCKED_IPS="${BLOCKED_IPS:-}"

	return 0
}

# Merge additional rules into loaded profile
# Usage: merge_egress_rules <type> <values...>
# Types: allow_domain, block_domain, allow_ip, block_ip, allow_port
merge_egress_rules() {
	local rule_type="$1"
	shift
	local values=("$@")

	case "$rule_type" in
	allow_domain)
		for domain in "${values[@]}"; do
			EGRESS_ALLOWED_DOMAINS="$EGRESS_ALLOWED_DOMAINS $domain"
		done
		;;
	block_domain)
		for domain in "${values[@]}"; do
			EGRESS_BLOCKED_DOMAINS="$EGRESS_BLOCKED_DOMAINS $domain"
		done
		;;
	allow_ip)
		for ip in "${values[@]}"; do
			EGRESS_ALLOWED_IPS="$EGRESS_ALLOWED_IPS $ip"
		done
		;;
	block_ip)
		for ip in "${values[@]}"; do
			EGRESS_BLOCKED_IPS="$EGRESS_BLOCKED_IPS $ip"
		done
		;;
	allow_port)
		for port in "${values[@]}"; do
			EGRESS_ALLOWED_PORTS="$EGRESS_ALLOWED_PORTS $port"
		done
		;;
	*)
		return 1
		;;
	esac

	return 0
}

# Create isolated Docker network for container
# Usage: create_container_network <container_name>
# Returns network name on success
create_container_network() {
	local container_name="$1"
	local network_name="${container_name}-net"

	# Check if network already exists
	if docker network inspect "$network_name" >/dev/null 2>&1; then
		echo "$network_name"
		return 0
	fi

	# Try to create isolated bridge network with ICC disabled
	# Fall back to standard bridge if ICC restriction is not supported (missing kernel module)
	if docker network create \
		--driver bridge \
		--opt "com.docker.network.bridge.enable_icc=false" \
		--label "devbox.container=$container_name" \
		--label "devbox.type=egress-network" \
		"$network_name" >/dev/null 2>&1; then
		echo "$network_name"
		return 0
	fi

	# Fallback: create network without ICC restriction
	# This happens when br_netfilter kernel module is not loaded
	if docker network create \
		--driver bridge \
		--label "devbox.container=$container_name" \
		--label "devbox.type=egress-network" \
		"$network_name" >/dev/null 2>&1; then
		echo "$network_name"
		return 0
	fi

	return 1
}

# Start DNS proxy sidecar for domain filtering
# Usage: start_dns_proxy <container_name> <allowed_domains> <blocked_domains> [default_action] [static_ip]
# Returns DNS proxy IP address on success (empty string means no filtering needed)
#
# When default_action="drop" (strict mode):
#   - Block all domains by default (address=/#/)
#   - Only allow queries to explicitly whitelisted domains (server=/domain/upstream)
#
# When default_action="accept" (standard mode, default):
#   - Allow all domains by default
#   - Block specific domains (address=/domain/#)
#
# When static_ip is provided (for restart scenarios):
#   - DNS proxy is assigned the specified IP address
#   - This preserves connectivity for containers using --dns pointing to the old proxy
start_dns_proxy() {
	local container_name="$1"
	local allowed_domains="$2"
	local blocked_domains="$3"
	local default_action="${4:-accept}"
	local static_ip="${5:-}"
	local dns_container="${container_name}-dns"
	local network_name="${container_name}-net"

	# Remove any existing DNS container first
	docker rm -f "$dns_container" >/dev/null 2>&1 || true

	# Create dnsmasq configuration based on default action
	local dns_config=""

	if [[ "$default_action" == "drop" ]]; then
		# ALLOWLIST MODE: Block everything by default, only allow whitelisted domains
		# address=/#/ returns NXDOMAIN for all domains not explicitly allowed
		dns_config="# Allowlist mode: block all domains by default\naddress=/#/\n\n"
		dns_config="${dns_config}# Allowed domains - forward to upstream DNS\n"

		# Add allowed domains (forward to upstream DNS)
		for domain in $allowed_domains; do
			# Skip comments and empty lines
			[[ "$domain" =~ ^#.*$ ]] && continue
			[[ -z "$domain" ]] && continue
			# Handle wildcards - remove leading *. if present
			domain="${domain#\*.}"
			# Forward queries for this domain to upstream DNS
			dns_config="${dns_config}server=/${domain}/8.8.8.8\n"
			dns_config="${dns_config}server=/${domain}/1.1.1.1\n"
		done

		# Also add blocked domains explicitly (for extra safety, in case upstream resolves them)
		if [[ -n "$blocked_domains" ]]; then
			dns_config="${dns_config}\n# Explicitly blocked domains (additional safety)\n"
			for domain in $blocked_domains; do
				[[ "$domain" =~ ^#.*$ ]] && continue
				[[ -z "$domain" ]] && continue
				domain="${domain#\*.}"
				dns_config="${dns_config}address=/${domain}/#\n"
			done
		fi
	else
		# BLOCKLIST MODE: Allow everything by default, block specific domains
		dns_config="# Blocklist mode: allow all, block specific domains\n"

		# Add blocked domains (return NXDOMAIN via address=/#)
		for domain in $blocked_domains; do
			# Skip comments and empty lines
			[[ "$domain" =~ ^#.*$ ]] && continue
			[[ -z "$domain" ]] && continue
			# Handle wildcards - dnsmasq uses address=/domain/# syntax
			# Remove leading *. if present
			domain="${domain#\*.}"
			dns_config="${dns_config}address=/${domain}/#\n"
		done
	fi

	# Start dnsmasq container
	# Using alpine with dnsmasq, configure to apply the generated rules
	# and forward unblocked queries to upstream DNS (8.8.8.8, 1.1.1.1)

	# Build IP flag for static IP assignment (used in restart scenarios)
	local ip_flag=""
	if [[ -n "$static_ip" ]]; then
		ip_flag="--ip $static_ip"
	fi

	local dns_id
	# Note: $ip_flag is intentionally unquoted to allow it to be empty or expand to --ip <value>
	# shellcheck disable=SC2086
	if ! dns_id=$(docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		$ip_flag \
		--label "devbox.container=$container_name" \
		--label "devbox.type=dns-proxy" \
		--label "devbox.dns.mode=$default_action" \
		--restart unless-stopped \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && mkdir -p /etc/dnsmasq.d && echo -e '$dns_config' > /etc/dnsmasq.d/devbox.conf && echo 'server=8.8.8.8' >> /etc/dnsmasq.conf && echo 'server=1.1.1.1' >> /etc/dnsmasq.conf && dnsmasq -k --log-queries --log-facility=-" 2>&1); then
		return 1
	fi

	# Wait for container to start and get IP address (max 30 seconds)
	local dns_ip=""
	local attempts=0
	local max_attempts=30
	while [[ -z "$dns_ip" ]] && [[ $attempts -lt $max_attempts ]]; do
		sleep 1
		dns_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null || true)
		((attempts++)) || true
	done

	if [[ -z "$dns_ip" ]]; then
		# Cleanup failed DNS proxy
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		return 1
	fi

	echo "$dns_ip"
	return 0
}

# Get DNS proxy IP address
# Usage: get_dns_proxy_ip <container_name>
get_dns_proxy_ip() {
	local container_name="$1"
	local dns_container="${container_name}-dns"

	docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null
}

# Restart DNS proxy with new profile configuration
# Usage: restart_dns_proxy <container_name> <profile> [static_ip] [profiles_dir] [apply_custom_rules]
# Preserves IP address to maintain connectivity for existing containers
# If apply_custom_rules is "true", also applies custom rules from container labels
# Returns new DNS proxy IP on success, empty on failure
restart_dns_proxy() {
	local container_name="$1"
	local profile="$2"
	local static_ip="${3:-}"
	local profiles_dir="${4:-$PROJECT_ROOT/profiles}"
	local apply_custom_rules="${5:-false}"

	# Load profile configuration
	if ! load_egress_profile "$profile" "$profiles_dir"; then
		return 1
	fi

	# Apply custom rules from container labels if requested
	if [[ "$apply_custom_rules" == "true" ]]; then
		apply_custom_rules_from_labels "$container_name"
	fi

	# For profiles that don't need DNS proxy, just return success
	if [[ "$EGRESS_NETWORK_MODE" == "none" ]] || [[ "$EGRESS_NETWORK_MODE" == "bridge" ]]; then
		return 0
	fi

	# If no static IP provided, try to get current DNS proxy IP
	if [[ -z "$static_ip" ]]; then
		static_ip=$(get_dns_proxy_ip "$container_name")
	fi

	# Call start_dns_proxy with profile settings and static IP
	# start_dns_proxy removes the old container before creating the new one
	local new_ip
	new_ip=$(start_dns_proxy \
		"$container_name" \
		"$EGRESS_ALLOWED_DOMAINS" \
		"$EGRESS_BLOCKED_DOMAINS" \
		"$EGRESS_DEFAULT_ACTION" \
		"$static_ip")

	if [[ -z "$new_ip" ]]; then
		return 1
	fi

	# Verify IP was preserved (warn if not)
	if [[ -n "$static_ip" ]] && [[ "$new_ip" != "$static_ip" ]]; then
		if declare -f log_warning >/dev/null 2>&1; then
			log_warning "DNS proxy IP changed from $static_ip to $new_ip"
			log_warning "Container may need restart to use new DNS proxy"
		fi
	fi

	echo "$new_ip"
	return 0
}

# Cleanup network resources for a container
# Usage: cleanup_network_resources <container_name>
cleanup_network_resources() {
	local container_name="$1"
	local dns_container="${container_name}-dns"
	local network_name="${container_name}-net"

	# Stop and remove DNS proxy container
	if docker rm -f "$dns_container" >/dev/null 2>&1; then
		# Log only if we have access to log_info (it may not be available)
		if declare -f log_info >/dev/null 2>&1; then
			log_info "DNS proxy removed"
		fi
	fi

	# Remove network (must be done after containers are removed)
	if docker network rm "$network_name" >/dev/null 2>&1; then
		if declare -f log_info >/dev/null 2>&1; then
			log_info "Egress network removed"
		fi
	fi

	return 0
}

# Format egress configuration for display
# Usage: format_egress_config
format_egress_config() {
	echo "  Profile: $EGRESS_PROFILE_NAME"
	if [[ -n "$EGRESS_PROFILE_DESCRIPTION" ]]; then
		echo "  Description: $EGRESS_PROFILE_DESCRIPTION"
	fi
	echo "  Network mode: $EGRESS_NETWORK_MODE"
	echo "  Default action: $EGRESS_DEFAULT_ACTION"

	if [[ -n "$EGRESS_ALLOWED_PORTS" ]]; then
		local ports
		# Clean up whitespace and format
		ports=$(echo "$EGRESS_ALLOWED_PORTS" | tr '\n' ' ' | tr -s ' ' | xargs)
		echo "  Allowed ports: $ports"
	fi

	if [[ -n "$EGRESS_ALLOWED_DOMAINS" ]]; then
		local count
		count=$(echo "$EGRESS_ALLOWED_DOMAINS" | tr '\n' ' ' | wc -w)
		echo "  Allowed domains: $count domain patterns"
	fi

	if [[ -n "$EGRESS_BLOCKED_DOMAINS" ]]; then
		local count
		count=$(echo "$EGRESS_BLOCKED_DOMAINS" | tr '\n' ' ' | wc -w)
		echo "  Blocked domains: $count domain patterns"
	fi
}

# Get the egress rules directory for a container
# Usage: get_egress_rules_dir <container_name>
# Returns the path to the egress rules directory
get_egress_rules_dir() {
	local container_name="$1"
	local devbox_dir="${DEVBOX_DATA_DIR:-$HOME/.devbox}"
	echo "$devbox_dir/egress-rules/$container_name"
}

# Store a custom egress rule for a container
# Usage: store_egress_rule <container_name> <rule_type> <value>
# rule_type: allow-domain, block-domain, allow-ip, block-ip, allow-port
store_egress_rule() {
	local container_name="$1"
	local rule_type="$2"
	local value="$3"

	local rules_dir
	rules_dir=$(get_egress_rules_dir "$container_name")

	# Create directory if it doesn't exist
	mkdir -p "$rules_dir"

	local rule_file="$rules_dir/${rule_type}s.txt"

	# Check if rule already exists
	if [[ -f "$rule_file" ]] && grep -qxF "$value" "$rule_file" 2>/dev/null; then
		return 0 # Already exists
	fi

	# Append the rule
	echo "$value" >>"$rule_file"
	return 0
}

# Get custom egress rules from files
# Usage: get_custom_egress_rules_from_labels <container_name>
# Note: Named for backwards compatibility, but reads from files not labels
# Outputs rules in format suitable for parsing:
#   ALLOW_DOMAIN domain1
#   ALLOW_DOMAIN domain2
#   BLOCK_DOMAIN domain1
#   ALLOW_IP 10.0.0.0/8
#   BLOCK_IP 192.168.0.0/16
#   ALLOW_PORT 8080
get_custom_egress_rules_from_labels() {
	local container_name="$1"

	local rules_dir
	rules_dir=$(get_egress_rules_dir "$container_name")

	# If rules directory doesn't exist, no custom rules
	[[ ! -d "$rules_dir" ]] && return 0

	# Read allow domains
	if [[ -f "$rules_dir/allow-domains.txt" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			[[ "$line" =~ ^#.*$ ]] && continue
			echo "ALLOW_DOMAIN $line"
		done <"$rules_dir/allow-domains.txt"
	fi

	# Read block domains
	if [[ -f "$rules_dir/block-domains.txt" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			[[ "$line" =~ ^#.*$ ]] && continue
			echo "BLOCK_DOMAIN $line"
		done <"$rules_dir/block-domains.txt"
	fi

	# Read allow IPs
	if [[ -f "$rules_dir/allow-ips.txt" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			[[ "$line" =~ ^#.*$ ]] && continue
			echo "ALLOW_IP $line"
		done <"$rules_dir/allow-ips.txt"
	fi

	# Read block IPs
	if [[ -f "$rules_dir/block-ips.txt" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			[[ "$line" =~ ^#.*$ ]] && continue
			echo "BLOCK_IP $line"
		done <"$rules_dir/block-ips.txt"
	fi

	# Read allow ports
	if [[ -f "$rules_dir/allow-ports.txt" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			[[ "$line" =~ ^#.*$ ]] && continue
			echo "ALLOW_PORT $line"
		done <"$rules_dir/allow-ports.txt"
	fi

	return 0
}

# Cleanup egress rules files for a container
# Usage: cleanup_egress_rules <container_name>
cleanup_egress_rules() {
	local container_name="$1"
	local rules_dir
	rules_dir=$(get_egress_rules_dir "$container_name")

	if [[ -d "$rules_dir" ]]; then
		rm -rf "$rules_dir"
	fi
}

# Apply custom egress rules from container labels to loaded profile
# Usage: apply_custom_rules_from_labels <container_name_or_id>
# Must be called after load_egress_profile to modify EGRESS_* variables
apply_custom_rules_from_labels() {
	local container="$1"

	local rules
	rules=$(get_custom_egress_rules_from_labels "$container") || return 0

	while IFS= read -r rule; do
		[[ -z "$rule" ]] && continue

		local rule_type="${rule%% *}"
		local rule_value="${rule#* }"

		case "$rule_type" in
		ALLOW_DOMAIN)
			EGRESS_ALLOWED_DOMAINS="$EGRESS_ALLOWED_DOMAINS $rule_value"
			;;
		BLOCK_DOMAIN)
			EGRESS_BLOCKED_DOMAINS="$EGRESS_BLOCKED_DOMAINS $rule_value"
			;;
		ALLOW_IP)
			EGRESS_ALLOWED_IPS="$EGRESS_ALLOWED_IPS $rule_value"
			;;
		BLOCK_IP)
			EGRESS_BLOCKED_IPS="$EGRESS_BLOCKED_IPS $rule_value"
			;;
		ALLOW_PORT)
			EGRESS_ALLOWED_PORTS="$EGRESS_ALLOWED_PORTS $rule_value"
			;;
		esac
	done <<<"$rules"

	return 0
}

# Get egress label value for container
# Usage: get_egress_label_value <profile> <custom_rules...>
get_egress_label_value() {
	local profile="$1"
	shift
	local custom_rules=("$@")

	local label_value="$profile"

	# Add custom rules indicator if any
	if [[ ${#custom_rules[@]} -gt 0 ]]; then
		label_value="${label_value}+custom"
	fi

	echo "$label_value"
}
