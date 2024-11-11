# Hexagonal Architecture Initializer

A Bash script to initialize a Java 21 project with a hexagonal architecture using Maven, Spring Boot, and Spring Cloud. This script automates the creation of a multi-module Maven project following best practices and allows for customization through configuration files.

## Features

- **Automated Project Setup**: Quickly generate a modular Maven project with a hexagonal architecture.
- **Latest Dependencies**: Automatically fetches the latest versions of Spring Boot and Spring Cloud.
- **Customizable Configuration**: All POM templates, module configurations, and directory structures are configurable via the `pom_config.cfg` file.
- **SonarQube Integration**: Configures SonarQube for multi-module project analysis.
- **Git Repository Initialization**: Initializes a Git repository and makes the initial commit.

## Project Structure

The generated project will have the following structure:

```
project-name (parent pom)
├── core (pom)
│   ├── domain (jar)
│   ├── application (pom)
│   │   ├── ports (jar)
│   │   └── service (jar)
│   └── shared-kernel (jar)
├── adapters (pom)
│   ├── web (jar)
│   ├── messaging (jar)
│   ├── persistence (jar)
│   └── client (jar)
├── container (jar)
└── pom.xml
```

## Requirements

- **Bash Shell**: Unix-based system with Bash installed.
- **Utilities**: `curl`, `sed`, and `git` must be installed and available in your system's PATH.
- **Java**: Java Development Kit (JDK) 21 installed (for building and running the project).
- **Maven**: Apache Maven installed (for project management).

## Usage

### 1. Clone the Repository

```bash
git clone https://github.com/sudoitir/hexagonal-architecture-initializer.git
cd hexagonal-architecture-initializer
```

### 2. Make the Script Executable

```bash
chmod +x initialize_project.sh
```

### 3. Customize Configuration (Optional)

Edit the `pom_config.cfg` file to customize:

- **POM Templates**: Adjust the parent, module, and leaf POM templates.
- **Module Configurations**: Modify the modules, their types, and relationships.
- **Directory Structure**: Define custom directories for leaf modules.
- **SonarQube Settings**: Configure SonarQube modules and properties.

### 4. Run the Script

Run the script and provide the required inputs when prompted:

```bash
./initialize_project.sh
```

**Alternatively**, provide the inputs as command-line arguments:

```bash
./initialize_project.sh MyHexagonalProject com.example myhexproject
```

### 5. Verify the Output

After running the script, you should see output similar to:

```
Using Spring Boot version: 3.3.5
Using Spring Cloud version: 2023.0.3
Initialized empty Git repository in /path/to/MyHexagonalProject/.git/
[master (root-commit) 0a1b2c3] Initial project structure with SonarQube configurations
 10 files changed, 200 insertions(+)
...
Project 'MyHexagonalProject' has been initialized and packaged as 'MyHexagonalProject.tar.gz'.
```

### 6. Extract and Inspect the Project

```bash
tar -xzf MyHexagonalProject.tar.gz
cd MyHexagonalProject
tree
```

## Configuration Details

All configurations are located in the `pom_config.cfg` file.

### POM Templates

- **Root POM** (`POM_TEMPLATE_ROOT`): Template for the parent `pom.xml`.
- **Module POM** (`POM_TEMPLATE_MODULE`): Template for modules containing sub-modules.
- **Leaf POM** (`POM_TEMPLATE_LEAF`): Template for modules without sub-modules.

### Modules Configuration (`MODULES_CONFIG`)

Define modules with the format:

```
module_path:module_type:module_parent:module_pom_template:module_submodules
```

- `module_path`: Path of the module relative to the base directory.
- `module_type`: `module` (contains sub-modules) or `leaf` (no sub-modules).
- `module_parent`: Artifact ID of the parent module.
- `module_pom_template`: POM template to use (`POM_TEMPLATE_MODULE` or `POM_TEMPLATE_LEAF`).
- `module_submodules`: Space-separated list of sub-modules (for modules of type `module`).

### Directory Structure (`DIRECTORY_STRUCTURE`)

Define directories to be created in leaf modules:

```
src/main/java/entity
src/main/java/event
src/main/java/valueobject
src/main/java/service
src/main/java/handler
src/main/java/mapper
```

### SonarQube Modules (`SONAR_MODULES`)

Specify, which modules to include in SonarQube analysis:

```
SONAR_MODULES="core adapters container"
```

## Customization

### Adding or Modifying Modules

Edit the `MODULES_CONFIG` in `pom_config.cfg` to add or remove modules. Ensure you follow the correct format and update the `PARENT_MODULES` and `SONAR_MODULES` variables accordingly.

### Adjusting Directory Structures

Modify the `DIRECTORY_STRUCTURE` variable to change the directories created within leaf modules.

### Modifying POM Templates

Customize the POM templates (`POM_TEMPLATE_ROOT`, `POM_TEMPLATE_MODULE`, `POM_TEMPLATE_LEAF`) to include additional properties, dependencies, plugins, or other configurations.

## Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the Repository**: Click on the 'Fork' button on GitHub.
2. **Create a Feature Branch**: `git checkout -b feature/YourFeature`
3. **Commit Your Changes**: `git commit -m 'feat: Add some feature'`
4. **Push to the Branch**: `git push origin feature/YourFeature`
5. **Open a Pull Request**: Submit your changes for review.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions or suggestions, please open an issue on GitHub or contact [mahdi@sudoit.ir](mailto:mahdi@sudoit.ir).
