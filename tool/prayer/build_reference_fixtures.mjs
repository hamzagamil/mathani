// Build-time PrayTimes reference only; this source is NOT application code.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import vm from 'node:vm';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const source = readFileSync(resolve(root, 'tool/prayer/vendor/PrayTimes.js'), 'utf8');
const pinnedHash = 'f0e8442410446b1bf2db613bdebd3aa3aef5cdf5483068fbd9212d5acaa180fd';
if(createHash('sha256').update(source).digest('hex')!==pinnedHash) throw Error('Reference source changed; review and repin deliberately');
const context = vm.createContext({});
vm.runInContext(source, context, { timeout: 1000 });
const cities = [
  ['Cairo',30.0444,31.2357,'Africa/Cairo'],['Makkah',21.4225,39.8262,'Asia/Riyadh'],
  ['Karachi',24.8607,67.0011,'Asia/Karachi'],['London',51.5074,-0.1278,'Europe/London'],
  ['Oslo',59.9139,10.7522,'Europe/Oslo'],['New York',40.7128,-74.006,'America/New_York'],
  ['Los Angeles',34.0522,-118.2437,'America/Los_Angeles'],['Singapore',1.3521,103.8198,'Asia/Singapore'],
  ['Jakarta',-6.2088,106.8456,'Asia/Jakarta'],['Sydney',-33.8688,151.2093,'Australia/Sydney'],
];
const methods = {
  muslim_world_league:['MWL',18,17,1],
  egyptian:['Egypt',19.5,17.5,1],
  karachi:['Karachi',18,18,1],
  umm_al_qura:['Makkah',18.5,'90 min',0],
  north_america:['ISNA',15,15,1],
};
const ramadan = JSON.parse(readFileSync(resolve(root,'assets/prayer/ramadan_intervals.json'),'utf8'));
function isRamadanEvening(date) {
  const tomorrow = new Date(Date.parse(date+'T00:00:00Z')+86400000).toISOString().slice(0,10);
  return ramadan.intervals.some(v=>tomorrow>=v.ramadanCivilStart&&tomorrow<v.shawwalCivilStart);
}
const cases=[];
const boundary = ramadan.intervals.find(v=>v.year===1447);
const previousDay = date => new Date(Date.parse(date+'T00:00:00Z')-86400000).toISOString().slice(0,10);
const dates=[...new Set(['2026-03-15','2026-03-08','2026-03-29','2026-11-01','2026-06-21',
  previousDay(boundary.ramadanCivilStart),boundary.ramadanCivilStart,
  previousDay(boundary.shawwalCivilStart),boundary.shawwalCivilStart])];
for(const [city,latitude,longitude,timezoneId] of cities)
for(const date of dates)
for(const [methodId,[preset,fajr,isha,dhuhrOffset]] of Object.entries(methods))
for(const madhhab of ['shafii','hanafi'])
for(const highLatitudeRule of ['middleOfNight','seventhOfNight']){
  const p=new context.PrayTimes(preset);
  p.adjust({fajr,isha:methodId==='umm_al_qura'&&isRamadanEvening(date)?'120 min':isha,
    asr:madhhab==='hanafi'?'Hanafi':'Standard',
    highLats:highLatitudeRule==='middleOfNight'?'NightMiddle':'OneSeventh'});
  p.tune({dhuhr:dhuhrOffset});
  const [y,m,d]=date.split('-').map(Number);
  const times=p.getTimes([y,m,d],[latitude,longitude],0,0,'Float');
  const events={};
  for(const kind of ['fajr','sunrise','dhuhr','asr','maghrib','isha']){
    const hours=times[kind];
    events[kind]=Number.isFinite(hours)?new Date(Date.UTC(y,m-1,d)+Math.round(hours*60)*60000).toISOString():null;
  }
  cases.push({city,latitude,longitude,timezoneId,date,methodId,madhhab,highLatitudeRule,events});
}
const output={reference:'PrayTimes.js 2.5',source:'https://praytimes.org/code/v2/js/PrayTimes.js',
  sourceSha256:createHash('sha256').update(source).digest('hex'),
  license:'LGPL-3.0',conventionVersion:1,ramadanSourceVersion:ramadan.sourceVersion,
  notes:'Independent solar implementation. UTC rounded minutes, matching method offsets; review discrepancies rather than changing expected results to match the app.',
  polarCases: [{city:'Tromso',latitude:69.6492,longitude:18.9553,timezoneId:'Europe/Oslo',
    date:'2026-06-21',unavailableEvents:['fajr','sunrise','maghrib','isha']}],
  cases};
const target=resolve(root,'test/fixtures/prayer_times/reference.json');
mkdirSync(dirname(target),{recursive:true});
writeFileSync(target,JSON.stringify(output,null,2)+'\n');
console.log('Generated '+cases.length+' independent reference cases; SHA256 '+output.sourceSha256);
