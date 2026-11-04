import Foundation
var passed=0, failed=0
func check(_ name:String,_ yes:Bool){if yes{passed+=1}else{failed+=1;print("FAIL "+name)}}
let ordinary=["--arena8-six","--arena8-title"]
for context in [(false,true,false),(true,false,false),(true,true,true)] {
 check("mode rejects wrong context",!Arena8MixedPressureMode.enabled(arguments:ordinary+["--arena8-mixed-pressure"],sixRoom:context.0,isolated:context.1,arena9:context.2))
}
check("normal six-room unchanged",!Arena8MixedPressureMode.enabled(arguments:ordinary,sixRoom:true,isolated:true,arena9:false))
check("trial flag alone does not enable",!Arena8MixedPressureMode.enabled(arguments:ordinary+["--arena8-pressure-trial"],sixRoom:true,isolated:true,arena9:false))
for flag in ["--arena8-carrier-fixture","--arena8-signaler-fixture","--arena8-six-traversal","--arena8-pressure-kiting","--arena8-pressure-late"] {
 check("conflicting fixture fails closed",!Arena8MixedPressureMode.enabled(arguments:ordinary+["--arena8-mixed-pressure",flag],sixRoom:true,isolated:true,arena9:false))
}
check("explicit mixed mode",Arena8MixedPressureMode.enabled(arguments:ordinary+["--arena8-mixed-pressure"],sixRoom:true,isolated:true,arena9:false))
check("default profile baseline",Arena8MixedPressureMode.profile(arguments:ordinary) == .baseline)
check("explicit profile trial",Arena8MixedPressureMode.profile(arguments:ordinary+["--arena8-pressure-trial"]) == .trial)
for profile in Arena8PreviewSpawnClock.Profile.allCases {
 var c=Arena8PreviewSpawnClock(profile:profile)
 check("fixed approved factor",profile.intervalScale == (profile == .trial ? 0.8:1))
 for value in [0.0,-1,Double.infinity,Double.nan] {check("reject invalid base interval",c.interval(base:value)==nil)}
 check("correct initial interval",c.interval(base:1.2) == (profile == .trial ? 0.96:1.2))
 check("positive fraction no attempt",!c.advance(dt:0.1,baseInterval:1.2) && c.accumulated==0.1)
 let saved=c.accumulated
 for dt in [-1.0,Double.infinity,Double.nan] {check("invalid dt changes no state",!c.advance(dt:dt,baseInterval:1.2) && c.accumulated==saved && c.attempts==0)}
 check("hold does not consume remaining",!c.advance(dt:100,baseInterval:1.2,held:true) && c.accumulated==saved && c.attempts==0)
 for interval in [0.0,-1,Double.infinity,Double.nan] {check("invalid interval changes no state",!c.advance(dt:10,baseInterval:interval) && c.accumulated==saved && c.attempts==0)}
 let left=c.interval(base:1.2)!-c.accumulated
 check("not early",!c.advance(dt:left-0.001,baseInterval:1.2))
 check("one at boundary",c.advance(dt:0.002,baseInterval:1.2) && c.attempts==1 && c.accumulated==0)
 check("no immediate replay",!c.advance(dt:0,baseInterval:1.2) && c.attempts==1)
 check("one attempt oversized active dt",c.advance(dt:120,baseInterval:0.25) && c.attempts==2 && c.accumulated==0)
 check("oversized remainder discarded",!c.advance(dt:0.001,baseInterval:0.25) && c.attempts==2)
 c=Arena8PreviewSpawnClock(profile:profile)
 check("fresh run zeroed",c.attempts==0 && c.accumulated==0 && c.profile==profile)
}
// Independent reference of the shipped update ordering. The actual WaveManager
// source is compiled/differentially compared separately in differential.py.
for hz in [30,60,120] {
 var c=Arena8PreviewSpawnClock(profile:.baseline), elapsed=0.0,acc=0.0,events=0
 for _ in 0..<(hz*125) {
  let dt=1.0/Double(hz);elapsed+=dt;acc+=dt
  let base=elapsed<90 ? max(1.2-elapsed*0.010,0.55):max(0.55-(elapsed-90)*0.02,0.25)
  let wanted=acc>=base
  if wanted{acc=0;events+=1}
  check("baseline reference event",c.advance(dt:dt,baseInterval:base)==wanted && c.accumulated==acc && c.attempts==events)
 }
}
for base in [1.2,0.55,0.25] {
 let c=Arena8PreviewSpawnClock(profile:.trial)
 check("25percent nominal attempts",abs(base/c.interval(base:base)!-1.25)<1e-12)
}
print("RESULT \(passed) passed \(failed) failed");exit(failed==0 ? 0:1)
