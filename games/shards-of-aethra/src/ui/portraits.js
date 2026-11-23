// Champion portraits: painted art where it exists, otherwise a render of the 3D model.
import * as THREE from 'three';
import { CHAMPIONS, PAINTED_PORTRAITS } from '../data/champions.js';
import { TRAITS } from '../data/traits.js';
import { buildChampion } from '../render/models.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

const urls = {};

export function portraitURL(id) {
  return urls[id] || '';
}

export function portraitStyle(id) {
  const ch = CHAMPIONS.find((c) => c.id === id);
  const col = ch ? TRAITS[ch.traits[0]].color : '#445';
  const url = portraitURL(id);
  if (PAINTED_PORTRAITS.has(id)) return `background-image:url(${url})`;
  return `background-image:url(${url}), radial-gradient(circle at 50% 40%, ${col}cc, #0a0e18 75%)`;
}

export function isRendered(id) { return !PAINTED_PORTRAITS.has(id); }

export async function preparePortraits(base, onProgress) {
  for (const c of CHAMPIONS) if (PAINTED_PORTRAITS.has(c.id)) urls[c.id] = `${base}portraits/${c.id}.webp`;
  const missing = CHAMPIONS.filter((c) => !PAINTED_PORTRAITS.has(c.id));
  if (!missing.length) return;
  const w = 480;
  const h = 360;
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: true });
  } catch {
    return;
  }
  renderer.setSize(w, h);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.82;
  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.6;
  const key = new THREE.DirectionalLight(0xffe2c0, 3);
  key.position.set(2, 3, 4);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x9fc8ff, 3);
  rim.position.set(-3, 2, -3);
  scene.add(rim);
  scene.add(new THREE.HemisphereLight(0xbfd8ff, 0x3a2a20, 0.9));
  const cam = new THREE.PerspectiveCamera(28, w / h, 0.1, 50);
  for (const c of missing) {
    const rig = buildChampion(c.id);
    rig.update(1.3, 0.016);
    scene.add(rig.root);
    const H = rig.height;
    rig.root.rotation.y = -0.4;
    cam.position.set(0.9 * H, H * 0.95, H * 2.6);
    cam.lookAt(0, H * 0.55, 0);
    renderer.render(scene, cam);
    urls[c.id] = renderer.domElement.toDataURL('image/png');
    scene.remove(rig.root);
    if (onProgress) onProgress();
    await new Promise((r) => setTimeout(r, 0));
  }
  renderer.dispose();
  pmrem.dispose();
}
