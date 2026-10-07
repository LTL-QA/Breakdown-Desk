import {departments,categories,normalize,type DeskData} from './model';
declare global{interface Window{BREAKDOWN_CONFIG?:{supabaseUrl:string;supabaseKey:string}}}
type Session={access_token:string;refresh_token:string;expires_at:number};
let refreshing:Promise<Session>|null=null;
export function demo(){return sessionStorage.getItem('breakdown-demo')==='yes'}
export function startDemo(){sessionStorage.setItem('breakdown-demo','yes')}
export function configured(){const c=window.BREAKDOWN_CONFIG;return Boolean(c?.supabaseUrl&&c?.supabaseKey)}
function config(){const c=window.BREAKDOWN_CONFIG;if(!c?.supabaseUrl||!c?.supabaseKey)throw new Error('Complete config.js with your Supabase URL and public key first.');return {url:c.supabaseUrl.replace(/\/$/,''),key:c.supabaseKey}}
export function session(){try{return JSON.parse(localStorage.getItem('breakdown-session')||'null') as Session|null}catch{return null}}
function storeSession(d:any){if(!d.access_token||!d.refresh_token)throw new Error('Sign-in did not return a session.');const s={access_token:d.access_token,refresh_token:d.refresh_token,expires_at:Date.now()+Number(d.expires_in??3600)*1000};localStorage.setItem('breakdown-session',JSON.stringify(s));return s}
async function auth(path:string,body:unknown){const c=config();const r=await fetch(c.url+'/auth/v1/'+path,{method:'POST',headers:{apikey:c.key,'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw new Error(d.msg||d.error_description||d.message||'Authentication failed.');return d}
export async function login(email:string,password:string){storeSession(await auth('token?grant_type=password',{email,password}))}
export function logout(){sessionStorage.removeItem('breakdown-demo');const s=session();if(s&&configured()){const c=config();fetch(c.url+'/auth/v1/logout',{method:'POST',headers:{apikey:c.key,Authorization:'Bearer '+s.access_token}}).catch(()=>{})}localStorage.removeItem('breakdown-session');localStorage.removeItem('breakdown-snapshot');window.dispatchEvent(new Event('desk-signout'))}
async function token(){let s=session();if(!s)throw new Error('Please sign in.');if(s.expires_at<Date.now()+60000){refreshing??=auth('token?grant_type=refresh_token',{refresh_token:s.refresh_token}).then(storeSession).finally(()=>{refreshing=null});s=await refreshing}return s.access_token}
async function rpc(name:string,body:unknown){const c=config();const access=await token();const r=await fetch(c.url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:c.key,Authorization:'Bearer '+access,'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw new Error(d.message||'Database request failed.');return d}
const DEMO_KEY='breakdown-demo-data';
function demoData():DeskData{const saved=localStorage.getItem(DEMO_KEY);const data=saved?JSON.parse(saved):{machines:[],reasons:[],breakdowns:[],staff:[]};return {...data,user:{email:'local-preview',name:'Preview',role:'closer'},serverTime:Date.now()}}
export async function loadDesk():Promise<DeskData>{return demo()?demoData():rpc('desk_data',{})}
export async function saveDesk(payload:unknown){
 if(!demo())return rpc('desk_mutate',{payload});
 const p=payload as Record<string,any>,d=demoData(),now=Date.now();
 if(p.action==='report'){
  const department=String(p.department),name=String(p.machine||'').trim().replace(/\s+/g,' '),category=String(p.category),reason=String(p.reason||'').trim(),start=Number(p.start);
  if(!departments.includes(department)||!categories.includes(category)||!name||!reason||!Number.isFinite(start)||start<=0||start>now)throw new Error('Complete all fields and use a start time that is not in the future.');
  const key=department+'|'+normalize(name);let m=d.machines.find(m=>m.key===key);if(!m){m={id:crypto.randomUUID(),department,name,key};d.machines.push(m)}
  if(d.breakdowns.some(b=>b.machineId===m!.id&&(b.end===null||b.end>start)))throw new Error('This machine already has an ongoing or overlapping breakdown.');
  d.breakdowns.unshift({id:crypto.randomUUID(),machineId:m.id,category,reason,start,end:null,reportedBy:'local-preview',closedBy:null,resolution:null,createdAt:now});
  const rk=category+'|'+normalize(reason);if(!d.reasons.some(r=>r.key===rk))d.reasons.push({id:crypto.randomUUID(),category,description:reason,key:rk});
 }else if(p.action==='close'){
  const b=d.breakdowns.find(b=>b.id===p.id),end=Number(p.end);if(!b||b.end!==null)throw new Error('Breakdown is already closed.');if(!Number.isFinite(end)||end<b.start||end>now)throw new Error('End time must be between the start time and now.');b.end=end;b.closedBy='local-preview';b.resolution=String(p.resolution||'');
 }else throw new Error('Staff roles are available after connecting the shared database.');
 localStorage.setItem(DEMO_KEY,JSON.stringify(d));return {ok:true};
}
