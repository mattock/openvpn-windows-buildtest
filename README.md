# openvpn-windows-buildtest

## Introduction

This is an automated openvpn-build testing and snapshot publishing script, which 
does three things:

- Tests building OpenVPN "master" and "release/2.3" branches with openvpn-build on every commit
- Publishes the produced installers automatically
- Emails build successes and failures to one or more addresses

The script is based on polling a Git repository, but a build is only triggered 
when there are new commits.

## Requirements and configuration

First make sure you can successfully build using 
[openvpn-build](https://github.com/OpenVPN/openvpn-build.git) - otherwise this 
script will fail miserably.

The email feature requires properly configured MTA such as postfix, as the
script will send emails using the "mail" program. Using heirloom-mailx or
similar is probably an option also.

The publishing feature requires allowing passwordless SSH key login to the
target webserver, plus proper directory permissions to allow uploads.

Right now it is assumed that all builds are signed and that a signing 
certificate is available as a (pfx) file. The signing step could be made 
optional.

After the requirements are taken care of, copy the vars.example configuration
file to _vars_ and adapt it to your environment. Vars files for release/2.3,
release/2.4 and master Git branches are provided as they don't contain any
sensitive data such as passwords.

Note that the script fetches openvpn-build at build time. You can use your own 
fork by modifying OPENVPN_BUILD_GIT_URL in the vars file.

## Usage

You can run the script with

    $ ./build.sh config-file

Where config-file is based on vars.2.3.example or vars.master.example. The name 
of the file as such is irrelevant. You can customize the behavior of the script
by overriding variables, e.g.

    $ EMAIL=jake@domain.com FORCE=true ./build.sh vars.master

The command forces a build of Git "master" and sends the report to
jake@domain.com.

To automate the script add entries to cron, e.g.

    05 * * * * cd /home/john/openvpn-windows-buildtest && ./build.sh vars.2.3
    25 * * * * cd /home/john/openvpn-windows-buildtest && ./build.sh vars.2.4
    45 * * * * cd /home/john/openvpn-windows-buildtest && ./build.sh vars.master

## License

This program has been licensed under the BSD license. See the file LICENSE for 
details.
