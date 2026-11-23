// Renderer, camera, lighting, sky and post-processing.
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

export const NOISE_GLSL = /* glsl */ `
vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
vec2 mod289(vec2 x){return x-floor(x*(1.0/289.0))*289.0;}
vec3 permute(vec3 x){return mod289(((x*34.0)+1.0)*x);}
float snoise(vec2 v){
  const vec4 C=vec4(0.211324865405187,0.366025403784439,-0.577350269189626,0.024390243902439);
  vec2 i=floor(v+dot(v,C.yy)); vec2 x0=v-i+dot(i,C.xx);
  vec2 i1=(x0.x>x0.y)?vec2(1.0,0.0):vec2(0.0,1.0);
  vec4 x12=x0.xyxy+C.xxzz; x12.xy-=i1; i=mod289(i);
  vec3 p=permute(permute(i.y+vec3(0.0,i1.y,1.0))+i.x+vec3(0.0,i1.x,1.0));
  vec3 m=max(0.5-vec3(dot(x0,x0),dot(x12.xy,x12.xy),dot(x12.zw,x12.zw)),0.0); m=m*m; m=m*m;
  vec3 x=2.0*fract(p*C.www)-1.0; vec3 h=abs(x)-0.5; vec3 ox=floor(x+0.5); vec3 a0=x-ox;
  m*=1.79284291400159-0.85373472095314*(a0*a0+h*h);
  vec3 g; g.x=a0.x*x0.x+h.x*x0.y; g.yz=a0.yz*x12.xz+h.yz*x12.yw;
  return 130.0*dot(m,g);
}
float fbm2(vec2 p){float s=0.0;float a=0.5;for(int i=0;i<5;i++){s+=a*snoise(p);p*=2.02;a*=0.5;}return s;}
`;

const GradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    uVignette: { value: 0.32 },
    uSat: { value: 1.12 },
    uTime: { value: 0 },
    uFlash: { value: 0 },
    uFlashColor: { value: new THREE.Color(1, 1, 1) },
  },
  vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float uVignette; uniform float uSat; uniform float uTime; uniform float uFlash; uniform vec3 uFlashColor;
    varying vec2 vUv;
    void main(){
      vec4 c = texture2D(tDiffuse, vUv);
      float l = dot(c.rgb, vec3(0.2126,0.7152,0.0722));
      c.rgb = mix(vec3(l), c.rgb, uSat);
      // split toning: cool shadows, warm highlights
      c.rgb += vec3(-0.012,0.0,0.03) * (1.0 - smoothstep(0.0,0.5,l));
      c.rgb += vec3(0.03,0.012,-0.02) * smoothstep(0.45,1.0,l);
      vec2 d = vUv - 0.5; d.x *= 1.25;
      float v = smoothstep(0.85, 0.2, length(d));
      c.rgb *= mix(1.0 - uVignette, 1.0, v);
      c.rgb = mix(c.rgb, uFlashColor, uFlash);
      gl_FragColor = c;
    }`,
};

export class Stage {
  constructor(container, quality = 'high') {
    this.container = container;
    this.quality = quality;
    const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance', alpha: false });
    renderer.setClearColor(0x0b1426, 1);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.88;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(renderer.domElement);
    this.renderer = renderer;

    const scene = new THREE.Scene();
    this.scene = scene;
    scene.fog = new THREE.Fog(0xe9a07c, 62, 170);

    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    scene.environmentIntensity = 0.4;

    this.camera = new THREE.PerspectiveCamera(30, 1, 0.5, 400);
    this.camBase = new THREE.Vector3(0, 23.5, 25.5);
    this.camTarget = new THREE.Vector3(0, 0, 0.2);
    this.shake = 0;
    this.camOffset = new THREE.Vector3();

    this.setupLights();
    this.setupSky();
    this.setupPost();
    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.clock = new THREE.Clock();
    this.time = 0;
  }

  setupLights() {
    const sun = new THREE.DirectionalLight(0xffd8a8, 2.7);
    sun.position.set(-14, 26, 12);
    sun.castShadow = true;
    const sm = this.quality === 'low' ? 1024 : 2048;
    sun.shadow.mapSize.set(sm, sm);
    const sc = sun.shadow.camera;
    sc.left = -16; sc.right = 16; sc.top = 16; sc.bottom = -16; sc.near = 1; sc.far = 80;
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.03;
    sun.shadow.radius = 4;
    this.scene.add(sun);
    this.scene.add(sun.target);
    this.sun = sun;
    const hemi = new THREE.HemisphereLight(0xa9c6ff, 0x4a3628, 0.75);
    this.scene.add(hemi);
    const rim = new THREE.DirectionalLight(0x9fc4ff, 1.4);
    rim.position.set(10, 10, -22);
    this.scene.add(rim);
    this.rim = rim;
  }

  setupSky() {
    const geo = new THREE.SphereGeometry(300, 48, 24);
    const mat = new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      uniforms: { uTime: { value: 0 } },
      vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0);} `,
      fragmentShader: `
        uniform float uTime; varying vec3 vDir;
        ${NOISE_GLSL}
        void main(){
          float h = vDir.y;
          vec3 top = vec3(0.10,0.20,0.46);
          vec3 mid = vec3(0.42,0.46,0.78);
          vec3 hor = vec3(1.0,0.66,0.46);
          vec3 low = vec3(0.95,0.52,0.42);
          vec3 c = mix(hor, mid, smoothstep(0.02,0.22,h));
          c = mix(c, top, smoothstep(0.22,0.75,h));
          c = mix(low, c, smoothstep(-0.12,0.03,h));
          // sun glow
          vec3 sunDir = normalize(vec3(-0.55,0.22,-0.8));
          float sd = max(dot(vDir, sunDir),0.0);
          c += vec3(1.0,0.72,0.42)*pow(sd,10.0)*0.6 + vec3(1.0,0.9,0.7)*pow(sd,180.0)*1.6;
          // wispy high clouds
          vec2 p = vDir.xz/(0.25+max(h,0.02))*1.6;
          float n = fbm2(p*0.9 + vec2(uTime*0.004,0.0));
          float cl = smoothstep(0.15,0.75,n) * smoothstep(0.02,0.18,h) * (1.0-smoothstep(0.45,0.9,h));
          c = mix(c, vec3(1.0,0.86,0.78), cl*0.45);
          // stars near zenith
          float st = step(0.9985, fract(sin(dot(floor(vDir.xz*420.0), vec2(12.9898,78.233)))*43758.5453));
          c += st * smoothstep(0.55,0.95,h) * 0.6;
          gl_FragColor = vec4(c,1.0);
        }`,
    });
    this.sky = new THREE.Mesh(geo, mat);
    this.scene.add(this.sky);

    // Sea of clouds far below the floating arena.
    const cgeo = new THREE.PlaneGeometry(600, 600, 1, 1);
    const cmat = new THREE.ShaderMaterial({
      transparent: false,
      fog: false,
      uniforms: { uTime: { value: 0 } },
      vertexShader: `varying vec3 vW; void main(){ vec4 w = modelMatrix*vec4(position,1.0); vW=w.xyz; gl_Position=projectionMatrix*viewMatrix*w; }`,
      fragmentShader: `
        uniform float uTime; varying vec3 vW;
        ${NOISE_GLSL}
        void main(){
          vec2 p = vW.xz*0.018;
          float n = fbm2(p + vec2(uTime*0.006, uTime*0.003));
          float n2 = fbm2(p*2.3 - vec2(uTime*0.01,0.0));
          float d = length(vW.xz);
          vec3 shadow = vec3(0.78,0.48,0.52);
          vec3 lit = vec3(1.0,0.86,0.72);
          vec3 c = mix(shadow, lit, smoothstep(-0.3,0.6,n+n2*0.4));
          c = mix(c, vec3(1.0,0.68,0.5), smoothstep(60.0,260.0,d)*0.85);
          gl_FragColor = vec4(c,1.0);
        }`,
    });
    this.clouds = new THREE.Mesh(cgeo, cmat);
    this.clouds.rotation.x = -Math.PI / 2;
    this.clouds.position.y = -26;
    this.scene.add(this.clouds);
  }

  setupPost() {
    const size = new THREE.Vector2();
    this.renderer.getSize(size);
    const rt = new THREE.WebGLRenderTarget(16, 16, { type: THREE.HalfFloatType, samples: this.quality === 'low' ? 0 : 4 });
    this.composer = new EffectComposer(this.renderer, rt);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.8, 0.55, 1.35);
    this.composer.addPass(this.bloom);
    this.grade = new ShaderPass(GradeShader);
    this.composer.addPass(this.grade);
    this.composer.addPass(new OutputPass());
  }

  resize() {
    const w = this.container.clientWidth || window.innerWidth;
    const h = this.container.clientHeight || window.innerHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, this.quality === 'low' ? 1 : this.quality === 'medium' ? 1.5 : 2);
    this.renderer.setPixelRatio(dpr);
    this.renderer.setSize(w, h);
    this.composer.setPixelRatio(dpr);
    this.composer.setSize(w, h);
    this.camera.aspect = w / h;
    // Keep the whole board in view on narrow screens.
    const aspect = w / h;
    this.camera.fov = aspect < 1.2 ? 30 + (1.2 - aspect) * 26 : 30;
    this.camera.updateProjectionMatrix();
    this.width = w;
    this.height = h;
  }

  addShake(a) { this.shake = Math.min(1.2, this.shake + a); }
  flash(color, amount = 0.25) {
    this.grade.uniforms.uFlashColor.value.set(color);
    this.grade.uniforms.uFlash.value = amount;
  }

  render(dt) {
    this.time += dt;
    const t = this.time;
    this.sky.material.uniforms.uTime.value = t;
    this.clouds.material.uniforms.uTime.value = t;
    this.grade.uniforms.uFlash.value *= Math.pow(0.02, dt);
    // Gentle camera drift plus shake.
    this.shake *= Math.pow(0.05, dt);
    const s = this.shake * 0.25;
    this.camera.position.set(
      this.camBase.x + Math.sin(t * 0.13) * 0.25 + (Math.random() - 0.5) * s + this.camOffset.x,
      this.camBase.y + Math.sin(t * 0.17) * 0.12 + (Math.random() - 0.5) * s + this.camOffset.y,
      this.camBase.z + (Math.random() - 0.5) * s + this.camOffset.z,
    );
    this.camera.lookAt(this.camTarget);
    this.composer.render(dt);
  }
}
