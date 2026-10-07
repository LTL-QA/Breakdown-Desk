import React,{useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {Activity} from 'lucide-react';
import Desk from './desk';
import {configured,session,login,demo,startDemo} from './backend';
import './styles.css';
function App(){const [signed,setSigned]=useState(Boolean(session())||demo()),[email,setEmail]=useState(''),[password,setPassword]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);useEffect(()=>{const off=()=>setSigned(false);window.addEventListener('desk-signout',off);return()=>window.removeEventListener('desk-signout',off)},[]);
 if(!configured()&&!demo())return <div className="setup-screen"><div className="logo"><Activity/></div><h1>Breakdown Desk</h1><h2>Connect your shared database</h2><p>This bundle runs on Vercel or GitHub Pages. To start, follow <b>START-HERE.md</b> in the ZIP, run <b>database/setup.sql</b> in your Supabase project, and fill in <b>config.js</b> with your project URL and public key.</p><p>There is no ChatGPT sign-in or ChatGPT hosting dependency.</p><button className="primary full" onClick={()=>{startDemo();setSigned(true)}}>Preview the app on this device</button><p>Preview records are saved on this browser only. Shared records and staff permissions require the database setup.</p></div>;
 if(signed)return <Desk/>;
 return <div className="login-screen"><section className="panel"><div className="logo"><Activity/></div><h1>Breakdown Desk</h1><p>Sign in to your plant workspace</p>{error&&<div className="alert" role="alert">{error}</div>}<form onSubmit={async e=>{e.preventDefault();setBusy(true);setError('');try{await login(email,password);setPassword('');setSigned(true)}catch(err){setError(err instanceof Error?err.message:'Sign-in failed')}finally{setBusy(false)}}}><label>Email<input autoComplete="username" required type="email" value={email} onChange={e=>setEmail(e.target.value)}/></label><label>Password<input autoComplete="current-password" required type="password" value={password} onChange={e=>setPassword(e.target.value)}/></label><button className="primary full" disabled={busy}>{busy?'Signing in…':'Sign in'}</button></form><small>Ask your administrator for an account or a password reset.</small></section></div>
}
createRoot(document.getElementById('root')!).render(<App/>);
