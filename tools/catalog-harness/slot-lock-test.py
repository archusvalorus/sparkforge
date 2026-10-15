#!/usr/bin/env python3
"""Regression test for with-slot.py, the catalog harness's run-slot wrapper (v2.2 J1).

Bounded (a few seconds, 16 slots in a private temporary directory) and
self-cleaning. Every wrapper it starts runs in its own process group that the
test owns from the moment of `Popen`; cleanup kills and reaps every owned
group, whatever state its processes are in (paused included), BEFORE the
temporary directory is removed. The directory is removed ONLY when that
cleanup is confirmed (no survivor, no error); otherwise it is kept, with its
lock files, the test exits unsuccessfully, and it reports the kept path and
what it knows about the processes still holding the locks. No context manager
or finalizer can delete a kept directory later. It never touches the real slot
directory or any preference file.

What it proves, with ownership asserted WHILE the holders are alive (by
trying each slot's lock from outside, non-blocking):
  concurrent ownership   16 holders at once get 16 distinct slots; each held
                         lock refuses another taker; the exported name equals
                         the substituted one
  exhausted slots        a latecomer with every slot held waits its bound,
                         exits non-zero, takes nothing; all stay held
  wrapper interruption   the wrapper killed (-9) while its child lives: the
                         slot stays held (the child inherited the lock)
  child interruption     the child killed: the slot frees; the other owners
                         are untouched; a newcomer receives exactly that slot
  paused children        holders whose children are stopped (SIGSTOP) are
                         still killed and reaped by cleanup, and their locks
                         are released
  interrupted startup    a failure while holders are still starting (some
                         children paused) leaves no process behind: cleanup
                         reaps every owned group and every lock is free
  stale lock files       lock files left behind with old pid text and no
                         holder are simply free: 16 acquirers at once
  cleanup                released holders exit 0; nothing in the slot
                         directory is ever deleted (lock files only)

Usage (repo root):  python3 tools/catalog-harness/slot-lock-test.py   # exit 0 = pass
"""
import fcntl, json, os, pathlib, select, shutil, signal, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
WRAPPER = os.path.join(HERE, 'with-slot.py')
COUNT = 16
STEP_TIMEOUT = 20          # seconds, for any single wait or read


def held(lock_path):
    """True when some process holds the exclusive lock (we cannot take it)."""
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    except OSError:
        return True
    finally:
        os.close(fd)


def lock(slots, i):
    return os.path.join(slots, f'{i}.lock')


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def read_line_bounded(proc, timeout):
    """One line of the process's stdout, or '' when nothing arrives in time."""
    fd = proc.stdout.fileno()
    buf = b''
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return ''
        ready, _, _ = select.select([fd], [], [], remaining)
        if not ready:
            return ''
        chunk = os.read(fd, 1)
        if not chunk:
            return buf.decode(errors='replace')
        buf += chunk
        if chunk == b'\n':
            return buf.decode(errors='replace')


