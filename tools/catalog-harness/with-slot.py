#!/usr/bin/env python3
"""Run a command as the holder of one of N run slots (v2.2 J1, catalog harness).

Why: the real CodexManager writes to the process's UserDefaults domain, which
is named after the executable. Runs in parallel (the mutation suite) must not
share a domain, so each run's harness executable is named after its slot
(`sparkforge-catalog-harness-slotN`) and at most N small preference files
ever exist.

Ownership is an EXCLUSIVE `flock` on the slot's lock file, held for as long as
the command runs (the child inherits the lock's file descriptor, so the slot
stays owned if this wrapper dies before the child). The kernel releases it when
the last holder exits, however it exits. There is therefore no pid file, no
liveness guess and no reclamation step: a slot is free exactly when its lock
can be taken, and no process can take, remove or reuse a slot another live
process holds. Nothing outside the slot directory is touched, and nothing in it
is ever deleted.

Usage:  with-slot.py [--slots DIR] [--count N] [--wait SECONDS] -- CMD [ARG...]
Every `{slot}` in CMD/ARG is replaced by the slot name, e.g. `slot7`, which is
also exported as SPARKFORGE_HARNESS_SLOT. Exits with the command's status.
"""
import fcntl, os, subprocess, sys, time

DEFAULT_SLOTS = os.path.join(os.environ.get('TMPDIR') or '/tmp', 'sparkforge-catalog-harness-slots')


def acquire(slots_dir, count, wait):
    """→ (fd, index): the fd holds the exclusive lock. Tries every slot, then retries until `wait` runs out."""
    os.makedirs(slots_dir, exist_ok=True)
    deadline = time.monotonic() + wait
    while True:
        for i in range(count):
            fd = os.open(os.path.join(slots_dir, f'{i}.lock'), os.O_RDWR | os.O_CREAT, 0o644)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                os.close(fd)
                continue
            # Informational only (who held it last); ownership is the lock itself.
            os.ftruncate(fd, 0)
            os.write(fd, f'{os.getpid()}\n'.encode())
            return fd, i
        if time.monotonic() >= deadline:
            sys.exit(f'with-slot: all {count} run slots are held by other live runs (waited {wait:g}s)')
        time.sleep(0.2)


def main():
    args = sys.argv[1:]
    slots_dir, count, wait = DEFAULT_SLOTS, 32, 120.0
    while args and args[0] != '--':
        if args[0] == '--slots' and len(args) > 1:
            slots_dir, args = args[1], args[2:]
        elif args[0] == '--count' and len(args) > 1:
            count, args = int(args[1]), args[2:]
        elif args[0] == '--wait' and len(args) > 1:
            wait, args = float(args[1]), args[2:]
        else:
            sys.exit(f'with-slot: unknown option {args[0]!r}')
    if not args or args[0] != '--' or len(args) < 2:
        sys.exit(__doc__)
    command = args[1:]
    fd, index = acquire(slots_dir, count, wait)
    name = f'slot{index}'
    command = [a.replace('{slot}', name) for a in command]
    env = dict(os.environ, SPARKFORGE_HARNESS_SLOT=name)
    try:
        return subprocess.call(command, env=env, pass_fds=[fd])
    finally:
        os.close(fd)


if __name__ == '__main__':
    sys.exit(main())
