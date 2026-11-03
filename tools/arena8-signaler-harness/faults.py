from pathlib import Path
import subprocess,tempfile,os,json
r=Path(__file__).resolve().parent;root=r.parents[1];source=(root/'Sparkforge/Systems/Arena8PacketCommands.swift').read_text()
faults=[
 ('no-source-authorization','authorizedSignaler == source && !packet.members.contains(source)','true'),
 ('no-prepare-source-life','commands[packetID] == nil, live.contains(source)','commands[packetID] == nil, true'),
 ('preempt-pending','commands[packetID] == nil, live.contains(source)','true, live.contains(source)'),
 ('no-commit-source-life','live.contains(ticket.source),','true,'),
 ('no-commit-source-authorization','authorizedSignaler == ticket.source && !packet.members.contains(ticket.source)','!packet.members.contains(ticket.source)'),
 ('ignore-warning-hold','if !held { command.remaining','if true { command.remaining'),
 ('ignore-commit-hold','guard !held, var command = current(ticket)','guard true, var command = current(ticket)'),
 ('ignore-command-identity','command.ticket == ticket else','true else'),
]
results=[]
with tempfile.TemporaryDirectory(prefix='sf-signaler-faults-') as tmp:
 for name,old,new in faults:
  assert source.count(old)==1,(name,source.count(old))
  p=Path(tmp)/(name+'.swift');p.write_text(source.replace(old,new,1));env=dict(os.environ);env['SPARKFORGE_SIGNALER_CORE_PATH']=str(p)
  run=subprocess.run(['sh',str(r/'run.sh')],env=env,capture_output=True,text=True)
  failed=[x for x in run.stdout.splitlines() if x.startswith('FAIL ')]
  caught=run.returncode==1 and bool(failed) and 'RESULT ' in run.stdout
  results.append({'fault':name,'exit':run.returncode,'compile_valid_behaviorally_caught':caught,'failures':failed})
  if not caught:print(run.stdout,run.stderr);raise SystemExit('Fault not caught by behavior: '+name)
print(json.dumps(results,indent=2));print('RESULT 8 compile-valid behavioral faults caught')
