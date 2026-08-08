import os
import sys
from PyQt5.QtWidgets import QApplication
from PyQt5.QtSvg import QSvgRenderer
from PyQt5.QtGui import QImage, QPainter
from PyQt5.QtCore import Qt

svg_icon = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="fieldGrad" cx="36%" cy="34%" r="62%" fx="36%" fy="34%">
      <stop offset="0%" stop-color="#0F7A6E"/>
      <stop offset="100%" stop-color="#064A42"/>
    </radialGradient>
    <radialGradient id="lesionGrad" cx="500" cy="500" r="300" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#C4703C"/>
      <stop offset="100%" stop-color="#8E4A22"/>
    </radialGradient>
  </defs>
  
  <!-- Field -->
  <circle cx="512" cy="512" r="440" fill="url(#fieldGrad)"/>
  
  <!-- Ring -->
  <circle cx="512" cy="512" r="400" fill="none" stroke="#EDF1EF" stroke-width="26"/>
  
  <!-- Lesion -->
  <path d="M500,300 C596,292 662,352 664,442 C666,506 634,542 646,602 C658,668 594,706 520,704 C444,702 372,674 340,616 C302,548 322,462 368,406 C408,356 446,306 500,300 Z" fill="url(#lesionGrad)"/>
</svg>"""

svg_bg = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="fieldGrad" cx="36%" cy="34%" r="62%" fx="36%" fy="34%">
      <stop offset="0%" stop-color="#0F7A6E"/>
      <stop offset="100%" stop-color="#064A42"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#fieldGrad)"/>
</svg>"""

svg_fg = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="lesionGrad" cx="500" cy="500" r="300" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#C4703C"/>
      <stop offset="100%" stop-color="#8E4A22"/>
    </radialGradient>
  </defs>
  <g transform="translate(174.08, 174.08) scale(0.66)">
    <circle cx="512" cy="512" r="400" fill="none" stroke="#EDF1EF" stroke-width="26"/>
    <path d="M500,300 C596,292 662,352 664,442 C666,506 634,542 646,602 C658,668 594,706 520,704 C444,702 372,674 340,616 C302,548 322,462 368,406 C408,356 446,306 500,300 Z" fill="url(#lesionGrad)"/>
  </g>
</svg>"""

svg_splash = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="lesionGrad" cx="500" cy="500" r="300" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#C4703C"/>
      <stop offset="100%" stop-color="#8E4A22"/>
    </radialGradient>
  </defs>
  <circle cx="512" cy="512" r="400" fill="none" stroke="#EDF1EF" stroke-width="26"/>
  <path d="M500,300 C596,292 662,352 664,442 C666,506 634,542 646,602 C658,668 594,706 520,704 C444,702 372,674 340,616 C302,548 322,462 368,406 C408,356 446,306 500,300 Z" fill="url(#lesionGrad)"/>
</svg>"""

def render_svg_str(svg_content, png_path, size=1024):
    renderer = QSvgRenderer(svg_content.encode('utf-8'))
    image = QImage(size, size, QImage.Format_ARGB32)
    image.fill(Qt.transparent)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.Antialiasing)
    painter.setRenderHint(QPainter.SmoothPixmapTransform)
    renderer.render(painter)
    painter.end()
    image.save(png_path)
    print(f"Saved {png_path}")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    
    with open('app/assets/icon/icon.svg', 'w') as f:
        f.write(svg_icon)
    
    render_svg_str(svg_icon, 'app/assets/icon/icon_1024.png')
    render_svg_str(svg_bg, 'app/assets/icon/adaptive_bg.png')
    render_svg_str(svg_fg, 'app/assets/icon/adaptive_fg.png')
    render_svg_str(svg_splash, 'app/assets/icon/splash_logo.png', 320)
