#!/bin/bash

# Function to prompt for input if not provided
prompt_input() {
    local var_name="$1"
    local prompt_message="$2"
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        read -p "$prompt_message: " var_value
        eval "$var_name=\"$var_value\""
    fi
}

# Function to prompt for yes/no input
prompt_yes_no() {
    local prompt_message="$1"
    local default_choice="$2"
    local choice
    while true; do
        read -p "$prompt_message (y/n): " choice
        choice="${choice:-$default_choice}"
        case "$choice" in
            y|Y ) echo "y"; return;;
            n|N ) echo "n"; return;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to sanitize module names
sanitize_module_name() {
    local module_name="$1"
    # Remove dots, underscores, and dashes
    echo "${module_name//[\._-]/}"
}

# Get input from command line arguments or prompt user
project_name="$1"
groupId="$2"
artifactId="$3"

prompt_input project_name "Enter project name"
prompt_input groupId "Enter groupId (e.g., com.company)"
prompt_input artifactId "Enter artifactId"

# Check if project directory already exists
if [ -d "$project_name" ]; then
    echo "Error: Directory '$project_name' already exists. Please choose a different project name."
    exit 1
fi

# Set initial variables
VERSION="0.0.1-SNAPSHOT"
BASE_DIR="$project_name"

# Fetch the latest Spring Boot version using sed
SPRING_BOOT_METADATA_URL="https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-dependencies/maven-metadata.xml"
SPRING_BOOT_VERSION=$(curl -sk "$SPRING_BOOT_METADATA_URL" | sed -n 's:.*<release>\(.*\)</release>.*:\1:p')
if [ -z "$SPRING_BOOT_VERSION" ]; then
    SPRING_BOOT_VERSION=$(curl -sk "$SPRING_BOOT_METADATA_URL" | sed -n 's:.*<latest>\(.*\)</latest>.*:\1:p')
fi

if [ -z "$SPRING_BOOT_VERSION" ]; then
    echo "Unable to retrieve Spring Boot version."
    exit 1
fi

echo "Using Spring Boot version: $SPRING_BOOT_VERSION"

# Fetch the latest Spring Cloud version using sed
SPRING_CLOUD_METADATA_URL="https://repo1.maven.org/maven2/org/springframework/cloud/spring-cloud-dependencies/maven-metadata.xml"
SPRING_CLOUD_VERSION=$(curl -sk "$SPRING_CLOUD_METADATA_URL" | sed -n 's:.*<release>\(.*\)</release>.*:\1:p')
if [ -z "$SPRING_CLOUD_VERSION" ]; then
    SPRING_CLOUD_VERSION=$(curl -sk "$SPRING_CLOUD_METADATA_URL" | sed -n 's:.*<latest>\(.*\)</latest>.*:\1:p')
fi

if [ -z "$SPRING_CLOUD_VERSION" ]; then
    echo "Unable to retrieve Spring Cloud version."
    exit 1
fi

echo "Using Spring Cloud version: $SPRING_CLOUD_VERSION"

# Read configurations from config file
CONFIG_FILE="pom_config.cfg"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Prompt once for creating additional directories
create_extra_dirs=$(prompt_yes_no "Do you want to create additional directories for modules?" "y")

# Create the base project directory
mkdir -p "$BASE_DIR"

# Initialize git repository
cd "$BASE_DIR" || exit
git init
cd .. || exit

# Function to create a pom.xml file
create_pom() {
    local dir="$1"
    local pom_template="$2"
    local artifact="$3"
    local parentGroupId="$4"
    local parentArtifactId="$5"
    local parentVersion="$6"
    local modules="$7"
    local packaging="$8"

    mkdir -p "$dir"

    # Replace placeholders in the POM template
    local pom_content="${pom_template//\$\{groupId\}/$groupId}"
    pom_content="${pom_content//\$\{artifactId\}/$artifact}"
    pom_content="${pom_content//\$\{version\}/$VERSION}"
    pom_content="${pom_content//\$\{parentGroupId\}/$parentGroupId}"
    pom_content="${pom_content//\$\{parentArtifactId\}/$parentArtifactId}"
    pom_content="${pom_content//\$\{parentVersion\}/$parentVersion}"
    pom_content="${pom_content//\$\{spring-boot.version\}/$SPRING_BOOT_VERSION}"
    pom_content="${pom_content//\$\{spring-cloud.version\}/$SPRING_CLOUD_VERSION}"
    pom_content="${pom_content//\$\{project_name\}/$project_name}"
    pom_content="${pom_content//\$\{packaging\}/$packaging}"

    # Handle modules
    if [ -n "$modules" ]; then
        local modules_xml=""
        for module in $modules; do
            modules_xml="$modules_xml        <module>$module</module>\n"
        done
        pom_content="${pom_content//\$\{modules_section\}/<modules>\n$modules_xml    </modules>}"
    else
        pom_content="${pom_content//\$\{modules_section\}/}"
    fi

    echo -e "$pom_content" > "$dir/pom.xml"
}

