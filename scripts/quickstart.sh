#!/usr/bin/env bash

# Quickstart script to install arkpy CLI tool

set -e -o pipefail

# Configuration
ARK_CONTROLLER_NAME="ark-controller"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
white='\033[1;37m'
blue='\033[0;34m'
black='\033[0;30m'
b="\033[1m"
dim="\033[2m"
nc='\033[0m'

bg_red="\033[48;5;9m"
bg_blue="\033[48;5;4m"
bg_green="\033[48;5;2m"
bg_yellow="\033[48;5;3m"
bg_white="\033[48;5;15m"

error_exit() {
    log_error "$1" "$2" >&2
    exit 1
}

log_error() {
    local message="$1"
    local details="$2"
    echo -e "${b}${bg_red}${white}[ERROR]${nc} ${message}"
    if [[ -n "$details" ]]; then
        echo -e "$details" | sed 's/^/        /'
    fi
}

log_info() {
    local message="$1"
    local details="$2"
    echo -e " ${b}${bg_blue}${white}[INFO]${nc} ${message}"
    if [[ -n "$details" ]]; then
        echo -e "$details" | sed 's/^/        /'
    fi
}

log_ok() {
    local message="$1"
    local details="$2"
    echo -e "   ${b}${bg_green}${white}[OK]${nc} ${message}"
    if [[ -n "$details" ]]; then
        echo -e "$details" | sed 's/^/        /'
    fi
}

log_warn() {
    local message="$1"
    local details="$2"
    echo -e " ${b}${bg_yellow}${white}[WARN]${nc} ${message}"
    if [[ -n "$details" ]]; then
        echo -e "$details" | sed 's/^/        /'
    fi
}

# Helper function for a generic, free-form prompt
prompt_freeform() {
    local message="$1"
    local default="${2:-}"
    local reply

    if [ -n "${ARK_QUICKSTART_USE_DEFAULTS}" ]; then
        reply="$default"
    else
        printf "    ${b}${bg_white}${black}[?]${nc} $message (default: $default): "
        read -r reply < /dev/tty
    fi

    # If empty input, use default
    if [ -z "$reply" ]; then
        reply="$default"
    fi
    
    echo "$reply"
    return 0
}

# Helper function to prompt and check if user confirmed (yes or empty)
prompt_yes_no() {
    local message="$1"
    local default="${2:-y}"  # `y` or `n`. Defaults to `y`
    local reply
    
    if [ -n "${ARK_QUICKSTART_USE_DEFAULTS}" ]; then
        reply="$default"
    else
        # If default is Y
        local help_text="Y/n"
        if [ "$default" = "n" ]; then
            help_text="y/N"
        fi
        
        printf "    ${b}${bg_white}${black}[?]${nc} $message ($help_text): "
        read -r reply < /dev/tty
    fi
    
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;  # User types YES et al.
        [Nn]|[Nn][Oo]) return 1 ;;      # User types NO et al.
        "") [ "$default" = "y" ] && return 0 || return 1 ;; # User types nothing
        *) return 1 ;;  # User types invalid input
    esac
}

prompt_choice_with_default() {
    local prompt_message="$1"
    local default_behavior="$2"  # "reprompt" if user cannot just press Enter, or "default" if pressing Enter uses the default option
    shift 2  # Remove first two arguments, leaving only the options
    local options=("$@")
    local num_options=${#options[@]}
    local choice
    
    if [[ "$default_behavior" != "reprompt" && "$default_behavior" != "default" ]]; then
        error_exit "Script error" "default_behavior must be 'reprompt' or 'default'"
    fi

    if [ $num_options -eq 0 ]; then
        error_exit "Script error" "No options provided to prompt_choice_with_default"
    fi
    
    if [ -n "${ARK_QUICKSTART_USE_DEFAULTS}" ]; then
        echo "${options[0]}"  # First option is the default
        return 0
    fi
    
    while true; do
        echo -e "    ${b}${bg_white}${black}[?]${nc} ${prompt_message}:" >&2
        
        # Display enumerated options
        for i in "${!options[@]}"; do
            echo "        $i) ${options[i]}" >&2
        done
        
        # Prompt user for choice
        if [ "$default_behavior" = "default" ]; then
            read -r -p "        Enter choice [0-$(($num_options - 1)) or option name] (default: 0): " choice
        else
            read -r -p "        Enter choice [0-$(($num_options - 1)) or option name]: " choice
        fi
        
        # Handle empty input
        if [ -z "$choice" ]; then
            if [ "$default_behavior" = "default" ]; then
                echo "${options[0]}"
                return 0
            else
                log_error "Invalid input - No choice provided" >&2
                continue
            fi
        fi
        
        # Check if input is a valid number within range
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 0 ] && [ "$choice" -le "$(($num_options - 1))" ]; then
                echo "${options[$choice]}"
                return 0
            else
                log_error "Invalid input - The number $choice is out of the range (0-$((num_options - 1)))" >&2
                continue
            fi
        fi
        
        # Check if input matches any option name (case-insensitive)
        for option in "${options[@]}"; do
            if [[ "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" == "$(echo "$option" | tr '[:upper:]' '[:lower:]')" ]]; then
                echo "$option"
                return 0
            fi
        done
        
        log_error "Invalid input: '$choice' is not a valid option" >&2
    done
}

