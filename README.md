# LuaJIT WinAPI OpenGL Playground

DIY graphics playground на **LuaJIT + FFI + WinAPI + OpenGL 4.3**.

Проект начался как эксперимент: можно ли без SDL/GLFW/Qt, без C-обвязки и без тяжёлого движка поднять обычное Windows-окно, создать OpenGL-контекст, загрузить шейдеры, сделать hot-reload и запустить compute shader прямо из LuaJIT.

Ответ: да, можно.

Это не production engine. Это handmade-лаборатория, где мы строим графический рантайм снизу вверх: окно, message loop, OpenGL context, shader pipeline, compute pipeline, live resize, hot reload, тесты и дальше всё, что захочется.

---

## Что уже есть

- WinAPI-окно через LuaJIT FFI
- Ресайз, перетаскивание, maximize/minimize
- Live rendering во время resize/move окна
- OpenGL 4.3 core context через WGL
- Fullscreen triangle
- GLSL graphics shader hot-reload
- GLSL compute shader hot-reload
- Compute shader пишет в texture
- Fragment shader показывает эту texture
- Texture helpers
- Input layer: keyboard/mouse state
- Старый CPU/GDI software renderer как fallback/архивный слой
- Набор regression-тестов для OpenGL, texture, compute, resize lifecycle

---

## Текущий pipeline

```text
LuaJIT
  ↓
WinAPI window / message loop
  ↓
WGL OpenGL 4.3 core context
  ↓
compute.comp
  ↓
imageStore(...) в RGBA8 texture
  ↓
memory barrier
  ↓
fullscreen.vert + fullscreen.frag
  ↓
fullscreen triangle
  ↓
SwapBuffers