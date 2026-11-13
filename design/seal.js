// NexVault workspace seal: a deterministic glyph drawn from the first bytes of
// the workspace fingerprint. Members compare it (plus the 6-digit code) in person.
// The Dart port in app/lib/ui/seal.dart must stay byte-for-byte identical.
function sealSvg(bytes, size, opts = {}) {
  // 6 grounds x 3 metals so neighbouring workspaces differ at a glance
  const GROUNDS = ['#173D3A', '#2A3163', '#5B2333', '#3D2F14', '#1E4A6B', '#3E2457'];
  const METALS = ['#D2A24A', '#C9D2D6', '#D98552'];
  const ground = opts.ground || GROUNDS[bytes[7] % GROUNDS.length];
  const ink = opts.ink || METALS[bytes[8] % METALS.length];
  const c = 50;
  const lobes = 5 + (bytes[0] % 8);              // 5..12 outer lobes
  const depth = 2 + (bytes[1] % 4) * 2.5;        // lobe depth 2..9.5
  const rot = (bytes[2] / 255) * (360 / lobes);  // rotation of the rosette
  const star = 3 + (bytes[3] % 6);               // inner star points 3..8
  const dots = (bytes[4] << 8) | bytes[5];       // 16-bit ring pattern
  const inner = 0.38 + (bytes[6] % 4) * 0.06;    // star inner radius ratio

  // Outer scalloped rosette
  let d = '';
  const steps = 180;
  for (let i = 0; i <= steps; i++) {
    const a = (i / steps) * Math.PI * 2;
    const r = 44 - depth / 2 + (depth / 2) * Math.cos(a * lobes);
    const x = c + r * Math.cos(a + rot * Math.PI / 180);
    const y = c + r * Math.sin(a + rot * Math.PI / 180);
    d += (i ? 'L' : 'M') + x.toFixed(2) + ' ' + y.toFixed(2);
  }
  d += 'Z';

  // Dot ring: 16 positions, filled where the bit is set, hollow otherwise
  let ring = '';
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2 - Math.PI / 2;
    const x = c + 29 * Math.cos(a), y = c + 29 * Math.sin(a);
    ring += (dots >> i) & 1
      ? `<circle cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="2.6" fill="${ground}"/>`
      : `<circle cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="1.9" fill="none" stroke="${ground}" stroke-width="1.1"/>`;
  }

  // Inner star
  let s = '';
  for (let i = 0; i < star * 2; i++) {
    const a = (i / (star * 2)) * Math.PI * 2 - Math.PI / 2 + rot * Math.PI / 180;
    const r = i % 2 ? 20 * inner : 20;
    s += (i ? 'L' : 'M') + (c + r * Math.cos(a)).toFixed(2) + ' ' + (c + r * Math.sin(a)).toFixed(2);
  }
  s += 'Z';

  return `<svg viewBox="0 0 100 100" width="${size}" height="${size}" aria-hidden="true">
    <path d="${d}" fill="${ink}"/>
    <circle cx="50" cy="50" r="36" fill="none" stroke="${ground}" stroke-width="1.2"/>
    ${ring}
    <circle cx="50" cy="50" r="25" fill="${ground}"/>
    <path d="${s}" fill="${ink}"/>
  </svg>`;
}

function hexBytes(hex) {
  const out = [];
  for (let i = 0; i < hex.length; i += 2) out.push(parseInt(hex.substr(i, 2), 16));
  return out;
}

if (typeof module !== 'undefined') module.exports = { sealSvg, hexBytes };
