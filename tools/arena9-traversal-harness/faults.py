from pathlib import Path
import subprocess,tempfile,os,json
r=Path(__file__).resolve().parent
source=(r.parents[1]/'Sparkforge/Systems/Arena9TraversalRun.swift').read_text()
faults=[
 ('seal-live-instead-of-registered','registeredCounts[ticket.encounterID] == expectedCount','members[ticket.encounterID]?.count == expectedCount'),
 ('goal-not-required','!awardedSuccess, reachedGoal, sealed.contains(finalID)','!awardedSuccess, sealed.contains(finalID)'),
 ('final-living-not-required','sealed.contains(finalID), members[finalID]?.isEmpty == true','sealed.contains(finalID)'),
 ('repeat-success','active, !awardedSuccess, reachedGoal','active, reachedGoal'),
 ('stale-generation-register','active, ledger.accepts(ticket), !sealed.contains(ticket.encounterID)','active, !sealed.contains(ticket.encounterID)'),
 ('late-register-after-seal','ledger.accepts(ticket), !sealed.contains(ticket.encounterID), !seenMembers.contains(id)','ledger.accepts(ticket), !seenMembers.contains(id)'),
]
results=[]
with tempfile.TemporaryDirectory(prefix='sf-a9-faults-') as tmp:
 for name,old,new in faults:
  assert source.count(old)==1,name
  p=Path(tmp)/(name+'.swift');p.write_text(source.replace(old,new));env=dict(os.environ,SPARKFORGE_A9_RUN_PATH=str(p),SPARKFORGE_A9_MODEL_ONLY='1')
  run=subprocess.run(['sh',str(r/'run.sh')],env=env,capture_output=True,text=True)
  lines=run.stdout.splitlines();fail=[x for x in lines if x.startswith('FAIL ')];killed=run.returncode==1 and bool(fail) and any(x.startswith('RESULT ') for x in lines)
  results.append({'fault':name,'exit':run.returncode,'caught_by_behavior':killed,'failures':fail})
  if not killed:print(run.stdout,run.stderr);raise SystemExit('Fault not behaviorally caught: '+name)
print(json.dumps(results,indent=2));print('RESULT 6 compile-valid behavioral faults caught')
