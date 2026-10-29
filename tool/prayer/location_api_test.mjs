import test from 'node:test';
import assert from 'node:assert/strict';
import { dispatch } from '../../functions/_lib/prayer-location.js';
const base='https://get.mthani.app';
const env={GEONAMES_USERNAME:'test-account',PRAYER_ALLOWED_ORIGINS:base};
const cf={city:'Cairo',region:'Cairo',country:'EG',latitude:'30.0444',longitude:'31.2357',timezone:'Africa/Cairo'};
const request=(path,options={},geo=cf)=>{
  const value=new Request(base+path,options);Object.defineProperty(value,'cf',{value:geo});return value;
};
test('IP candidate is approximate/confirm-only and not cached',async()=>{
  const r=await dispatch(request('/api/prayer-location'),env,async()=>{throw Error('no vendor');});
  assert.equal(r.status,200);assert.equal(r.headers.get('cache-control'),'private, no-store');
  const p=await r.json();assert.equal(p.source,'ip');assert.equal(p.approximate,true);
  assert.equal(p.requiresConfirmation,true);assert.equal(p.timezoneId,'Africa/Cairo');
});
test('missing cf data returns unavailable',async()=>{
  const r=await dispatch(request('/api/prayer-location',{},{}),env);
  assert.equal(r.status,503);assert.equal((await r.json()).error.code,'locationUnavailable');
});
test('invalid parameters never contact provider',async()=>{
  let calls=0;const fetcher=async()=>{calls++;throw Error('unexpected');};
  assert.equal((await dispatch(request('/api/prayer-places?q=a'),env,fetcher)).status,400);
  assert.equal((await dispatch(request('/api/prayer-resolve',{method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({latitude:91,longitude:0})}),env,fetcher)).status,400);
  assert.equal(calls,0);
});
test('forbidden browser origin rejected, native allowed',async()=>{
  assert.equal((await dispatch(request('/api/prayer-location',{headers:{Origin:'https://evil.example'}}),env)).status,403);
  assert.equal((await dispatch(request('/api/prayer-location'),env)).status,200);
});
test('missing timezone is resolvable and provider errors sanitized',async()=>{
  let calls=0;
  const r=await dispatch(request('/api/prayer-places?q=Cairo&lang=en'),env,async(url)=>{
    calls++;assert.equal(new URL(url).hostname,'secure.geonames.org');
    return Response.json({geonames:[{geonameId:1,name:'Cairo',countryCode:'EG',lat:'30',lng:'31',adminName1:'Cairo'}]});});
  assert.equal(calls,1);assert.equal(r.status,200);
  const p=(await r.json()).places[0];assert.equal(p.selectable,false);assert.equal(p.resolvable,true);
  const bad=await dispatch(request('/api/prayer-places?q=Cairo'),env,
    async()=>Response.json({status:{value:18,message:'SECRET'}}));
  assert.equal(JSON.stringify(await bad.json()).includes('SECRET'),false);
});
test('resolve preserves GPS coordinates and bounded requests',async()=>{
  let calls=0;
  const r=await dispatch(request('/api/prayer-resolve',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({latitude:30.1,longitude:31.2,lang:'en',source:'device'})}),env,async(url)=>{
    calls++;return Response.json(String(url).includes('timezoneJSON')?{timezoneId:'Africa/Cairo'}:
      {geonames:[{name:'Cairo',countryCode:'EG',lat:'30',lng:'31'}]});});
  assert.equal(r.status,200);const p=await r.json();
  assert.equal(p.latitude,30.1);assert.equal(p.longitude,31.2);assert.equal(calls,2);
});


test('oversized and non-JSON resolves fail before any provider work',async()=>{
  const large=await dispatch(request('/api/prayer-resolve',{method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({noise:'x'.repeat(2100)})}),env);
  assert.equal(large.status,413);
  const wrong=await dispatch(request('/api/prayer-resolve',{method:'POST',body:'raw'}),env);
  assert.equal(wrong.status,415);
});
test('methods, empty matches, quota and unresolved zones have explicit states',async()=>{
  assert.equal((await dispatch(request('/api/prayer-location',{method:'POST'}),env)).status,405);
  const empty=await dispatch(request('/api/prayer-places?q=Cairo'),env,async()=>Response.json({geonames:[]}));
  assert.deepEqual((await empty.json()).places,[]);
  const quota=await dispatch(request('/api/prayer-places?q=Cairo'),env,
    async()=>Response.json({status:{value:18,message:'private'}}));
  assert.equal(quota.status,429);assert.equal(quota.headers.get('retry-after'),'60');
  const missing=await dispatch(request('/api/prayer-resolve',{method:'POST',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({latitude:30,longitude:31})}),env,
    async()=>Response.json({geonames:[]}));
  assert.equal(missing.status,422);
});
test('an unresponsive provider is aborted within the documented bound',async()=>{
  const start=Date.now();
  const r=await dispatch(request('/api/prayer-places?q=Cairo'),env,
    async()=>new Promise(()=>{}));
  assert.equal(r.status,504);assert.ok(Date.now()-start<8000);
});
