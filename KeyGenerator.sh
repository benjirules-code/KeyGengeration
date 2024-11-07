#!/bin/bash

# Function to generate RSA key
generate_rsa_key() {
    local key_size=$1
    local key_alias=$2
    local ca_cert=$3
    local ca_key=$4
    if [[ -z $ca_cert || -z $ca_key ]]; then
        openssl genrsa -out "$key_alias.pem" "$key_size"
    else
        openssl req -new -keyout "$key_alias.key" -out "$key_alias.csr" -subj "/CN=$key_alias"
        openssl x509 -req -in "$key_alias.csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial -out "$key_alias.pem"
    fi
}

# Function to generate ECDSA key
generate_ecdsa_key() {
    local key_type=$1
    local key_size=$2
    local key_alias=$3
    local ca_cert=$4
    local ca_key=$5
    if [[ -z $ca_cert || -z $ca_key ]]; then
        openssl ecparam -genkey -name "$key_type" -out "$key_alias.pem" -param_enc explicit -outform PEM
    else
        openssl req -new -keyout "$key_alias.key" -out "$key_alias.csr" -subj "/CN=$key_alias"
        openssl x509 -req -in "$key_alias.csr" -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial -out "$key_alias.pem"
    fi
}

# Function to prompt for expiry date
prompt_expiry_date() {
    read -p "Enter the number of days for the key validity (default is 365 days): " days_input
    days_input=${days_input:-365} # Default to 365 days if no input is provided
    if [[ ! $days_input =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid number."
        prompt_expiry_date
    fi
    days=$days_input
}

# Function to prompt for alias
prompt_alias() {
    read -p "Enter the alias for the key (default is key_$i): " alias_input
    alias=${alias_input:-key_$i} # Default to key_$i if no input is provided
}

# Function to prompt for encryption method
prompt_encryption_method() {
    local encryption_methods=("RSA" "ECDSA")
    PS3="Select encryption method: "
    select encryption_method in "${encryption_methods[@]}"; do
        case $encryption_method in
            "RSA") prompt_rsa_key_size; break ;;
            "ECDSA") prompt_ecdsa_key_size; break ;;
            *) echo "Invalid option. Please select again." ;;
        esac
    done
}

# Function to prompt for RSA key size
prompt_rsa_key_size() {
    local rsa_key_sizes=(2048 3072 4096)
    PS3="Select RSA key size in bits: "
    select key_size in "${rsa_key_sizes[@]}"; do
        if [[ -n $key_size ]]; then
            break
        else
            echo "Invalid option. Please select again."
        fi
    done
}

# Function to prompt for ECDSA key size
prompt_ecdsa_key_size() {
    local ecdsa_key_sizes=(256 384 521)
    PS3="Select ECDSA key size in bits: "
    select key_size in "${ecdsa_key_sizes[@]}"; do
        if [[ -n $key_size ]]; then
            break
        else
            echo "Invalid option. Please select again."
        fi
    done
}

# Function to prompt for CA signing or self-signing
prompt_ca_or_self_sign() {
    local sign_options=("CA" "Self-Signed")
    PS3="Select signing option: "
    select sign_option in "${sign_options[@]}"; do
        case $sign_option in
            "CA") ca_sign=true; break ;;
            "Self-Signed") ca_sign=false; break ;;
            *) echo "Invalid option. Please select again." ;;
        esac
    done
}

# Function to prompt for CA certificate and key paths
prompt_ca_paths() {
    read -p "Enter the path to the CA certificate file (leave blank for self-signing): " ca_cert_input
    ca_cert=${ca_cert_input:-""}
    if [[ -n $ca_cert ]]; then
        read -p "Enter the path to the CA key file: " ca_key_input
        ca_key=$ca_key_input
    else
        ca_key=""
    fi
}

# Function to convert days to expiry date
convert_expiry_date() {
    local expiry_days=$((current_date + days * 86400)) # 86400 seconds in a day
    expiry_date=$(date -d "@$expiry_days" "+%Y-%m-%d")
}

# Function to log key alias, expiry date, and size
log_to_file() {
    local key_size=$(wc -c < "$alias.pem")
    echo "$alias: $expiry_date (Size: $key_size bytes)" >> key_expiry_log.txt
}

# Function to generate keys based on user input
generate_keys() {
    # Get the current date in seconds
    current_date=$(date +%s)
    echo "Current date: $(date "+%Y-%m-%d")"

    # Prompt for the number of keys to generate
    read -p "Enter the number of keys to generate: " num_keys

    # Loop to generate keys
    for ((i=1; i<=$num_keys; i++)); do
        echo "Generating Key $i"

        # Prompt for alias
        prompt_alias

        # Prompt for encryption method
        prompt_encryption_method

        # Prompt for CA signing or self-signing
        prompt_ca_or_self_sign

        # Prompt for CA certificate and key paths if signing with CA
        if $ca_sign; then
            prompt_ca_paths
        fi

        # Check if key with the same alias exists in the log file
        if grep -q "^$alias:" key_expiry_log.txt; then
            echo "Key with alias '$alias' already exists. Deleting the existing key..."
            rm "$alias.pem"
            sed -i "/^$alias:/d" key_expiry_log.txt
        fi

        if [[ $encryption_method == "RSA" ]]; then
            generate_rsa_key "$key_size" "$alias" "$ca_cert" "$ca_key"
        elif [[ $encryption_method == "ECDSA" ]]; then
            generate_ecdsa_key "prime256v1" "$key_size" "$alias" "$ca_cert" "$ca_key"
        fi

        # Prompt for expiry date in days
        prompt_expiry_date

        # Convert days to expiry date
        convert_expiry_date

        # Log alias, expiry date, and size
        log_to_file

        echo "Key $i generated with alias '$alias', expiry date '$expiry_date', and size $(wc -c < "$alias.pem") bytes"

        # Reset alias and days
        alias=""
        days=""
    done

    echo "Key generation and expiry assignment completed. Check key_expiry_log.txt for details."
}

# Function to display menu
display_menu() {
    echo "Key Management System"
    echo "1. Generate Keys"
    echo "2. Exit"
}

# Main script
while true; do
    display_menu
    read -p "Select an option: " choice
    case $choice in
        1) generate_keys ;;
        2) echo "Exiting..."; exit ;;
        *) echo "Invalid option. Please select again." ;;
    esac
done
