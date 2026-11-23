// Hex board geometry. The arena is 7 columns x 8 rows of pointy-top hexes in
// "odd-r" offset layout. Rows 0-3 belong to the home Warden, rows 4-7 to the visitor.
export const COLS = 7;
export const ROWS = 8;
export const HALF_ROWS = 4;
export const HEX_SIZE = 1.0; // world units, centre to corner
export const CELLS = COLS * ROWS;

export const cellIndex = (c, r) => r * COLS + c;
export const cellCol = (i) => i % COLS;
export const cellRow = (i) => Math.floor(i / COLS);

function toCube(i) {
  const c = cellCol(i);
  const r = cellRow(i);
  const x = c - (r - (r & 1)) / 2;
  const z = r;
  return [x, -x - z, z];
}

export function hexDist(a, b) {
  const [ax, ay, az] = toCube(a);
  const [bx, by, bz] = toCube(b);
  return Math.max(Math.abs(ax - bx), Math.abs(ay - by), Math.abs(az - bz));
}

const NEIGHBOR_CACHE = [];
export function neighbors(i) {
  if (NEIGHBOR_CACHE[i]) return NEIGHBOR_CACHE[i];
  const c = cellCol(i);
  const r = cellRow(i);
  const odd = r & 1;
  const dirs = odd
    ? [[1, 0], [-1, 0], [0, -1], [1, -1], [0, 1], [1, 1]]
    : [[1, 0], [-1, 0], [-1, -1], [0, -1], [-1, 1], [0, 1]];
  const out = [];
  for (const [dc, dr] of dirs) {
    const nc = c + dc;
    const nr = r + dr;
    if (nc >= 0 && nc < COLS && nr >= 0 && nr < ROWS) out.push(cellIndex(nc, nr));
  }
  NEIGHBOR_CACHE[i] = out;
  return out;
}

export const HEX_W = Math.sqrt(3) * HEX_SIZE;
export const HEX_H = 1.5 * HEX_SIZE;

// World position (x, z) of a cell centre; the board is centred on the origin.
export function cellToWorld(i) {
  const c = cellCol(i);
  const r = cellRow(i);
  const x = HEX_W * (c + 0.5 * (r & 1)) - HEX_W * (COLS - 0.5) / 2;
  const z = -(HEX_H * r - HEX_H * (ROWS - 1) / 2);
  return { x, z };
}

// Mirror a home-side cell to the visitor side (rotate the board 180 degrees).
export function mirrorCell(i) {
  return CELLS - 1 - i;
}

// Bench slots sit in a straight row in front of the board.
export const BENCH_SIZE = 9;
export function benchToWorld(slot) {
  const spacing = 1.62;
  return { x: (slot - (BENCH_SIZE - 1) / 2) * spacing, z: cellToWorld(0).z + 2.55 };
}
