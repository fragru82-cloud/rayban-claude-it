// RayBan Claude – Dashboard (gira solo su http://localhost, vedi server.ts)
'use strict'

const REFRESH_MS = 3000
const COPY_FEEDBACK_MS = 1800
const state = { token: '', port: 0, host: '', tailscale: '' }

const $ = id => document.getElementById(id)

function setStatus(el, text, kind) {
  el.textContent = text
  el.className = 'hint' + (kind ? ' ' + kind : '')
}

async function api(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + state.token, ...(options.headers || {}) },
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Errore ' + res.status)
  return data
}

async function copyText(text, button) {
  await navigator.clipboard.writeText(text)
  const original = button.textContent
  button.textContent = 'Copiato ✓'
  setTimeout(() => { button.textContent = original }, COPY_FEEDBACK_MS)
}

function renderPairing() {
  $('host').textContent = state.host
  $('port').textContent = String(state.port)
  $('token').textContent = state.token
  const img = $('qr')
  img.src = '/api/pair.svg?host=' + encodeURIComponent(state.host)
  img.onload = () => setStatus($('qr-hint'), 'Scansiona con la fotocamera dell’iPhone')
  img.onerror = () => setStatus($('qr-hint'), 'Impossibile generare il codice QR', 'bad')
  renderRemote()
}

/** Mostra se l’iPhone raggiunge il PC anche fuori casa (tramite Tailscale). */
function renderRemote() {
  const hint = $('remote-hint')
  if (!state.tailscale) {
    setStatus(hint, '🌍 Fuori casa: Tailscale non trovato. Installa Tailscale (gratis) su PC e iPhone e ricarica questa pagina (vedi README, sezione fuori casa).')
    return
  }
  if (state.tailscale === state.host) {
    setStatus(hint, '🌍 Stai abbinando direttamente tramite Tailscale (' + state.tailscale + '): funziona a casa e fuori casa.', 'ok')
    return
  }
  setStatus(hint, '🌍 Fuori casa: tramite Tailscale (' + state.tailscale + '), già incluso nel codice QR. A casa l’app usa la Wi-Fi, fuori casa passa da sola a Tailscale.', 'ok')
}

function renderBadges(status) {
  const clients = status.clients || 0
  $('badge-clients').innerHTML = ''
  const dot = document.createElement('span')
  dot.className = 'dot ' + (clients ? 'ok' : 'warn')
  $('badge-clients').append(dot, document.createTextNode(clients === 1 ? '1 app connessa' : clients + ' app connesse'))

  $('badge-voice').innerHTML = ''
  const vdot = document.createElement('span')
  vdot.className = 'dot ok'
  $('badge-voice').append(vdot, document.createTextNode(status.tts ? 'Voce: ElevenLabs' : 'Voce: iPhone (gratuita)'))
  if (status.voice) $('eleven-voice').value = status.voice
}

function renderActivity(entries) {
  const list = $('activity')
  list.replaceChildren()
  if (!entries.length) {
    const li = document.createElement('li')
    li.className = 'hint'
    li.textContent = 'Ancora nessun messaggio.'
    list.append(li)
    return
  }
  entries.forEach(e => {
    const li = document.createElement('li')
    const t = document.createElement('span')
    t.className = 't'
    t.textContent = new Date(e.ts).toLocaleTimeString('it-IT')
    const who = document.createElement('span')
    who.className = e.direction === 'in' ? 'in' : 'out'
    who.textContent = (e.direction === 'in' ? '← ' : '→ ') + e.source + (e.hasImage ? ' 📷' : '')
    const text = document.createElement('span')
    text.textContent = e.text // textContent: niente HTML dai messaggi (protezione XSS)
    li.append(t, who, text)
    list.append(li)
  })
}

async function refresh() {
  try {
    renderBadges(await api('/api/status'))
    renderActivity((await api('/api/activity')).activity || [])
  } catch (e) {
    console.warn('Aggiornamento non riuscito', e)
  }
}

async function init() {
  const res = await fetch('/api/local')
  if (!res.ok) {
    document.body.textContent = 'La dashboard è raggiungibile solo direttamente dal PC, su http://localhost.'
    return
  }
  const local = await res.json()
  state.token = local.token
  state.port = local.port
  state.tailscale = local.tailscale || ''
  $('version').textContent = 'v' + local.version

  const select = $('ip-select')
  const ips = local.ips.length ? local.ips : [{ address: 'localhost', iface: 'nessuna rete trovata' }]
  ips.forEach(ip => {
    const opt = document.createElement('option')
    opt.value = ip.address
    opt.textContent = ip.address + ' – ' + ip.iface
    select.append(opt)
  })
  state.host = ips[0].address
  select.addEventListener('change', () => { state.host = select.value; renderPairing() })
  renderPairing()

  $('card-imessage').hidden = !local.imessage

  $('btn-reveal').addEventListener('click', ev => {
    const shown = $('token').classList.toggle('shown')
    ev.target.textContent = shown ? 'Nascondi token' : 'Mostra token'
  })
  $('btn-copy').addEventListener('click', ev =>
    copyText('Host: ' + state.host + '\nPort: ' + state.port + '\nToken: ' + state.token
      + (state.tailscale && state.tailscale !== state.host ? '\nFuori casa (Tailscale): ' + state.tailscale : ''), ev.target))
  document.querySelectorAll('[data-copy]').forEach(btn =>
    btn.addEventListener('click', () => copyText($(btn.dataset.copy).textContent, btn)))

  $('btn-test').addEventListener('click', async () => {
    const status = $('test-status')
    try {
      const r = await api('/api/test-message', { method: 'POST', body: JSON.stringify({ text: $('test-text').value }) })
      setStatus(status, r.delivered_to ? 'Consegnato a ' + r.delivered_to + ' app ✓' : 'Nessuna app connessa: prima abbina il telefono', r.delivered_to ? 'ok' : 'bad')
    } catch (e) { setStatus(status, e.message, 'bad') }
  })

  const saveTts = async body => {
    const status = $('tts-status')
    try {
      const r = await api('/api/tts', { method: 'POST', body: JSON.stringify(body) })
      $('eleven-key').value = ''
      setStatus(status, r.tts ? 'ElevenLabs attivo ✓' : 'Voce iPhone attiva (gratuita) ✓', 'ok')
      refresh()
    } catch (e) { setStatus(status, e.message, 'bad') }
  }
  $('btn-tts').addEventListener('click', () => {
    const key = $('eleven-key').value.trim()
    saveTts(key ? { key, voice_id: $('eleven-voice').value } : { voice_id: $('eleven-voice').value })
  })
  $('btn-tts-off').addEventListener('click', () => saveTts({ key: '' }))

  $('btn-im').addEventListener('click', async () => {
    const status = $('im-status')
    try {
      const { link } = await api('/api/pair-link?host=' + encodeURIComponent(state.host))
      const message = 'Abbina RayBan Claude:\n' + link
      await api('/api/send-imessage', { method: 'POST', body: JSON.stringify({ recipient: $('im-recipient').value, message }) })
      setStatus(status, 'Inviato ✓ – tocca il link sull’iPhone', 'ok')
    } catch (e) { setStatus(status, e.message, 'bad') }
  })

  refresh()
  setInterval(refresh, REFRESH_MS)
}

init()
