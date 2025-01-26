+++
title = "Pong Clone"

[taxonomies]
tags = ["Rust", "Wgpu", "Graphics"]

[extra]
date = "2022"
img = "icon.png"
+++

[Find the code here](https://github.com/BrackenLo/not_pong)

One of my first projects using Wgpu on my own. My main focus was exploring and getting an understanding of 
it's pipelines, shaders, buffers, etc. As such, the actual gameplay, and especially the physics is lacking
and is not something I went back to fix.

<img src = "example.gif" />

## A learning experience

Looking back on this project, there are many things that I would do differently with what I know today.
Multiple shaders although a single one would do, lack of delta time, very differently layered project
structure

The project doesn't implement any frame or delta time, instead relying on vsync. Not a consideration at the
time as it just worked as intended when I ran it. However, on running this project at a later date on a setup
that has some problems with vsync, the game runs very quickly. Nowadays I find myself having some kind of time
tracking with delta time included whenever any kind of physics or movement is involved.

<br><br>

## TODO (Sorry)
