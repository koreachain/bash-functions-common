#!/usr/bin/env python3
# ---
# install:
#   - python3-rich
#   - python3-yaml
# pip:
#   - git+ssh://git@github.com/koreachain/python-pip-common.git
"""
Usage:
  provision.py [--dry-run] <directory>

Option:
  --dry-run

Arguments:
  <directory:str>
"""

import atexit
import configparser
import os
import shutil
import sys

import yaml
from common import arg, cmd
from rich.console import Console

console = Console()


class ConfigParser(configparser.ConfigParser):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.optionxform = str

    def save(self, filename):
        with open(filename, "w") as configfile:
            self.write(configfile)


def generate_timers(name, options, tmpdir):
    if options["schedule"] == "hourly":
        random_delay = "5m"
        persist_runs = "false"
    elif options["schedule"] in ("daily", "weekly", "monthly"):
        random_delay = "1h"
        persist_runs = "true"
    else:
        random_delay = "0s"
        persist_runs = options.get("persistent", "false")

    timer = ConfigParser()
    timer["Unit"] = {
        "Description": f"Schedule {name}",
    }
    timer["Timer"] = {
        "OnCalendar": options["schedule"],
        "Persistent": persist_runs,
        "RandomizedDelaySec": random_delay,
    }
    timer["Install"] = {
        "WantedBy": "timers.target",
    }
    timer.save(f"{tmpdir}/{name}.timer")

    service = ConfigParser()
    service["Unit"] = {
        "Description": f"{name}",
    }
    service["Service"] = {
        "ExecStart": f"/usr/local/bin/{name}",
        "Type": "oneshot",
        "CPUSchedulingPolicy": "idle",
        "IOSchedulingClass": "idle",
        "TimeoutStartSec": options["timeout"],
    }
    service.save(f"{tmpdir}/{name}.service")


def generate_service(name, options, tmpdir):
    service = ConfigParser()
    service["Unit"] = {
        "Description": f"{name}",
        "After": options["after"],
    }
    service["Service"] = {
        "ExecStart": f"/usr/local/bin/{name}",
        "Restart": "on-failure",
        "CPUSchedulingPolicy": "idle",
        "IOSchedulingClass": "idle",
    }
    service["Install"] = {
        "WantedBy": "multi-user.target",
    }
    service.save(f"{tmpdir}/{name}.service")


def sync_and_enable(name, action, options, tmpdir):
    if options["scope"] == "system":
        user = "root"
        dest = "/etc/systemd/system"
        systemctl = ["systemctl"]
    else:
        user = "user"
        dest = f"/home/{user}/.config/systemd/user"
        systemctl = ["systemctl", "--user"]

    shell(["rsync", "-rv", "--chmod=600", f"{tmpdir}/", f"{dest}/"], user=user)
    shell([*systemctl, "daemon-reload"], user=user)
    if action == "program":
        shell([*systemctl, "enable", "--now", f"{name}.timer"], user=user)
    elif action == "startup":
        shell([*systemctl, "enable", "--now", f"{name}.service"], user=user)


def shell(*args, **kwargs):
    if kwargs:
        console.log(*args, kwargs)
    else:
        console.log(*args)

    if not args.dry_run:
        cmd.tty(*args, **kwargs)


def main():
    if os.geteuid() != 0:
        print("This script must be run as root.", file=sys.stderr)
        sys.exit(1)

    def cleanup_tmpdir():
        shutil.rmtree(tmpdir, ignore_errors=True)

    tmpdir = cmd.run(["mktemp", "-d", "./.tmp.XXXXXXXXXX"]).stdout
    atexit.register(cleanup_tmpdir)

    install, pip, disable = set(), set(), set()
    program, startup = [], []
    for root, dirs, files in os.walk(args.directory):
        for name in files:
            script = os.path.join(root, name)
            lines = []
            with open(script) as data:
                begin = True
                for line in data:
                    if begin:
                        if line.startswith("#!"):
                            begin = False
                            continue
                        else:
                            break

                    if line.startswith("#"):
                        lines.append(line.replace("# ", ""))
                    else:
                        break

                if not lines or not lines[0].startswith("---"):
                    continue

                shell(["install", script, "/usr/local/bin/"])

                instructions = yaml.safe_load("".join(lines))
                for action, data in instructions.items():
                    if action == "install":
                        install.update(data)
                    elif action == "pip":
                        pip.update(data)
                    elif action == "program":
                        program.append([name, action, data])
                    elif action == "startup":
                        startup.append([name, action, data])
                    elif action == "disable":
                        disable.update(data)
                    else:
                        raise ValueError(f"Unknown action: {action}")

    if install:
        shell(["apt", "install", *sorted(install)])

    if pip:
        shell(["pip3", "install", *sorted(pip)])

    for name, action, data in program:
        generate_timers(name, data, tmpdir)
        sync_and_enable(name, action, data, tmpdir)

    for name, action, data in startup:
        generate_service(name, data, tmpdir)
        sync_and_enable(name, action, data, tmpdir)

    if disable:
        shell(["systemctl", "disable", "--now", *sorted(disable)])

    shell(["install", sys.argv[0], "/usr/local/bin/"])

if __name__ == "__main__":
    args = arg.parse(__doc__)

    main()