# Array to hold manual instructions for installed tools
MANUAL_INSTRUCTIONS=()

quickstart() {
    # Check if we're in the project root
    if [ ! -f "version.txt" ]; then
        error_exit "quickstart.sh must run from project root directory" "version.txt not found"
    fi

    # Show version banner
    version=$(cat version.txt | tr -d '\n')
    log_info "ARK v${version}"

    # Read .ark.env if it exists
    if [ -e .ark.env ]; then
        source .ark.env

        details=""

        [ -n "${ARK_QUICKSTART_USE_DEFAULTS}" ] && details+="ARK_QUICKSTART_USE_DEFAULTS: ${ARK_QUICKSTART_USE_DEFAULTS}\n"
        [ -n "${ARK_QUICKSTART_MODEL_TYPE}" ] && details+="ARK_QUICKSTART_MODEL_TYPE: ${ARK_QUICKSTART_MODEL_TYPE}\n"
        [ -n "${ARK_QUICKSTART_MODEL_VERSION}" ] && details+="ARK_QUICKSTART_MODEL_VERSION: ${ARK_QUICKSTART_MODEL_VERSION}\n"
        [ -n "${ARK_QUICKSTART_BASE_URL}" ] && details+="ARK_QUICKSTART_BASE_URL: ${ARK_QUICKSTART_BASE_URL}\n"
        [ -n "${ARK_QUICKSTART_API_VERSION}" ] && details+="ARK_QUICKSTART_API_VERSION: ${ARK_QUICKSTART_API_VERSION}\n"
        [ -n "${ARK_QUICKSTART_API_KEY}" ] && details+="ARK_QUICKSTART_API_KEY: (hidden)\n"
        [ -n "${ARK_QUICKSTART_CONTROLLER_IMAGE}" ] && details+="ARK_QUICKSTART_CONTROLLER_IMAGE: ${ARK_QUICKSTART_CONTROLLER_IMAGE} (enables image caching)\n"

        if [ -n "$details" ]; then
            log_info "Using the following environment variables from .ark.env" "$details"
        fi
    fi
    # Ensure manual instructions are always printed before the script ends
    trap print_manual_instructions EXIT

    # Check essential development tools
    check_tool "brew" "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    check_tool "uv" "brew install uv"
    check_tool "node" "brew install node"
    check_tool "timeout" "brew install coreutils" 
    check_tool "ruff" "brew install ruff"
    check_tool "go" "brew install go"
    check_tool "envsubst" "brew install gettext"
    check_tool "yq" "brew install yq"
    check_tool "kubectl" "brew install kubectl"
    check_tool "docker" "brew install --cask docker"
    check_tool "helm" "brew install helm"
    check_tool "npm" "brew install node && npm install -g typescript && npm i -D @types/node"
    check_tool "fark" "make fark-build && make fark-install" "Add \$HOME/.local/bin to your PATH"
    check_tool "ark" "make ark-cli-install"
    check_tool "java" "brew install openjdk"
    check_optional_tool "k9s" "brew install k9s"
    check_optional_tool "chainsaw" "brew tap kyverno/chainsaw https://github.com/kyverno/chainsaw && brew install kyverno/chainsaw/chainsaw"

    # Check if docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        error_exit "Docker daemon is not running" "Start Docker Desktop or the Docker daemon"
    else
        log_info "Docker daemon running"
    fi

    # Create local Kubernetes cluster
    if kubectl cluster-info > /dev/null 2>&1; then
        log_info "Kubernetes cluster accessible" "$(kubectl cluster-info)"
    else
        log_warn "No Kubernetes cluster is accessible"
        choice=$(prompt_choice_with_default "Choose a tool to create a cluster" "default" "kind" "minikube")
        if [ "$choice" = "kind" ]; then
            check_tool "kind" "brew install kind"
            log_ok "Kind is installed"
            log_info "Creating Kind cluster"
            kind create cluster
            log_info "Kind cluster created"
        elif [ "$choice" = "minikube" ]; then
            check_tool "minikube" "brew install minikube"
            log_ok "Minikube is installed"
            log_info "Creating Minikube cluster"
            minikube start
            log_info "Minikube cluster created"
        fi
    fi

    # Note: CRDs will be installed automatically by 'make deploy' via Helm
    log_info "Cluster resources (CRDs) will be installed automatically during deployment"

    # Check ark controller status, will warn the user if not deployed.
    check_ark_controller

    # Webhook health check
    log_info "Testing webhook connectivity..."
    if ! kubectl get agent sample-agent >/dev/null 2>&1; then
        log_warn "Webhook may not be ready, restarting controller..."
        kubectl delete pod -l app.kubernetes.io/name=ark-controller -n ark-system
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ark-controller -n ark-system --timeout=60s
    fi

    # Check for default model (cluster is now running and kubectl should work)
    if kubectl get model default >/dev/null 2>&1; then
        log_info "Default model is already configured"
    else
        log_warn "No default model configured"
        if prompt_yes_no "Create default model?"; then
            # Use environment variables if set, otherwise prompt
            model_type=${ARK_QUICKSTART_MODEL_TYPE:-$(prompt_choice_with_default "Model type" "default" "azure" "openai")}
            model_version=${ARK_QUICKSTART_MODEL_VERSION:-$(prompt_freeform "Enter your model version" "gpt-4.1-mini")}
            base_url=${ARK_QUICKSTART_BASE_URL:-$(prompt_freeform "Enter your base URL")}

            # Remove trailing slash from base URL (if any)
            base_url=$(echo "$base_url" | sed 's:/*$::')

            # Ask for API version only if Azure
            if [ "$model_type" = "azure" ]; then
                API_VERSION=${ARK_QUICKSTART_API_VERSION:-$(prompt_freeform "Enter your Azure API version" "2024-12-01-preview")}
            else
                API_VERSION=""
            fi
            
            api_key=${ARK_QUICKSTART_API_KEY:-}
            if [ -z "$api_key" ]; then
                read -s -n 2000 -p  "enter your API key: "   api_key
                echo
            fi
            # Convert to base64 without line wrapping or spaces
            api_key=$(echo -n "$api_key" | base64 | tr -d '\n' | tr -d ' ')
            
            if [ -n "$api_key" ] && [ -n "$base_url" ]; then
                # Use envsubst to apply the configuration
                API_KEY="$api_key" envsubst < samples/quickstart/secret.yaml | kubectl apply -f -
                if [ "$model_type" = "azure" ]; then
                    BASE_URL="$base_url" MODEL_TYPE="$model_type" MODEL_VERSION="$model_version" API_VERSION="$API_VERSION" envsubst < samples/quickstart/azure.model.yaml | kubectl apply -f -
                else
                    BASE_URL="$base_url" MODEL_TYPE="$model_type" MODEL_VERSION="$model_version" envsubst < samples/quickstart/openai.model.yaml | kubectl apply -f -
                fi
                
                log_ok "Default model configured"
            else
                log_warn "Skipping default model setup"
            fi
        else
            log_warn "Skipping default model setup"
        fi
    fi

    if kubectl get model default >/dev/null 2>&1; then
        # Check for sample agent
        if kubectl get agent sample-agent >/dev/null 2>&1; then
            kubectl patch agent sample-agent --type='merge' -p='{"spec":{"modelRef":{"name":"default"}}}'
            # Add a simple tool to avoid empty tools array that causes Azure OpenAI API errors
            kubectl apply -f samples/tools/get-coordinates.yaml > /dev/null 2>&1 || true
            kubectl patch agent sample-agent --type='merge' -p='{"spec":{"tools":[{"type":"custom","name":"get-coordinates"}]}}'
            
            log_ok "Sample agent re-configured"
        else
            log_warn "No sample agent found"
            if prompt_yes_no "Create sample agent?"; then
                # Create sample agent based on the sample
                kubectl apply -f samples/tools/get-coordinates.yaml > /dev/null 2>&1 || true
                cat << EOF | kubectl apply -f -
apiVersion: ark.mckinsey.com/v1alpha1
kind: Agent
metadata:
  name: sample-agent
spec:
  prompt: You're a helpful assistant. Provide clear and concise answers.
  modelRef:
    name: default
  tools:
    - type: custom
      name: get-coordinates
EOF
                log_ok "Sample agent created"
            else
                log_warn "Skipping sample agent setup"
            fi
        fi

        # Test end-to-end functionality with a sample query
        log_info "Testing system with sample query..."
        if query_output=$(./scripts/query.sh agent/sample-agent "what is 2+2?" 2>&1); then
            log_ok "Test query succeeded"
        else
            log_warn "Test query failed - system may not be fully ready"
            # Check for specific error types
            if echo "$query_output" | grep -i -q "401\|403\|forbidden\|authentication\|unauthorized"; then
                local error_details="This usually means your API key or credentials are invalid.
To fix this, "
                if [ -f ".ark.env" ]; then
                    error_details+="edit your existing .ark.env file.\n"
                else
                    error_details+="create a new .ark.env file using .ark.env.local file as a template
    cp .ark.env.local .ark.env\n"
                fi
                error_details+="Update these values:
  ARK_QUICKSTART_API_KEY=your_actual_api_key
  ARK_QUICKSTART_BASE_URL=your_actual_base_url

  Run ${red}make quickstart-reconfigure-default-model${nc} to reconfigure the default model.
  Then run the ${red}make quickstart${nc} script again.
  
  ${red}Exiting due to authentication failure.${nc}"
                error_exit "Authentication/authorization failed" "$error_details"
            elif echo "$query_output" | grep -q "timeout\|timed out"; then
                log_warn "Query timed out - the system may be slow to respond" "Try running a query manually: fark agent sample-agent \"what is 2+2?\""
            else
                log_warn "Check controller logs for more details" "  kubectl logs -n ark-system deployment/ark-controller"
            fi
        fi
    else
        log_warn "No default model found - skipping sample-agent creation"
    fi


    # Check if dashboard is already installed
    dashboard_installed=false
    if kubectl get deployment -n default ark-dashboard > /dev/null 2>&1; then
        log_ok "ARK dashboard installed"
        dashboard_installed=true
    else
        log_warn "ark dashboard not installed"
        if prompt_yes_no "Install ARK dashboard?"; then
            echo "Installing ARK dashboard..."
            if make -j2 ark-dashboard-install; then
                log_ok "ARK dashboard installed"
                dashboard_installed=true
            else
                log_error "Failed to install ark dashboard" "install manually with: make -j2 ark-dashboard-install"
            fi
        else
            log_warn "Skipping ARK dashboard installation"
        fi
    fi

    # Check if ark-api is already installed
    api_installed=false
    if kubectl get deployment -n default ark-api > /dev/null 2>&1; then
        log_ok "ARK API installed"
        api_installed=true
    else
        log_warn "ARK API not installed"
        if prompt_yes_no "Install ARK API?"; then
            echo "Installing ARK API..."
            if make -j2 ark-api-install; then
                log_ok "ARK API installed"
                api_installed=true
            else
                log_error "Failed to install ARK API" "install manually with: make -j2 ark-api-install"
            fi
        else
            log_warn "Skipping ARK API installation"
        fi
    fi

    # If dashboard is installed, check port forwarding status
    if [ "$dashboard_installed" = true ]; then
        # Check if port forwarding is already running
        if pgrep -f "kubectl.*port-forward.*8080:80" > /dev/null; then
            log_ok "Dashboard port forward already running on localhost:8080"
        else
            if prompt_yes_no "Forward dashboard to localhost:8080?"; then
                log_info "Starting port forward to localhost:8080..."
                kubectl port-forward -n ark-system service/localhost-gateway-nginx 8080:80 > /dev/null 2>&1 &
                PORT_FORWARD_PID=$!
                sleep 2
                # Check if port forward is still running
                if kill -0 $PORT_FORWARD_PID 2>/dev/null; then
                    log_ok "Dashboard port forward started on localhost:8080"
                else
                    log_warn "Failed to start port forward - port 8080 may be in use" "try manually: kubectl port-forward -n ark-system service/localhost-gateway-nginx <port>:80"
                fi
            fi
        fi
    fi

    local completion_details="Try:\n"

    if [ "$dashboard_installed" = true ]; then
    	completion_details+="  dashboard:     ${blue}http://dashboard.127.0.0.1.nip.io:8080/${nc}\n"
    fi
    if [ "$api_installed" = true ]; then
    	completion_details+="  api:           ${blue}http://dashboard.127.0.0.1.nip.io:8080/api/docs/${nc} or ${blue}http://ark-api.127.0.0.1.nip.io:8080/docs/${nc}\n"
    fi
    completion_details+="  docs:          ${blue}https://mckinsey.github.io/agents-at-scale-ark/${nc}
  show agents:   ${b}${bg_white}${black}kubectl get agents${nc}
  run a query:   ${b}${bg_white}${black}fark agent sample-agent \"what is 2+2?\"${nc}
  new project:   ${b}${bg_white}${black}ark generate project my-agents${nc}
  ark help:      ${b}${bg_white}${black}ark --help${nc}
                 ${b}${bg_white}${black}fark completion zsh > ~/.fark-completion && echo 'source ~/.fark-completion' >> ~/.zshrc${nc} # install auto-complete
  check cluster: ${b}${bg_white}${black}k9s${nc}"
    # echo -e "  dev server:    ${white}make dev${nc}"
    # echo -e "  add services:  ${white}make services${nc}"
    log_ok "Quickstart complete!" "$completion_details"
}

