#!/usr/bin/env python3
import argparse, os, shlex, subprocess, sys 

# scope
# role
# datadir > target-dir
# connstring

# pghoard_restore get-basebackup --config /var/lib/pghoard/pghoard.json \
#  --target-dir /var/lib/pgsql/9.5/data

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scope")
    parser.add_argument("--role")
    parser.add_argument("--datadir")
    parser.add_argument("--connstring")
    parser.add_argument("--config", help="Full path to pghoard json config")
    parser.add_argument('--no_master')
    args = parser.parse_args()
    print(args)
    cmd = "pghoard_restore get-basebackup --config {args.config} --target-dir {args.datadir}".format(args=args)
    print(cmd)
    try:
        ret = subprocess.check_output(shlex.split(cmd), env=os.environ.copy())
    except subprocess.CalledProcessError:
        return 1
    for line in ret.decode('ASCII').splitlines():
        print(line)
    if 'RestoreError' in ret.decode('ASCII'):
        return 1

if __name__ == "__main__":
    sys.exit(main() or 0)