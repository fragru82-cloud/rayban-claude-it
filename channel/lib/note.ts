/**
 * Nota a sé stessi: «Ehi Claude, segnati che …» → un messaggio (es. WhatsApp) solo all'utente.
 *
 * Destinatario e webhook stanno nel file .env del canale, mai nel codice:
 *   RAYBANCLAUDE_NOTE_URL    URL HTTPS del webhook (POST JSON)
 *   RAYBANCLAUDE_NOTE_TOKEN  token Bearer
 *   RAYBANCLAUDE_NOTE_TO     numero del destinatario (solo cifre, con prefisso internazionale)
 * Il destinatario è fisso: Claude non può scegliere a chi scrivere.
 */

import { MAX_NOTE_CHARS, NOTE_TIMEOUT_MS } from './constants.ts'
import { cleanText } from './validate.ts'
import { EMOJI, MULTI_SPACE, NOTE_RECIPIENT } from './patterns.ts'

export const NOTE_TOOL = {
  name: 'send_note',
  description: 'Send a short note to the user\'s own phone (WhatsApp), e.g. when they say "segnati che …" or "mandami una nota". '
    + 'The recipient is fixed in the configuration – it always goes to the user only. Plain text, no emojis.',
  inputSchema: {
    type: 'object',
    properties: { text: { type: 'string', description: 'The note, in the user\'s words, e.g. "Chiamare il commercialista per F24"' } },
    required: ['text'],
  },
} as const

export interface NoteConfig {
  readonly url: string
  readonly token: string
  readonly to: string
}

/** Configurazione dal .env, oppure null se manca qualcosa o non è valida. */
export function noteConfigFrom(env: Readonly<Record<string, string | undefined>>): NoteConfig | null {
  const url = env.RAYBANCLAUDE_NOTE_URL?.trim() ?? ''
  const token = env.RAYBANCLAUDE_NOTE_TOKEN?.trim() ?? ''
  const to = env.RAYBANCLAUDE_NOTE_TO?.trim() ?? ''
  const validTo = NOTE_RECIPIENT.test(to)
  return url.startsWith('https://') && token && validTo ? { url, token, to } : null
}

/** Rimuove gli emoji: su WhatsApp via webhook diventano «??». */
export function stripEmoji(text: string): string {
  return text.replace(EMOJI, '').replace(MULTI_SPACE, ' ').trim()
}

/** Corpo JSON: campi doppi per compatibilità con i webhook più comuni. */
export function noteBody(config: NoteConfig, text: string): string {
  const message = `Nota dagli occhiali: ${text}`
  return JSON.stringify({ to: config.to, number: config.to, phone: config.to, message, text: message })
}

export async function sendNote(config: NoteConfig | null, rawText: unknown): Promise<string> {
  if (!config) throw new Error('Note non configurate: mancano RAYBANCLAUDE_NOTE_URL, _TOKEN o _TO nel file .env del canale.')
  const text = stripEmoji(cleanText(rawText, MAX_NOTE_CHARS))
  if (!text) throw new Error('text non può essere vuoto')
  const res = await fetch(config.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8', Authorization: `Bearer ${config.token}` },
    body: noteBody(config, text),
    signal: AbortSignal.timeout(NOTE_TIMEOUT_MS),
  })
  if (!res.ok) throw new Error(`Invio non riuscito (HTTP ${res.status})`)
  return 'Nota inviata sul telefono dell’utente.'
}
