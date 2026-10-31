from pathlib import Path
import subprocess,tempfile,json,sys
root=Path(__file__).resolve().parents[2]
source=(root/'Sparkforge/Systems/Arena8PacketCommands.swift').read_text()
main=(root/'tools/arena8-packet-harness/main.swift').read_text()
# Stop mutant at its first executed assertion so intentional ownership corruption
# cannot cascade into a later fixture guard. Compiler/crash outcomes never count.
assert main.count('failed += 1; print("FAIL \\(name)")') == 1
main=main.replace('failed += 1; print("FAIL \\(name)")', 'failed += 1; print("FAIL \\(name)"); exit(1)')
faults=[
 ('duplicate_escorts','escortSet.count == escorts.count,','true,','duplicate escorts rejected atomically'),
 ('owner_overlap','!escortSet.contains(owner), members.allSatisfy','true, members.allSatisfy','owner cannot duplicate escort'),
 ('held_clock','if !held { command.remaining = max(0, command.remaining - dt) }','if true { command.remaining = max(0, command.remaining - dt) }','held time does not progress'),
 ('held_commit','guard !held, var command = current(ticket), !command.committed,','guard true, var command = current(ticket), !command.committed,','held ready cannot commit'),
 ('repeat_commit','guard !held, var command = current(ticket), !command.committed,','guard !held, var command = current(ticket),','commit only once'),
 ('stale_membership','packet.incarnation == ticket.incarnation else','true else','regrouped escort rejects old association callback'),
 ('commit_live','packet.owner == ticket.source, packet.members.isSubset(of: live),','packet.owner == ticket.source,','live source required again'),
 ('commit_geometry','packet.owner == ticket.source, packet.members.isSubset(of: live),\n              destinationValid() else','packet.owner == ticket.source, packet.members.isSubset(of: live) else','geometry required again'),
]
results=[]
for name,before,after,expected in faults:
 assert source.count(before)==1,(name,'mutation not unique')
 with tempfile.TemporaryDirectory(prefix='sf-packet-fault-') as directory:
  d=Path(directory);(d/'Arena8PacketCommands.swift').write_text(source.replace(before,after));(d/'main.swift').write_text(main)
  compile=subprocess.run(['xcrun','swiftc',str(d/'Arena8PacketCommands.swift'),str(d/'main.swift'),'-o',str(d/'probe')],capture_output=True,text=True)
  if compile.returncode:raise RuntimeError(name+' failed to compile: '+compile.stderr)
  run=subprocess.run([str(d/'probe')],capture_output=True,text=True)
  caught=run.returncode==1 and ('FAIL '+expected) in run.stdout
  result={'fault':name,'compiled':True,'exit':run.returncode,'expected_failure':expected,'caught':caught};results.append(result);print(json.dumps(result),flush=True)
  if not caught:raise RuntimeError(name+' survived or crashed instead of named assertion: '+run.stdout+run.stderr)
print(json.dumps({'faults':len(results),'caught':sum(x['caught'] for x in results),'all_compile_valid':True}))