class Holders:
    """Wrapper processes whose child reports its slot, then waits for a release file.

    Each wrapper is started in its own process group (`start_new_session`), and
    the group is recorded before anything else happens, so `cleanup` owns every
    descendant even when startup stops halfway (a failed read, an exception,
    a paused child)."""

    def __init__(self, slots, release):
        self.slots, self.release = slots, release
        self.procs = []          # every wrapper ever started, in order
        self.children = []       # the child pids that reported in, in order

    def start(self, wait='2'):
        p = subprocess.Popen(
            ['python3', WRAPPER, '--slots', self.slots, '--count', str(COUNT), '--wait', wait, '--',
             'sh', '-c', f'echo "$$ {{slot}} $SPARKFORGE_HARNESS_SLOT"; while [ ! -f "{self.release}" ]; do sleep 0.05; done'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        self.procs.append(p)                       # owned from this moment on
        line = read_line_bounded(p, STEP_TIMEOUT).split()
        if len(line) != 3:
            raise RuntimeError(f'holder did not report a slot within {STEP_TIMEOUT}s')
        self.children.append(int(line[0]))
        return p, int(line[0]), line[1], line[2]

    def release_all(self):
        pathlib.Path(self.release).touch()
        codes = []
        for p in self.procs:
            try:
                codes.append(p.wait(timeout=STEP_TIMEOUT))
            except subprocess.TimeoutExpired:
                codes.append('timeout')
        return codes

    def cleanup(self):
        """Kill and reap every owned process group; return what survived (should be nothing).

        SIGKILL ends a stopped process too, so paused children need no SIGCONT.
        Wrappers are our children and are waited for; their children are
        reparented when the wrapper dies, so they are polled until gone."""
        for p in self.procs:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        for p in self.procs:
            try:
                p.wait(timeout=STEP_TIMEOUT)
            except subprocess.TimeoutExpired:
                pass
            if p.stdout: p.stdout.close()
            if p.stderr: p.stderr.close()
        deadline = time.monotonic() + STEP_TIMEOUT
        while time.monotonic() < deadline:
            survivors = [p.pid for p in self.procs if group_alive(p.pid)] + [c for c in self.children if alive(c)]
            if not survivors:
                return []
            time.sleep(0.05)
        return survivors


def process_diagnostics(holders_list, survivors):
    """What is known about the processes that were not confirmed gone (bounded)."""
    pids = sorted({p.pid for h in holders_list for p in h.procs} | {c for h in holders_list for c in h.children} | set(survivors))
    rows = []
    for h in holders_list:
        for p in h.procs:
            rows.append({'wrapper': p.pid, 'exited': p.poll(), 'groupAlive': group_alive(p.pid)})
        for c in h.children:
            rows.append({'child': c, 'alive': alive(c)})
    ps = ''
    if pids:
        try:
            ps = subprocess.run(['ps', '-o', 'pid,pgid,stat,command', '-p', ','.join(map(str, pids))],
                                capture_output=True, text=True, timeout=5).stdout
        except Exception as e:                      # diagnostics must never fail the report
            ps = f'(ps unavailable: {type(e).__name__})'
    return {'owned': rows, 'ps': ps}


def run():
    results = {}
    # mkdtemp, not TemporaryDirectory: nothing may remove this directory later
    # except the confirmed-cleanup branch below.
    tmp = tempfile.mkdtemp(prefix='sparkforge-slot-lock-test-')
    slots = os.path.join(tmp, 'slots')
    release = os.path.join(tmp, 'release')
    owned = []               # every Holders ever made; all cleaned in `finally`
    def holders():
        h = Holders(slots, release)
        owned.append(h)
        return h
    try:
        # concurrent ownership
        h = holders()
        reported = [h.start() for _ in range(COUNT)]
        names = [r[2] for r in reported]
        results['concurrentOwnership'] = {
            'allAlive': all(r[0].poll() is None for r in reported),
            'distinctSlots': len(set(names)) == COUNT,
            'exportedNameMatches': all(r[2] == r[3] for r in reported),
            'everyHeldLockRefusesAnotherTaker': all(held(lock(slots, i)) for i in range(COUNT)),
        }
        # exhausted slots
        t0 = time.monotonic()
        late = subprocess.run(['python3', WRAPPER, '--slots', slots, '--count', str(COUNT), '--wait', '1', '--', 'sh', '-c', 'echo TOOK {slot}'],
                              capture_output=True, text=True, timeout=STEP_TIMEOUT, start_new_session=True)
        results['exhaustedSlots'] = {
            'exitNonZero': late.returncode != 0, 'tookNothing': 'TOOK' not in late.stdout,
            'waitedAboutABound': 0.9 <= time.monotonic() - t0 <= 10,
            'allStillHeld': all(held(lock(slots, i)) for i in range(COUNT)),
        }
        # wrapper interruption, then child interruption
        victim, child_pid, name, _ = reported[0]
        slot_index = int(name[len('slot'):])
        os.kill(victim.pid, signal.SIGKILL)
        victim.wait(timeout=STEP_TIMEOUT)
        time.sleep(0.3)
        still_held = held(lock(slots, slot_index))
        os.kill(child_pid, signal.SIGKILL)
        time.sleep(0.3)
        freed = not held(lock(slots, slot_index))
        others = all(held(lock(slots, int(n[len('slot'):]))) for n in names[1:])
        newcomer = h.start()
        results['interruption'] = {
            'heldAfterWrapperKilled': still_held, 'freeAfterChildKilled': freed,
            'otherOwnersUntouched': others, 'newcomerGotTheFreedSlot': newcomer[2] == name,
        }
        # cleanup of a normal release
        before = sorted(os.listdir(slots))
        codes = h.release_all()
        results['cleanup'] = {
            'releasedExitZero': sorted(set(c for i, c in enumerate(codes) if i != 0)) == [0],   # index 0 was the killed wrapper
            'slotDirUnchanged': sorted(os.listdir(slots)) == before,
            'lockFilesOnly': all(n.endswith('.lock') for n in before),
            'nothingSurvivesCleanup': h.cleanup() == [],
        }
        os.remove(release)

        # paused children: stopped processes must still be killed and reaped
        h = holders()
        paused = [h.start() for _ in range(4)]
        for _, pid, _, _ in paused:
            os.kill(pid, signal.SIGSTOP)
        time.sleep(0.2)
        survivors = h.cleanup()
        results['pausedChildren'] = {
            'childrenWereStopped': True,
            'nothingSurvivesCleanup': survivors == [],
            'locksReleased': not any(held(lock(slots, int(r[2][len('slot'):]))) for r in paused),
            'wrappersReaped': all(p.poll() is not None for p in h.procs),
        }

        # interrupted startup: a failure while holders are still starting
        h = holders()
        started = []
        caught = False
        try:
            for n in range(4):
                if n == 3:
                    raise RuntimeError('injected: the fourth holder failed to start')
                row = h.start()
                started.append(row)
                os.kill(row[1], signal.SIGSTOP)        # some children are paused when it fails
        except RuntimeError:
            caught = True
        survivors = h.cleanup()                        # what `finally` would do
        results['interruptedStartup'] = {
            'failureRaised': caught, 'startedBeforeFailure': len(started) == 3,
            'nothingSurvivesCleanup': survivors == [],
            'childrenGone': not any(alive(r[1]) for r in started),
            'locksReleased': not any(held(lock(slots, int(r[2][len('slot'):]))) for r in started),
            'slotDirIntact': all(os.path.exists(lock(slots, int(r[2][len('slot'):]))) for r in started),
        }

        # stale lock files
        h = holders()
        for i in range(COUNT):
            with open(lock(slots, i), 'w') as f:
                f.write('99999999\n')
        reported = [h.start() for _ in range(COUNT)]
        results['staleLockFiles'] = {
            'distinctSlots': len(set(r[2] for r in reported)) == COUNT,
            'allHeldWhileAlive': all(held(lock(slots, i)) for i in range(COUNT)),
        }
        codes = h.release_all()
        results['staleLockFiles']['releasedExitZero'] = sorted(set(codes)) == [0]
        results['staleLockFiles']['allFreeAfter'] = not any(held(lock(slots, i)) for i in range(COUNT))
    finally:
        # Reliable, bounded cleanup of everything this test started, whatever
        # happened above. The directory is removed only when every owned
        # process is CONFIRMED gone and no cleanup step failed; otherwise it
        # is kept with its lock files and the failure is reported.
        leftovers, errors = [], []
        for h in owned:
            try:
                leftovers += h.cleanup()
            except Exception as e:                  # keep going: every holder gets its attempt
                errors.append(f'{type(e).__name__}: {e}')
        confirmed = not leftovers and not errors
        if confirmed:
            shutil.rmtree(tmp, ignore_errors=True)
            results['finalCleanup'] = {'nothingSurvives': True}
        else:
            diagnostics = process_diagnostics(owned, leftovers)
            results['finalCleanup'] = {'nothingSurvives': False, 'survivors': leftovers, 'cleanupErrors': errors,
                                       'retainedDirectory': tmp, 'processes': diagnostics}
            print(f'slot-lock-test: cleanup NOT confirmed — kept {tmp} (its lock files are still linked); '
                  f'survivors {leftovers}; errors {errors}', file=sys.stderr)
            print(json.dumps(diagnostics, indent=1), file=sys.stderr)
    ok = all(all(v.values()) for v in results.values()) and len(results) == 8
    results['verdict'] = 'PASS' if ok else 'FAIL'
    return ok, results


if __name__ == '__main__':
    passed, results = run()
    print(json.dumps(results, indent=1))
    sys.exit(0 if passed else 1)
