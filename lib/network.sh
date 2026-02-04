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

	# Create isolated bridge network
	if docker network create \
		--driver bridge \
		--opt "com.docker.network.bridge.enable_icc=false" \
		--label "devbox.container=$container_name" \
		--label "devbox.type=egress-network" \
		"$network_name" >/dev/null 2>&1; then
		echo "$network_name"
		return 0
	fi

	return 1
}

# Start DNS proxy sidecar for domain filtering
# Usage: start_dns_proxy <container_name> <allowed_domains> <blocked_domains>
# Returns DNS proxy container ID on success
start_dns_proxy() {
	local container_name="$1"
	local allowed_domains="$2"
	local blocked_domains="$3"
	local dns_container="${container_name}-dns"
	local network_name="${container_name}-net"

	# Skip if permissive mode (no filtering needed)
	if [[ -z "$allowed_domains" ]] && [[ -z "$blocked_domains" ]]; then
		return 0
	fi

	# Create dnsmasq configuration
	local dns_config=""

	# Add blocked domains (return NXDOMAIN)
	for domain in $blocked_domains; do
		# Skip comments and empty lines
		[[ "$domain" =~ ^#.*$ ]] && continue
		[[ -z "$domain" ]] && continue
		# Handle wildcards - dnsmasq uses server=/domain/ syntax
		domain="${domain#\*.}" # Remove leading *.
		dns_config="${dns_config}address=/${domain}/#\n"
	done

	# For strict mode with allowlist, we'd need more complex configuration
	# For now, use dnsmasq in basic mode with upstream DNS

	# Start dnsmasq container
	local dns_id
	if dns_id=$(docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		--label "devbox.container=$container_name" \
		--label "devbox.type=dns-proxy" \
		--restart unless-stopped \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq && echo -e '$dns_config' > /etc/dnsmasq.d/devbox.conf && dnsmasq -k --log-queries --log-facility=-" 2>/dev/null); then
		echo "$dns_id"
		return 0
	fi

	return 1
}

# Get DNS proxy IP address
# Usage: get_dns_proxy_ip <container_name>
get_dns_proxy_ip() {
	local container_name="$1"
	local dns_container="${container_name}-dns"

	docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null
}

# Cleanup network resources for a container
# Usage: cleanup_network_resources <container_name>
cleanup_network_resources() {
	local container_name="$1"
	local dns_container="${container_name}-dns"
	local network_name="${container_name}-net"

	# Stop and remove DNS proxy container
	docker rm -f "$dns_container" >/dev/null 2>&1 || true

	# Remove network (must be done after containers are removed)
	docker network rm "$network_name" >/dev/null 2>&1 || true

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
