// Activated production-source mutations in memory, never modifying the checkout.
// A missing fixture/module, timeout, parser error, or inactive anchor is a failure.
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),os=require('node:os');
const {spawnSync}=require('node:child_process');
const controls={
 'test-stabilization-messages.cjs':['message-route','failure-identity','sending-state','parent406'],
 'test-stabilization-runtime.cjs':['entry-reset-catch','startup-no-error'],
 'test-stabilization-profiles.cjs':['profile-bio','profile-context','member-aba','member-auto-retry','member-retry-reset','member-raw-cursor'],
 'test-stabilization-search-intent.cjs':['search-owner','search-epoch','search-clear-token','search-route-owner','search-nearest','search-target-chat'],
 'test-stabilization-message-ids.cjs':['lexical-cache','lexical-rounding','lexical-depth','lexical-duplicate']
};
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'telegram-stabilization-controls-'));
const results=[];
for(const [file,mutants]of Object.entries(controls))for(const mutant of mutants){
 const receipt=path.join(directory,mutant+'.json');
 const child=spawnSync(process.execPath,[path.join(__dirname,file),'--mutant='+mutant,'--receipt='+receipt],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024});
 assert.equal(child.error,undefined,mutant+' child must finish');assert.equal(child.signal,null,mutant+' child must not be killed');
 assert.equal(child.status,1,mutant+' must fail correct assertions');
 assert.ok(fs.existsSync(receipt),mutant+' requires a completed structured receipt, not a fixture exception');
 const result=JSON.parse(fs.readFileSync(receipt,'utf8'));assert.equal(result.mutant,mutant);assert.ok(result.mutatedFiles.length>0);assert.ok(result.failed>0);
 assert.ok(result.results.filter(r=>!r.pass).every(r=>r.code==='ERR_ASSERTION'));
 results.push({mutant,file,failed:result.failed,activated:result.mutatedFiles,receipt});console.log('PASS activated assertion-rejected '+mutant);
}
const result={controls:results.length,passed:results.length,results,directory};console.log(JSON.stringify(result));
const output=process.argv.find(arg=>arg.startsWith('--receipt='));if(output)fs.writeFileSync(path.resolve(output.slice(10)),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
