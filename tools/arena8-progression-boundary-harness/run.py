#!/usr/bin/env python3
"""Focused retained variant of arena7-integration-harness/run.py.
Run only inside a separately coordinated host window. No app/Simulator is used.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,re,shutil,signal,subprocess,time,uuid
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def interrupted(*_):raise KeyboardInterrupt('Owned progression host runner interrupted')

def owned_process(command,stream,timeout,report,persist=lambda:None):
    child=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
    def members():
        text=subprocess.check_output(['/bin/ps','-axo','pid=,pgid=,comm='],text=True,timeout=5)
        return [{'pid':int(f[0]),'pgid':int(f[1]),'executable':f[2]} for line in text.splitlines()
                if len(f:=line.strip().split(None,2))==3 and int(f[1])==child.pid]
    def stop():
        if child.poll() is None or members():
            try:os.killpg(child.pid,signal.SIGTERM)
            except ProcessLookupError:pass
        try:child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:os.killpg(child.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            child.wait(timeout=5)
        if members():
            try:os.killpg(child.pid,signal.SIGKILL)
            except ProcessLookupError:pass
        until=time.monotonic()+2
        while members() and time.monotonic()<until:time.sleep(0.05)
    try:
        report.update(pid=child.pid,pgid=child.pid,created_by_this_runner=True);persist()
        return child.wait(timeout=timeout)
    except BaseException:
        stop();raise
    finally:
        remaining=members()
        if remaining:stop();remaining=members()
        report.update(remaining=remaining,checked_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
        assert child.poll() is not None and not remaining,'Owned child group is not clear'

def main():
    signal.signal(signal.SIGTERM,interrupted)
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);parser.add_argument('--configuration',choices=['Debug','Release'],required=True);parser.add_argument('--revert-ledger-clear',action='store_true');args=parser.parse_args()
    assert not args.revert_ledger_clear or args.configuration=='Release','One declared Release control only'
    out=args.out.resolve();assert not out.exists(),'Fresh evidence only; no repeated attempt or overwrite';out.mkdir(parents=True)
    build=out/'build';build.mkdir();raw=out/'raw-inputs';raw.mkdir();receipt={'status':'PREPARING_NOT_A_PASS','configuration':args.configuration,'control':args.revert_ledger_clear,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'commands':[],'runs':[]};suites=[]
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def run(command,log,timeout):
        receipt['commands'].append({'argv':command,'log':str(log),'timeout':timeout});save()
        group={};receipt['commands'][-1]['owned_group']=group;save()
        try:
            with log.open('x') as stream:code=owned_process(command,stream,timeout,group,save)
        finally:save()
        receipt['commands'][-1]['exit']=code;save();return code
    try:
        dependencies=['Sparkforge/Systems/ProgressionManager.swift','Sparkforge/Systems/GameRunPreferences.swift','Sparkforge/Systems/BossRegistry.swift','Sparkforge/Config/GameConfig.swift','Sparkforge/Config/ArenaConfig.swift','Sparkforge/Config/ArenaGeometry.swift','Sparkforge/Systems/MeleeSector.swift','Sparkforge/Utils/VectorMath.swift','tools/signature-draw-harness/extract-config.sh','tools/arena8-progression-boundary-harness/Stubs.swift','tools/arena8-progression-boundary-harness/main.swift','tools/arena8-progression-boundary-harness/run.py']
        for name in dependencies:
            target=raw/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
        receipt['original_inputs']={n:sha(raw/n) for n in dependencies}
        text=(raw/'Sparkforge/Systems/ProgressionManager.swift').read_text()
        if args.revert_ledger_clear:
            line='        defaults.removeObject(forKey: Keys.defeatedBosses)\n';assert text.count(line)==1;text=text.replace(line,'',1)
        assert text.count('private init()')==1 and text.count('private let defaults = GameRunPreferences.shared')==1
        (build/'Progression.swift').write_text(text.replace('private init()','init()').replace('private let defaults = GameRunPreferences.shared','private let defaults = ProbeContext.store'))
        registry=(raw/'Sparkforge/Systems/BossRegistry.swift').read_text();assert registry.count('import SpriteKit')==1 and registry.count('@MainActor\n')==1
        (build/'Registry.swift').write_text(registry.replace('import SpriteKit','import Foundation').replace('@MainActor\n','',1))
        assert run(['sh',str(raw/'tools/signature-draw-harness/extract-config.sh'),str(raw/'Sparkforge/Config/GameConfig.swift'),str(build/'Config.swift'),'Arena','Geometry','Wave','BossMode'],out/'extract.log',15)==0
        source_paths=[build/'Progression.swift',build/'Registry.swift',build/'Config.swift',raw/'Sparkforge/Systems/GameRunPreferences.swift',raw/'Sparkforge/Config/ArenaConfig.swift',raw/'Sparkforge/Config/ArenaGeometry.swift',raw/'Sparkforge/Systems/MeleeSector.swift',raw/'Sparkforge/Utils/VectorMath.swift',raw/'tools/arena8-progression-boundary-harness/Stubs.swift',raw/'tools/arena8-progression-boundary-harness/main.swift']
        assert len(source_paths)==10;receipt['compiled_inputs']={str(p):sha(p) for p in source_paths}
        command=['/usr/bin/swiftc','-j1',*(['-D','DEBUG'] if args.configuration=='Debug' else []),'-module-cache-path',str(out/'module-cache'),'-o',str(out/'probe'),*map(str,source_paths)]
        (out/'compiler-argv.nul').write_bytes(b'\0'.join(x.encode() for x in command)+b'\0');code=run(command,out/'compile.log',120);receipt['compiler_exit']=code;save();assert code==0,'Compiler failure never counts as a caught control'
        receipt['binary_sha256']=sha(out/'probe')
        expected=re.findall(r'check\("([^"\n]+)"', (raw/'tools/arena8-progression-boundary-harness/main.swift').read_text());assert len(expected)==len(set(expected))==30
        failures={f'ER{i:02d}' for i in [8,9,11,14,15,16,17,19,20,21,22,23,25,26,27,29,30]} if args.revert_ledger_clear else set()
        for backend in (['memory'] if args.revert_ledger_clear else ['memory','private-suite']):
            suite='sf-a8-erasure-'+str(uuid.uuid4()).upper();assert suite not in suites
            if backend=='private-suite':suites.append(suite)
            command=[str(out/'probe'),'--suite-name',suite]+(['--private-suite'] if backend=='private-suite' else [])
            log=out/(backend+'.log');code=run(command,log,15);text=log.read_text();rows=re.findall(r'^(PASS|FAIL) (ER[^\n]+)$',text,re.M)
            actual_fails={name.split(' ',1)[0] for status,name in rows if status=='FAIL'}
            outcome={'backend':backend,'suite':suite,'exit':code,'rows':rows,'log_sha256':sha(log),'actual_failed_ids':sorted(actual_fails)};receipt['runs'].append(outcome);save()
            assert [name for _,name in rows]==expected and actual_fails==failures and code==(1 if failures else 0),'Unexpected actual census or behavior; stop without retry'
            assert f'Arena8 Progression Boundary: {30-len(failures)} passed / {len(failures)} failed' in text
        assert all(sha(ROOT/n)==h for n,h in receipt['original_inputs'].items()),'Candidate input drift'
        receipt['status']='EXACT_EXPECTED_HOST_RESULT_PENDING_INDEPENDENT_REVIEW';save()
    except BaseException as error:receipt.update(status='FAILED_OR_INCOMPLETE_NOT_A_PASS',error=repr(error));save();raise
    finally:
        # Only UUID-named domains supplied by this runner; never standard/owner domains.
        receipt['private_suite_cleanup']=[];cleanup_errors=[]
        for suite in suites:
            try:
                assert suite.startswith('sf-a8-erasure-') and uuid.UUID(suite[len('sf-a8-erasure-'):])
                log=out/('cleanup-'+suite+'.log')
                code=run([str(out/'probe'),'--private-suite','--suite-name',suite,'--cleanup-suite'],log,15)
                expected='CLEANUP '+suite+' ABSENT'
                receipt['private_suite_cleanup'].append({'suite':suite,'exit':code,'log_sha256':sha(log),'output':log.read_text()})
                assert code==0 and log.read_text().strip()==expected,'Owned suite absence not established by actual Foundation query'
            except BaseException as error:cleanup_errors.append({'suite':suite,'error':repr(error)})
        if cleanup_errors:receipt.update(status='FAILED_OR_INCOMPLETE_NOT_A_PASS',cleanup_errors=cleanup_errors)
        receipt['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
        if cleanup_errors and __import__('sys').exc_info()[0] is None:raise RuntimeError(cleanup_errors)
if __name__=='__main__':main()