# Function to create directory structure
create_directories() {
    local base="$1"
    local module_path="$2"
    local module_type="$3"
    local module_parent="$4"
    local module_name="$5"

    # Sanitize module names
    local sanitized_module_name=$(sanitize_module_name "$module_name")

    # Build the Java package path
    IFS='.' read -ra GROUP_ID_PARTS <<< "$groupId"
    local package_path=""
    for part in "${GROUP_ID_PARTS[@]}"; do
        package_path="$package_path/$part"
    done

    # Include parent module in package path if it exists and is different from the root artifact ID
    if [ -n "$module_parent" ] && [ "$module_parent" != "$artifactId" ]; then
        package_path="$package_path/$(sanitize_module_name "$module_parent")"
    fi

    package_path="$package_path/$sanitized_module_name"

    # Base Java directory
    local java_base="$base/src/main/java$package_path"

    if [ "$create_extra_dirs" == "y" ]; then
        # Get the directory structure for this module from the configuration
        local upper_module_name=$(echo "$sanitized_module_name" | tr '[:lower:]' '[:upper:]')
        local dir_structure_var="DIRECTORY_STRUCTURE_${upper_module_name}"
        local dir_structure="${!dir_structure_var}"

        # If no specific directory structure is defined, use default
        if [ -z "$dir_structure" ]; then
            dir_structure="$DIRECTORY_STRUCTURE_DEFAULT"
        fi

        # Create directories
        create_directories_from_structure "$java_base" "$dir_structure"
    else
        # Only create base package directory
        mkdir -p "$java_base"
    fi
}

# Function to create directories from a structure string
create_directories_from_structure() {
    local base="$1"
    local structure="$2"

    IFS=$'\n'
    for line in $structure; do
        # Remove leading and trailing whitespaces
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        # Skip empty lines and comments
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi

        # Create directory
        mkdir -p "$base/$line"
    done
}

# Create project based on configuration
create_project() {
    local base_dir="$BASE_DIR"
    local parent_group_id="$groupId"
    local parent_artifact_id="$artifactId"
    local parent_version="$VERSION"

    # Create root POM
    create_pom "$base_dir" "$POM_TEMPLATE_ROOT" "$artifactId" "" "" "" "$PARENT_MODULES" "pom"

    # Create directories and modules
    IFS=$'\n'
    for module_info in $MODULES_CONFIG; do
        # Parse module information
        module_path=$(echo "$module_info" | cut -d':' -f1)
        module_type=$(echo "$module_info" | cut -d':' -f2)
        module_parent=$(echo "$module_info" | cut -d':' -f3)
        module_pom_template=$(echo "$module_info" | cut -d':' -f4)
        module_submodules=$(echo "$module_info" | cut -d':' -f5)

        # Replace placeholders in module_parent
        module_parent="${module_parent//\$\{artifactId\}/$artifactId}"

        module_dir="$base_dir/$module_path"
        module_artifactId="$(basename $module_path)"

        # Determine packaging
        if [ "$module_type" == "module" ]; then
            packaging="pom"
        else
            packaging="jar"
        fi

        # Create module POM
        create_pom "$module_dir" "${!module_pom_template}" "$module_artifactId" "$parent_group_id" "$module_parent" "$parent_version" "$module_submodules" "$packaging"

        # Create directories for leaf modules
        if [ "$module_type" == "leaf" ]; then
            create_directories "$module_dir" "$module_path" "$module_type" "$module_parent" "$module_artifactId"
        fi
    done
}

# Start creating the project
create_project

# Adjust SonarQube configurations to support modules
# Add a sonar-project.properties file at the root
cat > "$BASE_DIR/sonar-project.properties" <<EOF
sonar.projectKey=${groupId}:${artifactId}
sonar.projectName=${project_name}
sonar.projectVersion=${VERSION}
sonar.sourceEncoding=UTF-8
sonar.modules=$(echo $SONAR_MODULES | tr ' ' ',')
EOF

# Add module-specific configurations
for module in $SONAR_MODULES; do
    echo "Configuring SonarQube for module: $module"
    cat >> "$BASE_DIR/sonar-project.properties" <<EOF

# Module: $module
$module.sonar.projectName=$module
$module.sonar.projectBaseDir=$module
EOF
done

# Initialize git repository and add files
cd "$BASE_DIR" || exit
git add .
git commit -m "Initial project structure with SonarQube configurations"
cd .. || exit

# Package the project into a tar.gz file
tar -czf "${project_name}.tar.gz" "$project_name"

# Remove the created project directory
rm -rf "$project_name"

echo "Project '${project_name}' has been packaged as '${project_name}.tar.gz'."
