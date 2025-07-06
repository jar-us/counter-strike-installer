# Counter-Strike Installer Scripts

This repository contains shell scripts to automate the setup, installation, and cleanup of a Counter-Strike 1.6 dedicated server (HLDS) in a virtual machine environment.

## Scripts

- **hlds_installation.sh**: Installs and configures the HLDS server.
- **hlds_cleanup.sh**: Cleans up HLDS server files and related resources.
- **vm_setup.sh**: Sets up a virtual machine for hosting the server.
- **vm_delete.sh**: Deletes the virtual machine and associated resources.

## Usage

1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd counter-strike-installer
   ```
2. **Make scripts executable:**
   ```sh
   chmod +x *.sh
   ```
3. **Run the scripts as needed:**
   ```sh
   ./vm_setup.sh
   ./hlds_installation.sh
   # ...
   ./hlds_cleanup.sh
   ./vm_delete.sh
   ```

> **Note:** These scripts are intended for use on Unix-like systems (Linux/macOS). Ensure you have the necessary permissions and dependencies installed.

## License

MIT License