# Helper function to check tools
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

check_tool_common() {
    local cmd="$1"
    local install_cmd="$2"
    local instructions="$3"
    local required="${4:-true}"

    if is_installed $cmd; then
        log_info "$cmd already installed${dim} at $(command -v $cmd)${nc}"
    else
        log_warn "$cmd not found"
        if prompt_yes_no "Install $cmd?"; then
            log_info "Installing $cmd..."
            if eval "$install_cmd" >/dev/null 2>&1; then
                log_ok "$cmd installed successfully at $(command -v $cmd)"
                if [[ -n "$instructions" ]]; then
                    MANUAL_INSTRUCTIONS+=("$instructions")
                fi
            else
                if [ "$required" = true ]; then
                    error_exit "Failed to install $cmd" "Install manually with: $install_cmd"
                else
                    log_warn "Failed to install $cmd" "Install manually with: $install_cmd"
                    log_warn "$cmd is optional. Continuing..."
                fi
            fi
        else
            if [ "$required" = true ]; then
                error_exit "$cmd is required for development" "Install with: $install_cmd"
            else
                log_warn "Skipping optional dependency $cmd. Continuing..."
            fi
        fi
    fi
}

check_tool() {
    check_tool_common "$1" "$2" "$3" true
}

check_optional_tool() {
    check_tool_common "$1" "$2" "$3" false
}

