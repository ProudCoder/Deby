# Deby - Setting up a development environment on a freshly installed `Debian 12.2.0`, on a local virtual machine



## Step 1: Identify your Guest/VM's IP Address
To display the current IP Address on your virtual machine, run:
```sh
hostname -I
```
Output (example):
```output
192.168.168.129
```


## Step 2: Login as a regular user (new terminal on host machine)
To login as a regular default username (example):
```sh
ssh username@192.168.168.129
```


## Step 3 (One-liner): as `root` user, Customize `root`'s Prompt Shell `PS1` + Enable SSH `root` Login + Restart SSH service:
### One-liner (copy-paste):
```sh
su - -c "sed -i \"/PS1=/c\  PS1='$\{debian_chroot:+($\debian_chroot)}\x5C[\x5C033[1;31m\x5C]\x5Cu\x5C[\x5C033[0m\x5C]@\x5C[\x5C033[1;31m\x5C]\x5Ch\x5C[\x5C033[0m\x5C]:\x5C[\x5C033[1;34m\x5C]\x5Cw\x5C[\x5C033[0m\x5C]\x5Cn\x5C[\x5C033[1;31m\x5C]\x5C$\x5C[\x5C033[0m\x5C] '\" /etc/bash.bashrc && sed -i '$ a PermitRootLogin yes' /etc/ssh/sshd_config && service ssh restart" && exit
```
>   Please note that the usage of the root password and making changes to system configuration files should be done with caution, as it can have a significant impact on system security and functionality.


This command does the following:

1. **Switch to `root` user**:
    1. `su - -c "command"`: This part is used to switch to the superuser `root` by opening a new shell with a login environment with the `-` option. This is often used to run commands with administrative privileges. The `-c` option specifies that we want to execute a command. In our case, the entire sed command enclosed in double quotes is provided as the command to run.
    - Or you can simply switch user to `'root'` user:
    ```sh
    su -
    ```
2. **Customize `root`'s Prompt Shell `PS1`**:
    1. `"sed -i \"/PS1=/c\  PS1=...\" /etc/bash.bashrc"`: This part of the command runs `sed` to modify the PS1 variable in the `/etc/bash.bashrc` file. It replaces the existing PS1 value with a new value: `PS1='${debian_chroot:+($debian_chroot)}\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;31m\]\h\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\n\[\033[1;31m\]\$\[\033[0m\] '`
    2. The PS1 variable controls the appearance of the shell prompt.
    - Or you can simply run (escaping the `'\'` with `'\\\'`):
    ```sh
    sed -i "/PS1=/c\  PS1='\${debian_chroot:+(\$debian_chroot)}\\\[\\\033[1;31m\\\]\\\u\\\[\\\033[0m\\\]@\\\[\\\033[1;31m\\\]\\\h\\\[\\\033[0m\\\]:\\\[\\\033[1;34m\\\]\\\w\\\[\\\033[0m\\\]\\\n\\\[\\\033[1;31m\\\]\\\\$\\\[\\\033[0m\\\] '" /etc/bash.bashrc
    ```
    - Same as (escaping `'\'` with `'\x5C'`):
    ```sh
    sed -i "/PS1=/c\  PS1='\${debian_chroot:+(\$debian_chroot)}\x5C[\x5C033[1;31m\x5C]\x5Cu\x5C[\x5C033[0m\x5C]@\x5C[\x5C033[1;31m\x5C]\x5Ch\x5C[\x5C033[0m\x5C]:\x5C[\x5C033[1;34m\x5C]\x5Cw\x5C[\x5C033[0m\x5C]\x5Cn\x5C[\x5C033[1;31m\x5C]\x5C\$\x5C[\x5C033[0m\x5C] '" /etc/bash.bashrc
    ```

3. **Enable Root SSH Login**:
    1. `&&`: This operator is used to run the next command if the previous one succeeds.
    2. `sed -i '$ a PermitRootLogin yes' /etc/ssh/sshd_config`: This command uses `sed` to append the line "PermitRootLogin yes" to the `/etc/ssh/sshd_config` file. It modifies the SSH server configuration to allow root login.
    ```sh
    sed -i '$ a PermitRootLogin yes' /etc/ssh/sshd_config
    ```


4. **Restart SSH service**:
    1. `&&`: This operator is used to run the next command if the previous one succeeds.
    2. `service ssh restart`: This command restarts the SSH service, applying the new configuration settings.
    - Or you can simply run (you must then exit the `root`'s shell session):
    ```sh
    service ssh restart && exit
    ```

5. **Exit the current session**
    1. `exit`: This command exits the current `username`'s shell session.
    - Or you can simply run:
    ```sh
    exit
    ```




## Step 4: Login as `root` user
Wait a few seconds and login as `root` user:
Login as :
```sh
ssh root@192.168.168.129
```

## Step 5: Login as `root` user
Wait a few seconds and login as `root` user:
Login as :
```sh
wget -O deby.sh https://raw.githubusercontent.com/ProudCoder/Deby/main/deby.sh && chmod +x deby.sh && ./deby.sh --new-username <New_Username> --host-id 100
```

