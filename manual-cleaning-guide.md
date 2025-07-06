### Manual Cleanup Steps

These commands will undo all the steps from our manual installation guide.

**1. Remove Created Directories**
This command forcefully removes the server files, the SteamCMD tool, and the Steam configuration folder from your home
directory.

```shell
rm -rf ~/hlds ~/steamcmd ~/.steam
```

* **`rm -rf`**: This command means "**r**e**m**ove **f**orcibly and **r**ecursively." It deletes the specified folders
  and everything inside them without asking for confirmation.

**2. Remove the Startup Script**
This deletes the `start_server.sh` file.

```shell
rm ~/start_server.sh
```

**3. Uninstall All Installed Packages**
This command will uninstall all the specific dependencies we added for the server. The `purge` command also removes any
configuration files associated with them.

```shell
sudo apt-get purge -y wget screen lib32gcc-s1 lib32stdc++6 libc6:i386
```

**4. Remove a Leftover Directory (Optional but Recommended)**
The `apt purge` command might leave an empty directory if it was created. This command will clean it up.

```shell
sudo rm -rf /opt/hlds
```

**5. Remove Unused Packages (Optional but Recommended)**
This command cleans up any other dependencies that were installed automatically but are no longer needed.

```shell
sudo apt-get autoremove -y
```

-----

After running these commands, your system will be in the same state it was in before you started the manual
installation, allowing you to run your perfected automation script again on a clean slate.