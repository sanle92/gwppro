'use client';
import {useEffect,useState} from 'react';
import {Download,RefreshCw,Radio,ChevronRight} from 'lucide-react';

export default function Analytics({items}:{items:any[]}){
  const [days,setDays]=useState(7);
  const [page,setPage]=useState(0);
  const [data,setData]=useState<any>(null);
  const [error,setError]=useState('');
  const [zone,setZone]=useState('Africa/Kampala');
  const [busy,setBusy]=useState(false);
  const [showAllPages,setShowAllPages]=useState(false);
  const [showAllCountries,setShowAllCountries]=useState(false);

  async function load(){
    setBusy(true);
    try{
      const r=await fetch(`/api/analytics?days=${days}&page=${page}`,{cache:'no-store'});
      const d:any=await r.json();
      if(!r.ok)throw new Error(d.error||'Analytics unavailable.');
      setData(d);
      setError('');
    }catch(e:any){
      setError(e.message);
    }finally{
      setBusy(false);
    }
  }

  useEffect(()=>{
    let active=true;
    async function refresh(){
      if(active&&document.visibilityState==='visible')await load();
    }
    void refresh();
    const timer=setInterval(refresh,15000);
    return()=>{
      active=false;
      clearInterval(timer);
    };
  },[days,page]);

  const date=(v:string)=>new Date(v).toLocaleString('en-GB',{timeZone:zone,dateStyle:'medium',timeStyle:'short'});
  const seconds=(n:number)=>`${Math.floor(n/60)}m ${Math.round(n%60)}s`;

  function csv(){
    const rows=[
      ['Visitor / account','Started','Last seen','Country','City','Page','Device','Browser','Timezone'],
      ...data.history.map((r:any)=>[r.email||'Visitor '+r.visitor.slice(0,8),r.started,r.last_seen,r.country,r.city,r.path,r.device,r.browser,r.timezone])
    ];
    const escape=(v:any)=>'"'+String(/^[=+@-]/.test(String(v))?"'"+v:v).replaceAll('"','""')+'"';
    const url=URL.createObjectURL(new Blob(['\ufeff'+rows.map(r=>r.map(escape).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));
    const a=document.createElement('a');
    a.href=url;
    a.download='gwppro-visitor-history-page-'+(page+1)+'.csv';
    a.click();
    URL.revokeObjectURL(url);
  }

  const groups=(title:string,rows:any[],showAll:boolean,setShowAll:(v:boolean)=>void)=>
    <section className="panel analytics-breakdown">
      <h2>{title}</h2>
      {!rows.length?<p>No visits recorded in this period.</p>:
      <div className="analytics-list">
        {(showAll?rows:rows.slice(0,5)).map((r:any)=><div key={r.name}><span>{r.name}</span><b>{r.count}</b><i style={{width:Math.max(3,100*r.count/Math.max(...rows.map(x=>x.count)))+'%'}}/></div>)}
        {rows.length>5&&!showAll&&<button className="textbutton" onClick={()=>setShowAll(true)}>See more <ChevronRight size={13}/></button>}
        {showAll&&<button className="textbutton" onClick={()=>setShowAll(false)}>Show less</button>}
      </div>}
    </section>;

  return <div className="analytics">
    <div className="analytics-controls">
      <label>Period
        <select value={days} onChange={e=>{setDays(Number(e.target.value));setPage(0);}}>
          <option value={1}>Last 24 hours</option>
          <option value={7}>Last 7 days</option>
          <option value={30}>Last 30 days</option>
          <option value={90}>Last 90 days</option>
        </select>
      </label>
      <label>Display time
        <select value={zone} onChange={e=>setZone(e.target.value)}>
          <option value="Africa/Kampala">Kampala (UTC+3)</option>
          <option value="UTC">UTC</option>
        </select>
      </label>
      <button className="secondary" onClick={load} disabled={busy}><RefreshCw size={15}/>Refresh</button>
      {data&&<small>Updated {date(data.updated)}</small>}
    </div>

    {error&&<p className="notice error" role="alert">{error}</p>}
    {!data&&!error&&<p className="panel empty">Loading real visitor activity…</p>}

    {data&&<>
      <div className="stats">
        {[
          ['Live visitors',data.summary.live,'Activity in the last 90 seconds'],
          ['Unique visitors',data.summary.visitors,'Consenting browsers in this period'],
          ['Page views',data.summary.views,`${data.summary.sessions} recorded sessions`],
          ['Average visit',seconds(data.summary.duration),'Observed time between activity']
        ].map(([label,value,info])=><div className="stat" key={label}><span>{label}</span><strong>{value}</strong><small>{info}</small></div>)}
      </div>

      <section className="panel live-panel">
        <div className="panel-head">
          <h2><Radio size={17}/> Live activity</h2>
          <span className="badge">Refreshes every 15 seconds</span>
        </div>
        {!data.live.length?<div className="empty"><h3>No active visitors right now</h3><p>Activity appears after a visitor allows analytics. Live activity expires after 90 seconds.</p></div>:
        <div className="live-grid">
          {data.live.map((r:any)=><div key={r.id}><span className="live-dot"/><b>{r.email||'Visitor '+r.visitor.slice(0,8)}</b><p>{r.path}</p><small>{r.city}, {r.country} · {r.device}</small><small>Last seen {date(r.last_seen)}</small></div>)}
        </div>}
      </section>

      <section className="panel visit-trend">
        <div className="panel-head"><h2>Daily page views</h2><small>UTC days · recorded activity</small></div>
        {data.daily.length?<div className="daily-bars">{data.daily.map((r:any)=><div key={r.name}><strong>{r.count}</strong><i style={{height:Math.max(4,90*r.count/Math.max(...data.daily.map((x:any)=>x.count)))+'px'}}/><small>{r.name.slice(5)}</small></div>)}</div>:<p className="empty">Your first recorded visits will appear here.</p>}
      </section>

      <div className="analytics-grid">
        {groups('Top pages',data.pages,showAllPages,setShowAllPages)}
        {groups('Countries · approximate',data.countries,showAllCountries,setShowAllCountries)}
        {groups('Devices',data.devices,false,()=>{})}
        {groups('Referral domains',data.referrers,false,()=>{})}
      </div>

      <section className="panel visitor-history">
        <div className="panel-head">
          <div><h2>Visitor history</h2><p>Visit dates, locations and device details. {data.total} sessions in this period.</p></div>
          <button className="secondary" onClick={csv} disabled={!data.history.length}><Download size={15}/>Export this page</button>
        </div>
        <div className="table-scroll">
          <table>
            <thead><tr>{['Visitor / account','Started','Last activity','Location','Page','Device / browser','Duration'].map(s=><th key={s}>{s}</th>)}</tr></thead>
            <tbody>
              {data.history.slice(0,5).map((r:any)=><tr key={r.id}>
                <td>{r.email||'Visitor '+r.visitor.slice(0,8)}</td>
                <td>{date(r.started)}</td>
                <td>{date(r.last_seen)}</td>
                <td>{r.city}, {r.country}<small>{r.timezone}</small></td>
                <td>{r.path}</td>
                <td>{r.device}<small>{r.browser}</small></td>
                <td>{seconds((Date.parse(r.last_seen)-Date.parse(r.started))/1000)}</td>
              </tr>)}
            </tbody>
          </table>
          {!data.history.length&&<p className="empty">No visitor history yet.</p>}
        </div>
        <div className="history-pagination">
          <button className="secondary" disabled={!page} onClick={()=>setPage(page-1)}>Previous</button>
          <small>Page {page+1} · 5 rows per page</small>
          <button className="secondary" disabled={(page+1)*5>=data.total} onClick={()=>setPage(page+1)}>Next</button>
        </div>
      </section>

      <p className="analytics-note">Analytics began with this update. Only consenting visits are counted; browsers are not verified people. Location is an approximate network estimate. History is retained for 90 days. <a href="/privacy">Privacy & data</a></p>
    </>}

    <section className="panel business-overview">
      <div className="panel-head"><h2>Studio overview</h2></div>
      <div className="pipeline">{['inquiry','client','project','proposal'].map(k=><div key={k}><b>{k==='inquiry'?'Inquiries':k[0].toUpperCase()+k.slice(1)+'s'}</b><strong>{items.filter(x=>x.kind===k).length}</strong></div>)}</div>
      <div className="business-revenue">{[...new Set(items.filter(x=>x.kind==='invoice'&&x.status==='Paid').map(x=>x.currency))].map(currency=><p key={currency}>Recorded paid invoices · {currency} <b>{items.filter(x=>x.kind==='invoice'&&x.status==='Paid'&&x.currency===currency).reduce((n,x)=>n+Number(x.amount||0),0).toLocaleString()}</b></p>)}</div>
    </section>
  </div>;
}
