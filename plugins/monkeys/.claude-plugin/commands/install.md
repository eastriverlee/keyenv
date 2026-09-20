---
description: Install or update the monkeys binary from the latest release
---

Install the `monkeys` binary on this machine.

1. Run the installer that ships with this plugin:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/skills/monkeys/scripts/install.sh"
   ```

   It picks the build for this operating system and processor, checks the
   published checksum, and installs into `~/.local/bin`. Pass
   `INSTALL_DIRECTORY` to put it somewhere else.

2. Confirm it answers:

   ```sh
   monkeys help | head -1
   ```

   A "command not found" here means `~/.local/bin` is missing from `PATH`. Say
   so and give the line to add, rather than moving the binary somewhere else.

3. On Linux, `monkeys` needs `secret-tool` to reach the vault. If step 2
   worked but `monkeys list` reports it missing, tell the person to install
   `libsecret-tools` on Debian or Ubuntu, `libsecret` on Fedora or Arch.

Report the installed path and stop. Do not store any secret on the person's
behalf.
