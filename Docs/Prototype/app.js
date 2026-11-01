(() => {
'use strict';

const $ = (selector, root = document) => root.querySelector(selector);
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const id = () => globalThis.crypto?.randomUUID?.() || 'record-' + Date.now() + '-' + Math.random().toString(36).slice(2);
const clone = value => JSON.parse(JSON.stringify(value));
const paths = {
  mic:'<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/>',
  scan:'<path d="M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5M7 7v10M10 7v10M14 7v10M17 7v10"/>',
  search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  home:'<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z"/><path d="M9 21v-8h6v8"/>',
  box:'<path d="m3 7 9-4 9 4v11l-9 4-9-4Z"/><path d="m3 7 9 4 9-4M12 11v11M8 5l9 4"/>',
  pin:'<path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 0 1 14 0Z"/><circle cx="12" cy="10" r="2.5"/>',
  user:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  back:'<path d="m14.5 5-7 7 7 7"/>',
  arrow:'<path d="m9 6 6 6-6 6"/>',
  close:'<path d="m6 6 12 12M18 6 6 18"/>',
  down:'<path d="m6 9 6 6 6-6"/>',
  check:'<path d="m5 12 4 4L19 6"/>',
  more:'<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="19" cy="12" r="1" fill="currentColor"/>',
  camera:'<path d="M4 7h4l2-3h4l2 3h4v13H4Z"/><circle cx="12" cy="13" r="4"/>',
  image:'<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8" cy="8" r="1.5"/><path d="m4 17 5-5 4 4 3-3 5 5"/>',
  star:'<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z"/>',
  edit:'<path d="m15 4 5 5M4 20l5-1L21 7l-5-5L4 14Z"/>',
  calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v5M17 3v5M3 11h18M7 15h3M14 15h3"/>',
  archive:'<path d="M4 8h16v13H4Z"/><rect x="2" y="3" width="20" height="5" rx="1"/><path d="M9 12h6"/>',
  trash:'<path d="M3 6h18M9 3h6M6 6l1 15h10l1-15M10 10v7M14 10v7"/>',
  file:'<path d="M5 3h9l5 5v13H5Z"/><path d="M14 3v6h5M8 13h8M8 17h5"/>',
  settings:'<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3" fill="var(--surface)"/><circle cx="15" cy="17" r="3" fill="var(--surface)"/>',
  info:'<circle cx="12" cy="12" r="9"/><path d="M12 10v7M12 6v1"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
  leaf:'<path d="M4 20c2-9 8-13 15-16 2 12-3 18-11 15M6 17l7-7"/>',
  folder:'<path d="M3 6h7l2 3h9v11H3Z"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1 1M18 18l1 1M5 19l1-1M18 6l1-1"/>',
  share:'<circle cx="18" cy="4" r="3"/><circle cx="5" cy="12" r="3"/><circle cx="18" cy="20" r="3"/><path d="m8 10 7-4M8 14l7 4"/>',
  text:'<path d="M3 5h18M12 5v15M8 20h8M3 3v4M21 3v4"/>',
  grid:'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  loan:'<path d="M4 8h15m-5-5 5 5-5 5M20 17H5m5-5-5 5 5 5"/>'
};
function icon(name, cls = '') { return `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.box}</svg>`; }
function button(action, label, cls = '', data = '') { return `<button type="button" class="${cls}" data-action="${action}" ${data}>${label}</button>`; }
function iconButton(action, name, label, data = '') { return button(action, icon(name), 'icon-btn', `aria-label="${escapeHtml(label)}" ${data}`); }
function art(kind) {
  const backgrounds = {charger:'#ebe7dc',keys:'#e7eddf',camp:'#dce4da',camera:'#e3e6e7',book:'#eee5da',umbrella:'#e1e7ed',plain:'#e7ece2'};
  const objects = {
    charger:'<path d="M86 69C60 65 38 99 63 118c26 20 38-14 58 2" fill="none" stroke="#c9c6bd" stroke-width="9"/><path d="M86 68C60 64 38 98 63 117c26 20 38-14 58 2" fill="none" stroke="#fffdf6" stroke-width="6"/><g transform="rotate(-12 113 75)"><rect x="86" y="40" width="63" height="73" rx="15" fill="#d7d4cb"/><rect x="83" y="36" width="63" height="73" rx="15" fill="#fffdf7"/><rect x="93" y="60" width="43" height="28" rx="6" fill="#eeeae0"/><rect x="109" y="68" width="11" height="5" rx="2" fill="#697569"/><path d="M101 36V22M126 36V22" stroke="#a5aba4" stroke-width="6"/><text x="115" y="100" text-anchor="middle" font-family="sans-serif" font-size="7" fill="#899183">65W</text></g>',
    keys:'<g transform="rotate(-20 103 78)"><circle cx="93" cy="57" r="24" fill="none" stroke="#858c79" stroke-width="4"/><circle cx="93" cy="57" r="24" fill="none" stroke="#bbc2af" stroke-width="2"/><path d="M103 74v49h13v-8h8v-8h-8V74" fill="#b3a479"/><circle cx="110" cy="68" r="16" fill="#d5c596"/><circle cx="110" cy="65" r="5" fill="#e7eddf"/><rect x="65" y="61" width="30" height="55" rx="11" fill="#44775b"/><circle cx="80" cy="70" r="3" fill="#dce5d8"/><path d="M74 91h12M80 85v12" stroke="#b0c6af" stroke-width="2"/></g>',
    camp:'<path d="M50 66h108v65H50Z" fill="#7d927a"/><path d="m50 66 18-23h72l18 23" fill="#a7b49a"/><path d="M48 63h113v13H48Z" fill="#c7cbb2"/><path d="M64 79v43M145 79v43" stroke="#657e67" stroke-width="3"/><rect x="91" y="58" width="28" height="10" rx="3" fill="#526d58"/><rect x="92" y="94" width="25" height="12" rx="3" fill="#e3ddc1"/><path d="m66 43 5-15h20l6 15" fill="#d6c9a3"/><path d="M109 43V27h17v16" fill="#487a60"/><path d="M109 30h17" stroke="#bad0ba" stroke-width="3"/>',
    camera:'<g transform="rotate(-8 110 80)"><rect x="45" y="59" width="126" height="72" rx="14" fill="#4c5653"/><path d="M68 59V46h41l10 13" fill="#63716a"/><rect x="50" y="65" width="28" height="57" rx="8" fill="#33443a"/><rect x="145" y="50" width="16" height="9" rx="3" fill="#313e35"/><circle cx="114" cy="94" r="38" fill="#303d35"/><circle cx="114" cy="94" r="29" fill="#718079"/><circle cx="114" cy="94" r="24" fill="#273b35"/><circle cx="114" cy="94" r="16" fill="#1b2d28"/><circle cx="108" cy="87" r="7" fill="#50776a"/><rect x="142" y="68" width="18" height="8" rx="2" fill="#d6d9cb"/></g>',
    book:'<g transform="rotate(-10 107 80)"><rect x="57" y="35" width="99" height="111" rx="7" fill="#bb9673"/><rect x="54" y="30" width="99" height="110" rx="7" fill="#eddec0"/><rect x="61" y="30" width="5" height="110" fill="#c8ad82"/><path d="M82 65h49M82 74h34" stroke="#8f8767" stroke-width="3"/><path d="m82 104 20-17 27 26H82Z" fill="#90a187"/><circle cx="127" cy="93" r="6" fill="#d2ab6b"/><path d="M72 134h74" stroke="#cdbb98" stroke-width="2"/></g>',
    umbrella:'<path d="M109 73v54c0 16-23 16-23 2" fill="none" stroke="#806d53" stroke-width="5"/><path d="M39 81c6-68 131-68 140 0-17-12-30-12-47 0-14-12-27-12-42 0-17-12-33-12-51 0" fill="#758eaa"/><path d="M109 31c-21 11-20 34-19 50M109 31c20 12 24 33 23 50" fill="none" stroke="#b4c3d0" stroke-width="2"/><path d="M109 31v-9" stroke="#806d53" stroke-width="3"/>',
    plain:'<rect x="60" y="46" width="95" height="85" rx="16" fill="#bacbb6"/><path d="m60 61 47 21 48-21M107 82v49" stroke="#7e997b" stroke-width="3"/><path d="m60 61 47-22 48 22" fill="#d5dfc9"/>'
  };
  return `<svg viewBox="0 0 220 165" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="物品示例插图"><rect width="220" height="165" fill="${backgrounds[kind] || backgrounds.plain}"/><ellipse cx="110" cy="137" rx="65" ry="8" fill="#34452c" opacity=".08"/>${objects[kind] || objects.plain}</svg>`;
}
function photo(photoData) { return photoData?.src ? `<img src="${escapeHtml(photoData.src)}" alt="当前物品照片">` : art(photoData?.kind || 'plain'); }
const seed = () => ({
  locations:[{id:'study',name:'书房',parent:null},{id:'drawer',name:'书桌抽屉',parent:'study'},{id:'entry',name:'玄关',parent:null},{id:'cabinet',name:'右侧小柜',parent:'entry'},{id:'storage',name:'储物间',parent:null},{id:'shelf',name:'靠门置物架',parent:'storage'}],
  items:[
    {id:'charger',title:'旅行充电器',kind:'SINGLE',quantity:1,location:'drawer',photos:[{kind:'charger'}],notes:'65W，出差带这一只就够了。',aliases:'快充 充电头',category:'数码',favorite:true,status:'ACTIVE'},
    {id:'keys',title:'备用钥匙',kind:'SINGLE',quantity:1,location:'cabinet',photos:[{kind:'keys'}],notes:'绿色钥匙套，另一套放在日常背包里。',aliases:'家门钥匙',category:'家居',favorite:true,status:'ACTIVE'},
    {id:'camp',title:'周末露营箱',kind:'GROUP',quantity:null,location:'shelf',photos:[{kind:'camp'}],notes:'炉头、折叠碗、营灯、野餐垫。下次出门，先来这里看看。',aliases:'户外',category:'家居',favorite:false,status:'ACTIVE'},
    {id:'camera',title:'随身相机',kind:'SINGLE',quantity:1,location:'drawer',photos:[{kind:'camera'}],notes:'黑色相机包里还有一块备用电池。',category:'数码',favorite:false,status:'LENT',borrower:'小林',date:'2026-11-08',dateType:'归还',lead:1},
    {id:'book',title:'植物观察手册',kind:'SINGLE',quantity:1,location:'study',photos:[{kind:'book'}],notes:'阳台植物的养护记录和购买清单。',category:'其他',favorite:false,status:'ACTIVE'},
    {id:'umbrella',title:'蓝色长柄伞',kind:'SINGLE',quantity:1,location:'entry',photos:[{kind:'umbrella'}],notes:'雨停了，晾干再收进玄关。',category:'家居',favorite:false,status:'ACTIVE'}
  ].map((item,index)=>({...item,createdAt:1793487600000-index*60000,updatedAt:1793487600000-index*60000,history:['2026.11.01 · 记进家当'],confirmed:'2026.11.01'})),
  drafts:[], recent:['充电器','钥匙','露营']
});
const storageKey = 'itemnest-product-prototype-1';
let store;
try { store = JSON.parse(localStorage.getItem(storageKey)); } catch {}
if (!store || store.version !== 1) store = {version:1,mode:'demo',demo:seed(),own:{locations:[],items:[],drafts:[],recent:[]},theme:'system',simple:false,calendar:false,widget:false};
if (store.reminders === undefined) store.reminders=!!store.calendar;
if (!store.capabilityDemo) {
  const now=Date.now(),today=new Date(),day=today.getFullYear()+'-'+String(today.getMonth()+1).padStart(2,'0')+'-'+String(today.getDate()).padStart(2,'0');
  store.demo.items.push(
    {id:'expiry-cream',title:'保湿面霜',kind:'SINGLE',quantity:1,location:'cabinet',photos:[{kind:'plain'}],category:'其他',notes:'到期日期示例；所有物品都能使用。',status:'ACTIVE',date:day,dateType:'到期',lead:0,createdAt:now,updatedAt:now,history:['日期示例 · 直接填写到期日']},
    {id:'expiry-battery',title:'备用五号电池',kind:'SINGLE',quantity:4,location:'drawer',photos:[{kind:'plain'}],category:'家居',notes:'商品条码为演示码值。',status:'ACTIVE',date:'2027-05-01',dateType:'到期',lead:0,expiryMode:'shelf',producedOn:'2026-11-01',shelfValue:6,shelfUnit:'MONTH',barcode:'6900000000016',createdAt:now-1,updatedAt:now-1,history:['日期示例 · 保质期 6 个月']}
  );
  store.capabilityDemo=true;
}
let route = {page:'home',filter:'全部'};
let navigation = [];
let layers = [];
let working = null;
let selection = null;
let importMode = 'single';
let importLocation = null;
let locationScope = true;
let toastTimer;
let searchTimer;
let draftTimer;
let pressTimer;
let longPressed = false;
const phone = $('#phone');
const data = () => store[store.mode];
const itemById = itemId => data().items.find(item=>item.id === itemId);
const currentItems = () => data().items.filter(item=>!item.deletedAt && item.status !== 'ARCHIVED');
const label = item => {if(item.title?.trim())return item.title.trim();const date=new Date(item.createdAt||Date.now());return '照片记录 · '+(date.getMonth()+1)+'月'+date.getDate()+'日 '+String(date.getHours()).padStart(2,'0')+':'+String(date.getMinutes()).padStart(2,'0');};
const loc = locId => data().locations.find(location=>location.id === locId);
function path(locId) { const location = loc(locId); return location ? (location.parent ? path(location.parent) + ' / ' : '') + location.name : '添加位置'; }
function inside(locationId, parentId) { if (!locationId) return false; return locationId === parentId || (loc(locationId)?.parent ? inside(loc(locationId).parent,parentId) : false); }
function persist() { try {localStorage.setItem(storageKey,JSON.stringify(store));} catch {toast('浏览器空间已满，本次演示内容保留在当前页面');} }
function toast(message) { clearTimeout(toastTimer); $('#toast').textContent = message; $('#toast').classList.add('show'); toastTimer = setTimeout(()=>$('#toast').classList.remove('show'),3000); }
function applyTheme() { const dark = store.theme === 'dark' || (store.theme === 'system' && matchMedia('(prefers-color-scheme: dark)').matches); phone.dataset.theme = dark ? 'dark' : 'light'; phone.classList.toggle('simple-motion',store.simple); }
function navigate(page, extras = {}) { if (route.page === 'edit') saveDraft(); navigation.push({...route,scroll:$('.scroll')?.scrollTop || 0}); route = {page,...extras}; layers=[];selection=null;render(); }
function back() { if (layers.length) { closeLayer(); return; } if (route.page === 'edit') {saveDraft();working=null;} route=navigation.pop() || {page:'home',filter:'全部'};selection=null;render(); if ($('.scroll')) $('.scroll').scrollTop=route.scroll || 0; }
function goTab(page) { route={page,filter:'全部'};navigation=[];layers=[];selection=null;render(); }
function top(title, subtitle, right = '') { return `<header class="top"><div><h1>${title}</h1><p class="subtitle">${subtitle}</p></div>${right}</header>`; }
function subtop(title, right='') { return `<header class="subtop">${iconButton('back','back','返回')}<h1>${title}</h1>${right}</header>`; }
function dock() { return `<div class="dock-wrap"><nav class="dock" aria-label="一级导航">${[['home','box','家当'],['locations','pin','位置'],['mine','user','我的']].map(([page,symbol,title])=>button('tab',icon(symbol)+`<span class="tab-label">${title}</span>`,route.page===page?'active':'',`data-page="${page}" aria-label="${title}" ${route.page===page?'aria-current="page"':''}`)).join('')}</nav>${button('capture',icon('plus')+'<span>记下</span>','add-fab','aria-label="记下一件"')}</div>`; }
function row(action, symbol, title, subtitle='', extra='', attrs='') { return button(action,icon(symbol)+`<span class="row-copy"><strong>${title}</strong>${subtitle?`<small>${subtitle}</small>`:''}</span>${extra || icon('arrow','row-arrow')}`,'row',attrs); }
function empty(title, text, action='capture', actionLabel='记下一件', compact=false) { return `<div class="empty ${compact?'compact':''}">${compact?`<div class="empty-icon">${icon('box')}</div>`:'<img src="assets/brand.png" alt="">'}<h2>${title}</h2><p>${text}</p>${button(action,actionLabel,'primary')}${!compact?button('mode-demo','看看示例','text-btn'):''}</div>`; }
function itemCard(item) { return button('item',`<div class="picture">${photo(item.photos?.[0])}${item.kind==='GROUP'?'<span class="item-badge">整组</span>':''}${item.status==='LENT'?`<span class="item-badge borrowed">借给${escapeHtml(item.borrower)}</span>`:''}${selection?`<span class="card-check ${selection.has(item.id)?'checked':''}">${selection.has(item.id)?icon('check'):''}</span>`:''}</div><div class="item-copy"><h3>${escapeHtml(label(item))}</h3><p>${icon('pin')}${escapeHtml(path(item.location))}</p></div>`,'item-card',`data-id="${item.id}" aria-label="${escapeHtml(label(item))}，${escapeHtml(path(item.location))}"`); }
function filteredItems() { let items=currentItems();if(route.filter==='常用')items=items.filter(i=>i.favorite);if(route.filter==='借出')items=items.filter(i=>i.status==='LENT');if(route.filter==='整组')items=items.filter(i=>i.kind==='GROUP');return items.sort((a,b)=>b.updatedAt-a.updatedAt || a.id.localeCompare(b.id)); }

function localDay() {const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');}
function validDay(value) {if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return false;const d=new Date(value+'T00:00:00Z');return !Number.isNaN(d.getTime())&&d.toISOString().slice(0,10)===value&&value>='1900-01-01'&&value<='2200-12-31';}
function expiryValue(entry) {
  if(entry.expiryMode!=='shelf')return validDay(entry.date)?entry.date:'';
  const n=Number(entry.shelfValue),unit=entry.shelfUnit||'MONTH',limit={DAY:36500,MONTH:1200,YEAR:100}[unit];
  if(!validDay(entry.producedOn)||!Number.isInteger(n)||n<1||n>limit)return '';
  const d=new Date(entry.producedOn+'T00:00:00Z'),day=d.getUTCDate();
  if(unit==='DAY')d.setUTCDate(day+n);
  else {d.setUTCDate(1);d.setUTCMonth(d.getUTCMonth()+n*(unit==='YEAR'?12:1));const last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,0)).getUTCDate();d.setUTCDate(Math.min(day,last));}
  const result=d.toISOString().slice(0,10);return validDay(result)?result:'';
}
function expiryPreview(entry) {
  const date=expiryValue(entry);
  if(date)return '<strong>到期日期：'+date+'</strong><small>'+(store.reminders?'到期当天上午 9:00 提醒一次':'开启提醒后，到期当天上午 9:00 提醒一次')+'</small>';
  return '<span>'+(entry.expiryMode==='shelf'?(entry.producedOn?'填入有效的保质期后，自动算出到期日':'补上生产日期可计算到期日'):'日期选填，记下后随时可以补充')+'</span>';
}
function expiryFields(entry) {
  const shelf=entry.expiryMode==='shelf';
  return '<section class="expiry-fields"><div class="section-head"><h2>到期日期</h2><span>选填 · 适用所有物品</span></div><div class="segment">'+button('expiry-mode','直接填日期',!shelf?'active':'','data-value="direct"')+button('expiry-mode','按保质期计算',shelf?'active':'','data-value="shelf"')+'</div>'+
  (shelf?'<label class="form-field"><span>生产日期</span><input data-field="producedOn" type="date" min="1900-01-01" max="2200-12-31" value="'+escapeHtml(entry.producedOn||'')+'"></label><label class="form-field"><span>保质期</span><div class="date-inline"><input data-field="shelfValue" type="number" min="1" step="1" placeholder="例如 6" value="'+escapeHtml(entry.shelfValue||'')+'"><select data-field="shelfUnit">'+[['DAY','天'],['MONTH','个月'],['YEAR','年']].map(([v,t])=>'<option value="'+v+'" '+((entry.shelfUnit||'MONTH')===v?'selected':'')+'>'+t+'</option>').join('')+'</select></div></label>':'<label class="form-field"><span>到期日期</span><input data-field="date" type="date" min="1900-01-01" max="2200-12-31" value="'+escapeHtml(entry.date||'')+'"></label>')+
  '<div id="expiry-preview" class="expiry-result" aria-live="polite">'+expiryPreview(entry)+'</div></section>';
}
function dateState(item) {
  if(item.handled)return '已处理';
  if(!item.date)return '生产日期待补充';
  const days=Math.round((new Date(item.date+'T00:00:00Z')-new Date(localDay()+'T00:00:00Z'))/86400000);
  return days<0?'已过期':days===0?'今天到期':days<=30?'还有 '+days+' 天':'到期日期';
}
function reminderCopy(item) {
  if(!item.date)return '补上生产日期可计算到期日';
  const d=new Date(item.date+'T09:00:00');
  if(d<=new Date())return '在应用内关注 · 提醒时刻已到';
  return store.reminders?'安排示意 · '+d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')+' 09:00':'日期已保存 · 可开启到期提醒';
}

function home() {
  const items=filteredItems(),all=currentItems(),groups=all.filter(i=>i.kind==='GROUP').length;
  const header=selection?top('已选 '+selection.size+' 条','选择你这次想整理的记录',button('selection-done','完成','text-btn')):top('我的家当',`记住放哪，用好已有${store.mode==='demo'?'<span class="demo-tag">示例家当</span>':''}`,iconButton('selection','grid','批量整理'));
  let content=button('search',icon('search')+'<span>找找自己的东西</span><span class="key">搜索</span>','search-entry');
  const due=all.filter(i=>i.date&&!i.handled&&i.date<=localDay());
  if(due.length)content+='<div class="panel">'+row('dates','calendar',due.length+' 条日期待关注','看看已到期的物品')+'</div>';
  if(route.demoState==='loading')return header+'<div class="scroll">'+content+'<div class="loading-state"><div class="loading-ring"></div><p>正在读取家当</p>'+button('home','查看内容状态','text-btn')+'</div></div>'+dock();
  if(route.demoState==='error')return header+'<div class="scroll">'+content+empty('这次读取遇到问题','你的记录仍保存在本机，点击后重新读取。','home','重新读取',true)+'</div>'+dock();
  if(data().drafts.length) content+=`<div class="insight">${icon('edit')}<div><strong>继续刚才的记录</strong><p>${escapeHtml(data().drafts[0].title || '有一条记录等你继续')}</p></div>${button('resume',icon('arrow'),'icon-btn small',`data-id="${data().drafts[0].draftId}" aria-label="继续草稿"`)}</div>`;
  if (!all.length) content+=empty('从一件开始，慢慢记。','先记一件你以后会找的东西。<br>一张照片，或一个名字就好。');
  else {
    if(!data().drafts.length) content+=`<div class="insight">${icon('leaf')}<div><strong>每一件，都有安放的地方</strong><p>${all.length-groups} 条单件记录 · ${groups} 组家当</p></div></div>`;
    content+=`<div class="filters">${['全部','常用','借出','整组'].map(f=>button('filter',f,'chip '+((route.filter||'全部')===f?'active':''),`data-value="${f}"`)).join('')}</div>`;
    if(selection) content+=button('select-all','选择当前全部 '+items.length+' 条','text-btn');
    content+=items.length?`<div class="grid">${items.map(itemCard).join('')}</div><p class="footer-small">把位置记住，下次就好找了。</p>`:empty('这里还没有对应记录','看看全部家当，或记下一件。','clear-filter','查看全部',true);
  }
  return header+`<div class="scroll">${content}</div>`+(selection?`<div class="batchbar">${button('batch-move',icon('pin')+'移位置','primary',selection.size?'':'disabled')}${button('batch-trash',icon('trash')+'回收站','secondary',selection.size?'':'disabled')}</div>`:dock());
}
function results(query='') { const words=query.trim().normalize('NFKC').toLowerCase().split(/\s+/).filter(Boolean);return data().items.filter(item=>!item.deletedAt && (route.scope==='archive'?item.status==='ARCHIVED':item.status!=='ARCHIVED')).filter(item=>words.every(word=>[label(item),item.aliases,item.notes,item.category,path(item.location)].join(' ').normalize('NFKC').toLowerCase().includes(word))).sort((a,b)=>Number(label(b)===query)-Number(label(a)===query)||b.updatedAt-a.updatedAt); }
function resultRow(item) { return button('item',`<div class="picture">${photo(item.photos?.[0])}</div><div class="row-copy"><strong>${escapeHtml(label(item))}</strong><p>${escapeHtml(path(item.location))}</p><span class="match">${item.kind==='GROUP'?'整组 · ':''}${item.status==='LENT'?'借给'+escapeHtml(item.borrower):item.status==='ARCHIVED'?'归档记录':'在手'}${item.kind==='SINGLE'?' · '+item.quantity+' 件':''}</span></div>${icon('arrow','row-arrow')}`,'result-row',`data-id="${item.id}"`); }
function searchContent() { if(!route.query?.trim())return `<div class="section-head"><h2>最近找过</h2>${button('clear-history','清空','text-btn')}</div><div class="search-hints">${data().recent.map(word=>button('search-word',escapeHtml(word),'chip',`data-value="${escapeHtml(word)}"`)).join('') || '<p class="subtext">名称、别称和位置，都可以试试。</p>'}</div><div class="section-head"><h2>也可以按位置找</h2></div><div class="panel">${row('locations','pin','看看家里的位置','按房间、柜子和抽屉寻找')}</div><div class="section-head"><h2>最近记下</h2></div>${currentItems().slice(0,3).map(resultRow).join('')}`;
  const matches=results(route.query);
  return `<p class="caption">找到 ${matches.length} 条记录</p>${matches.length?matches.map(resultRow).join(''):empty('换个线索，再找找','试试物品的别称，或按位置看看。','locations','按位置找',true)+button('capture-query','用这个名称记下','secondary wide')}`;
}
function searchPage() { return `<div class="search-top">${iconButton('back','back','返回')}<label class="search-input">${icon('search')}<input id="query" value="${escapeHtml(route.query || '')}" aria-label="搜索家当" placeholder="名称、别称、位置" autocomplete="off">${button('clear-query',icon('close'),'icon-btn small','aria-label="清除搜索"')}</label></div><div class="scroll"><div class="filters">${button('search-scope','在手与借出','chip '+(route.scope!=='archive'?'active':''),'data-value="current"')}${button('search-scope','归档','chip '+(route.scope==='archive'?'active':''),'data-value="archive"')}</div><div class="two-actions">${button('voice-search',icon('mic')+'说出搜索词','text-btn')}${button('scan',icon('scan')+'扫一扫查同款','text-btn')}</div><div id="search-results">${searchContent()}</div></div>`; }
function locationCard(location) { const total=currentItems().filter(item=>inside(item.location,location.id)).length;const children=data().locations.filter(l=>l.parent===location.id).length;return button('location',`<div class="loc-icon">${icon(location.parent?'folder':'home')}</div><div><strong>${escapeHtml(location.name)}</strong><p>${total} 条记录${children?' · '+children+' 处子位置':''}</p></div>${icon('arrow','row-arrow')}`,'location-card',`data-id="${location.id}"`); }
function locationsPage() { const roots=data().locations.filter(location=>!location.parent);return top('位置','从你最容易想到的地方开始',iconButton('new-location','plus','新建位置'))+`<div class="scroll"><div class="insight">${icon('pin')}<div><strong>给家当一个好找的位置</strong><p>房间、柜子、抽屉，都可以。</p></div></div>${roots.length?roots.map(locationCard).join(''):empty('先记住一个地方','从书房、玄关，或手边的抽屉开始。','new-location','新建位置',true)}${roots.length?button('new-location',icon('plus')+'新建位置','secondary wide'):''}</div>`+dock(); }
function locationDetail() {const location=loc(route.id);if(!location)return subtop('位置')+empty('位置已经变化','回到位置列表看看。','locations','查看位置',true);const children=data().locations.filter(l=>l.parent===location.id),items=currentItems().filter(i=>locationScope?inside(i.location,location.id):i.location===location.id);return subtop(escapeHtml(location.name),iconButton('location-menu','more','管理位置'))+`<div class="scroll"><p class="path">${escapeHtml(path(location.id))}</p><div class="insight">${icon('folder')}<div><strong>这处位置，记下了 ${items.length} 条</strong><p>整理眼前这一小处就好。</p></div></div>${children.length?'<div class="section-head"><h2>里面还有</h2></div>'+children.map(locationCard).join(''):''}<div class="section-head"><h2>这里的家当</h2>${button('location-scope',locationScope?'包含子位置':'只看这里','text-btn')}</div>${items.length?'<div class="grid">'+items.map(itemCard).join(''):'<p class="caption">把放在这里的物品随手记下。</p>'}</div><div class="detail-footer">${button('capture-here',icon('plus')+'在这里记下','primary')}</div>`; }
function detail() {
  const item=itemById(route.id);if(!item)return subtop('家当')+empty('记录已经变化','回到家当看看当前记录。','home','查看家当',true);
  const status=item.deletedAt?'回收站':item.status==='LENT'?'借给'+escapeHtml(item.borrower):item.status==='ARCHIVED'?'已归档 · '+escapeHtml(item.archiveReason||'已整理'):'在手';
  return subtop('这件家当',iconButton('item-menu','more','更多操作'))+`<div class="scroll"><button class="hero-picture" data-action="preview" aria-label="查看物品图片">${photo(item.photos?.[0])}</button><h2 class="detail-title">${escapeHtml(label(item))}</h2><div class="status-line"><span class="badge ${item.status==='LENT'?'warm':''}">${status}</span><span>${item.kind==='GROUP'?'整组记录 · 1 组':item.quantity+' 件'}${item.category?' · '+escapeHtml(item.category):''}</span></div><div class="place-panel"><div class="label">${icon('pin')}${item.status==='LENT'?'归还时放回':'放在这里'}</div><p class="path">${escapeHtml(path(item.location))}</p><small>${item.confirmed?'位置确认于 '+escapeHtml(item.confirmed):'随时可以补上位置'}</small><div class="actions">${button('move',icon('pin')+'改位置','secondary')}${button('found',icon('check')+'找到了','text-btn')}</div></div>${item.notes?'<div class="section-head"><h2>关于它</h2></div><div class="panel padded"><p class="note-text">'+escapeHtml(item.notes)+'</p></div>':''}${item.date?'<div class="section-head"><h2>记着这一天</h2></div><div class="panel">'+row('dates','calendar',escapeHtml(item.dateType||'到期')+' · '+item.date,escapeHtml(reminderCopy(item)))+'</div>':''}${item.kind==='GROUP'?button('capture-item-here',icon('plus')+'在此位置记一件','secondary wide'):''}<div class="section-head"><h2>它的记录</h2></div><ul class="timeline">${(item.history||[]).slice().reverse().map(event=>'<li>'+escapeHtml(event)+'</li>').join('')}</ul></div><div class="detail-footer">${iconButton('favorite','star',item.favorite?'取消常用':'设为常用','aria-pressed="'+!!item.favorite+'"')}${button(item.deletedAt?'restore-trash':item.status==='ARCHIVED'?'restore-archive':item.status==='LENT'?'return':'edit',item.deletedAt?'恢复记录':item.status==='ARCHIVED'?'恢复到家当':item.status==='LENT'?'已归还':'编辑','primary')}</div>`;
}
function mine() { const items=currentItems(),single=items.filter(i=>i.kind==='SINGLE'),groups=items.filter(i=>i.kind==='GROUP');return top('我的','每一次整理，都留在这里')+`<div class="scroll"><div class="profile"><img src="assets/brand.png" alt=""><div><h2>我的家当</h2><p>属于自己的生活小档案</p></div></div><div class="stats"><div><b>${single.length}</b><span>单件记录 · 条</span></div><div><b>${groups.length}</b><span>整组记录 · 组</span></div><div><b>${single.filter(i=>i.status==='ACTIVE').reduce((n,i)=>n+i.quantity,0)}</b><span>在手单件 · 件</span></div></div><div class="panel">${row('favorites','star','常用家当','下次更快找到')}${row('drafts','edit','草稿',data().drafts.length+' 条，可以接着记')}${row('dates','calendar','提醒','日期到了，心里有数')}${row('archive','archive','归档与回收站','物品的去向，也值得记住')}</div><div class="panel">${row('data','file','数据管理','完整备份、导出与恢复')}${row('settings','settings','外观与隐私','按自己的习惯使用')}${row('help','info','帮助与关于','从一件开始，慢慢整理')}</div><p class="footer-small">记住放哪，用好已有。<br>我的家当 1.0</p></div>`+dock(); }
function dates() {
  const items=currentItems().filter(i=>(i.date||i.expiryMode==='shelf')&&(!!i.handled===!!route.handled)).sort((a,b)=>(a.date||'9999').localeCompare(b.date||'9999'));
  return subtop('提醒')+'<div class="scroll"><div class="panel">'+row('reminder-settings','calendar','到期提醒',store.reminders?'已开启 · 原型状态示意':'到期当天提醒，同一天合成一条')+'</div><div class="segment">'+button('date-tab','待关注',!route.handled?'active':'','data-value="pending"')+button('date-tab','已处理',route.handled?'active':'','data-value="done"')+'</div>'+
  (items.length?items.map(item=>'<article class="date-card"><span class="badge warm">'+dateState(item)+'</span><h3 class="spaced">'+escapeHtml(label(item))+'</h3><p>'+escapeHtml(path(item.location))+'</p><p>'+(item.date?escapeHtml(item.dateType||'到期')+' · '+item.date:'保质期 '+escapeHtml(item.shelfValue||'')+({DAY:' 天',MONTH:' 个月',YEAR:' 年'}[item.shelfUnit||'MONTH']))+'</p><p>'+reminderCopy(item)+'</p><div class="actions">'+button('item','查看物品','secondary','data-id="'+item.id+'"')+button('handled',item.handled?'重新关注':'处理完成','text-btn','data-id="'+item.id+'"')+'</div></article>').join(''):empty(route.handled?'处理过的日期会留在这里':'记下日期，到期提醒','录入时可填到期日，或用生产日期和保质期计算。','capture','记下一件',true))+'</div>';
}
function reminderSettings() {
  return subtop('到期提醒')+'<div class="scroll"><div class="insight">'+icon('calendar')+'<div><strong>日期记下，到了提醒你</strong><p>到期当天上午 9:00，同一天合成一条。</p></div></div><div class="panel">'+row('reminder-toggle','calendar','到期提醒',store.reminders?'已开启（原型示意）':'开启后，新填日期沿用设置','<span class="switch '+(store.reminders?'on':'')+'" role="switch" aria-checked="'+!!store.reminders+'"></span>')+row('reminder-detail','box','外部提醒显示物品名称','默认显示数量，打开应用查看详情','<span class="switch '+(store.reminderDetails?'on':'')+'" role="switch" aria-checked="'+!!store.reminderDetails+'"></span>')+'</div><p class="caption">首次开启会申请系统提醒所需的授权。通过日历承接时，会说明用途并申请日历访问。</p><p class="subtext">网页展示设置与安排结果。真实通知由原生应用接入系统后发送。</p>'+button('dates','查看日期','secondary wide')+'</div>';
}
function notificationPreview() {
  const due=currentItems().filter(i=>i.date&&!i.handled&&i.date<=localDay()),count=due.length||1;
  return subtop('系统通知示意')+'<div class="scroll"><p class="caption">展示通知内容和点击去向。实际样式、横幅与锁屏展示遵循系统设置。</p><div class="notification-stage">'+button('dates','<span class="notification-brand">'+icon('box')+'我的家当 <small>09:00</small></span><strong>'+count+' 条日期提醒</strong><span>'+(store.reminderDetails?escapeHtml(due.map(label).slice(0,3).join('、')||'物品到期提醒'):'打开查看日期与处理')+'</span>','notification-card')+'</div><p class="caption">点通知后，进入提醒列表，查看或处理具体物品。</p></div>';
}
function scanPage() {
  const matches=route.code?data().items.filter(i=>!i.deletedAt&&i.barcode===route.code):[];
  return subtop('扫码查同款')+'<div class="scroll"><div class="insight">'+icon('scan')+'<div><strong>看看自己是否记过</strong><p>扫描商品条码，查找自己的家当。</p></div></div><p class="caption">扫码结果演示 · 正式应用使用华为系统扫码界面。</p>'+button('scan-sample','模拟扫描：五号电池','primary wide')+'<label class="form-field"><span>商品条码</span><input id="barcode-query" value="'+escapeHtml(route.code||'')+'" maxlength="256" placeholder="也可以手动输入"></label>'+button('scan-query','查找这个条码','secondary wide')+(route.code?'<div class="section-head"><h2>当前家当中的匹配</h2><span>'+matches.length+' 条</span></div>'+(matches.length?matches.map(i=>'<div class="panel">'+resultRow(i)+'<p class="caption spaced">日期：'+escapeHtml(i.date||'随时补充')+'</p>'+button('same-item','再记同款','text-btn wide','data-id="'+i.id+'"')+'</div>').join(''):'<p class="caption">这是一个新码值。写个名称或选张照片，就能把它记下来。</p>'+button('barcode-capture','把这件记下来','primary wide')):'')+'</div>';
}
function archivePage() { const trash=route.section==='trash',items=data().items.filter(i=>trash?!!i.deletedAt:i.status==='ARCHIVED'&&!i.deletedAt);return subtop('归档与回收站')+`<div class="scroll"><div class="segment">${button('archive-tab','归档',!trash?'active':'','data-value="archive"')}${button('archive-tab','回收站',trash?'active':'','data-value="trash"')}</div><p class="caption">${trash?'回收站中的记录保留 30 天，可以随时恢复。':'已经用完、送出或整理好的物品，在这里留下一份记录。'}</p>${items.length?items.map(resultRow).join(''):empty(trash?'回收站是空的':'整理过的家当，会留在这里',trash?'当前家当都好好保存着。':'从详情里的“归档”记录物品的去向。','home','查看家当',true)}</div>`; }
function settings() { return subtop('外观与隐私')+`<div class="scroll"><div class="panel"><div class="row">${icon('sun')}<div class="row-copy"><strong>外观</strong><small>选择让自己舒服的颜色</small></div></div><div class="setting-options">${[['system','跟随系统'],['light','浅色'],['dark','深色']].map(([value,title])=>button('theme',title,store.theme===value?'active':'',`data-value="${value}"`)).join('')}</div>${row('motion','leaf','简洁动效','保留清楚的状态变化',`<span class="switch ${store.simple?'on':''}" role="switch" aria-checked="${store.simple}"></span>`)}</div><div class="panel">${row('widget-toggle','grid','桌面卡片展示常用家当','开启后展示最多 3 条名称与位置',`<span class="switch ${store.widget?'on':''}" role="switch" aria-checked="${store.widget}"></span>`)}${row('reminder-settings','calendar','到期提醒','到期当天提醒一次')}</div><div class="panel padded"><h3>你的家当，保存在设备中</h3><p class="caption">名称、照片和位置在本机保存。你可以制作完整备份，也可以通过系统备份和换机继续使用。</p><p class="subtext">开启到期提醒后，汇总内容交给系统通知或日历。名称按详情开关展示。导出文件保存到你选择的位置。</p></div>${button('widgets','预览桌面卡片','secondary wide')}<p class="footer-small">字体与字号跟随系统设置。</p></div>`; }
function dataPage() { return subtop('数据管理')+`<div class="scroll"><div class="insight">${icon('box')}<div><strong>让记下的家当，长久陪着你</strong><p>当前有 ${data().items.length} 条记录</p></div></div><div class="panel">${row('backup','file','制作完整备份','记录、照片、位置和草稿一起保存')}${row('csv','share','导出清单','一份方便阅读的表格清单')}${row('restore-preview','archive','从备份恢复','先核对内容，再选择恢复方式')}</div><div class="panel padded"><h3>系统备份与换机</h3><p class="caption">通过手机的系统备份和换机功能，可以把自己的家当带到新设备。应用会恢复照片、记录、草稿和使用偏好。</p><p class="subtext">手动完整备份会生成 .itemnest 文件，保存在你指定的位置。</p></div><p class="caption">完整备份包含物品照片、位置和借出信息，请选择自己信任的保存位置。</p></div>`; }
function importPage() {return subtop('把照片记进家当')+`<div class="scroll"><p class="caption">已收到 2 张照片，选择一种好记的方式。</p><div class="import-photos"><div class="picture">${art('charger')}</div><div class="picture">${art('keys')}</div></div><div class="import-choice">${button('import-mode','每张记一件',importMode==='single'?'active':'','data-value="single"')}${button('import-mode','合成一组',importMode==='group'?'active':'','data-value="group"')}</div><label class="form-field"><span>${importMode==='group'?'组的名称':'第一件名称'} <small>选填</small></span><input id="import-title" placeholder="${importMode==='group'?'例如：出门小物':'例如：旅行充电器'}"></label>${importMode==='single'?'<label class="form-field"><span>第二件名称 <small>选填</small></span><input id="import-title2" placeholder="例如：备用钥匙"></label>':''}<button class="form-location" data-action="import-location">${icon('pin')}<div><small>放在这里</small><span>${escapeHtml(path(importLocation))}</span></div>${icon('arrow','row-arrow')}</button><p class="subtext">每张记一件，方便分别寻找；合成一组，记住它们放在一起。</p></div><div class="detail-footer">${button('import-save',importMode==='group'?'保存这组':'保存 2 条记录','primary')}</div>`; }
function widgets() {return subtop('桌面卡片')+`<div class="scroll"><p class="caption">从桌面，直接找东西或记下一件。</p><div class="section-head"><h2>2 × 2</h2><span>随手操作</span></div><div class="widget small"><h3>我的家当</h3><p>记住放哪，用好已有</p><div class="widget-actions">${button('search',icon('search')+'找东西')}${button('capture',icon('plus')+'记一件')}</div></div><div class="section-head"><h2>2 × 4</h2><span>常用家当</span></div><div class="widget"><h3>我的家当</h3>${store.widget?currentItems().filter(i=>i.favorite).slice(0,3).map(i=>row('item','box',escapeHtml(label(i)),escapeHtml(path(i.location)),'',`data-id="${i.id}"`)).join(''):'<p>从一件值得记住的东西开始。</p>'}<div class="widget-actions">${button('search',icon('search')+'找东西')}${button('capture',icon('plus')+'记一件')}</div></div><p class="caption">常用摘要由“外观与隐私”中的开关控制。</p>${button('settings','设置卡片内容','secondary wide')}<div class="section-head"><h2>长按应用图标</h2><span>四个快捷方式</span></div><div class="panel">${row('capture','plus','记一件')}${row('search','search','找东西')}${row('dates','calendar','看临期')}${row('scan','scan','扫一扫')}</div><div class="section-head"><h2>日期摘要卡片</h2><span>示意</span></div><div class="widget"><h3>看看这些日期</h3><p>更新于 ${localDay()}</p>${currentItems().filter(i=>i.date&&!i.handled).sort((a,b)=>a.date.localeCompare(b.date)).slice(0,3).map(i=>row('dates','calendar',escapeHtml(label(i)),i.date)).join('')}${button('dates','查看日期','text-btn')}</div></div>`; }
function help() {return subtop('帮助与关于')+`<div class="scroll"><div class="profile"><img src="assets/brand.png" alt=""><div><h2>我的家当</h2><p>记住放哪，用好已有。</p></div></div>${[['从一件开始','先挑一件你以后会找的东西。写个名称或加张照片，就能记下来。','capture','试着记下一件'],['一箱，也可以是一条','用整组记录记住收纳箱里有什么。以后需要更细时，再在同一位置记下一件。','capture-group','记下一组'],['找到以后，顺手确认','详情中点“找到了”确认位置。搬动以后，点“改位置”记住新去处。','home','看看已有家当'],['把记录好好保存','完整备份包含照片和位置，恢复时可以先核对内容。','data','去数据管理']].map(([title,text,action,cta])=>`<section class="help-block"><h2>${title}</h2><p>${text}</p>${button(action,cta,'text-btn')}</section>`).join('')}<p class="footer-small">我的家当 · 1.0<br>com.imotong.itemnest</p></div>`; }
function fields() {return `<div class="segment">${button('kind','记一件',working.kind==='SINGLE'?'active':'','data-value="SINGLE"')}${button('kind','记一组',working.kind==='GROUP'?'active':'','data-value="GROUP"')}</div>${working.photos.length?'<div class="photo-list">'+working.photos.map((p,index)=>`<div class="photo-thumb"><div class="picture">${photo(p)}</div>${button('remove-photo',icon('close'),'',`data-index="${index}" aria-label="移除第 ${index+1} 张照片"`)}</div>`).join('')+'</div>':`<div class="photo-choices">${button('camera',icon('camera')+'拍照')}${button('photos',icon('image')+'从相册选')}${button('sample-photo',icon('box')+'示例图片')}</div>`}${working.photos.length?'<div class="two-actions">'+button('photos',icon('plus')+'添加照片','text-btn')+button('ocr',icon('text')+'提取照片文字','text-btn')+'</div>':''}<label class="form-field"><span>${working.kind==='GROUP'?'这组叫什么':'物品名称'} <small>${working.photos.length?'选填':'名称或照片，填一项就好'}</small></span><input name="title" data-field="title" maxlength="80" value="${escapeHtml(working.title)}" placeholder="给它起个容易想起的名字" autocomplete="off"></label>${button('voice-name',icon('mic')+'说出名称','text-btn')}${working.barcode?'<p class="caption">商品条码：'+escapeHtml(working.barcode)+'</p>':''}<button class="form-location" data-action="draft-location">${icon('pin')}<div><small>${working.location?'放在这里':'放在哪里'}</small><span>${escapeHtml(path(working.location))}</span></div>${icon('arrow','row-arrow')}</button>${button('more-fields',(working.more?'收起':'更多信息')+icon('down'),'disclosure')}${working.more?`<div class="more-fields"><label class="form-field"><span>分类</span><select data-field="category"><option value="">添加分类</option>${['数码','衣物','家居','食品','工具','证件','其他'].map(c=>'<option '+(working.category===c?'selected':'')+'>'+c+'</option>').join('')}</select></label>${working.kind==='SINGLE'?'<label class="form-field"><span>数量</span><input data-field="quantity" type="number" min="1" max="9999" value="'+(working.quantity||1)+'"></label>':''}<label class="form-field"><span>别称 <small>用空格分开</small></span><input data-field="aliases" maxlength="150" value="${escapeHtml(working.aliases||'')}" placeholder="例如：充电头 快充"></label><label class="form-field"><span>${working.kind==='GROUP'?'里面有什么':'备注'}</span><textarea data-field="notes" maxlength="2000" placeholder="写下以后会用到的线索">${escapeHtml(working.notes||'')}</textarea></label>${button('voice-notes',icon('mic')+'说出说明','text-btn')}${expiryFields(working)}</div>` : ''}<p id="form-error" class="field-error"></p>`; }
function validWorking() {return !!working && (!!working.title.trim() || working.photos.length>0);}
function saveFooter(edit=false) {return `<div class="form-foot"><span class="hint">${validWorking()?'随时可以再补充':'写个名称，或加张照片'}</span>${button('save',edit?'保存修改':'保存','primary',validWorking()?'':'disabled')}</div>`; }
function editPage() {return subtop('编辑物品')+`<div class="scroll edit-body">${fields()}</div>`+saveFooter(true); }
const pageInfo = {home:['P01','家当'],search:['P02','搜索'],detail:['P05','物品详情'],edit:['P06','编辑物品'],locations:['P07','位置'],location:['P08','位置详情'],mine:['P11','我的'],dates:['P12','提醒'],data:['P13','数据管理'],archive:['P14','归档与回收站'],settings:['P15','外观与隐私'],import:['P16','接收图片'],widgets:['P18','桌面卡片'],help:['P19','帮助与关于'],reminderSettings:['P21','到期提醒'],scan:['P22','扫码查同款'],notification:['P21','系统通知示意']};
function render() {
  applyTheme();
  const pages={home,search:searchPage,detail,edit:editPage,locations:locationsPage,location:locationDetail,mine,dates,data:dataPage,archive:archivePage,settings,import:importPage,widgets,help,reminderSettings,scan:scanPage,notification:notificationPreview};
  $('#app').innerHTML=(pages[route.page]||home)();
  $('#page-code').textContent=(pageInfo[route.page]||pageInfo.home).join(' · ');
  $('#mode-switch').textContent=store.mode==='demo'?'空白开始':'查看示例';
  renderLayers();
}
function sheet(title,body,footer='',size='') {return `<section class="sheet ${size}" role="dialog" aria-modal="true" aria-label="${escapeHtml(title)}"><div class="handle"></div><header class="sheet-head"><h2>${title}</h2>${button('close',icon('close'),'icon-btn small','aria-label="关闭面板"')}</header><div class="sheet-body">${body}</div>${footer}</section>`; }
function openLayer(type,params={}) {layers.push({type,...params});renderLayers();setTimeout(()=>$('.sheet-head button')?.focus({preventScroll:true}),40);}
function closeLayer() {
  const closed=layers.pop();
  if(closed?.type==='capture'){saveDraft();working=null;render();}
  else renderLayers();
  if(!layers.length)$('#app button')?.focus({preventScroll:true});
}
function renderLayers() {
  $('#layers').innerHTML=layers.length?'<div class="overlay">'+layerContent(layers.at(-1))+'</div>':'';
  $('#app').inert=layers.length>0;
  $('#page-code').textContent=selection?'P10 · 批量整理':(pageInfo[route.page]||pageInfo.home).join(' · ');
  if(layers.length) $('#page-code').textContent=({capture:'P03 · 记下',picker:'P04 · 选择位置',newLocation:'P09 · 新建位置',drafts:'P11 · 草稿',ocr:'P17 · 文字候选',preview:'P17 · 图片预览',voice:'P23 · 语音填写'}[layers.at(-1).type]||$('#page-code').textContent);
}
function layerContent(layer) {
  const item=itemById(route.id);
  if(layer.type==='sceneMenu')return sheet('原型场景','<p class="caption">选择想查看的任务或页面状态。</p><div class="panel">'+row('home','box','示例中的当前家当')+row('expiry-demo','calendar','P20 · 录入到期日期','直接填写，或按保质期计算')+row('notification','calendar','系统通知示意')+row('scan','scan','P22 · 扫码查同款')+row('import','share','P16 · 分享收图')+row('widgets','grid','P18 · 桌面卡片')+row('data','file','P13 · 数据管理')+row('settings','settings','P15 · 深浅外观')+row('help','info','P19 · 帮助')+row('loading-scene','clock','首页读取状态')+row('error-scene','info','首页重新读取状态')+'</div>');
  if(layer.type==='voice')return sheet('说出'+({title:'名称',notes:'说明',query:'搜索词'}[layer.target]),'<p class="caption">语音候选示例 · 正式应用使用设备上的离线语音识别。</p><div class="voice-symbol">'+icon('mic')+'</div>'+(layer.ready?'<label class="form-field"><span>识别结果，可继续编辑</span><textarea id="voice-candidate">'+escapeHtml(layer.target==='notes'?'炉头、折叠碗、营灯':layer.target==='query'?'电池':'备用五号电池')+'</textarea></label>'+button('voice-adopt','采用文字','primary wide')+button('voice-again','重新说','text-btn wide'):button('voice-example','查看一句口述的结果','primary wide'))+button('close','取消','text-btn wide'));
  if(layer.type==='capture')return sheet(working.kind==='GROUP'?'记下一组':'记下一件',fields(),saveFooter());
  if(layer.type==='receipt') {const saved=itemById(layer.id);return sheet('已记下',`<div class="receipt"><div class="check-circle">${icon('check')}</div><h3>这件家当，记住了。</h3><p>${escapeHtml(label(saved))}<br>${saved.location?escapeHtml(path(saved.location)):'随时可以补上位置'}</p><div class="picture">${photo(saved.photos?.[0])}</div><div class="receipt-buttons">${saved.date&&!store.reminders?button('reminder-settings','开启到期提醒','secondary'):''}${button('receipt-view','查看这件','primary',`data-id="${saved.id}"`)}${button('continue','继续记下','secondary',`data-id="${saved.id}"`)}${button('receipt-search','试着找一下','text-btn',`data-id="${saved.id}"`)}${button('finish-session','完成这次整理','text-btn')}</div></div>`);}
  if(layer.type==='picker') {const all=data().locations.slice().sort((a,b)=>path(a.id).localeCompare(path(b.id),'zh-CN'));return sheet('放在哪里',`<p class="caption">选择你能想起来的那一处。</p><div class="location-picks">${all.map(location=>`<div class="location-select-row"><div class="loc-label">${escapeHtml(location.name)}<small>${escapeHtml(path(location.id))}</small></div>${button('choose-location','选择这里','choose',`data-id="${location.id}"`)}</div>`).join('')}</div>${button('new-location',icon('plus')+'新建位置','secondary wide')}${['draft','import'].includes(layer.target)?button('choose-location','稍后补充位置','text-btn wide','data-id=""'):''}`);}
  if(layer.type==='newLocation')return sheet(layer.edit?'修改位置':'新建位置',`<label class="form-field"><span>位置名称</span><input id="loc-name" maxlength="30" value="${escapeHtml(layer.edit?loc(layer.edit)?.name:'')}" placeholder="例如：书桌抽屉"></label><label class="form-field"><span>上一级</span><select id="loc-parent"><option value="">作为一级位置</option>${data().locations.filter(l=>!layer.edit || !inside(l.id,layer.edit)).map(l=>'<option value="'+l.id+'" '+(l.id===layer.parent?'selected':'')+'>'+escapeHtml(path(l.id))+'</option>').join('')}</select></label><p id="loc-error" class="field-error"></p>`,`<div class="form-foot">${button('save-location','保存位置','primary')}</div>`);
  if(layer.type==='draftChoice')return sheet('接着记，还是另记一条？','<p class="caption">刚才的内容已经保存在草稿里。</p><div class="receipt-buttons">'+button('resume-latest','继续刚才','primary')+button('capture-fresh','另记一条','secondary')+'</div>');
  if(layer.type==='drafts')return sheet('草稿',data().drafts.length?data().drafts.map(d=>'<div class="panel">'+row('resume','edit',escapeHtml(d.title||'照片记录'),new Date(d.draftTime).toLocaleString('zh-CN'),'',`data-id="${d.draftId}"`)+row('delete-draft','trash','移除这条草稿','','',`data-id="${d.draftId}"`)+'</div>').join(''):'<p class="caption">输入到一半的记录，会保存在这里。</p>');
  if(layer.type==='menu') {
    const entries=item.deletedAt?[['restore-trash','archive','恢复记录'],['delete-confirm','trash','永久删除']]:item.status==='ARCHIVED'?[['restore-archive','archive','恢复家当'],['trash-confirm','trash','移到回收站']]:[['favorite','star',item.favorite?'取消常用':'设为常用'],['move','pin','改位置'],...(item.kind==='SINGLE'?[['quantity','box','调整数量']]:[]),...(item.status==='ACTIVE'?[['loan','loan','借出']]:[['return','loan','已归还']]),['date-edit','calendar','关注日期'],['archive-confirm','archive','归档'],['trash-confirm','trash','回收站']];
    return sheet('管理这件家当','<div class="menu-options">'+entries.map(([a,s,t])=>button(a,'<span>'+icon(s)+'</span>'+t,a.includes('trash')||a.includes('delete')?'danger':'')).join('')+'</div>');
  }
  if(layer.type==='quantity')return sheet('调整数量',`<p class="caption">当前 ${item.quantity} 件。填 0 时，记录归档为已用完。</p><label class="form-field"><span>现在还有</span><input id="quantity-value" class="number-input" type="number" min="0" max="9999" value="${item.quantity}"></label><p id="short-error" class="field-error"></p>`,`<div class="form-foot">${button('quantity-save','确认数量','primary')}</div>`);
  if(layer.type==='loan')return sheet('借给谁了',`<label class="form-field"><span>对方称呼</span><input id="borrower" maxlength="40" placeholder="例如：小林"></label><label class="form-field"><span>预计归还日期 <small>选填</small></span><input id="return-date" type="date"></label><p class="caption">本次借出整条记录，共 ${item.kind==='GROUP'?'1 组':item.quantity+' 件'}。原位置保留为归还参考。</p><p id="short-error" class="field-error"></p>`,`<div class="form-foot">${button('loan-save','记下借出','primary')}</div>`);
  if(layer.type==='date')return sheet('修改日期','<p class="caption">日期随物品一同编辑保存。</p>'+button('edit','编辑物品日期','primary wide'));
  if(layer.type==='confirm')return sheet(layer.title,`<p class="caption">${layer.message}</p>${layer.action==='archive-save'?'<label class="form-field"><span>这件物品的去向</span><select id="archive-reason"><option>已送出</option><option>已出售</option><option>已丢弃</option><option>其他归档</option></select></label>':''}<div class="receipt-buttons">${button(layer.action,layer.confirm,layer.danger?'danger-btn':'primary')}${button('close','继续保留','secondary')}</div>`);
  if(layer.type==='preview')return sheet('物品照片',`<div class="preview-picture">${photo(item?.photos?.[0] || working?.photos[0])}</div><div class="two-actions">${button('main-photo','设为主图','secondary')}${button('ocr',icon('text')+'提取文字','primary')}</div>`);
  if(layer.type==='ocr')return sheet('照片里的文字',`<p class="caption">候选示例 · 选择你需要的内容，填入当前记录。</p><div class="candidate"><span>旅行充电器</span>${button('use-ocr','填入名称','','data-value="旅行充电器"')}</div><div class="candidate"><span>65W 快充</span>${button('use-ocr-note','补到备注','','data-value="65W 快充"')}</div><div class="candidate"><span>2026-12-31</span>${button('use-ocr-date','选择日期','','data-value="2026-12-31"')}</div><p class="subtext">文字来源于当前照片。你可以继续编辑名称，也可以先保留照片。</p>`);
  if(layer.type==='backup')return sheet('完整备份预览',`<div class="file-preview">${icon('file')}<strong>我的家当_20261101_1200.itemnest</strong><p>${data().items.length} 条记录 · ${data().locations.length} 个位置<br>包含照片、日期和草稿</p></div><p class="caption">选择自己信任的保存位置，把这份家当好好收起来。</p>`,`<div class="form-foot">${button('backup-result','查看保存结果','primary')}</div>`);
  if(layer.type==='backupResult')return sheet('备份保存结果',`<div class="receipt"><div class="check-circle">${icon('check')}</div><h3>这份家当，收好了。</h3><p>我的家当_20261101_1200.itemnest</p><p class="caption">原型展示保存回执，正式文件由应用接入系统选择器后生成。</p>${button('close','完成','primary wide')}</div>`);
  if(layer.type==='restore')return sheet('核对备份内容',`<div class="file-preview"><strong>我的家当_20261028_0930.itemnest</strong><p>示例文件 · 2026 年 10 月 28 日<br>6 条记录，6 张照片，3 个位置</p></div><div class="panel">${row('noop','plus','新增 2 条','按备份中的记录保存')}${row('noop','edit','1 条内容有差异','默认保留当前版本')}</div><label class="form-field"><span>恢复方式</span><select id="restore-mode"><option value="merge">合并到当前家当</option><option value="replace">用备份替换当前家当</option></select></label><p id="restore-note" class="caption">先保留当前记录，再加入确认的新内容。</p>`,`<div class="form-foot">${button('restore-result','查看恢复结果','primary')}</div>`);
  if(layer.type==='restoreResult')return sheet('恢复结果预览','<div class="success-note">新增 2 条 · 保留当前版本 1 条<br>照片与位置已完成核对<br>未来日历：待安排</div><p class="caption">这是恢复流程演示。实际文件校验、合并与替换由正式应用按数据规范实现。</p>'+button('close','完成','primary wide'));
  if(layer.type==='csv')return sheet('导出清单预览','<div class="file-preview">'+icon('file')+'<strong>我的家当_20261101.csv</strong><p>名称、数量、状态、位置和日期<br>UTF-8 表格清单</p></div><p class="caption">完整照片随完整备份保存。</p>'+button('close','完成预览','primary wide'));
  if(layer.type==='locationMenu')return sheet('管理位置','<div class="panel">'+row('rename-location','edit','修改名称与上一级','位置里的家当会跟随路径更新')+row('new-child','plus','新建子位置','按照真实空间继续细分')+'</div>');
  return sheet('当前操作','<p class="caption">继续看看这份家当。</p>');
}
function startCapture(params={}) {
  if(params.resume) working=clone(params.resume);
  else working={draftId:id(),title:params.title||'',kind:params.kind||'SINGLE',quantity:1,photos:[],location:params.location||null,notes:'',aliases:'',category:'',date:'',dateType:'到期',lead:0,expiryMode:'direct',shelfUnit:'MONTH',barcode:params.barcode||'',more:!!params.more||params.kind==='GROUP',sessionId:params.sessionId||id()};
  layers=[];openLayer('capture');
}
function saveDraft() {
  clearTimeout(draftTimer);
  if(!working)return;
  if(!working.title.trim() && !working.photos.length && !working.notes?.trim()){
    data().drafts=data().drafts.filter(d=>d.draftId!==working.draftId);persist();return;
  }
  const drafts=data().drafts,index=drafts.findIndex(d=>d.draftId===working.draftId),draft={...clone(working),draftTime:Date.now()};
  if(index>=0)drafts.splice(index,1);
  drafts.unshift(draft);persist();
}
function changed(item, event) {item.updatedAt=Date.now();item.history??=[];item.history.push(new Date().toLocaleDateString('zh-CN')+' · '+event);persist();}
function updateWorking(field,value) {
  if(!working)return;
  working[field]=field==='quantity'?Number(value):value;
  if(['date','producedOn','shelfValue','shelfUnit'].includes(field)){working.dateType='到期';working.lead=0;if(working.expiryMode==='shelf')working.date=expiryValue(working);const preview=$('#expiry-preview');if(preview)preview.innerHTML=expiryPreview(working);}
  const save=$('[data-action="save"]');
  if(save)save.disabled=!validWorking();
  const hint=$('.form-foot .hint');
  if(hint)hint.textContent=validWorking()?'随时可以再补充':'写个名称，或加张照片';
  clearTimeout(draftTimer);draftTimer=setTimeout(saveDraft,500);
}
function saveWorking() {
  if(!validWorking())return;
  if(working.expiryMode==='shelf'&&working.shelfValue){const n=Number(working.shelfValue),limit={DAY:36500,MONTH:1200,YEAR:100}[working.shelfUnit||'MONTH'];if(!Number.isInteger(n)||n<1||n>limit||(working.producedOn&&!expiryValue(working))){$('#form-error').textContent='请填写有效的生产日期和整数保质期';return;}}
  if(working.kind==='SINGLE' && (!Number.isInteger(working.quantity)||working.quantity<1||working.quantity>9999)){$('#form-error').textContent='请填写 1—9999 的整数数量';return;}
  const save=$('[data-action="save"]');if(save){save.disabled=true;save.textContent='正在保存';}
  clearTimeout(draftTimer);
  if(working.expiryMode==='shelf')working.date=expiryValue(working);
  const existing=working.itemId?itemById(working.itemId):null;
  const saved={...(existing||{}),...clone(working),id:existing?.id || id(),createdAt:existing?.createdAt||Date.now(),updatedAt:Date.now(),status:existing?.status||'ACTIVE',quantity:working.kind==='GROUP'?null:working.quantity,history:existing?.history||[],confirmed:working.location?new Date().toLocaleDateString('zh-CN'):null};
  if(existing&&(existing.date!==saved.date||existing.producedOn!==saved.producedOn||existing.shelfValue!==saved.shelfValue||existing.shelfUnit!==saved.shelfUnit)){saved.handled=false;saved.lead=0;}
  delete saved.draftId;delete saved.draftTime;delete saved.itemId;delete saved.sessionId;delete saved.more;
  if(existing)Object.assign(existing,saved);else data().items.unshift(saved);
  changed(existing||saved,existing?'更新记录':'记进家当');
  data().drafts=data().drafts.filter(d=>d.draftId!==working.draftId);
  persist();working=null;layers=[];
  if(existing){route={page:'detail',id:existing.id};render();toast('修改已保存');}
  else {render();openLayer('receipt',{id:saved.id});}
}
function chooseLocation(locationId) {
  const target=layers.at(-1).target;
  if(target==='draft'){working.location=locationId||null;layers.pop();saveDraft();renderLayers();if(route.page==='edit')render();}
  if(target==='move'||target==='return'){const item=itemById(route.id);item.location=locationId;item.confirmed=new Date().toLocaleDateString('zh-CN');if(target==='return'){item.status='ACTIVE';item.borrower='';if(item.dateType==='归还')item.handled=true;}changed(item,target==='return'?'已归还，放回 '+path(locationId):'移到 '+path(locationId));layers=[];render();toast(target==='return'?'已经放回家当':'位置已更新');}
  if(target==='batch'){selection.forEach(itemId=>{const item=itemById(itemId);item.location=locationId;item.confirmed=new Date().toLocaleDateString('zh-CN');changed(item,'移到 '+path(locationId));});const count=selection.size;selection=null;layers=[];render();toast(count+' 条记录的位置已更新');}
  if(target==='import'){importLocation=locationId;layers=[];render();}
}
function saveLocation() {
  const layer=layers.at(-1),name=$('#loc-name').value.trim(),parent=$('#loc-parent').value||null;
  if(!name){$('#loc-error').textContent='给这个位置起个名字';return;}
  if(data().locations.some(l=>l.id!==layer.edit&&l.parent===parent&&l.name.normalize('NFKC').toLowerCase()===name.normalize('NFKC').toLowerCase())){$('#loc-error').textContent='这里已有这个位置，可以换个名称';return;}
  const depth=parent?path(parent).split(' / ').length+1:1;
  const descendants=layer.edit?data().locations.filter(l=>inside(l.id,layer.edit)):[],oldDepth=layer.edit?path(layer.edit).split(' / ').length:1;
  const height=Math.max(0,...descendants.map(l=>path(l.id).split(' / ').length-oldDepth));
  if(depth+height>4){$('#loc-error').textContent='位置最多 4 层，请选择更上一级的位置';return;}
  const locationId=layer.edit||id();
  if(layer.edit)Object.assign(loc(layer.edit),{name,parent});else data().locations.push({id:locationId,name,parent});
  persist();layers.pop();
  if(layers.at(-1)?.type==='picker')chooseLocation(locationId);
  else{layers=[];render();toast('位置已保存');}
}
function shortError(message) {const element=$('#short-error');if(element)element.textContent=message;else toast(message);}
function handle(action,el) {
  const item=itemById(route.id),value=el?.dataset.value,itemId=el?.dataset.id;
  if(action==='noop')return;
  if(action==='expiry-demo'){startCapture({title:'保湿面霜',more:true});return;}
  if(action==='expiry-mode'){if(working.expiryMode!=='shelf')working.directDate=working.date;working.expiryMode=value;working.dateType='到期';working.lead=0;working.date=working.expiryMode==='shelf'?expiryValue(working):(working.directDate||'');saveDraft();renderCurrentForm();return;}
  if(action==='reminder-settings')return navigate('reminderSettings');
  if(action==='notification')return navigate('notification');
  if(action==='reminder-toggle'){store.reminders=!store.reminders;persist();render();toast('到期提醒设置已展示');return;}
  if(action==='reminder-detail'){store.reminderDetails=!store.reminderDetails;persist();render();return;}
  if(action==='scan')return navigate('scan');
  if(action==='scan-sample'){route.code='6900000000016';render();return;}
  if(action==='scan-query'){route.code=$('#barcode-query').value.trim();render();return;}
  if(action==='barcode-capture'){startCapture({barcode:route.code});return;}
  if(action==='same-item'){const source=itemById(itemId);startCapture({title:source.title,barcode:source.barcode});working.category=source.category;saveDraft();renderCurrentForm();return;}
  if(action==='voice-name'||action==='voice-notes'||action==='voice-search'){openLayer('voice',{target:action==='voice-name'?'title':action==='voice-notes'?'notes':'query',draftId:working?.draftId});return;}
  if(action==='voice-example'||action==='voice-again'){layers.at(-1).ready=action==='voice-example';renderLayers();return;}
  if(action==='voice-adopt'){
    const layer=layers.at(-1),text=$('#voice-candidate').value.trim(),limit=layer.target==='title'?80:layer.target==='query'?100:2000;
    if(!text||[...text].length>limit){toast('请填写 1—'+limit+' 字');return;}
    layers.pop();
    if(layer.target==='query'){route.query=text;render();}
    else if(working&&working.draftId===layer.draftId){const next=layer.target==='notes'&&working.notes?working.notes+'\n'+text:text;if([...next].length>2000){toast('说明最多 2000 字');return;}updateWorking(layer.target,next);saveDraft();renderCurrentForm();}
    return;
  }
  if(action==='loading-scene'||action==='error-scene'){route={page:'home',demoState:action==='loading-scene'?'loading':'error'};layers=[];render();return;}
  if(action==='back')return back();
  if(action==='close')return closeLayer();
  if(action==='tab')return goTab(el.dataset.page);
  if(['home','locations','mine'].includes(action))return goTab(action);
  if(['dates','data','settings','help','widgets','import'].includes(action))return navigate(action);
  if(action==='archive')return navigate('archive',{section:'archive'});
  if(action==='mode-demo'||action==='mode-own'){saveDraft();working=null;store.mode=action==='mode-demo'?'demo':'own';persist();goTab('home');return;}
  if(action==='search'){navigate('search',{query:''});return;}
  if(action==='clear-query'){route.query='';$('#query').value='';$('#search-results').innerHTML=searchContent();$('#query').focus();return;}
  if(action==='search-word'){route.query=value;render();return;}
  if(action==='search-scope'){route.scope=value;render();return;}
  if(action==='clear-history'){data().recent=[];persist();$('#search-results').innerHTML=searchContent();return;}
  if(action==='capture-query')return startCapture({title:route.query});
  if(action==='filter'){route.filter=value;render();return;}
  if(action==='clear-filter'){route.filter='全部';render();return;}
  if(action==='favorites'){goTab('home');route.filter='常用';render();return;}
  if(action==='item'){
    if(longPressed){longPressed=false;return;}
    if(selection){selection.has(itemId)?selection.delete(itemId):selection.add(itemId);render();return;}
    if(route.page==='search'&&route.query){data().recent=[route.query,...data().recent.filter(t=>t!==route.query)].slice(0,8);persist();}
    navigate('detail',{id:itemId});return;
  }
  if(action==='selection'){selection=new Set();render();return;}
  if(action==='selection-done'){selection=null;render();return;}
  if(action==='select-all'){selection=new Set(filteredItems().map(i=>i.id));render();return;}
  if(action==='batch-move'){openLayer('picker',{target:'batch'});return;}
  if(action==='batch-trash'){openLayer('confirm',{title:'移入回收站',message:'本次选中的 '+selection.size+' 条记录将保留 30 天，可随时恢复。',action:'batch-trash-save',confirm:'移入回收站'});return;}
  if(action==='batch-trash-save'){const count=selection.size;selection.forEach(i=>{const record=itemById(i);record.deletedAt=Date.now();changed(record,'移入回收站');});selection=null;layers=[];render();toast(count+' 条记录已移入回收站');return;}
  if(action==='capture'){if(data().drafts.length){openLayer('draftChoice');return;}startCapture();return;}
  if(action==='capture-fresh')return startCapture();
  if(action==='capture-group')return startCapture({kind:'GROUP'});
  if(action==='capture-here')return startCapture({location:route.id});
  if(action==='capture-item-here')return startCapture({location:item.location});
  if(action==='kind'){working.kind=value;working.more||=value==='GROUP';renderCurrentForm();saveDraft();return;}
  if(action==='more-fields'){working.more=!working.more;renderCurrentForm();return;}
  if(action==='draft-location'){openLayer('picker',{target:'draft'});return;}
  if(action==='new-location'){openLayer('newLocation',{parent:route.page==='location'?route.id:null});return;}
  if(action==='save-location')return saveLocation();
  if(action==='choose-location')return chooseLocation(itemId);
  if(action==='location'){navigate('location',{id:itemId});return;}
  if(action==='location-scope'){locationScope=!locationScope;render();return;}
  if(action==='location-menu'){openLayer('locationMenu');return;}
  if(action==='rename-location'){openLayer('newLocation',{edit:route.id,parent:loc(route.id).parent});return;}
  if(action==='new-child'){openLayer('newLocation',{parent:route.id});return;}
  if(action==='photos'||action==='camera'){if(working.photos.length>=6){toast('每条记录最多 6 张照片');return;}$(action==='camera'?'#camera-input':'#photo-input').click();return;}
  if(action==='sample-photo'){working.photos.push({kind:working.kind==='GROUP'?'camp':'charger'});saveDraft();renderCurrentForm();return;}
  if(action==='remove-photo'){working.photos.splice(Number(el.dataset.index),1);saveDraft();renderCurrentForm();return;}
  if(action==='save')return saveWorking();
  if(action==='receipt-view'){layers=[];navigate('detail',{id:itemId});return;}
  if(action==='receipt-search'){layers=[];navigate('search',{query:label(itemById(itemId))});return;}
  if(action==='continue'){const saved=itemById(itemId);startCapture({location:saved.location,kind:saved.kind});return;}
  if(action==='finish-session'){layers=[];render();return;}
  if(action==='drafts'){openLayer('drafts');return;}
  if(action==='resume'||action==='resume-latest'){
    const draft=itemId?data().drafts.find(d=>d.draftId===itemId):data().drafts[0];if(!draft)return;
    if(draft.itemId){working=clone(draft);layers=[];navigate('edit',{id:draft.itemId});}else startCapture({resume:draft});return;
  }
  if(action==='delete-draft'){data().drafts=data().drafts.filter(d=>d.draftId!==itemId);persist();renderLayers();return;}
  if(action==='edit'){working={...clone(item),itemId:item.id,draftId:id(),more:true,photos:clone(item.photos||[])};navigate('edit',{id:item.id});return;}
  if(action==='item-menu'){openLayer('menu');return;}
  if(action==='move'||action==='return'){openLayer('picker',{target:action});return;}
  if(action==='found'){item.confirmed=new Date().toLocaleDateString('zh-CN');changed(item,'确认位置');render();toast('位置已确认');return;}
  if(action==='favorite'){item.favorite=!item.favorite;changed(item,item.favorite?'设为常用':'移出常用');layers=[];render();toast(item.favorite?'已放进常用家当':'已更新常用状态');return;}
  if(action==='quantity'){openLayer('quantity');return;}
  if(action==='quantity-save'){const n=Number($('#quantity-value').value);if(!Number.isInteger(n)||n<0||n>9999){shortError('请填写 0—9999 的整数');return;}item.quantity=n;if(n===0){item.status='ARCHIVED';item.archiveReason='已用完';}changed(item,'数量改为 '+n);layers=[];render();toast('数量已更新');return;}
  if(action==='loan'){openLayer('loan');return;}
  if(action==='loan-save'){const borrower=$('#borrower').value.trim();if(!borrower){shortError('填写对方的称呼');return;}item.borrower=borrower;item.status='LENT';if($('#return-date').value){item.date=$('#return-date').value;item.dateType='归还';item.handled=false;}changed(item,'借给 '+borrower);layers=[];render();toast('借出已记下');return;}
  if(action==='date-edit'){working={...clone(item),itemId:item.id,draftId:id(),more:true,photos:clone(item.photos||[])};navigate('edit',{id:item.id});return;}
  if(action==='archive-confirm'){openLayer('confirm',{title:'记录这件物品的去向',message:escapeHtml(label(item))+' 会保存在归档中，随时可查看或恢复。',action:'archive-save',confirm:'归档这件'});return;}
  if(action==='archive-save'){item.status='ARCHIVED';item.archiveReason=$('#archive-reason').value;changed(item,item.archiveReason);layers=[];render();toast('已放入归档');return;}
  if(action==='trash-confirm'){openLayer('confirm',{title:'移入回收站',message:escapeHtml(label(item))+' 将在回收站保留 30 天。',action:'trash-save',confirm:'移入回收站'});return;}
  if(action==='trash-save'){item.deletedAt=Date.now();changed(item,'移入回收站');layers=[];render();toast('已移入回收站');return;}
  if(action==='restore-trash'||action==='restore-archive'){if(action==='restore-trash')delete item.deletedAt;else{item.status='ACTIVE';item.quantity=item.kind==='SINGLE'?Math.max(1,item.quantity||1):null;}changed(item,'恢复记录');layers=[];render();toast('记录已恢复');return;}
  if(action==='delete-confirm'){openLayer('confirm',{title:'永久删除这条记录',message:'删除 '+escapeHtml(label(item))+' 及其仅由这条记录使用的照片。',action:'delete-save',confirm:'永久删除',danger:true});return;}
  if(action==='delete-save'){data().items=data().items.filter(i=>i.id!==item.id);persist();layers=[];navigate('archive',{section:'trash'});toast('记录已删除');return;}
  if(action==='archive-tab'){route.section=value;render();return;}
  if(action==='date-tab'){route.handled=value==='done';render();return;}
  if(action==='handled'){const record=itemById(itemId);record.handled=!record.handled;changed(record,record.handled?'日期已处理':'重新关注日期');render();toast(record.handled?'这件事，记得处理好了':'已回到待关注');return;}
  if(action==='calendar'){navigate('reminderSettings');return;}
  if(action==='theme'){store.theme=value;persist();render();return;}
  if(action==='motion'){store.simple=!store.simple;persist();render();return;}
  if(action==='widget-toggle'){store.widget=!store.widget;persist();render();return;}
  if(action==='preview'){openLayer('preview');return;}
  if(action==='main-photo'){toast('当前图片已是主图');return;}
  if(action==='ocr'){openLayer('ocr');return;}
  if(action.startsWith('use-ocr')){
    const target=working||item;if(!target)return;
    if(action==='use-ocr')target.title=value;if(action==='use-ocr-note')target.notes=(target.notes?target.notes+'\n':'')+value;if(action==='use-ocr-date'){target.date=value;target.dateType='到期';target.expiryMode='direct';target.lead=0;target.handled=false;target.more=true;}
    layers.pop();if(working){saveDraft();renderCurrentForm();}else{changed(item,'采用照片文字候选');render();}toast('已填入，可以继续编辑');return;
  }
  if(action==='backup'){openLayer('backup');return;}
  if(action==='backup-result'){layers=[];openLayer('backupResult');return;}
  if(action==='restore-preview'){openLayer('restore');return;}
  if(action==='restore-result'){layers=[];openLayer('restoreResult');return;}
  if(action==='csv'){openLayer('csv');return;}
  if(action==='import-mode'){importMode=value;render();return;}
  if(action==='import-location'){openLayer('picker',{target:'import'});return;}
  if(action==='import-save'){const titles=[$('#import-title').value.trim(),$('#import-title2')?.value.trim()||''];const count=importMode==='group'?1:2;for(let index=0;index<count;index++){const record={id:id(),title:titles[index],kind:count===1?'GROUP':'SINGLE',quantity:count===1?null:1,photos:count===1?[{kind:'charger'},{kind:'keys'}]:[{kind:index===0?'charger':'keys'}],location:importLocation,status:'ACTIVE',createdAt:Date.now(),updatedAt:Date.now(),history:[],notes:''};data().items.unshift(record);changed(record,'从分享图片记下');}persist();goTab('home');toast('已记下 '+count+' 条记录');return;}
}
function renderCurrentForm(){if(route.page==='edit'){render();}else renderLayers();}
document.addEventListener('click',event=>{
  const element=event.target.closest('[data-action]');
  if(element&&!element.disabled){event.preventDefault();handle(element.dataset.action,element);}
  else if(event.target.classList.contains('overlay'))closeLayer();
});
document.addEventListener('input',event=>{
  if(event.target.dataset.field)updateWorking(event.target.dataset.field,event.target.value);
  if(event.target.id==='query'){route.query=event.target.value;if(event.isComposing)return;clearTimeout(searchTimer);searchTimer=setTimeout(()=>{if($('#search-results'))$('#search-results').innerHTML=searchContent();},200);}
});
document.addEventListener('compositionend',event=>{if(event.target.id==='query'){$('#search-results').innerHTML=searchContent();}});
document.addEventListener('change',event=>{
  if(event.target.dataset.field)updateWorking(event.target.dataset.field,event.target.value);
  if(event.target.id==='restore-mode')$('#restore-note').textContent=event.target.value==='replace'?'替换前，当前数据会保存为一份 7 天保护快照。':'先保留当前记录，再加入确认的新内容。';
});
document.addEventListener('keydown',event=>{
  if(event.key==='Escape'){back();return;}
  if(event.key==='Tab'&&layers.length){const focusable=[...$('#layers').querySelectorAll('button:not(:disabled),input,textarea,select')];const first=focusable[0],last=focusable.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}}
});
document.addEventListener('pointerdown',event=>{const card=event.target.closest('.item-card');if(!card||selection)return;clearTimeout(pressTimer);pressTimer=setTimeout(()=>{selection=new Set([card.dataset.id]);longPressed=true;render();},550);});
['pointerup','pointercancel','pointermove'].forEach(name=>document.addEventListener(name,()=>clearTimeout(pressTimer)));
async function receiveFiles(event) {
  if(!working)return;
  const files=[...event.target.files].slice(0,6-working.photos.length),draftId=working.draftId;
  for(const file of files){
    if(file.size>30*1024*1024){toast('请选择 30MB 以内的图片');continue;}
    const src=await new Promise(resolve=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=()=>resolve(null);reader.readAsDataURL(file);});
    if(!src||!working||working.draftId!==draftId)continue;
    working.photos.push({src});saveDraft();
  }
  event.target.value='';if(working&&working.draftId===draftId)renderCurrentForm();
}
$('#photo-input').addEventListener('change',receiveFiles);
$('#camera-input').addEventListener('change',receiveFiles);
$('#mode-switch').addEventListener('click',()=>handle(store.mode==='demo'?'mode-own':'mode-demo'));
$('#scenes-switch').addEventListener('click',()=>openLayer('sceneMenu'));
$('#scenes').innerHTML=[['home','示例家当'],['capture','记下一件'],['locations','位置'],['expiry-demo','到期录入'],['notification','通知示意'],['dates','日期提醒'],['import','分享收图'],['widgets','桌面卡片'],['settings','深浅外观']].map(([action,title])=>button(action,title)).join('');
document.addEventListener('visibilitychange',()=>{if(document.hidden)saveDraft();});
window.addEventListener('pagehide',saveDraft);
persist();
matchMedia('(prefers-color-scheme: dark)').addEventListener('change',applyTheme);
render();
})();
