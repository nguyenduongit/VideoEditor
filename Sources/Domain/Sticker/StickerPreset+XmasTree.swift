import Foundation

extension StickerPreset {
    /// Mã nguồn SVG động kèm hoạt họa CSS @keyframes (Cây thông Noel đung đưa, đèn lấp lánh, tuyết rơi).
    /// Chuẩn W3C SVG 100% Native hình vuông 500x500, tương thích trọn vẹn với WebKit, CoreGraphics, AppKit NSImage.
    public static let animatedXmasTreeSVGMarkup: String = """
<svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cây thông Noel hoạt họa, đèn nhấp nháy, tuyết rơi">
<style>
.sway{transform-origin:250px 470px;animation:sway 3s ease-in-out infinite}
.pulse{transform-box:fill-box;transform-origin:50% 50%;animation:pulse 1.5s ease-in-out infinite}
.tw1{transform-box:fill-box;transform-origin:center;animation:twinkle 1.5s ease-in-out infinite;animation-delay:0s}
.tw2{transform-box:fill-box;transform-origin:center;animation:twinkle 1.5s ease-in-out infinite;animation-delay:-0.375s}
.tw3{transform-box:fill-box;transform-origin:center;animation:twinkle 1.5s ease-in-out infinite;animation-delay:-0.75s}
.tw4{transform-box:fill-box;transform-origin:center;animation:twinkle 1.5s ease-in-out infinite;animation-delay:-1.125s}
.fall{animation:fall 3s linear infinite;opacity:0}
@keyframes sway{0%,100%{transform:rotate(-1.6deg)}50%{transform:rotate(1.6deg)}}
@keyframes pulse{0%,100%{transform:scale(.95);opacity:.9}50%{transform:scale(1.15);opacity:1}}
@keyframes twinkle{0%,100%{opacity:.35;transform:scale(.85)}50%{opacity:1;transform:scale(1.18)}}
@keyframes fall{0%{transform:translate(0,-15px) rotate(0deg);opacity:0}15%{opacity:.95}85%{opacity:.9}100%{transform:translate(35px,490px) rotate(360deg);opacity:0}}
</style>
<defs>
  <linearGradient id="trunk" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#451a03"/><stop offset=".5" stop-color="#78350f"/><stop offset="1" stop-color="#451a03"/></linearGradient>
  <linearGradient id="pine1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#22c55e"/><stop offset="1" stop-color="#15803d"/></linearGradient>
  <linearGradient id="pine2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#16a34a"/><stop offset="1" stop-color="#14532d"/></linearGradient>
  <linearGradient id="pine3" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#15803d"/><stop offset="1" stop-color="#0f3d20"/></linearGradient>
  <radialGradient id="starGlow" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fef08a"/><stop offset="1" stop-color="#eab308"/></radialGradient>
  <radialGradient id="starHalo" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fef9c3" stop-opacity=".75"/><stop offset="1" stop-color="#fef08a" stop-opacity="0"/></radialGradient>
  <radialGradient id="bRed" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#fca5a5"/><stop offset="1" stop-color="#dc2626"/></radialGradient>
  <radialGradient id="bGold" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#fef08a"/><stop offset="1" stop-color="#d97706"/></radialGradient>
  <radialGradient id="bBlue" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#a5f3fc"/><stop offset="1" stop-color="#0284c7"/></radialGradient>
  <radialGradient id="bPurple" cx=".35" cy=".35" r=".7"><stop offset="0" stop-color="#f0abfc"/><stop offset="1" stop-color="#9333ea"/></radialGradient>
  <filter id="sh" x="-15%" y="-15%" width="130%" height="130%"><feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#000" flood-opacity=".3"/></filter>
  <g id="snow">
    <path d="M0 -9 L0 9 M-7.8 -4.5 L7.8 4.5 M-7.8 4.5 L7.8 -4.5 M-2.5 -6.5 L0 -4.5 L2.5 -6.5 M-2.5 6.5 L0 4.5 L2.5 6.5" stroke="#ffffff" stroke-width="1.3" stroke-linecap="round" fill="none" opacity=".9"/>
  </g>
</defs>
<g class="fall" style="animation-delay:0s"><g transform="translate(130 15)"><use href="#snow" transform="scale(.9)"/></g></g>
<g class="fall" style="animation-delay:-0.375s"><g transform="translate(360 10)"><use href="#snow" transform="scale(.75)"/></g></g>
<g class="fall" style="animation-delay:-0.75s"><g transform="translate(70 45)"><use href="#snow" transform="scale(.85)"/></g></g>
<g class="fall" style="animation-delay:-1.125s"><g transform="translate(420 30)"><use href="#snow" transform="scale(.7)"/></g></g>
<g class="fall" style="animation-delay:-1.5s"><g transform="translate(240 10)"><use href="#snow" transform="scale(.95)"/></g></g>
<g class="fall" style="animation-delay:-1.875s"><g transform="translate(180 50)"><use href="#snow" transform="scale(.65)"/></g></g>
<g class="fall" style="animation-delay:-2.25s"><g transform="translate(310 25)"><use href="#snow" transform="scale(.8)"/></g></g>
<g class="fall" style="animation-delay:-2.625s"><g transform="translate(100 65)"><use href="#snow" transform="scale(.75)"/></g></g>
<g filter="url(#sh)">
<g class="sway">
  <rect x="232" y="420" width="36" height="52" rx="4" fill="url(#trunk)"/>
  <path d="M250 290 L395 425 Q355 436 320 422 Q285 436 250 422 Q215 436 180 422 Q145 436 105 425 Z" fill="url(#pine3)" stroke="#064e3b" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M250 195 L355 315 Q325 326 295 314 Q272 326 250 314 Q228 326 205 314 Q175 326 145 315 Z" fill="url(#pine2)" stroke="#064e3b" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M250 95 L315 215 Q290 225 270 215 Q250 225 230 215 Q210 225 185 215 Z" fill="url(#pine1)" stroke="#064e3b" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M205 180 Q250 210 295 185" stroke="#fef08a" stroke-width="2.5" stroke-linecap="round" fill="none" opacity=".85" stroke-dasharray="3 5"/>
  <path d="M165 275 Q250 315 335 280" stroke="#fef08a" stroke-width="3" stroke-linecap="round" fill="none" opacity=".85" stroke-dasharray="4 6"/>
  <path d="M125 380 Q250 430 375 385" stroke="#fef08a" stroke-width="3.5" stroke-linecap="round" fill="none" opacity=".85" stroke-dasharray="4 7"/>
  <g class="tw1"><circle cx="230" cy="170" r="7" fill="url(#bRed)"/><circle cx="228" cy="168" r="2" fill="#fff" opacity=".8"/></g>
  <g class="tw2"><circle cx="270" cy="190" r="6.5" fill="url(#bGold)"/><circle cx="268" cy="188" r="1.8" fill="#fff" opacity=".8"/></g>
  <g class="tw3"><circle cx="180" cy="270" r="8" fill="url(#bBlue)"/><circle cx="178" cy="268" r="2.2" fill="#fff" opacity=".8"/></g>
  <g class="tw1"><circle cx="240" cy="255" r="7.5" fill="url(#bRed)"/><circle cx="238" cy="253" r="2" fill="#fff" opacity=".8"/></g>
  <g class="tw4"><circle cx="295" cy="275" r="8" fill="url(#bPurple)"/><circle cx="293" cy="273" r="2.2" fill="#fff" opacity=".8"/></g>
  <g class="tw2"><circle cx="220" cy="300" r="7" fill="url(#bGold)"/><circle cx="218" cy="298" r="1.9" fill="#fff" opacity=".8"/></g>
  <g class="tw2"><circle cx="145" cy="370" r="8.5" fill="url(#bGold)"/><circle cx="143" cy="367" r="2.3" fill="#fff" opacity=".8"/></g>
  <g class="tw3"><circle cx="205" cy="360" r="8" fill="url(#bBlue)"/><circle cx="203" cy="358" r="2.2" fill="#fff" opacity=".8"/></g>
  <g class="tw1"><circle cx="265" cy="370" r="8.5" fill="url(#bRed)"/><circle cx="263" cy="367" r="2.3" fill="#fff" opacity=".8"/></g>
  <g class="tw4"><circle cx="325" cy="360" r="8" fill="url(#bPurple)"/><circle cx="323" cy="358" r="2.2" fill="#fff" opacity=".8"/></g>
  <g class="tw2"><circle cx="360" cy="395" r="7.5" fill="url(#bGold)"/><circle cx="358" cy="393" r="2" fill="#fff" opacity=".8"/></g>
  <g class="tw1"><circle cx="130" cy="400" r="7" fill="url(#bRed)"/><circle cx="128" cy="398" r="1.9" fill="#fff" opacity=".8"/></g>
  <g class="pulse">
    <circle cx="250" cy="95" r="32" fill="url(#starHalo)"/>
    <path d="M250 68 L256 87 L276 88 L260 100 L266 119 L250 107 L234 119 L240 100 L224 88 L244 87 Z" fill="url(#starGlow)" stroke="#ca8a04" stroke-width="1.6" stroke-linejoin="round"/>
  </g>
</g>
</g>
</svg>
"""
}

