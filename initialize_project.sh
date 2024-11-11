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

# Get input from command line arguments or prompt user
project_name="$1"
groupId="$2"
artifactId="$3"

prompt_input project_name "Enter project name"
prompt_input groupId "Enter groupId"
prompt_input artifactId "Enter artifactId"

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

# Create the base project directory
mkdir -p "$BASE_DIR"

# Initialize git repository
cd "$BASE_DIR" || exit
git init
cd ..

# Function to create a pom.xml file
create_pom() {
    local dir="$1"
    local pom_template="$2"
    local artifact="$3"
    local parentGroupId="$4"
    local parentArtifactId="$5"
    local parentVersion="$6"
    local modules="$7"

    mkdir -p "$dir"

    # Replace placeholders in the POM template
    local pom_content="${pom_template//\$\{groupId\}/$groupId}"
    pom_content="${pom_content//\$\{artifactId\}/$artifact}"
    pom_content="${pom_content//\$\{version\}/$VERSION}"
    pom_content="${pom_content//\$\{parentGroupId\}/$parentGroupId}"
    pom_content="${pom_content//\$\{parentArtifactId\}/$parentArtifactId}"
    pom_content="${pom_content//\$\{parentVersion\}/$parentVersion}"
    pom_content="${pom_content//\$\{SPRING_BOOT_VERSION\}/$SPRING_BOOT_VERSION}"
    pom_content="${pom_content//\$\{SPRING_CLOUD_VERSION\}/$SPRING_CLOUD_VERSION}"
    pom_content="${pom_content//\$\{modules\}/$modules}"
    pom_content="${pom_content//\$\{project_name\}/$project_name}"

    echo "$pom_content" > "$dir/pom.xml"
}

# Function to create directory structure
create_directories() {
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
    create_pom "$base_dir" "$POM_TEMPLATE_ROOT" "$artifactId" "" "" "" "$PARENT_MODULES"

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

        # Create module POM
        create_pom "$module_dir" "${!module_pom_template}" "$(basename $module_path)" "$parent_group_id" "$module_parent" "$parent_version" "$module_submodules"

        # Create directories for leaf modules
        if [ "$module_type" == "leaf" ]; then
            create_directories "$module_dir" "$DIRECTORY_STRUCTURE"
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
sonar.modules=$(echo "$SONAR_MODULES" | tr ' ' ',')
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
cd ..

# Package the project into a tar.gz file
tar -czf "${project_name}.tar.gz" "$project_name"

echo "Project '${project_name}' has been initialized and packaged as '${project_name}.tar.gz'."
rm -rf "$BASE_DIR" || exit # Cleanup
