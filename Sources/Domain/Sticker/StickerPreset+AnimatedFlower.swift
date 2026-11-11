import Foundation

extension StickerPreset {
    /// Mã nguồn SVG động kèm hoạt họa CSS @keyframes (Cây hoa lá đung đưa, cánh hoa rơi).
    /// Chuẩn W3C SVG 100% Native, unroll trực tiếp các cánh hoa để tương thích trọn vẹn
    /// với mọi bộ dựng đồ họa (WebKit, CoreGraphics, AppKit NSImage).
    public static let animatedFlowerSVGMarkup: String = """
<svg viewBox="-50 0 500 500" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cây hoa hồng nhạt đung đưa, cánh hoa rơi">
<style>
.sway{transform-origin:200px 470px;animation:sway 3s ease-in-out infinite}
.leaf{transform-box:fill-box;transform-origin:50% 100%;animation:leaf 1.5s ease-in-out infinite}
.spin{transform-box:fill-box;transform-origin:50% 50%;animation:spin 3s ease-in-out infinite}
.breathe{transform-box:fill-box;transform-origin:50% 50%;animation:breathe 1.5s ease-in-out infinite}
.fall{animation:fall 3s linear infinite;opacity:0}
.spark{animation:spark 1.5s ease-in-out infinite;transform-box:fill-box;transform-origin:center}
@keyframes sway{0%,100%{transform:rotate(-2deg)}50%{transform:rotate(2deg)}}
@keyframes leaf{0%,100%{transform:rotate(-6deg)}50%{transform:rotate(6deg)}}
@keyframes spin{0%,100%{transform:rotate(-10deg)}50%{transform:rotate(10deg)}}
@keyframes breathe{0%,100%{transform:scale(.96)}50%{transform:scale(1.06)}}
@keyframes fall{0%{transform:translate(0,-10px) rotate(0deg);opacity:0}15%{opacity:.95}85%{opacity:.9}100%{transform:translate(40px,470px) rotate(360deg);opacity:0}}
@keyframes spark{0%,100%{opacity:.2;transform:scale(.7)}50%{opacity:1;transform:scale(1.15)}}
</style>
<defs>
  <linearGradient id="gp" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#f472b6"/><stop offset="1" stop-color="#fbcfe8"/></linearGradient>
  <linearGradient id="gp2" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#fb7185"/><stop offset="1" stop-color="#fecdd3"/></linearGradient>
  <linearGradient id="gp3" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#e11d48"/><stop offset="1" stop-color="#fda4af"/></linearGradient>
  <linearGradient id="gl" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#15803d"/><stop offset="1" stop-color="#86efac"/></linearGradient>
  <radialGradient id="gc" cx=".4" cy=".35" r=".8"><stop offset="0" stop-color="#fef08a"/><stop offset="1" stop-color="#f59e0b"/></radialGradient>
  <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="3" stdDeviation="3" flood-color="#000" flood-opacity=".25"/></filter>
  <g id="flower">
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(45)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(90)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(135)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(180)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(225)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(270)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" transform="rotate(315)" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(22.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(67.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(112.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(157.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(202.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(247.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(292.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-16 -20 -14 -50 0 -62C14 -50 16 -20 0 0Z" transform="rotate(337.5)" fill="url(#gp2)" stroke="#be123c" stroke-width="1.4" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" transform="rotate(60)" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" transform="rotate(120)" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" transform="rotate(180)" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" transform="rotate(240)" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <path d="M0 0C-12 -14 -10 -34 0 -42C10 -34 12 -14 0 0Z" transform="rotate(300)" fill="url(#gp3)" stroke="#9f1239" stroke-width="1.2" stroke-linejoin="round"/>
    <circle r="11" fill="url(#gc)" stroke="#b45309" stroke-width="1.5"/>
    <g fill="#b45309">
      <circle cx="0" cy="-5" r="1.3"/>
      <circle cx="4.5" cy="-2.5" r="1.3"/>
      <circle cx="4.5" cy="2.5" r="1.3"/>
      <circle cx="0" cy="5" r="1.3"/>
      <circle cx="-4.5" cy="2.5" r="1.3"/>
      <circle cx="-4.5" cy="-2.5" r="1.3"/>
    </g>
  </g>
  <g id="leafshape">
    <path d="M0 0C-26 -18 -28 -62 0 -92C28 -62 26 -18 0 0Z" fill="url(#gl)" stroke="#14532d" stroke-width="2" stroke-linejoin="round"/>
    <path d="M0 -4L0 -80M0 -30L-12 -44M0 -30L12 -44M0 -50L-10 -62M0 -50L10 -62" stroke="#dcfce7" stroke-width="1.4" stroke-linecap="round" fill="none" opacity=".75"/>
  </g>
  <path id="falling_petal" d="M0 0C-18 -22 -16 -56 0 -70C16 -56 18 -22 0 0Z" fill="url(#gp)" stroke="#be185d" stroke-width="1.6" stroke-linejoin="round"/>
</defs>
<g class="fall" style="animation-delay:0s"><g transform="translate(110 30)"><use href="#falling_petal" transform="scale(.35)"/></g></g>
<g class="fall" style="animation-delay:-0.5s"><g transform="translate(280 10)"><use href="#falling_petal" transform="scale(.3)"/></g></g>
<g class="fall" style="animation-delay:-1s"><g transform="translate(60 50)"><use href="#falling_petal" transform="scale(.28)"/></g></g>
<g class="fall" style="animation-delay:-1.5s"><g transform="translate(340 40)"><use href="#falling_petal" transform="scale(.33)"/></g></g>
<g class="fall" style="animation-delay:-2s"><g transform="translate(200 15)"><use href="#falling_petal" transform="scale(.3)"/></g></g>
<g class="fall" style="animation-delay:-2.5s"><g transform="translate(160 60)"><use href="#falling_petal" transform="scale(.32)"/></g></g>
<g filter="url(#sh)">
<g class="sway">
  <path d="M200 470C194 410 210 350 200 262" stroke="#166534" stroke-width="7" stroke-linecap="round" fill="none"/>
  <path d="M203 400C240 385 262 350 268 318" stroke="#166534" stroke-width="4" stroke-linecap="round" fill="none"/>
  <path d="M198 360C165 345 142 318 136 290" stroke="#166534" stroke-width="4" stroke-linecap="round" fill="none"/>
  <g transform="translate(198 450) rotate(-62)"><g class="leaf" style="animation-delay:0s"><use href="#leafshape" transform="scale(1.1)"/></g></g>
  <g transform="translate(202 430) rotate(58)"><g class="leaf" style="animation-delay:-0.25s"><use href="#leafshape" transform="scale(1.1)"/></g></g>
  <g transform="translate(200 395) rotate(-50)"><g class="leaf" style="animation-delay:-0.5s"><use href="#leafshape" transform="scale(.9)"/></g></g>
  <g transform="translate(203 372) rotate(48)"><g class="leaf" style="animation-delay:-0.75s"><use href="#leafshape" transform="scale(.85)"/></g></g>
  <g transform="translate(205 395) rotate(70)"><g class="leaf" style="animation-delay:-1s"><use href="#leafshape" transform="scale(.6)"/></g></g>
  <g transform="translate(199 340) rotate(-40)"><g class="leaf" style="animation-delay:-1.25s"><use href="#leafshape" transform="scale(.6)"/></g></g>
  <g transform="translate(136 290)"><g class="spin" style="animation-delay:-1s"><g class="breathe" style="animation-delay:-0.5s"><use href="#flower" transform="scale(.5)"/></g></g></g>
  <g transform="translate(268 318)"><g class="spin" style="animation-delay:-2s"><g class="breathe" style="animation-delay:-1s"><use href="#flower" transform="scale(.42)"/></g></g></g>
  <g transform="translate(200 250)"><g class="spin"><g class="breathe"><use href="#flower"/></g></g></g>
</g>
</g>
<g fill="#fde047">
  <circle class="spark" cx="85" cy="200" r="3" style="animation-delay:0s"/>
  <circle class="spark" cx="320" cy="170" r="2.5" style="animation-delay:-0.25s"/>
  <circle class="spark" cx="110" cy="330" r="2" style="animation-delay:-0.5s"/>
  <circle class="spark" cx="330" cy="260" r="3" style="animation-delay:-0.75s"/>
  <circle class="spark" cx="250" cy="120" r="2.5" style="animation-delay:-1s"/>
  <circle class="spark" cx="150" cy="140" r="2" style="animation-delay:-1.25s"/>
</g>
</svg>
"""
}
