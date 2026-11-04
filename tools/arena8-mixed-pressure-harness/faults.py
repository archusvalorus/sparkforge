from pathlib import Path
import tempfile,subprocess,os,json
r=Path(__file__).resolve().parent;root=r.parents[1];source=(root/'Sparkforge/Prototypes/Arena8PreviewSpawnClock.swift').read_text()
faults=[('wrong-trial-rate','self == .trial ? 0.8 : 1','self == .trial ? 0.75 : 1'),('ignore-hold','guard !held, dt.isFinite','guard true, dt.isFinite'),('retain-overdue-credit','accumulated = 0\n        attempts','accumulated -= interval\n        attempts'),('replay-emission','accumulated = 0\n        attempts','accumulated = interval\n        attempts'),('early-boundary','accumulated >= interval','accumulated >= interval - 0.01'),('lost-attempt-counter','attempts += 1','attempts += 0'),('negative-time-admitted','dt >= 0','true'),('emit-every-update','accumulated >= interval','accumulated >= 0')]
results=[]
with tempfile.TemporaryDirectory(prefix='sf-mixed-faults-') as d:
 for name,old,new in faults:
  assert source.count(old)==1,(name,source.count(old));p=Path(d)/(name+'.swift');p.write_text(source.replace(old,new,1));env=dict(os.environ);env['SPARKFORGE_MIXED_CLOCK_PATH']=str(p)
  run=subprocess.run(['sh',str(r/'run.sh')],env=env,capture_output=True,text=True);fail=[x for x in run.stdout.splitlines() if x.startswith('FAIL ')];caught=run.returncode==1 and bool(fail) and 'RESULT ' in run.stdout
  results.append({'fault':name,'exit':run.returncode,'compile_valid_behaviorally_caught':caught,'failed_assertions':len(fail),'examples':fail[:8]})
  assert caught,(name,run.stdout,run.stderr)
print(json.dumps(results,indent=2));print('RESULT 8 compile-valid behavioral faults caught')
