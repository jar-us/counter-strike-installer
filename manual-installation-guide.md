### Complete Manual Installation Guide

**Step 1: System Preparation (Update and Add 32-bit Support)**

First, we update the server's software list and enable the system to recognize and install 32-bit programs, which is required for the HLDS server.

```shell
# Enable the 32-bit architecture
sudo dpkg --add-architecture i386

# Update package lists to include new 32-bit packages
sudo apt-get update

# Upgrade existing packages to ensure system is current
sudo apt-get upgrade -y
```

  * **Explanation:** The `dpkg --add-architecture i386` command is the critical first step that tells your 64-bit Ubuntu system that it's allowed to look for and install 32-bit software.

**Step 2: Install All Necessary Dependencies**

This command installs all the required packages at once. We learned through troubleshooting that several were needed.

```shell
sudo apt-get install -y wget screen lib32gcc-s1 lib32stdc++6 libc6:i386
```

  * **Explanation:**
      * `wget`: A tool for downloading files from the internet.
      * `screen`: Allows the server to run in the background even after you disconnect.
      * `lib32gcc-s1` & `lib32stdc++6`: Specific 32-bit libraries that the HLDS engine depends on. Missing these caused the "Unable to initialize Steam" error.
      * `libc6:i386`: This is the most important 32-bit library. It provides the **program loader** (`/lib/ld-linux.so.2`) and was the final fix for the `./hlds_run: No such file or directory` error.

**Step 3: Download and Extract SteamCMD**

Instead of using the Ubuntu package, we download SteamCMD directly from Valve. This is the step that avoids the interactive license agreement.

```shell
# Create a directory for the SteamCMD tool
mkdir ~/steamcmd

# Enter the directory
cd ~/steamcmd

# Download the SteamCMD package
wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz

# Extract the package contents
tar -xvf steamcmd_linux.tar.gz
```

  * **Explanation:** This method is non-interactive and more reliable than the packaged version.
  * **USER INPUT REQUIRED (Originally):** The command we originally tried was `sudo apt-get install steamcmd`. **This is the command that popped up the interactive "STEAM LICENSE AGREEMENT"** and required you to agree. The `wget` method we are using here has no such prompt.

**Step 4: Download the Counter-Strike Server Files**

Now we use SteamCMD to download the actual game server files into a separate `hlds` directory in your home folder.

```shell
# Create the directory for the game server
mkdir ~/hlds

# Run SteamCMD and pass it all the commands at once
~/steamcmd/steamcmd.sh +force_install_dir ~/hlds +login anonymous +app_update 90 validate +quit
```

  * **Explanation:** This command tells SteamCMD to install the application with ID `90` (Half-Life Dedicated Server, which includes Counter-Strike 1.6) into the `~/hlds` folder. `validate` checks that all files are correct.

**Step 5: Apply the `steamclient.so` Fix**

The server needs a symbolic link to find a key Steam library file.

```shell
# Create the directory structure the server expects
mkdir -p ~/.steam/sdk32

# Create the symbolic link
ln -s ~/hlds/steamclient.so ~/.steam/sdk32/steamclient.so
```

  * **Explanation:** This was the fix for the initial `Unable to initialize Steam` error. It creates a "shortcut" so the HLDS engine can find the `steamclient.so` library where it expects it to be.

**Step 6: Create the Final, Working `start_server.sh` Script**

This `cat` command creates the startup script with the final fix (`export LD_LIBRARY_PATH`) included.

```shell
cat <<EOF > ~/start_server.sh
#!/bin/bash
echo "Starting Counter-Strike 1.6 Server directly..."
# Explicitly set the library path to the server directory
export LD_LIBRARY_PATH=~/hlds
# Launch the main executable directly to bypass the hlds_run script
cd ~/hlds && ./hlds_linux -game cstrike +map de_dust2 +maxplayers 16 -insecure -nomaster
EOF
```

  * **Explanation:** This script does two crucial things:
    1.  `export LD_LIBRARY_PATH=~/hlds`: This tells the system to look inside the `~/hlds` directory for necessary libraries. This was the fix for the final "Unable to initialize Steam" error.
    2.  It uses all the parameters we discovered were necessary: `-game cstrike`, `-insecure`, and `-nomaster`.

**Step 7: Make the Script Executable**

Finally, we give the script permission to be run.

```shell
chmod +x ~/start_server.sh
```

After completing these seven steps manually, you will have a fully functional server, and you can start it by running `./start_server.sh`.
