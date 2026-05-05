#!/usr/bin/env node
/**
 * Diagnostic: captures raw stdin bytes to see exactly what
 * the Vietnamese IME sends in a terminal environment.
 *
 * Usage: node scripts/diagnose-ime-input.js
 * Then type Vietnamese text (e.g., "cộng hòa xã hội" via Telex).
 * Press Ctrl+C to exit and see the captured events.
 */

const events = [];

process.stdin.setRawMode(true);
process.stdin.resume();
process.stdin.setEncoding(null); // raw bytes

console.log('=== Vietnamese IME Input Diagnostic ===');
console.log('Type Vietnamese text (e.g., "cộng hòa xã hội")');
console.log('Press Ctrl+C when done to see captured events.\n');

process.stdin.on('data', (buf) => {
  const hex = [...buf].map(b => b.toString(16).padStart(2, '0')).join(' ');
  const ascii = [...buf].map(b => b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : b === 0x7f ? '<DEL>' : b === 0x08 ? '<BS>' : `<${b.toString(16)}>`).join('');
  const text = buf.toString('utf8');

  const hasDel = buf.includes(0x7f);
  const hasBs = buf.includes(0x08);

  const entry = {
    time: Date.now(),
    hex,
    ascii,
    text,
    len: buf.length,
    hasDel,
    hasBs
  };
  events.push(entry);

  // Show live
  const flags = [hasDel && 'DEL', hasBs && 'BS'].filter(Boolean).join('+') || '-';
  process.stdout.write(`[${entry.len}b ${flags}] ${hex}  "${text.replace(/[\x00-\x1f\x7f]/g, c => `\\x${c.charCodeAt(0).toString(16).padStart(2, '0')}`)}" \r\n`);

  // Ctrl+C
  if (buf.length === 1 && buf[0] === 0x03) {
    console.log('\n=== Summary ===');
    console.log(`Total events: ${events.length}`);
    console.log(`Events with DEL (0x7F): ${events.filter(e => e.hasDel).length}`);
    console.log(`Events with BS (0x08): ${events.filter(e => e.hasBs).length}`);
    console.log('\nAll events:');
    events.forEach((e, i) => {
      console.log(`  ${i}: [${e.len}b] ${e.hex}  text="${e.text.replace(/[\x00-\x1f\x7f]/g, c => `\\x${c.charCodeAt(0).toString(16).padStart(2, '0')}`)}"${e.hasDel ? ' <<DEL>>' : ''}${e.hasBs ? ' <<BS>>' : ''}`);
    });
    process.exit(0);
  }
});
