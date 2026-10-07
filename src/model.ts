export const departments=['Milling department','Press','Glazing lines','Kiln','Polishing & Squaring','Sorting & Packing'];
export const categories=['Electrical','Mechanical','Production','Quality'];
export type Machine={id:string;department:string;name:string;key:string};
export type Breakdown={id:string;machineId:string;category:string;reason:string;start:number;end:number|null;reportedBy:string;closedBy:string|null;resolution:string|null;createdAt:number};
export type Reason={id:string;category:string;description:string;key:string};
export type DeskData={machines:Machine[];reasons:Reason[];breakdowns:Breakdown[];staff:{email:string;role:string}[];user:{email:string;name:string;role:string};serverTime:number};
export function normalize(v:string){return v.trim().replace(/\s+/g,' ').toLocaleLowerCase();}
export function clippedDuration(b:Breakdown,from:number,to:number,now:number){return Math.max(0,Math.min(b.end??now,to,now)-Math.max(b.start,from));}
export function minutes(ms:number){return Math.round(ms/60000);}
export function duration(ms:number){const m=Math.floor(Math.max(0,ms)/60000);return m>=1440?`${Math.floor(m/1440)}d ${Math.floor((m%1440)/60)}h ${m%60}m`:m>=60?`${Math.floor(m/60)}h ${m%60}m`:`${m}m`;}
export function localInput(time=Date.now()){const d=new Date(time);return new Date(time-d.getTimezoneOffset()*60000).toISOString().slice(0,16);}
