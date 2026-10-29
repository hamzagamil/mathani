// Bounded read-only normalization; never log request bodies, queries or geo data.
class ApiError extends Error {
  constructor(status,code,retryable=false){super(code);this.status=status;this.code=code;this.retryable=retryable;}
}
const fail=(status,code,retryable=false)=>{throw new ApiError(status,code,retryable);};
const coordinates=(lat,lon)=>{
  if(lat==null||lon==null||lat===''||lon==='') fail(400,'invalidRequest');
  const latitude=Number(lat),longitude=Number(lon);
  if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||Math.abs(latitude)>90||Math.abs(longitude)>180) fail(400,'invalidRequest');
  return {latitude,longitude};
};
function zone(value){
  if(typeof value!=='string'||!value) return null;
  if(!/^(?:[A-Za-z_+-]+(?:\/[A-Za-z0-9_+.-]+)+|UTC|GMT)$/.test(value)) return null;
  try{new Intl.DateTimeFormat('en',{timeZone:value});return value;}catch{return null;}
}
function language(value){
  if(value!=null&&value!=='ar'&&value!=='en') fail(400,'invalidRequest');
  return value??'en';
}
function place(raw,source='manual',coords=null){
  const point=coords??coordinates(raw.lat,raw.lng);
  const timezoneId=zone(raw.timezone?.timeZoneId??raw.timezoneId);
  return {...point,placeId:raw.geonameId==null?null:'geonames:'+raw.geonameId,
    city:typeof raw.name==='string'?raw.name:'',region:typeof raw.adminName1==='string'?raw.adminName1:'',
    countryCode:/^[A-Z]{2}$/.test(raw.countryCode??'')?raw.countryCode:'',
    timezoneId,source,approximate:source==='ip',requiresConfirmation:true,
    selectable:timezoneId!==null,resolvable:timezoneId===null,
    ...(timezoneId===null?{reason:'timezoneUnresolved'}:{})};
}
async function readBody(request){
  if(!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) fail(415,'invalidRequest');
  const reader=request.body?.getReader();if(!reader) fail(400,'invalidRequest');
  const chunks=[];let size=0;
  try{
    for(;;){const {done,value}=await reader.read();if(done) break;
      size+=value.byteLength;if(size>2048){await reader.cancel();fail(413,'invalidRequest');}chunks.push(value);}
  }finally{reader.releaseLock();}
  const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.byteLength;}
  try{const v=JSON.parse(new TextDecoder().decode(bytes));
    if(!v||typeof v!=='object'||Array.isArray(v)) fail(400,'invalidRequest');return v;
  }catch(e){if(e instanceof ApiError) throw e;fail(400,'invalidRequest');}
}
function timeout(promise,signal){
  return new Promise((resolve,reject)=>{
    const abort=()=>reject(new ApiError(504,'providerTimeout',true));
    if(signal.aborted)return abort();
    signal.addEventListener('abort',abort,{once:true});
    promise.then(resolve,reject).finally(()=>signal.removeEventListener('abort',abort));
  });
}
export async function dispatch(request,env={},fetcher=fetch){
  const headers=new Headers({'Content-Type':'application/json; charset=utf-8',
    'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff',
    'Referrer-Policy':'no-referrer','Vary':'Origin'});
  const response=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
  const total=new AbortController();const totalTimer=setTimeout(()=>total.abort(),8000);
  try{
    const origin=request.headers.get('origin');
    const allowed=new Set((env.PRAYER_ALLOWED_ORIGINS??'https://get.mthani.app,https://read.mthani.app').split(',').map(v=>v.trim()).filter(Boolean));
    if(origin&&!allowed.has(origin)) fail(403,'originNotAllowed');
    if(origin)headers.set('Access-Control-Allow-Origin',origin);
    const url=new URL(request.url);
    const method=url.pathname==='/api/prayer-resolve'?'POST':'GET';
    if(request.method==='OPTIONS'){
      headers.set('Access-Control-Allow-Methods',method);
      headers.set('Access-Control-Allow-Headers','Content-Type');
      return new Response(null,{status:204,headers});
    }
    if(request.method!==method){headers.set('Allow',method+', OPTIONS');fail(405,'methodNotAllowed');}
    const provider=async(service,params)=>{
      if(!env.GEONAMES_USERNAME||env.GEONAMES_USERNAME==='demo')fail(503,'providerUnavailable',true);
      const target=new URL('https://secure.geonames.org/'+service);
      for(const [k,v]of Object.entries({...params,username:env.GEONAMES_USERNAME}))target.searchParams.set(k,String(v));
      const perRequest=new AbortController();
      const abort=()=>perRequest.abort();total.signal.addEventListener('abort',abort,{once:true});
      const timer=setTimeout(abort,5000);
      try{
        const upstream=await timeout(fetcher(target.toString(),{signal:perRequest.signal,headers:{Accept:'application/json'}}),perRequest.signal);
        if(upstream.status===429)fail(429,'rateLimited',true);
        if(!upstream.ok)fail(502,'providerUnavailable',true);
        const body=await timeout(upstream.json(),perRequest.signal);
        if(body.status){if([18,19,20].includes(body.status.value))fail(429,'rateLimited',true);fail(502,'providerUnavailable',true);}
        return body;
      }catch(e){if(e instanceof ApiError)throw e;if(perRequest.signal.aborted)fail(504,'providerTimeout',true);fail(502,'providerUnavailable',true);
      }finally{clearTimeout(timer);total.signal.removeEventListener('abort',abort);}
    };
    if(url.pathname==='/api/prayer-location'){
      if(url.search)fail(400,'invalidRequest');
      const cf=request.cf??{};let point;
      try{point=coordinates(cf.latitude,cf.longitude);}catch{fail(503,'locationUnavailable',true);}
      if(!zone(cf.timezone))fail(503,'locationUnavailable',true);
      return response(place({name:cf.city,adminName1:cf.region,countryCode:cf.country,timezoneId:cf.timezone},'ip',point));
    }
    if(url.pathname==='/api/prayer-places'){
      const q=(url.searchParams.get('q')??'').trim();if(q.length<2||q.length>80)fail(400,'invalidRequest');
      const lang=language(url.searchParams.get('lang'));
      const limit=Number(url.searchParams.get('limit')??10);if(!Number.isInteger(limit)||limit<1||limit>10)fail(400,'invalidRequest');
      const country=url.searchParams.get('country');if(country&&!/^[A-Z]{2}$/.test(country))fail(400,'invalidRequest');
      const body=await provider('searchJSON',{q,lang,maxRows:limit,featureClass:'P',style:'FULL',...(country?{country}:{})});
      if(!Array.isArray(body.geonames))fail(502,'providerUnavailable',true);
      const places=[];for(const raw of body.geonames.slice(0,limit)){try{places.push(place(raw));}catch{/* omit invalid provider rows */}}
      return response({places,attribution:{name:'GeoNames',url:'https://www.geonames.org/'}});
    }
    if(url.pathname==='/api/prayer-resolve'){
      const body=await timeout(readBody(request),total.signal);
      if(typeof body.latitude!=='number'||typeof body.longitude!=='number')fail(400,'invalidRequest');
      const point=coordinates(body.latitude,body.longitude),lang=language(body.lang);
      const source=body.source??'device';if(!['device','manual'].includes(source))fail(400,'invalidRequest');
      const [near,time]=await Promise.all([
        provider('findNearbyPlaceNameJSON',{lat:point.latitude,lng:point.longitude,lang,maxRows:1,style:'FULL'}),
        provider('timezoneJSON',{lat:point.latitude,lng:point.longitude,lang})]);
      if(!zone(time.timezoneId))fail(422,'timezoneUnresolved');
      return response({...place({...near.geonames?.[0],timezoneId:time.timezoneId},source,point),
        attribution:{name:'GeoNames',url:'https://www.geonames.org/'}});
    }
    fail(404,'invalidRequest');
  }catch(e){
    const error=e instanceof ApiError?e:new ApiError(502,'providerUnavailable',true);
    if(error.status===429)headers.set('Retry-After','60');
    return response({error:{code:error.code,retryable:error.retryable}},error.status);
  }finally{clearTimeout(totalTimer);}
}