print_manual_instructions() {
    if [ ${#MANUAL_INSTRUCTIONS[@]} -gt 0 ]; then
        local details=""
        for instruction in "${MANUAL_INSTRUCTIONS[@]}"; do
            details+="${instruction}\n"
        done
        log_warn "Please manually carry out the instructions below:" "$details"
    fi
}

# Helper function to check ark controller status.
check_ark_controller() {
    # Has the controller manager been deployed? Is it available?
    if kubectl get deployment -n ark-system ${ARK_CONTROLLER_NAME} > /dev/null 2>&1; then
        if kubectl wait --for=condition=available --timeout=5s deployment/${ARK_CONTROLLER_NAME} -n ark-system > /dev/null 2>&1; then
            version=$(kubectl get pods -n ark-system -l app.kubernetes.io/name=${ARK_CONTROLLER_NAME} -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/version}')
            log_info "ARK controller running version ${white}${version}${nc}"
        else
            log_warn "ARK controller not running"
        fi
    else
        log_warn "ARK controller not deployed"
        if prompt_yes_no "Deploy ARK controller (this can take some time)?"; then
            log_info "Deploying ARK controller..."
            if ! (cd ark && IMAGE="${ARK_QUICKSTART_CONTROLLER_IMAGE:-${ARK_CONTROLLER_NAME}}" IMAGE_TAG="${ARK_QUICKSTART_CONTROLLER_TAG:-latest}" make deploy); then
                log_error "Deployment failed" "If you see CRD ownership errors, this means you have an old ARK installation.
Please recreate your local cluster to start fresh.

For minikube: minikube delete && minikube start
For kind: kind delete cluster && kind create cluster"
                return
            fi
            # Wait for controller to be ready before webhook validation can work
            kubectl wait --for=condition=available deployment/${ARK_CONTROLLER_NAME} -n ark-system --timeout=300s
            log_ok "ARK controller deployed"
        else
            log_warn "Skipping ARK controller deployment"
        fi
    fi
}

# Run the quickstart
quickstart
